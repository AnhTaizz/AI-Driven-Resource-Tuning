[CmdletBinding()]
param(
    [ValidateSet('A', 'B', 'SINGLE')]
    [string]$BuildRole = 'SINGLE',
    [switch]$RebuildBuilderImage
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$modulePath = Join-Path $PSScriptRoot 'TpcdsToolkit.psm1'
$nativeHelper = Join-Path $repositoryRoot 'infrastructure\docker\host\native-command.ps1'
$configPath = Join-Path $repositoryRoot 'configs\tpcds\toolkit-build-v1.json'
$dockerfilePath = Join-Path $repositoryRoot 'infrastructure\tpcds\Dockerfile'
$dockerContext = Join-Path $repositoryRoot 'infrastructure\tpcds'
$containerBuildScript = Join-Path $dockerContext 'build-toolkit.sh'

Import-Module $modulePath -Force
. $nativeHelper

function ConvertTo-TpcdsMetadataMap {
    param([string[]]$Lines)
    $result = @{}
    foreach ($line in $Lines) {
        if ($line -match '^([A-Z0-9_]+)=(.*)$') {
            if ($result.ContainsKey($matches[1])) {
                throw "Duplicate builder metadata key: $($matches[1])"
            }
            $result[$matches[1]] = $matches[2]
        }
    }
    return $result
}

function Assert-TpcdsBuilderMetadata {
    param([hashtable]$Metadata, [psobject]$Config)
    foreach ($key in @(
        'OS_ID', 'OS_VERSION_ID', 'ARCHITECTURE', 'LIBC_IDENTITY',
        'COMPILER_VERSION', 'MAKE_VERSION', 'FLEX_VERSION', 'BISON_VERSION',
        'BINUTILS_VERSION', 'FILE_VERSION'
    )) {
        if (-not $Metadata.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($Metadata[$key])) {
            throw "Builder metadata is missing $key."
        }
    }
    if ($Metadata['OS_ID'] -cne 'debian' -or $Metadata['OS_VERSION_ID'] -cne '12' -or
        $Metadata['ARCHITECTURE'] -cne 'x86_64') {
        throw "Unexpected builder OS/architecture: $($Metadata['OS_ID'])/$($Metadata['OS_VERSION_ID'])/$($Metadata['ARCHITECTURE'])"
    }
    foreach ($property in $Config.builder.packages.PSObject.Properties) {
        $key = 'PACKAGE_' + $property.Name.Replace('-', '_').ToUpperInvariant()
        if (-not $Metadata.ContainsKey($key)) {
            throw "Builder metadata is missing pinned package $($property.Name)."
        }
        if ($Metadata[$key] -cne [string]$property.Value) {
            throw "Builder package $($property.Name) mismatch. Expected $($property.Value), observed $($Metadata[$key])."
        }
    }
}

function Get-TpcdsProjectInputRecords {
    param([string[]]$Paths)
    return @($Paths | ForEach-Object {
        $resolved = (Resolve-Path -LiteralPath $_).Path
        [pscustomobject][ordered]@{
            repository_relative_path = $resolved.Substring($repositoryRoot.Length + 1).Replace([char]92, [char]47)
            size_bytes = [int64](Get-Item -LiteralPath $resolved).Length
            sha256 = Get-TpcdsSha256 -Path $resolved
        }
    })
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ($config.schema_version -cne 'tpcds_toolkit_build_config/v1') {
    throw 'Unexpected TPC-DS toolkit build config schema.'
}
$branch = (Invoke-NativeCommand -FilePath 'git' -ArgumentList @('branch', '--show-current') -NoEcho).StdOut | Select-Object -First 1
if ($branch -cne 'tpcds-integrate') {
    throw "P04B must run from branch tpcds-integrate; observed $branch."
}

$archivePath = Assert-TpcdsPathUnderRoot `
    -Path (Join-Path $repositoryRoot ($config.archive.repository_relative_path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))) `
    -Root $repositoryRoot `
    -Description 'archive path'
$artifactRoot = Join-Path $repositoryRoot 'artifacts\tpcds_toolkit'
$workRoot = Join-Path $artifactRoot '.work'
$ignoreProbe = 'artifacts/tpcds_toolkit/.work/P04B_IGNORE_PROBE'
$ignoreResult = Invoke-NativeCommand -FilePath 'git' -ArgumentList @('check-ignore', '-q', '--', $ignoreProbe) -AllowNonZero -NoEcho
if ($ignoreResult.ExitCode -ne 0) {
    throw 'artifacts/tpcds_toolkit/ is not protected by a Git ignore rule.'
}

$inspection = Get-TpcdsArchiveInspection `
    -ArchivePath $archivePath `
    -ExpectedSizeBytes ([int64]$config.archive.size_bytes) `
    -ExpectedSha256 ([string]$config.archive.sha256) `
    -AllowedTopLevelRoots ([string[]]$config.archive_layout.allowed_top_level_roots) `
    -RequiredRegularFiles ([string[]]$config.archive_layout.required_regular_files)

$builderBuildOutput = @('BUILDER_IMAGE_REUSED=true')
$imageInspect = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
    'image', 'inspect', $config.builder.local_image_tag
) -AllowNonZero -NoEcho
if ($RebuildBuilderImage -or $imageInspect.ExitCode -ne 0) {
    $builderBuildResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
        'build',
        '--platform', $config.builder.platform,
        '--pull=false',
        '--tag', $config.builder.local_image_tag,
        '--file', $dockerfilePath,
        $dockerContext
    ) -AllowNonZero -NoEcho
    $builderBuildOutput = @($builderBuildResult.Combined)
    if ($builderBuildResult.ExitCode -ne 0) {
        throw "Dedicated TPC-DS builder image failed to build (exit $($builderBuildResult.ExitCode))."
    }
}

$imageIdentityResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
    'image', 'inspect', '--format', '{{.Id}}|{{.Os}}|{{.Architecture}}', $config.builder.local_image_tag
) -NoEcho
$imageIdentityParts = (($imageIdentityResult.StdOut | Select-Object -First 1) -split '\|')
if ($imageIdentityParts.Count -ne 3 -or $imageIdentityParts[0] -notmatch '^sha256:[0-9a-f]{64}$' -or
    $imageIdentityParts[1] -cne 'linux' -or $imageIdentityParts[2] -cne 'amd64') {
    throw "Unexpected local builder image identity: $($imageIdentityParts -join '|')"
}
$builderImageId = $imageIdentityParts[0]
$builderDigestFirst12 = $builderImageId.Substring(7, 12)

$metadataResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
    'run', '--rm', '--platform', $config.builder.platform,
    '--network', 'none', '--read-only', '--cap-drop', 'ALL',
    '--security-opt', 'no-new-privileges',
    $config.builder.local_image_tag, '--metadata-only'
) -NoEcho
$builderMetadata = ConvertTo-TpcdsMetadataMap -Lines $metadataResult.StdOut
Assert-TpcdsBuilderMetadata -Metadata $builderMetadata -Config $config

$timestamp = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")
$toolkitBuildId = "tpcds-tools-4.0.0-$($config.archive.sha256.Substring(0,12))-$builderDigestFirst12-$timestamp"
$workspace = Join-Path $workRoot $toolkitBuildId
$sourceRoot = Join-Path $workspace 'source'
$buildRoot = Join-Path $workspace 'build'
$workspaceLogs = Join-Path $workspace 'logs'
$promotionParent = Join-Path $workspace 'promotion'
$stagingRoot = Join-Path $promotionParent $toolkitBuildId
$finalRoot = Join-Path $artifactRoot $toolkitBuildId
$buildStartedAt = [DateTime]::UtcNow

