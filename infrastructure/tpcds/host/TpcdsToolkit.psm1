Set-StrictMode -Version 2.0

function Get-TpcdsSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-TpcdsUtf8Lf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Text
    )

    $normalized = $Text -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $normalized, $encoding)
}

function Assert-TpcdsPathUnderRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Root,
        [string]$Description = 'path'
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "TPC-DS $Description escapes its allowed root: $fullPath"
    }
    return $fullPath
}

function Assert-TpcdsNoReparsePoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [string]$Description = 'path'
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $item = Get-Item -Force -LiteralPath $Path
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "TPC-DS $Description must not be a symlink or reparse point: $Path"
    }
}

function Get-TpcdsZipEntryRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.IO.Compression.ZipArchive]$Zip,
        [Parameter(Mandatory)] [string[]]$AllowedTopLevelRoots,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]]$RequiredRegularFiles
    )

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $regularFiles = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $topLevelRoots = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $records = New-Object 'System.Collections.Generic.List[object]'

    foreach ($entry in $Zip.Entries) {
        $name = $entry.FullName.Replace([char]92, [char]47)
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw 'TPC-DS ZIP contains an empty entry name.'
        }
        if ($name -match '[\x00-\x1f]' -or $name.StartsWith('/') -or
            $name.StartsWith('//') -or $name -match '^[A-Za-z]:' -or
            [System.IO.Path]::IsPathRooted($name)) {
            throw "TPC-DS ZIP contains a rooted or invalid path: $name"
        }

        $isDirectory = $name.EndsWith('/')
        $trimmed = if ($isDirectory) { $name.TrimEnd('/') } else { $name }
        $segments = @($trimmed.Split('/'))
        if ($segments.Count -eq 0) {
            throw "TPC-DS ZIP contains an invalid path: $name"
        }
        foreach ($segment in $segments) {
            if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or $segment -eq '..') {
                throw "TPC-DS ZIP contains path traversal or a non-canonical segment: $name"
            }
            if ($segment.Contains(':') -or $segment.EndsWith('.') -or $segment.EndsWith(' ') -or
                $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') {
                throw "TPC-DS ZIP contains a Windows-unsafe path segment: $name"
            }
        }

        $normalized = $segments -join '/'
        if (-not $seen.Add($normalized)) {
            throw "TPC-DS ZIP contains a duplicate normalized path: $normalized"
        }

        $unixMode = ($entry.ExternalAttributes -shr 16) -band 0xFFFF
        $unixType = $unixMode -band 0xF000
        if ($unixType -eq 0xA000) {
            throw "TPC-DS ZIP contains an unexpected symlink entry: $normalized"
        }
        if ($unixType -ne 0 -and $unixType -ne 0x8000 -and $unixType -ne 0x4000) {
            throw ('TPC-DS ZIP contains an unsupported special entry ({0:X4}): {1}' -f $unixType, $normalized)
        }
        if ($isDirectory -and $unixType -eq 0x8000) {
            throw "TPC-DS ZIP entry type disagrees with its directory path: $normalized"
        }
        if (-not $isDirectory -and $unixType -eq 0x4000) {
            throw "TPC-DS ZIP entry type disagrees with its regular-file path: $normalized"
        }

        [void]$topLevelRoots.Add($segments[0])
        if (-not $isDirectory) {
            [void]$regularFiles.Add($normalized)
        }
        [void]$records.Add([pscustomobject][ordered]@{
            path = $normalized
            is_directory = [bool]$isDirectory
            size_bytes = [int64]$entry.Length
            external_attributes = [int]$entry.ExternalAttributes
        })
    }

    $observedRoots = [string[]]($topLevelRoots | ForEach-Object { [string]$_ })
    $expectedRoots = [string[]]@($AllowedTopLevelRoots)
    [Array]::Sort($observedRoots, [System.StringComparer]::Ordinal)
    [Array]::Sort($expectedRoots, [System.StringComparer]::Ordinal)
    if (($observedRoots -join "`n") -cne ($expectedRoots -join "`n")) {
        throw "Unexpected TPC-DS ZIP top-level layout. Expected [$($expectedRoots -join ', ')], observed [$($observedRoots -join ', ')]."
    }
    foreach ($required in $RequiredRegularFiles) {
        if (-not $regularFiles.Contains($required)) {
            throw "TPC-DS ZIP is missing required regular file: $required"
        }
    }

    return [object[]]($records | ForEach-Object { $_ })
}

