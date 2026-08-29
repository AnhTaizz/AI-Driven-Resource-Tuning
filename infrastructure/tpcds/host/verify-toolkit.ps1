[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ArtifactPath,
    [switch]$NoWriteReport
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$modulePath = Join-Path $PSScriptRoot 'TpcdsToolkit.psm1'
$nativeHelper = Join-Path $repositoryRoot 'infrastructure\docker\host\native-command.ps1'
$configPath = Join-Path $repositoryRoot 'configs\tpcds\toolkit-build-v1.json'
Import-Module $modulePath -Force
. $nativeHelper

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$artifactBoundary = Join-Path $repositoryRoot 'artifacts\tpcds_toolkit'
$resolvedArtifact = Assert-TpcdsPathUnderRoot `
    -Path ([System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $ArtifactPath))) `
    -Root $artifactBoundary `
    -Description 'verification artifact root'
if (-not (Test-Path -LiteralPath $resolvedArtifact -PathType Container)) {
    throw "Missing P04B artifact root: $resolvedArtifact"
}
if ($resolvedArtifact.StartsWith((Join-Path $artifactBoundary '.work'), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'P04B verification requires a promoted artifact root, not a .work path.'
}
Assert-TpcdsNoReparsePoint -Path $resolvedArtifact -Description 'promoted artifact root'

$manifestPath = Join-Path $resolvedArtifact 'build_manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing P04B build manifest: $manifestPath"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-TpcdsBuildManifest -ArtifactRoot $resolvedArtifact -Manifest $manifest -Config $config
foreach ($inputRecord in $manifest.repository.project_owned_input_hashes) {
    $inputPath = Assert-TpcdsPathUnderRoot `
        -Path (Join-Path $repositoryRoot ($inputRecord.repository_relative_path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))) `
        -Root $repositoryRoot `
        -Description 'project-owned build input'
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        throw "Missing project-owned P04B build input: $($inputRecord.repository_relative_path)"
    }
    $inputItem = Get-Item -LiteralPath $inputPath
    if ([int64]$inputItem.Length -ne [int64]$inputRecord.size_bytes -or
        (Get-TpcdsSha256 -Path $inputPath) -cne $inputRecord.sha256) {
        throw "Project-owned P04B build input changed after the build: $($inputRecord.repository_relative_path)"
    }
}

$archivePath = Assert-TpcdsPathUnderRoot `
    -Path (Join-Path $repositoryRoot ($config.archive.repository_relative_path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))) `
    -Root $repositoryRoot `
    -Description 'archive path'
$archive = Get-TpcdsArchiveInspection `
    -ArchivePath $archivePath `
    -ExpectedSizeBytes ([int64]$config.archive.size_bytes) `
    -ExpectedSha256 ([string]$config.archive.sha256) `
    -AllowedTopLevelRoots ([string[]]$config.archive_layout.allowed_top_level_roots) `
    -RequiredRegularFiles ([string[]]$config.archive_layout.required_regular_files)

$workspace = Join-Path $artifactBoundary ".work\$($manifest.toolkit_build_id)"
$sourceRoot = Join-Path $workspace 'source'
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Missing retained immutable P04B source workspace: $sourceRoot"
}
$sourceIdentity = Assert-TpcdsSourceIdentity `
    -SourceRoot $sourceRoot `
    -ExpectedSha256 $manifest.source.pre_build_manifest_sha256

$imageResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
    'image', 'inspect', '--format', '{{.Id}}|{{.Os}}|{{.Architecture}}', $manifest.builder.image_reference
) -NoEcho
$imageIdentity = $imageResult.StdOut | Select-Object -First 1
if ($imageIdentity -cne "$($manifest.builder.image_id)|linux|amd64") {
    throw "Current local P04B builder image identity differs from the manifest: $imageIdentity"
}
$metadataResult = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
    'run', '--rm', '--platform', 'linux/amd64', '--network', 'none',
    '--read-only', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
    $manifest.builder.image_reference, '--metadata-only'
) -NoEcho
$metadata = @{}
foreach ($line in $metadataResult.StdOut) {
    if ($line -match '^([A-Z0-9_]+)=(.*)$') {
        $metadata[$matches[1]] = $matches[2]
    }
}
foreach ($comparison in @(
    @('COMPILER_VERSION', [string]$manifest.builder.compiler_version),
    @('MAKE_VERSION', [string]$manifest.builder.make_version),
    @('FLEX_VERSION', [string]$manifest.builder.flex_version),
    @('BISON_VERSION', [string]$manifest.builder.bison_version),
    @('LIBC_IDENTITY', [string]$manifest.builder.libc_identity)
)) {
    if (-not $metadata.ContainsKey($comparison[0]) -or $metadata[$comparison[0]] -cne $comparison[1]) {
        throw "P04B builder toolchain identity changed for $($comparison[0])."
    }
}

