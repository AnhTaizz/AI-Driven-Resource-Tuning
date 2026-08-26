[CmdletBinding()]
param(
    [ValidateRange(30, 600)] [int]$ObservationSeconds = 180,
    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$composeFile = Join-Path $repositoryRoot 'infrastructure\docker\compose.yaml'
$observabilityDirectory = Join-Path $repositoryRoot 'infrastructure\docker\observability'
. (Join-Path $PSScriptRoot 'native-command.ps1')
. (Join-Path $PSScriptRoot 'verification-session.ps1')
. (Join-Path $PSScriptRoot 'environment-file.ps1')
. (Join-Path $PSScriptRoot 'runtime-evidence.ps1')

if (-not $EnvFile) {
    $EnvFile = Join-Path $repositoryRoot 'configs\environments\local_yarn_v1.env'
}
if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Missing $EnvFile. Copy configs/environments/local_yarn_v1.env.example to local_yarn_v1.env first."
}
$EnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
$settings = Import-LocalYarnEnvironmentFile -Path $EnvFile
$imageName = if ($settings.ContainsKey('LOCAL_YARN_IMAGE')) {
    $settings['LOCAL_YARN_IMAGE']
} else {
    'ai-resource-tuning/local-yarn:spark-3.5.9-hadoop-3.3.6-java11-python3.10.21'
}

function Invoke-StreamingNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$FilePath,
        [Parameter(Mandatory)] [string[]]$ArgumentList
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $exitCode = $null
    try {
        $ErrorActionPreference = 'Continue'
        & $FilePath @ArgumentList 2>&1 | ForEach-Object {
            $line = $_.ToString()
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                [Console]::Error.WriteLine($line)
            } else {
                [Console]::Out.WriteLine($line)
            }
        }
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "Observability job command failed with exit code $exitCode."
    }
}

$verificationLock = $null
try {
    $verificationLock = Enter-LocalYarnVerificationLock -RepositoryRoot $repositoryRoot

    [void](Invoke-NativeCommand -FilePath 'docker' -ArgumentList @('info') -NoEcho)
    $activeSession = Get-LocalYarnActiveVerificationSession -RepositoryRoot $repositoryRoot
    if (-not $activeSession) {
        throw 'No LOCAL_YARN_V1 verification session exists. Run start.ps1 and verify.ps1 first.'
    }
    $activeStatus = Get-Content -LiteralPath $activeSession.status_path -Raw | ConvertFrom-Json
    if ($activeStatus.status -ne 'COMPLETE') {
        throw "Active verification $($activeStatus.verification_id) is $($activeStatus.status). Complete verify.ps1 before submitting an observability job."
    }
    if ($activeStatus.evidence_classification -ne 'INFRASTRUCTURE_VERIFICATION_ONLY') {
        throw 'Active verification has an unexpected evidence classification.'
    }

    $expectedImagesPath = Join-Path $activeSession.evidence_directory 'service_images_final.json'
    if (-not (Test-Path -LiteralPath $expectedImagesPath)) {
        throw "Active verification is missing its final service identity record: $expectedImagesPath"
    }
    $expectedRuntime = Get-Content -LiteralPath $expectedImagesPath -Raw | ConvertFrom-Json
    $currentRuntime = Get-LocalYarnServiceImageEvidence `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile `
        -IntendedImage $imageName 6>$null

    $identityMismatches = @()
    if ($expectedRuntime.intended_image.reference -ne $imageName) {
        $identityMismatches += 'intended image reference'
    }
    if ($expectedRuntime.intended_image.image_id -ne $currentRuntime.intended_image.image_id) {
        $identityMismatches += 'intended image ID'
    }
    foreach ($currentService in @($currentRuntime.services)) {
        $expectedServices = @($expectedRuntime.services | Where-Object {
            $_.service -eq $currentService.service
        })
        if ($expectedServices.Count -ne 1) {
            $identityMismatches += "$($currentService.service) evidence record"
            continue
        }
        $expectedService = $expectedServices[0]
        foreach ($field in @('container_id', 'actual_image_id', 'image_reference', 'started_at')) {
            if ($expectedService.$field -ne $currentService.$field) {
                $identityMismatches += "$($currentService.service).$field"
            }
        }
        if ($currentService.service -eq 'hdfs-init' `
                -and $expectedService.finished_at -ne $currentService.finished_at) {
            $identityMismatches += 'hdfs-init.finished_at'
        }
    }
    if ($identityMismatches.Count -gt 0) {
        throw "Current LOCAL_YARN_V1 runtime does not match completed verification $($activeStatus.verification_id): $($identityMismatches -join ', '). Stop the cluster, then run start.ps1 and verify.ps1 to create fresh evidence."
    }

    $composePrefix = @('compose', '--env-file', $EnvFile, '-f', $composeFile)
    $runningResult = Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList ($composePrefix + @('ps', '--status', 'running', '--services')) `
        -NoEcho
    $runningServices = @($runningResult.StdOut | Where-Object { $_ })
    $requiredServices = @(
        'namenode',
        'datanode-1',
        'datanode-2',
        'resourcemanager',
        'nodemanager-1',
        'nodemanager-2',
        'history-server'
    )
    $missingServices = @($requiredServices | Where-Object { $runningServices -notcontains $_ })
    if ($missingServices.Count -gt 0) {
        throw "LOCAL_YARN_V1 is not running: missing $($missingServices -join ', '). Run start.ps1 followed by verify.ps1 first."
    }

    $resourceManagerPort = if ($settings.ContainsKey('RESOURCE_MANAGER_UI_PORT')) {
        [int]$settings['RESOURCE_MANAGER_UI_PORT']
    } else {
        8088
    }
    $historyServerPort = if ($settings.ContainsKey('HISTORY_SERVER_UI_PORT')) {
        [int]$settings['HISTORY_SERVER_UI_PORT']
    } else {
        18080
    }
    [void](Invoke-RestMethod `
        -Uri "http://127.0.0.1:$resourceManagerPort/ws/v1/cluster/info" `
        -Method Get `
        -TimeoutSec 5)
    [void](Invoke-RestMethod `
        -Uri "http://127.0.0.1:$historyServerPort/api/v1/version" `
        -Method Get `
        -TimeoutSec 5)

    $containerSource = '/opt/local-yarn/observability-source'
    $readOnlySourceMount = "${observabilityDirectory}:${containerSource}:ro"
    $runArguments = $composePrefix + @(
        'run',
        '--rm',
        '--no-deps',
        '--no-TTY',
        '--volume', $readOnlySourceMount,
        '--env', "HOST_RESOURCE_MANAGER_PORT=$resourceManagerPort",
        '--env', "HOST_HISTORY_SERVER_PORT=$historyServerPort",
        'spark-client',
        '/bin/bash',
        "$containerSource/run-observability-test.sh",
        $ObservationSeconds.ToString()
    )

    Write-Host 'Starting INFRASTRUCTURE_OBSERVABILITY_ONLY Spark job.'
    Write-Host 'This job is not benchmark evidence, EXP_001, C1, or ML data.'
    Write-Host 'Keep this terminal open. URLs appear after YARN and the live Spark REST API are ready.'
    Invoke-StreamingNativeCommand -FilePath 'docker' -ArgumentList $runArguments
} finally {
    Exit-LocalYarnVerificationLock -Lock $verificationLock
}