function Get-TpcdsArchiveInspection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ArchivePath,
        [Parameter(Mandatory)] [int64]$ExpectedSizeBytes,
        [Parameter(Mandatory)] [string]$ExpectedSha256,
        [Parameter(Mandatory)] [string[]]$AllowedTopLevelRoots,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]]$RequiredRegularFiles
    )

    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        throw "Missing canonical TPC-DS archive: $ArchivePath"
    }
    Assert-TpcdsNoReparsePoint -Path $ArchivePath -Description 'archive'
    $archive = Get-Item -LiteralPath $ArchivePath
    if ([int64]$archive.Length -ne $ExpectedSizeBytes) {
        throw "TPC-DS archive size mismatch. Expected $ExpectedSizeBytes bytes, observed $($archive.Length)."
    }
    $sha256 = Get-TpcdsSha256 -Path $ArchivePath
    if ($sha256 -cne $ExpectedSha256.ToLowerInvariant()) {
        throw "TPC-DS archive SHA-256 mismatch. Expected $ExpectedSha256, observed $sha256."
    }

    Add-Type -AssemblyName System.IO.Compression
    $stream = [System.IO.File]::Open(
        $archive.FullName,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    try {
        $zip = New-Object System.IO.Compression.ZipArchive(
            $stream,
            [System.IO.Compression.ZipArchiveMode]::Read,
            $false
        )
        try {
            $records = @(Get-TpcdsZipEntryRecords `
                -Zip $zip `
                -AllowedTopLevelRoots $AllowedTopLevelRoots `
                -RequiredRegularFiles $RequiredRegularFiles)
        } finally {
            $zip.Dispose()
        }
    } finally {
        $stream.Dispose()
    }

    return [pscustomobject][ordered]@{
        path = $archive.FullName
        size_bytes = [int64]$archive.Length
        sha256 = $sha256
        entry_count = [int]$records.Count
        regular_file_count = [int]@($records | Where-Object { -not $_.is_directory }).Count
        directory_count = [int]@($records | Where-Object { $_.is_directory }).Count
        entries = [object[]]$records
    }
}

function Expand-TpcdsArchiveProtected {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Inspection,
        [Parameter(Mandatory)] [string]$DestinationRoot
    )

    if (Test-Path -LiteralPath $DestinationRoot) {
        throw "TPC-DS extraction destination already exists: $DestinationRoot"
    }
    $parent = Split-Path -Parent $DestinationRoot
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "TPC-DS extraction parent does not exist: $parent"
    }
    Assert-TpcdsNoReparsePoint -Path $parent -Description 'extraction parent'
    [void](New-Item -ItemType Directory -Path $DestinationRoot)
    Assert-TpcdsNoReparsePoint -Path $DestinationRoot -Description 'extraction root'
    $destination = (Resolve-Path -LiteralPath $DestinationRoot).Path

    Add-Type -AssemblyName System.IO.Compression
    $stream = [System.IO.File]::Open(
        $Inspection.path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    try {
        $zip = New-Object System.IO.Compression.ZipArchive(
            $stream,
            [System.IO.Compression.ZipArchiveMode]::Read,
            $false
        )
        try {
            if ($zip.Entries.Count -ne $Inspection.entry_count) {
                throw 'TPC-DS archive entry count changed between inspection and extraction.'
            }
            $recordByPath = @{}
            foreach ($record in $Inspection.entries) {
                $recordByPath[$record.path] = $record
            }
            foreach ($entry in $zip.Entries) {
                $normalized = $entry.FullName.Replace([char]92, [char]47).TrimEnd('/')
                if (-not $recordByPath.ContainsKey($normalized)) {
                    throw "TPC-DS archive entry changed between inspection and extraction: $normalized"
                }
                $record = $recordByPath[$normalized]
                $target = Assert-TpcdsPathUnderRoot `
                    -Path (Join-Path $destination ($normalized.Replace('/', [System.IO.Path]::DirectorySeparatorChar))) `
                    -Root $destination `
                    -Description 'extraction target'
                if ($record.is_directory) {
                    if (-not (Test-Path -LiteralPath $target)) {
                        [void](New-Item -ItemType Directory -Path $target)
                    }
                    continue
                }

                $targetParent = Split-Path -Parent $target
                if (-not (Test-Path -LiteralPath $targetParent)) {
                    [void](New-Item -ItemType Directory -Path $targetParent)
                }
                Assert-TpcdsNoReparsePoint -Path $targetParent -Description 'extraction directory'
                if (Test-Path -LiteralPath $target) {
                    throw "TPC-DS extraction refuses to overwrite a path: $target"
                }
                $input = $entry.Open()
                try {
                    $output = [System.IO.File]::Open(
                        $target,
                        [System.IO.FileMode]::CreateNew,
                        [System.IO.FileAccess]::Write,
                        [System.IO.FileShare]::None
                    )
                    try {
                        $input.CopyTo($output)
                    } finally {
                        $output.Dispose()
                    }
                } finally {
                    $input.Dispose()
                }
                if ((Get-Item -LiteralPath $target).Length -ne [int64]$record.size_bytes) {
                    throw "TPC-DS extracted size mismatch: $normalized"
                }
            }
        } finally {
            $zip.Dispose()
        }
    } finally {
        $stream.Dispose()
    }

    foreach ($item in Get-ChildItem -LiteralPath $destination -Force -Recurse) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "TPC-DS extraction created an unexpected reparse point: $($item.FullName)"
        }
    }
}

