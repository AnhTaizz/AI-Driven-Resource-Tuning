[CmdletBinding()]
param([string]$ArtifactPath)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$modulePath = Join-Path $repositoryRoot 'infrastructure\tpcds\host\TpcdsToolkit.psm1'
$configPath = Join-Path $repositoryRoot 'configs\tpcds\toolkit-build-v1.json'
$dockerfilePath = Join-Path $repositoryRoot 'infrastructure\tpcds\Dockerfile'
$containerBuildPath = Join-Path $repositoryRoot 'infrastructure\tpcds\build-toolkit.sh'
$hostBuildPath = Join-Path $repositoryRoot 'infrastructure\tpcds\host\build-toolkit.ps1'
$hostVerifyPath = Join-Path $repositoryRoot 'infrastructure\tpcds\host\verify-toolkit.ps1'

Import-Module $modulePath -Force
Add-Type -AssemblyName System.IO.Compression

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$MessagePattern, [string]$FailureMessage)
    $threw = $false
    try {
        & $Action
    } catch {
        $threw = $true
        if ($MessagePattern -and $_.Exception.Message -notmatch $MessagePattern) {
            throw "$FailureMessage Unexpected error: $($_.Exception.Message)"
        }
    }
    if (-not $threw) {
        throw $FailureMessage
    }
}

