[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$BuildAPath,
    [Parameter(Mandatory)] [string]$BuildBPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$modulePath = Join-Path $PSScriptRoot 'TpcdsToolkit.psm1'
$configPath = Join-Path $repositoryRoot 'configs\tpcds\toolkit-build-v1.json'
Import-Module $modulePath -Force
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$artifactBoundary = Join-Path $repositoryRoot 'artifacts\tpcds_toolkit'

function Read-TpcdsBuild {
    param([string]$Path, [string]$ExpectedRole)
    $root = Assert-TpcdsPathUnderRoot `
        -Path ([System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))) `
        -Root $artifactBoundary `
        -Description "Build $ExpectedRole artifact root"
    $manifestPath = Join-Path $root 'build_manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Missing Build $ExpectedRole manifest: $manifestPath"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Assert-TpcdsBuildManifest -ArtifactRoot $root -Manifest $manifest -Config $config
    if ($manifest.build_role -cne $ExpectedRole) {
        throw "Expected Build $ExpectedRole role, observed $($manifest.build_role)."
    }
    return [pscustomobject][ordered]@{ root = $root; manifest = $manifest }
}

$buildA = Read-TpcdsBuild -Path $BuildAPath -ExpectedRole 'A'
$buildB = Read-TpcdsBuild -Path $BuildBPath -ExpectedRole 'B'
if ($buildA.manifest.toolkit_build_id -ceq $buildB.manifest.toolkit_build_id) {
    throw 'Build A and Build B must be distinct clean isolated builds.'
}

$builderToolchainA = [pscustomobject][ordered]@{
    image_id = $buildA.manifest.builder.image_id
    compiler_version = $buildA.manifest.builder.compiler_version
    make_version = $buildA.manifest.builder.make_version
    flex_version = $buildA.manifest.builder.flex_version
    bison_version = $buildA.manifest.builder.bison_version
    libc_identity = $buildA.manifest.builder.libc_identity
    pinned_packages = $buildA.manifest.builder.pinned_packages
}
$builderToolchainB = [pscustomobject][ordered]@{
    image_id = $buildB.manifest.builder.image_id
    compiler_version = $buildB.manifest.builder.compiler_version
    make_version = $buildB.manifest.builder.make_version
    flex_version = $buildB.manifest.builder.flex_version
    bison_version = $buildB.manifest.builder.bison_version
    libc_identity = $buildB.manifest.builder.libc_identity
    pinned_packages = $buildB.manifest.builder.pinned_packages
}
$comparison = [pscustomobject][ordered]@{
    archive_sha256_match = [bool]($buildA.manifest.archive.sha256 -ceq $buildB.manifest.archive.sha256)
    source_manifest_sha256_match = [bool]($buildA.manifest.source.pre_build_manifest_sha256 -ceq $buildB.manifest.source.pre_build_manifest_sha256)
    builder_toolchain_identity_match = [bool](
        ($builderToolchainA | ConvertTo-Json -Depth 10 -Compress) -ceq
        ($builderToolchainB | ConvertTo-Json -Depth 10 -Compress)
    )
    build_argv_match = [bool](
        ($buildA.manifest.build.argv -join "`n") -ceq
        ($buildB.manifest.build.argv -join "`n")
    )
    project_owned_input_hashes_match = [bool](
        ($buildA.manifest.repository.project_owned_input_hashes | ConvertTo-Json -Depth 8 -Compress) -ceq
        ($buildB.manifest.repository.project_owned_input_hashes | ConvertTo-Json -Depth 8 -Compress)
    )
    dsdgen_sha256_match = [bool]($buildA.manifest.artifacts.dsdgen.sha256 -ceq $buildB.manifest.artifacts.dsdgen.sha256)
    tpcds_idx_sha256_match = [bool]($buildA.manifest.artifacts.tpcds_idx.sha256 -ceq $buildB.manifest.artifacts.tpcds_idx.sha256)
}
$allMatch = $true
foreach ($property in $comparison.PSObject.Properties) {
    if (-not [bool]$property.Value) {
        $allMatch = $false
    }
}

$report = [pscustomobject][ordered]@{
    schema_version = 'tpcds_toolkit_repeat_build_verification/v1'
    verified_at_utc = [DateTime]::UtcNow.ToString('o')
    status = if ($allMatch) { 'MATCH' } else { 'MISMATCH' }
    bit_reproducible_for_observed_artifacts = [bool]$allMatch
    build_a = [pscustomobject][ordered]@{
        toolkit_build_id = $buildA.manifest.toolkit_build_id
        repository_relative_path = $buildA.root.Substring($repositoryRoot.Length + 1).Replace([char]92, [char]47)
        source_manifest_sha256 = $buildA.manifest.source.pre_build_manifest_sha256
        builder_image_id = $buildA.manifest.builder.image_id
        dsdgen_size_bytes = [int64]$buildA.manifest.artifacts.dsdgen.size_bytes
        dsdgen_sha256 = $buildA.manifest.artifacts.dsdgen.sha256
        tpcds_idx_size_bytes = [int64]$buildA.manifest.artifacts.tpcds_idx.size_bytes
        tpcds_idx_sha256 = $buildA.manifest.artifacts.tpcds_idx.sha256
    }
    build_b = [pscustomobject][ordered]@{
        toolkit_build_id = $buildB.manifest.toolkit_build_id
        repository_relative_path = $buildB.root.Substring($repositoryRoot.Length + 1).Replace([char]92, [char]47)
        source_manifest_sha256 = $buildB.manifest.source.pre_build_manifest_sha256
        builder_image_id = $buildB.manifest.builder.image_id
        dsdgen_size_bytes = [int64]$buildB.manifest.artifacts.dsdgen.size_bytes
        dsdgen_sha256 = $buildB.manifest.artifacts.dsdgen.sha256
        tpcds_idx_size_bytes = [int64]$buildB.manifest.artifacts.tpcds_idx.size_bytes
        tpcds_idx_sha256 = $buildB.manifest.artifacts.tpcds_idx.sha256
    }
    comparisons = $comparison
    negative_result_notes = if ($allMatch) { @() } else { @('One or more frozen build identities differ. No bit-reproducibility claim is permitted until the difference is explained.') }
}

$verificationRoot = Join-Path $artifactBoundary 'verification'
if (-not (Test-Path -LiteralPath $verificationRoot)) {
    [void](New-Item -ItemType Directory -Path $verificationRoot)
}
$timestamp = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")
$reportPath = Join-Path $verificationRoot "repeat-build-$timestamp.json"
if (Test-Path -LiteralPath $reportPath) {
    throw "Refusing to overwrite P04B repeat-build report: $reportPath"
}
Write-TpcdsUtf8Lf -Path $reportPath -Text (($report | ConvertTo-Json -Depth 15) + "`n")
Write-Host "TPCDS_REPEAT_BUILD_REPORT=$reportPath"
Write-Host "TPCDS_REPEAT_BUILD_STATUS=$($report.status)"
if (-not $allMatch) {
    throw 'TPC-DS Build A / Build B identities differ; see the retained negative-result report.'
}
Write-Host 'TPCDS_REPEAT_BUILD_VERIFICATION=PASS'
