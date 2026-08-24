[CmdletBinding()]
param([string]$EnvFile)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$composeFile = Join-Path $repositoryRoot 'infrastructure\docker\compose.yaml'
$nativeCommandHelper = Join-Path $PSScriptRoot 'native-command.ps1'
. $nativeCommandHelper
. (Join-Path $PSScriptRoot 'verification-session.ps1')
. (Join-Path $PSScriptRoot 'environment-file.ps1')
if (-not $EnvFile) {
    $EnvFile = Join-Path $repositoryRoot 'configs\environments\local_yarn_v1.env'
}
if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Missing environment file: $EnvFile"
}
$EnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
[void](Import-LocalYarnEnvironmentFile -Path $EnvFile)

$verificationLock = $null
try {
    $verificationLock = Enter-LocalYarnVerificationLock -RepositoryRoot $repositoryRoot
    [void](Invoke-NativeCommand -FilePath 'docker' -ArgumentList @(
        'compose',
        '--env-file', $EnvFile,
        '-f', $composeFile,
        'down'
    ))
} finally {
    Exit-LocalYarnVerificationLock -Lock $verificationLock
}

Write-Host 'LOCAL_YARN_V1 stopped. Named HDFS volumes were preserved.'