function New-TestZip {
    param([string]$Path, [hashtable]$Entries)
    $stream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
    try {
        $zip = New-Object System.IO.Compression.ZipArchive(
            $stream,
            [System.IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            foreach ($name in $Entries.Keys) {
                $entry = $zip.CreateEntry($name)
                $writer = New-Object System.IO.StreamWriter(
                    $entry.Open(),
                    (New-Object System.Text.UTF8Encoding($false))
                )
                try {
                    $writer.Write([string]$Entries[$name])
                } finally {
                    $writer.Dispose()
                }
            }
        } finally {
            $zip.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-TestZipIdentity {
    param([string]$Path)
    return [pscustomobject][ordered]@{
        size = [int64](Get-Item -LiteralPath $Path).Length
        sha256 = Get-TpcdsSha256 -Path $Path
    }
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Assert-True ($config.schema_version -ceq 'tpcds_toolkit_build_config/v1') 'Unexpected TPC-DS build config schema.'
Assert-True ([int64]$config.archive.size_bytes -eq 7479651) 'Frozen TPC-DS archive size changed.'
Assert-True ($config.archive.sha256 -ceq 'd63e2bf093e23964b393364991be9fdd7a9cdd40fcdf91f99660eabde4c6162d') 'Frozen TPC-DS archive SHA-256 changed.'
Assert-True ($config.builder.base_image_platform_digest -match '^sha256:[0-9a-f]{64}$') 'Builder base is not pinned by an immutable digest.'
Assert-True ($config.builder.platform -ceq 'linux/amd64') 'Builder platform is not linux/amd64.'
Assert-True (($config.build.argv -join "`n") -ceq (@(
    'make', '-f', 'makefile', 'OS=LINUX', 'CC=gcc', 'LEX=flex',
    'YACC=bison -y', 'LINUX_CFLAGS=-g -Wall -fcommon', 'dsdgen', 'tpcds.idx'
) -join "`n")) 'Allowlisted TPC-DS build argv changed.'

$dockerfileText = Get-Content -LiteralPath $dockerfilePath -Raw
$containerBuildText = Get-Content -LiteralPath $containerBuildPath -Raw
$hostBuildText = Get-Content -LiteralPath $hostBuildPath -Raw
$hostVerifyText = Get-Content -LiteralPath $hostVerifyPath -Raw
Assert-True ($dockerfileText -match [regex]::Escape($config.builder.base_image_platform_digest)) 'Dockerfile does not use the frozen base image digest.'
foreach ($property in $config.builder.packages.PSObject.Properties) {
    Assert-True ($dockerfileText -match [regex]::Escape([string]$property.Value)) "Dockerfile does not pin package $($property.Name)."
}
Assert-True ($containerBuildText -match 'make -f makefile OS=LINUX CC=gcc LEX=flex' -and $containerBuildText -match 'LINUX_CFLAGS=-g -Wall -fcommon') 'Container wrapper lacks the exact allowlisted make invocation or frozen GCC compatibility flag.'
Assert-True ($containerBuildText -notmatch '(?m)^\s*(?:\./)?dsdgen(?:\s|$)') 'Container wrapper executes dsdgen.'
Assert-True (($containerBuildText + $hostBuildText + $hostVerifyText) -notmatch '(?i)docker\s+compose|spark-submit|hdfs\s+dfs|/ws/v1/cluster') 'P04B tooling reaches LOCAL_YARN_V1, Spark, HDFS, or YARN.'
Assert-True ($hostBuildText -match "'--network', 'none'" -and $hostBuildText -match 'target=/source,readonly') 'P04B build container lacks network isolation or a read-only source mount.'
Assert-True ($hostBuildText -notmatch '(?i)Invoke-WebRequest|Invoke-RestMethod|curl|wget') 'P04B host wrapper contains a download path.'
Assert-True ($hostVerifyText -match 'project_owned_input_hashes' -and $hostVerifyText -match 'build input changed after the build') 'P04B verifier does not bind current project-owned inputs to the build manifest.'
foreach ($forbiddenTarget in $config.build.forbidden_targets) {
    Assert-True (-not ($config.build.argv -ccontains [string]$forbiddenTarget)) "Forbidden make target is allowlisted: $forbiddenTarget"
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tpcds-p04b-test-" + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temporaryRoot)
try {
    $identityZip = Join-Path $temporaryRoot 'identity.zip'
    New-TestZip -Path $identityZip -Entries @{ 'expected/file.txt' = 'identity' }
    $identity = Get-TestZipIdentity -Path $identityZip
    Assert-Throws -Action {
        Get-TpcdsArchiveInspection `
            -ArchivePath $identityZip `
            -ExpectedSizeBytes $identity.size `
            -ExpectedSha256 ('0' * 64) `
            -AllowedTopLevelRoots @('expected') `
            -RequiredRegularFiles @('expected/file.txt')
    } -MessagePattern 'SHA-256 mismatch' -FailureMessage 'Archive identity mismatch was not rejected.'

    $unsafeZip = Join-Path $temporaryRoot 'unsafe.zip'
    New-TestZip -Path $unsafeZip -Entries @{ '../escape.txt' = 'escape' }
    $unsafeIdentity = Get-TestZipIdentity -Path $unsafeZip
    Assert-Throws -Action {
        Get-TpcdsArchiveInspection `
            -ArchivePath $unsafeZip `
            -ExpectedSizeBytes $unsafeIdentity.size `
            -ExpectedSha256 $unsafeIdentity.sha256 `
            -AllowedTopLevelRoots @('expected') `
            -RequiredRegularFiles @()
    } -MessagePattern 'traversal|non-canonical|rooted' -FailureMessage 'Unsafe ZIP path was not rejected.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $temporaryRoot 'escape.txt'))) 'Unsafe ZIP test escaped its directory.'

    $layoutZip = Join-Path $temporaryRoot 'layout.zip'
    New-TestZip -Path $layoutZip -Entries @{ 'wrong/file.txt' = 'layout' }
    $layoutIdentity = Get-TestZipIdentity -Path $layoutZip
    Assert-Throws -Action {
        Get-TpcdsArchiveInspection `
            -ArchivePath $layoutZip `
            -ExpectedSizeBytes $layoutIdentity.size `
            -ExpectedSha256 $layoutIdentity.sha256 `
            -AllowedTopLevelRoots @('expected') `
            -RequiredRegularFiles @()
    } -MessagePattern 'Unexpected.*layout' -FailureMessage 'Unexpected ZIP layout was not rejected.'

    $sourceRoot = Join-Path $temporaryRoot 'source'
    [void](New-Item -ItemType Directory -Path $sourceRoot)
    [System.IO.File]::WriteAllText((Join-Path $sourceRoot 'one.txt'), 'before')
    $sourceIdentity = Get-TpcdsSourceIdentity -SourceRoot $sourceRoot
    [System.IO.File]::WriteAllText((Join-Path $sourceRoot 'one.txt'), 'after')
    Assert-Throws -Action {
        Assert-TpcdsSourceIdentity -SourceRoot $sourceRoot -ExpectedSha256 $sourceIdentity.sha256
    } -MessagePattern 'source identity changed' -FailureMessage 'Source mutation was not rejected.'

    $forbiddenRoot = Join-Path $temporaryRoot 'forbidden'
    [void](New-Item -ItemType Directory -Path $forbiddenRoot)
    [System.IO.File]::WriteAllText((Join-Path $forbiddenRoot 'table.dat'), 'forbidden')
    Assert-True (@(Get-TpcdsForbiddenArtifacts -Root $forbiddenRoot).Count -eq 1) 'Forbidden .dat artifact was not detected.'

    $missingRoot = Join-Path $temporaryRoot 'missing-build-output'
    [void](New-Item -ItemType Directory -Path $missingRoot)
    $minimalManifest = [pscustomobject][ordered]@{
        schema_version = 'tpcds_toolkit_build_manifest/v1'
        toolkit_build_id = 'missing-build-output'
        status = 'COMPLETE'
        promotion = [pscustomobject]@{ promoted = $true }
        source = [pscustomobject]@{
            pre_build_manifest_sha256 = ('1' * 64)
            post_build_manifest_sha256 = ('1' * 64)
            immutable_source_unchanged = $true
        }
        builder = [pscustomobject]@{ platform = 'linux/amd64'; image_id = ('sha256:' + ('2' * 64)) }
        build = [pscustomobject]@{ argv = @('make'); working_directory = '/workspace/build' }
        distributions = [pscustomobject]@{
            artifact_relative_path = 'share/tpcds/tpcds.idx'
            parameter_name = 'DISTRIBUTIONS'
            explicit_future_cli_path_required = $true
        }
        artifacts = [pscustomobject]@{
            dsdgen = [pscustomobject]@{ relative_path = 'bin/dsdgen'; size_bytes = 1; sha256 = ('3' * 64) }
            tpcds_idx = [pscustomobject]@{ relative_path = 'share/tpcds/tpcds.idx'; size_bytes = 1; sha256 = ('4' * 64) }
        }
        no_data_verification = [pscustomobject]@{
            archive_identity_verified = $true; source_identity_verified = $true
            builder_identity_verified = $true; build_command_allowlisted = $true
            dsdgen_not_executed = $true; no_dataset_files = $true
            no_hdfs_action = $true; no_spark_action = $true; no_yarn_action = $true
            no_partial_output_promoted = $true
        }
    }
    Assert-Throws -Action {
        Assert-TpcdsBuildManifest -ArtifactRoot $missingRoot -Manifest $minimalManifest
    } -MessagePattern 'Missing.*artifact' -FailureMessage 'Missing build output was not rejected.'
    $minimalManifest.schema_version = 'invalid/schema'
    Assert-Throws -Action {
        Assert-TpcdsBuildManifest -ArtifactRoot $missingRoot -Manifest $minimalManifest
    } -MessagePattern 'schema_version' -FailureMessage 'Invalid build manifest schema was not rejected.'
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Force -Recurse
    }
}

$artifactIgnore = & git check-ignore -v -- 'artifacts/tpcds_toolkit/.work/contract-test-probe'
Assert-True ($LASTEXITCODE -eq 0 -and $artifactIgnore -match 'artifacts/tpcds_toolkit/') 'Scoped P04B artifact ignore rule is missing.'
$archiveIgnore = & git check-ignore -v -- $config.archive.repository_relative_path
Assert-True ($LASTEXITCODE -eq 0 -and $archiveIgnore -match '\.local/tpcds/') 'Canonical local archive ignore boundary is missing.'
$trackedArchive = @(& git ls-files -- $config.archive.repository_relative_path)
Assert-True ($trackedArchive.Count -eq 0) 'Canonical local archive is tracked by Git.'
$ignoreText = Get-Content -LiteralPath (Join-Path $repositoryRoot '.gitignore') -Raw
Assert-True ($ignoreText -notmatch '(?m)^\*\.(zip|dat|o|parquet)\s*$') 'An unnecessarily broad TPC-DS ignore rule was added.'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'B0CF2ADA-2F20-4296-A89C-81B8202DCD13-TPC-DS-Tool'))) 'Historical vendored toolkit path was restored.'

if ($ArtifactPath) {
    $resolvedArtifact = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $ArtifactPath))
    $manifest = Get-Content -LiteralPath (Join-Path $resolvedArtifact 'build_manifest.json') -Raw | ConvertFrom-Json
    Assert-TpcdsBuildManifest -ArtifactRoot $resolvedArtifact -Manifest $manifest -Config $config
}

Write-Host 'TPCDS_TOOLKIT_STATIC_CONTRACT=PASS'