function Get-TpcdsSourceIdentity {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$SourceRoot)

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw "Missing TPC-DS extracted source root: $SourceRoot"
    }
    Assert-TpcdsNoReparsePoint -Path $SourceRoot -Description 'source root'
    $root = (Resolve-Path -LiteralPath $SourceRoot).Path
    $prefix = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $recordByPath = @{}
    foreach ($item in Get-ChildItem -LiteralPath $root -Force -Recurse) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "TPC-DS source contains a symlink or reparse point: $($item.FullName)"
        }
        if ($item.PSIsContainer) {
            continue
        }
        $relative = $item.FullName.Substring($prefix.Length).Replace([char]92, [char]47)
        if ($recordByPath.ContainsKey($relative)) {
            throw "TPC-DS source contains a duplicate relative path: $relative"
        }
        $recordByPath[$relative] = [pscustomobject][ordered]@{
            path = $relative
            size_bytes = [int64]$item.Length
            sha256 = Get-TpcdsSha256 -Path $item.FullName
        }
    }
    $paths = [string[]]@($recordByPath.Keys)
    [Array]::Sort($paths, [System.StringComparer]::Ordinal)
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $totalBytes = [int64]0
    foreach ($path in $paths) {
        $record = $recordByPath[$path]
        $totalBytes += $record.size_bytes
        [void]$lines.Add("$($record.sha256)`t$($record.size_bytes)`t$path")
    }
    $serialized = if ($lines.Count -eq 0) { '' } else { ($lines -join "`n") + "`n" }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $bytes = $encoding.GetBytes($serialized)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $digest = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    } finally {
        $sha.Dispose()
    }
    return [pscustomobject][ordered]@{
        sha256 = $digest
        file_count = [int]$paths.Count
        total_size_bytes = $totalBytes
        serialized_manifest = $serialized
    }
}

function Write-TpcdsSourceManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$SourceRoot,
        [Parameter(Mandatory)] [string]$ManifestPath
    )

    if (Test-Path -LiteralPath $ManifestPath) {
        throw "TPC-DS source manifest path already exists: $ManifestPath"
    }
    $identity = Get-TpcdsSourceIdentity -SourceRoot $SourceRoot
    Write-TpcdsUtf8Lf -Path $ManifestPath -Text $identity.serialized_manifest
    return [pscustomobject][ordered]@{
        path = (Resolve-Path -LiteralPath $ManifestPath).Path
        sha256 = $identity.sha256
        file_count = $identity.file_count
        total_size_bytes = $identity.total_size_bytes
    }
}

function Assert-TpcdsSourceIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$SourceRoot,
        [Parameter(Mandatory)] [string]$ExpectedSha256
    )

    $identity = Get-TpcdsSourceIdentity -SourceRoot $SourceRoot
    if ($identity.sha256 -cne $ExpectedSha256.ToLowerInvariant()) {
        throw "TPC-DS immutable source identity changed. Expected $ExpectedSha256, observed $($identity.sha256)."
    }
    return $identity
}

function Get-TpcdsForbiddenArtifacts {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) {
        return @()
    }
    return @(
        Get-ChildItem -LiteralPath $Root -Force -Recurse | Where-Object {
            ($_.PSIsContainer -and ($_.Name -ceq 'TPCDS_DEBUG' -or $_.Name -ceq 'TPCDS_SF1')) -or
            (-not $_.PSIsContainer -and $_.Extension -match '^(?i:\.dat|\.parquet|\.snappy)$')
        } | Select-Object -ExpandProperty FullName
    )
}

function Assert-TpcdsElfAmd64 {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x7f -or $bytes[1] -ne 0x45 -or
        $bytes[2] -ne 0x4c -or $bytes[3] -ne 0x46) {
        throw "TPC-DS dsdgen is not an ELF executable: $Path"
    }
    if ($bytes[4] -ne 2 -or $bytes[5] -ne 1) {
        throw "TPC-DS dsdgen is not a little-endian ELF64 executable: $Path"
    }
    $machine = [int]$bytes[18] + ([int]$bytes[19] -shl 8)
    if ($machine -ne 62) {
        throw "TPC-DS dsdgen is not an x86-64 executable (ELF e_machine=$machine): $Path"
    }
}