if (Test-Path -LiteralPath $workspace) {
    throw "Unique P04B workspace already exists: $workspace"
}
if (Test-Path -LiteralPath $finalRoot) {
    throw "P04B final artifact path already exists: $finalRoot"
}
if (-not (Test-Path -LiteralPath $artifactRoot)) {
    [void](New-Item -ItemType Directory -Path $artifactRoot)
}
Assert-TpcdsNoReparsePoint -Path $artifactRoot -Description 'artifact root'
if (-not (Test-Path -LiteralPath $workRoot)) {
    [void](New-Item -ItemType Directory -Path $workRoot)
}
Assert-TpcdsNoReparsePoint -Path $workRoot -Description 'workspace root'
[void](New-Item -ItemType Directory -Path $workspace)
[void](New-Item -ItemType Directory -Path $buildRoot)
[void](New-Item -ItemType Directory -Path $workspaceLogs)
[void](New-Item -ItemType Directory -Path $promotionParent)

$failure = $null
try {
    Expand-TpcdsArchiveProtected -Inspection $inspection -DestinationRoot $sourceRoot
    $sourceManifestPath = Join-Path $workspace 'source_manifest.txt'
    $sourceManifest = Write-TpcdsSourceManifest -SourceRoot $sourceRoot -ManifestPath $sourceManifestPath

    $releaseHeader = Join-Path $sourceRoot "$($config.archive_layout.source_root)\tools\release.h"
    $releaseText = Get-Content -LiteralPath $releaseHeader -Raw
    if ($releaseText -notmatch '#define\s+VERSION\s+4' -or
        $releaseText -notmatch '#define\s+RELEASE\s+0' -or
        $releaseText -notmatch '#define\s+MODIFICATION\s+0') {
        throw 'Extracted release.h does not identify toolkit version 4.0.0.'
    }

    Write-TpcdsUtf8Lf `
        -Path (Join-Path $workspaceLogs 'builder-image-build.log') `
        -Text ((@($builderBuildOutput) -join "`n") + "`n")
    Write-TpcdsUtf8Lf `
        -Path (Join-Path $workspaceLogs 'builder-preflight.txt') `
        -Text ((@($metadataResult.StdOut) -join "`n") + "`n")

    $dockerArguments = @(
        'run', '--rm', '--platform', $config.builder.platform,
        '--network', 'none', '--read-only', '--cap-drop', 'ALL',
        '--security-opt', 'no-new-privileges',
        '--tmpfs', '/tmp:rw,noexec,nosuid,size=64m',
        '--user', '65534:65534',
        '--mount', "type=bind,source=$archivePath,target=/input/archive.zip,readonly",
        '--mount', "type=bind,source=$sourceRoot,target=/source,readonly",
        '--mount', "type=bind,source=$buildRoot,target=/workspace",
        '--env', "TPCDS_ARCHIVE_SHA256=$($config.archive.sha256)",
        '--env', "TPCDS_ARCHIVE_SIZE_BYTES=$($config.archive.size_bytes)",
        '--env', "TPCDS_SOURCE_ROOT=$($config.archive_layout.source_root)",
        $config.builder.local_image_tag,
        '--build'
    )
    $buildResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList $dockerArguments -AllowNonZero -NoEcho
    Write-TpcdsUtf8Lf `
        -Path (Join-Path $workspaceLogs 'build.log') `
        -Text ((@($buildResult.Combined) -join "`n") + "`n")
    if ($buildResult.ExitCode -ne 0) {
        throw "TPC-DS isolated container build failed (exit $($buildResult.ExitCode))."
    }
    if ((@($buildResult.Combined) -join "`n") -notmatch 'TPCDS_TOOLKIT_CONTAINER_BUILD=PASS') {
        throw 'TPC-DS builder did not emit its explicit PASS marker.'
    }

    $archivePost = Get-TpcdsArchiveInspection `
        -ArchivePath $archivePath `
        -ExpectedSizeBytes ([int64]$config.archive.size_bytes) `
        -ExpectedSha256 ([string]$config.archive.sha256) `
        -AllowedTopLevelRoots ([string[]]$config.archive_layout.allowed_top_level_roots) `
        -RequiredRegularFiles ([string[]]$config.archive_layout.required_regular_files)
    $sourcePost = Assert-TpcdsSourceIdentity `
        -SourceRoot $sourceRoot `
        -ExpectedSha256 $sourceManifest.sha256

    $containerOutput = Join-Path $buildRoot 'output'
    $containerEvidence = Join-Path $buildRoot 'evidence'
    if (-not (Test-Path -LiteralPath $containerOutput -PathType Container)) {
        throw 'P04B builder did not create its bounded output staging directory.'
    }
    Move-Item -LiteralPath $containerOutput -Destination $stagingRoot
    [void](New-Item -ItemType Directory -Path (Join-Path $stagingRoot 'logs'))
    Copy-Item -LiteralPath $sourceManifestPath -Destination (Join-Path $stagingRoot 'logs\source_manifest.txt')
    Copy-Item -LiteralPath (Join-Path $workspaceLogs 'build.log') -Destination (Join-Path $stagingRoot 'logs\build.log')
    Copy-Item -LiteralPath (Join-Path $workspaceLogs 'builder-image-build.log') -Destination (Join-Path $stagingRoot 'logs\builder-image-build.log')
    Copy-Item -LiteralPath (Join-Path $workspaceLogs 'builder-preflight.txt') -Destination (Join-Path $stagingRoot 'logs\builder-preflight.txt')
    foreach ($evidenceName in @('toolchain.txt', 'dpkg-packages.txt', 'build-command.argv.json', 'dsdgen.file.txt', 'dsdgen.readelf.txt', 'artifact-sha256.txt')) {
        $evidencePath = Join-Path $containerEvidence $evidenceName
        if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
            throw "Missing builder evidence file: $evidenceName"
        }
        Copy-Item -LiteralPath $evidencePath -Destination (Join-Path $stagingRoot "logs\$evidenceName")
    }

    $dsdgenPath = Join-Path $stagingRoot 'bin\dsdgen'
    $indexPath = Join-Path $stagingRoot 'share\tpcds\tpcds.idx'
    if (-not (Test-Path -LiteralPath $dsdgenPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        throw 'P04B builder output is missing dsdgen or tpcds.idx.'
    }
    Assert-TpcdsElfAmd64 -Path $dsdgenPath
    $forbidden = @(Get-TpcdsForbiddenArtifacts -Root $workspace)
    if ($forbidden.Count -ne 0) {
        throw "P04B created forbidden dataset artifacts: $($forbidden -join ', ')"
    }

    $codeRevision = (Invoke-NativeCommand -FilePath 'git' -ArgumentList @('rev-parse', 'HEAD') -NoEcho).StdOut | Select-Object -First 1
    $projectInputs = Get-TpcdsProjectInputRecords -Paths @(
        $configPath,
        $dockerfilePath,
        $containerBuildScript,
        $modulePath,
        $PSCommandPath,
        (Join-Path $PSScriptRoot 'verify-toolkit.ps1'),
        (Join-Path $PSScriptRoot 'compare-toolkit-builds.ps1'),
        (Join-Path $repositoryRoot 'tests\tpcds\test_tpcds_toolkit_contract.ps1')
    )
    $warningLines = @($buildResult.Combined | Where-Object { $_ -match '(?i)warning:' })
    $buildEndedAt = [DateTime]::UtcNow
    $dsdgenItem = Get-Item -LiteralPath $dsdgenPath
    $indexItem = Get-Item -LiteralPath $indexPath
    $manifest = [pscustomobject][ordered]@{
        schema_version = 'tpcds_toolkit_build_manifest/v1'
        toolkit_build_id = $toolkitBuildId
        build_role = $BuildRole
        toolkit = [pscustomobject][ordered]@{
            name = $config.toolkit.name
            version = $config.toolkit.version
            source_version_evidence = 'DSGen-software-code-4.0.0/tools/release.h macros VERSION=4, RELEASE=0, MODIFICATION=0, PATCH=""'
        }
        status = 'COMPLETE'
        archive = [pscustomobject][ordered]@{
            repository_relative_path = $config.archive.repository_relative_path
            filename = Split-Path -Leaf $archivePath
            size_bytes = [int64]$inspection.size_bytes
            sha256 = $inspection.sha256
            checksum_kind = $config.archive.checksum_kind
            publisher_authenticated_checksum = $false
            pre_and_post_identity_match = [bool]($inspection.sha256 -ceq $archivePost.sha256)
            original_download_timestamp = $null
            temporary_download_url = $null
            acceptance_identity = $null
        }
        source = [pscustomobject][ordered]@{
            archive_entry_count = [int]$inspection.entry_count
            regular_file_count = [int]$inspection.regular_file_count
            extraction_manifest_relative_path = 'logs/source_manifest.txt'
            extraction_manifest_format = 'lowercase_sha256<TAB>size_bytes<TAB>normalized_path<LF>, ordinal path order, UTF-8 without BOM'
            pre_build_manifest_sha256 = $sourceManifest.sha256
            post_build_manifest_sha256 = $sourcePost.sha256
            manifest_file_count = [int]$sourceManifest.file_count
            manifest_total_size_bytes = [int64]$sourceManifest.total_size_bytes
            immutable_source_unchanged = [bool]($sourceManifest.sha256 -ceq $sourcePost.sha256)
            build_copy_root = "/workspace/build-source/$($config.archive_layout.source_root)"
        }
        builder = [pscustomobject][ordered]@{
            platform = $config.builder.platform
            image_reference = $config.builder.local_image_tag
            image_id = $builderImageId
            image_digest_kind = 'local_content_addressed_image_id_not_registry_digest'
            base_image_reference = $config.builder.base_image_reference
            base_image_platform_digest = $config.builder.base_image_platform_digest
            os = "$($builderMetadata['OS_ID']) $($builderMetadata['OS_VERSION_ID'])"
            architecture = $builderMetadata['ARCHITECTURE']
            libc_identity = $builderMetadata['LIBC_IDENTITY']
            compiler_version = $builderMetadata['COMPILER_VERSION']
            make_version = $builderMetadata['MAKE_VERSION']
            flex_version = $builderMetadata['FLEX_VERSION']
            bison_version = $builderMetadata['BISON_VERSION']
            binutils_version = $builderMetadata['BINUTILS_VERSION']
            file_version = $builderMetadata['FILE_VERSION']
            pinned_packages = $config.builder.packages
            complete_package_inventory_relative_path = 'logs/dpkg-packages.txt'
            network_during_toolkit_build = 'none'
            container_root_filesystem = 'read_only'
            immutable_archive_mount = '/input/archive.zip:ro'
            immutable_source_mount = '/source:ro'
        }
        build = [pscustomobject][ordered]@{
            working_directory = $config.build.working_directory
            argv = [string[]]$config.build.argv
            display_command = $config.build.display_command
            environment = $config.build.environment
            helper_closure = [string[]]$config.build.helper_closure
            required_generated_headers = [string[]]$config.build.required_generated_headers
            compatibility_flags = $config.build.compatibility_flags
            invoked_forbidden_targets = @()
            start_utc = $buildStartedAt.ToString('o')
            end_utc = $buildEndedAt.ToString('o')
            log_relative_path = 'logs/build.log'
        }
        artifacts = [pscustomobject][ordered]@{
            dsdgen = [pscustomobject][ordered]@{
                relative_path = 'bin/dsdgen'
                platform = 'linux/amd64'
                format = 'ELF64 little-endian x86-64'
                size_bytes = [int64]$dsdgenItem.Length
                sha256 = Get-TpcdsSha256 -Path $dsdgenPath
            }
            tpcds_idx = [pscustomobject][ordered]@{
                relative_path = 'share/tpcds/tpcds.idx'
                size_bytes = [int64]$indexItem.Length
                sha256 = Get-TpcdsSha256 -Path $indexPath
                lineage = 'Generated by the allowlisted Make dependency using ./distcomp -i tpcds.dst -o tpcds.idx.'
            }
            other_runtime_support = @()
        }
        distributions = [pscustomobject][ordered]@{
            parameter_name = $config.runtime.distributions_parameter
            source_default = $config.runtime.source_default
            artifact_relative_path = $config.runtime.distributions_relative_path
            resolution_mechanism = 'dsdgen CLI string parameter; dist.c opens the resolved value with fopen; not an environment-variable lookup'
            explicit_future_cli_path_required = $true
            future_invocation_contract = $config.runtime.required_future_invocation_contract
            dsdgen_executed_by_p04b = $false
        }
        repository = [pscustomobject][ordered]@{
            code_revision = $codeRevision
            branch = $branch
            project_owned_input_hashes = $projectInputs
            historical_vendored_path_restored = $false
            local_yarn_v1_modified_or_invoked = $false
        }
        no_data_verification = [pscustomobject][ordered]@{
            archive_identity_verified = $true
            source_identity_verified = $true
            builder_identity_verified = $true
            build_command_allowlisted = $true
            dsdgen_not_executed = $true
            no_dataset_files = $true
            no_hdfs_action = $true
            no_spark_action = $true
            no_yarn_action = $true
            no_tpcds_debug = $true
            no_tpcds_sf1 = $true
            no_exp_001 = $true
            no_partial_output_promoted = $true
        }
        promotion = [pscustomobject][ordered]@{
            promoted = $true
            repository_relative_path = "artifacts/tpcds_toolkit/$toolkitBuildId"
            local_only = $true
            distribution_authorized = $false
        }
        warnings = [object[]]@($warningLines | ForEach-Object {
            [pscustomobject][ordered]@{ source = 'compiler'; message = $_ }
        })
        errors = @()
        anomalies = @(
            [pscustomobject][ordered]@{
                kind = 'legacy_compiler_compatibility'
                detail = 'GCC 12 requires the explicitly frozen -fcommon compatibility flag for the upstream tentative global definitions; upstream source was not modified.'
            }
        )
    }

    $manifestPath = Join-Path $stagingRoot 'build_manifest.json'
    Write-TpcdsUtf8Lf -Path $manifestPath -Text (($manifest | ConvertTo-Json -Depth 20) + "`n")
    $parsedManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Assert-TpcdsBuildManifest -ArtifactRoot $stagingRoot -Manifest $parsedManifest -Config $config

    Move-Item -LiteralPath $stagingRoot -Destination $finalRoot
    $finalManifest = Get-Content -LiteralPath (Join-Path $finalRoot 'build_manifest.json') -Raw | ConvertFrom-Json
    Assert-TpcdsBuildManifest -ArtifactRoot $finalRoot -Manifest $finalManifest -Config $config

    Write-Host "TPCDS_TOOLKIT_BUILD_ID=$toolkitBuildId"
    Write-Host "TPCDS_TOOLKIT_BUILD_ROLE=$BuildRole"
    Write-Host "TPCDS_TOOLKIT_ARTIFACT_ROOT=$finalRoot"
    Write-Host "TPCDS_DSDGEN_SHA256=$($finalManifest.artifacts.dsdgen.sha256)"
    Write-Host "TPCDS_IDX_SHA256=$($finalManifest.artifacts.tpcds_idx.sha256)"
    Write-Host 'TPCDS_TOOLKIT_BUILD_RESULT=PASS'
} catch {
    $failure = $_
    $failureRecord = [pscustomobject][ordered]@{
        schema_version = 'tpcds_toolkit_build_failure/v1'
        toolkit_build_id = $toolkitBuildId
        build_role = $BuildRole
        status = 'FAILED'
        started_at_utc = $buildStartedAt.ToString('o')
        failed_at_utc = [DateTime]::UtcNow.ToString('o')
        failure_reason = $_.Exception.Message
        promoted = $false
        final_artifact_path_created = [bool](Test-Path -LiteralPath $finalRoot)
    }
    Write-TpcdsUtf8Lf `
        -Path (Join-Path $workspace 'failure_manifest.json') `
        -Text (($failureRecord | ConvertTo-Json -Depth 8) + "`n")
} finally {
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        $finalArchiveSha = Get-TpcdsSha256 -Path $archivePath
        if ($finalArchiveSha -cne $config.archive.sha256) {
            throw "Canonical TPC-DS archive changed during P04B. Observed $finalArchiveSha."
        }
    }
}

if ($failure) {
    throw $failure
}