$forbidden = @(
    @(Get-TpcdsForbiddenArtifacts -Root $workspace) +
    @(Get-TpcdsForbiddenArtifacts -Root $resolvedArtifact)
)
if ($forbidden.Count -ne 0) {
    throw "P04B no-data check found forbidden artifacts: $($forbidden -join ', ')"
}
if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'B0CF2ADA-2F20-4296-A89C-81B8202DCD13-TPC-DS-Tool')) {
    throw 'The historical vendored TPC-DS path was restored unexpectedly.'
}
$trackedArtifact = @((Invoke-NativeCommand -FilePath 'git' -ArgumentList @(
    'ls-files', '--', "artifacts/tpcds_toolkit/$($manifest.toolkit_build_id)"
) -NoEcho).StdOut)
if ($trackedArtifact.Count -ne 0) {
    throw "P04B local artifacts are tracked by Git: $($trackedArtifact -join ', ')"
}
$ignoreResult = Invoke-NativeCommand -FilePath 'git' -ArgumentList @(
    'check-ignore', '-q', '--', "artifacts/tpcds_toolkit/$($manifest.toolkit_build_id)/bin/dsdgen"
) -AllowNonZero -NoEcho
if ($ignoreResult.ExitCode -ne 0) {
    throw 'P04B local artifacts are not protected by the scoped Git ignore rule.'
}
$dockerChanges = @(
    (Invoke-NativeCommand -FilePath 'git' -ArgumentList @(
        'status', '--short', '--untracked-files=all', '--', 'infrastructure/docker'
    ) -NoEcho).StdOut | Where-Object {
        $_ -notmatch 'infrastructure/docker/observability/src/main/java/localyarn/LocalYarnObservability\.java$'
    }
)
if ($dockerChanges.Count -ne 0) {
    throw "P04B detected changes under LOCAL_YARN_V1 infrastructure: $($dockerChanges -join ', ')"
}

$report = [pscustomobject][ordered]@{
    schema_version = 'tpcds_toolkit_no_data_verification/v1'
    toolkit_build_id = $manifest.toolkit_build_id
    verified_at_utc = [DateTime]::UtcNow.ToString('o')
    status = 'PASS'
    archive = [pscustomobject][ordered]@{
        size_bytes = [int64]$archive.size_bytes
        sha256 = $archive.sha256
        unchanged = $true
    }
    source = [pscustomobject][ordered]@{
        manifest_sha256 = $sourceIdentity.sha256
        file_count = [int]$sourceIdentity.file_count
        unchanged = $true
    }
    builder = [pscustomobject][ordered]@{
        image_id = $manifest.builder.image_id
        platform = $manifest.builder.platform
        toolchain_matches_manifest = $true
        project_owned_input_hashes_match = $true
        network_during_toolkit_build = 'none'
    }
    artifacts = [pscustomobject][ordered]@{
        dsdgen_sha256 = $manifest.artifacts.dsdgen.sha256
        tpcds_idx_sha256 = $manifest.artifacts.tpcds_idx.sha256
        manifest_sizes_and_hashes_match = $true
        dsdgen_elf_linux_amd64 = $true
    }
    boundaries = [pscustomobject][ordered]@{
        dsdgen_executed = $false
        dataset_files_found = $false
        hdfs_action = $false
        spark_action = $false
        yarn_action = $false
        tpcds_debug_created = $false
        tpcds_sf1_created = $false
        exp_001_run = $false
        historical_vendored_tree_restored = $false
        local_yarn_v1_changed = $false
        artifact_tracked_by_git = $false
        artifact_ignored_by_git = $true
    }
}

if (-not $NoWriteReport) {
    $reportPath = Join-Path $resolvedArtifact 'logs\no-data-verification.json'
    if (Test-Path -LiteralPath $reportPath) {
        throw "Refusing to overwrite existing P04B verification report: $reportPath"
    }
    Write-TpcdsUtf8Lf -Path $reportPath -Text (($report | ConvertTo-Json -Depth 12) + "`n")
    Write-Host "TPCDS_NO_DATA_VERIFICATION_REPORT=$reportPath"
}
Write-Host "TPCDS_NO_DATA_BUILD_ID=$($manifest.toolkit_build_id)"
Write-Host 'TPCDS_TOOLKIT_NO_DATA_VERIFICATION=PASS'