function Assert-TpcdsBuildManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ArtifactRoot,
        [Parameter(Mandatory)] [psobject]$Manifest,
        [psobject]$Config
    )

    if ($Manifest.schema_version -cne 'tpcds_toolkit_build_manifest/v1') {
        throw 'Unexpected TPC-DS build manifest schema_version.'
    }
    if ($Manifest.status -cne 'COMPLETE' -or -not $Manifest.promotion.promoted) {
        throw 'TPC-DS build manifest is not complete and promoted.'
    }
    $root = (Resolve-Path -LiteralPath $ArtifactRoot).Path
    if ((Split-Path -Leaf $root) -cne $Manifest.toolkit_build_id) {
        throw 'TPC-DS artifact directory does not match toolkit_build_id.'
    }
    if ($Manifest.source.pre_build_manifest_sha256 -cne $Manifest.source.post_build_manifest_sha256 -or
        -not $Manifest.source.immutable_source_unchanged) {
        throw 'TPC-DS manifest does not prove immutable source preservation.'
    }
    if ($Manifest.builder.platform -cne 'linux/amd64' -or
        $Manifest.builder.image_id -notmatch '^sha256:[0-9a-f]{64}$') {
        throw 'TPC-DS builder identity is incomplete or not linux/amd64.'
    }
    if ($Manifest.build.argv.Count -eq 0 -or $Manifest.build.working_directory -notmatch '^/workspace/') {
        throw 'TPC-DS manifest lacks the exact build command or isolated working directory.'
    }
    if ($Manifest.distributions.artifact_relative_path -cne 'share/tpcds/tpcds.idx' -or
        $Manifest.distributions.parameter_name -cne 'DISTRIBUTIONS' -or
        -not $Manifest.distributions.explicit_future_cli_path_required) {
        throw 'TPC-DS DISTRIBUTIONS runtime contract is incomplete.'
    }

    foreach ($artifactProperty in @('dsdgen', 'tpcds_idx')) {
        $artifact = $Manifest.artifacts.$artifactProperty
        $path = Assert-TpcdsPathUnderRoot `
            -Path (Join-Path $root ($artifact.relative_path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))) `
            -Root $root `
            -Description 'manifest artifact'
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Missing TPC-DS build artifact: $($artifact.relative_path)"
        }
        $item = Get-Item -LiteralPath $path
        if ([int64]$item.Length -ne [int64]$artifact.size_bytes) {
            throw "TPC-DS artifact size mismatch: $($artifact.relative_path)"
        }
        $sha256 = Get-TpcdsSha256 -Path $path
        if ($sha256 -cne $artifact.sha256) {
            throw "TPC-DS artifact SHA-256 mismatch: $($artifact.relative_path)"
        }
    }
    Assert-TpcdsElfAmd64 -Path (Join-Path $root 'bin\dsdgen')

    foreach ($requiredLog in @('logs/source_manifest.txt', 'logs/build.log', 'logs/toolchain.txt', 'logs/dpkg-packages.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $requiredLog) -PathType Leaf)) {
            throw "Missing retained P04B evidence file: $requiredLog"
        }
    }
    $forbidden = @(Get-TpcdsForbiddenArtifacts -Root $root)
    if ($forbidden.Count -ne 0) {
        throw "Forbidden dataset artifacts exist under the P04B artifact root: $($forbidden -join ', ')"
    }
    foreach ($property in @(
        'archive_identity_verified', 'source_identity_verified', 'builder_identity_verified',
        'build_command_allowlisted', 'dsdgen_not_executed', 'no_dataset_files',
        'no_hdfs_action', 'no_spark_action', 'no_yarn_action', 'no_partial_output_promoted'
    )) {
        if (-not [bool]$Manifest.no_data_verification.$property) {
            throw "TPC-DS no-data verification is missing or false: $property"
        }
    }

    if ($Config) {
        if ([int64]$Manifest.archive.size_bytes -ne [int64]$Config.archive.size_bytes -or
            $Manifest.archive.sha256 -cne $Config.archive.sha256) {
            throw 'TPC-DS manifest archive identity differs from the frozen build config.'
        }
        if (($Manifest.build.argv -join "`n") -cne ($Config.build.argv -join "`n")) {
            throw 'TPC-DS manifest build argv differs from the frozen build config.'
        }
        if ($Manifest.builder.base_image_platform_digest -cne $Config.builder.base_image_platform_digest) {
            throw 'TPC-DS manifest base image digest differs from the frozen build config.'
        }
    }
}

Export-ModuleMember -Function @(
    'Get-TpcdsSha256',
    'Write-TpcdsUtf8Lf',
    'Assert-TpcdsPathUnderRoot',
    'Assert-TpcdsNoReparsePoint',
    'Get-TpcdsArchiveInspection',
    'Expand-TpcdsArchiveProtected',
    'Get-TpcdsSourceIdentity',
    'Write-TpcdsSourceManifest',
    'Assert-TpcdsSourceIdentity',
    'Get-TpcdsForbiddenArtifacts',
    'Assert-TpcdsElfAmd64',
    'Assert-TpcdsBuildManifest'
)
