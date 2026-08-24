[CmdletBinding()]
param(
    [string]$EnvFile,
    [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$composeFile = Join-Path $repositoryRoot 'infrastructure\docker\compose.yaml'
$snapshotScript = Join-Path $PSScriptRoot 'snapshot-environment.ps1'
. (Join-Path $PSScriptRoot 'native-command.ps1')
. (Join-Path $PSScriptRoot 'verification-session.ps1')
. (Join-Path $PSScriptRoot 'host-observation.ps1')
. (Join-Path $PSScriptRoot 'runtime-evidence.ps1')
. (Join-Path $PSScriptRoot 'environment-file.ps1')

if (-not $EnvFile) {
    $EnvFile = Join-Path $repositoryRoot 'configs\environments\local_yarn_v1.env'
}

$currentStep = 'LOAD_VERIFICATION_SESSION'
$statusCanBeUpdated = $false
$applicationId = $null
$verificationLock = $null

function Invoke-ComposeEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string[]]$Command,
        [switch]$AllowCommandFailure
    )

    $result = Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList (@('compose') + $script:composeArgs + $Command) `
        -AllowNonZero
    $result.Combined | Set-Content -LiteralPath (Join-Path $script:EvidenceDirectory "$Name.txt") -Encoding utf8
    $result.StdOut | Set-Content -LiteralPath (Join-Path $script:EvidenceDirectory "$Name.stdout.txt") -Encoding utf8
    $result.StdErr | Set-Content -LiteralPath (Join-Path $script:EvidenceDirectory "$Name.stderr.txt") -Encoding utf8
    if ($result.ExitCode -ne 0 -and -not $AllowCommandFailure) {
        $lastOutput = @($result.Combined | Select-Object -Last 20) -join "`n"
        throw "Compose evidence command '$Name' exited $($result.ExitCode). Last observed output:`n$lastOutput"
    }
    return $result
}

function Assert-LocalYarnServiceIdentityMatches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Expected,
        [Parameter(Mandatory)] [object]$Observed,
        [Parameter(Mandatory)] [string]$ObservationName
    )

    foreach ($expectedService in @($Expected.services)) {
        $observedService = @($Observed.services | Where-Object {
            $_.service -eq $expectedService.service
        }) | Select-Object -First 1
        if (-not $observedService) {
            throw "$ObservationName omitted service $($expectedService.service)."
        }
        if ($observedService.container_id -ne $expectedService.container_id) {
            throw "$ObservationName detected a recreated container for $($expectedService.service)."
        }
        if ($observedService.actual_image_id -ne $expectedService.actual_image_id) {
            throw "$ObservationName detected an image change for $($expectedService.service)."
        }
        if ($observedService.started_at -ne $expectedService.started_at) {
            throw "$ObservationName detected a new lifecycle start for $($expectedService.service)."
        }
        if ($expectedService.service -eq 'hdfs-init' -and
            $observedService.finished_at -ne $expectedService.finished_at) {
            throw "$ObservationName detected a rerun of the one-shot hdfs-init service."
        }
    }
}

function Assert-LocalYarnEvidenceBundle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Directory,
        [Parameter(Mandatory)] [string]$VerificationId,
        [Parameter(Mandatory)] [string]$ApplicationId
    )

    $documents = @{}
    foreach ($fileName in @(
        'verification_status.json',
        'host_baseline.json',
        'cluster_idle.json',
        'post_smoke.json',
        'java_base_image_resolution.json',
        'started_service_images.json',
        'service_images.json',
        'service_images_post_smoke.json',
        'service_images_final.json',
        'runtime_versions_by_environment.json',
        'yarn_nodes.json',
        'yarn_node_resources.json',
        'yarn_effective_config.json',
        'hdfs_effective_config.json',
        'yarn_idle_metrics.json',
        'yarn_idle_applications.json',
        'runtime_before_smoke.json',
        'runtime_after_smoke.json',
        'swap_assessment.json',
        'yarn_application.json',
        'yarn_metrics.json',
        'yarn_scheduler.json',
        'history_application.json',
        'spark_environment.json',
        'spark_effective_config.json',
        'environment_snapshot_ref.json'
    )) {
        $path = Join-Path $Directory $fileName
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Evidence bundle is missing required JSON document $fileName."
        }
        try {
            $documents[$fileName] = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        } catch {
            throw "Evidence bundle contains invalid JSON in $fileName`: $($_.Exception.Message)"
        }
        if ($null -eq $documents[$fileName]) {
            throw "Evidence bundle contains a null JSON document in $fileName."
        }
    }

    foreach ($fileName in @(
        'compose_ps.txt',
        'service_verification.txt',
        'hdfs_report.txt',
        'hdfs_report.stdout.txt',
        'yarn_capacity_report.txt',
        'spark_submit_output.txt',
        'application_id.txt',
        'spark_event_log_listing.txt',
        'spark_event_log_listing.stdout.txt',
        'history_environment_endpoint.txt'
    )) {
        $path = Join-Path $Directory $fileName
        if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) {
            throw "Evidence bundle is missing required non-empty artifact $fileName."
        }
    }

    foreach ($phase in @('host_baseline.json', 'cluster_idle.json', 'post_smoke.json')) {
        if ($documents[$phase].verification_id -ne $VerificationId) {
            throw "Evidence document $phase belongs to another verification session."
        }
    }
    if ($documents['verification_status.json'].verification_id -ne $VerificationId -or
        $documents['verification_status.json'].status -ne 'INCOMPLETE' -or
        $documents['verification_status.json'].application_id -ne $ApplicationId) {
        throw 'Verification status identity/state is inconsistent before completion.'
    }
    if ($documents['yarn_application.json'].app.id -ne $ApplicationId -or
        $documents['yarn_application.json'].app.state -ne 'FINISHED' -or
        $documents['yarn_application.json'].app.finalStatus -ne 'SUCCEEDED') {
        throw 'YARN application evidence is not the successful smoke application.'
    }
    if ($documents['history_application.json'].id -ne $ApplicationId) {
        throw 'Spark History Server evidence is not the smoke application.'
    }
    if ($documents['environment_snapshot_ref.json'].verification_id -ne $VerificationId -or
        $documents['environment_snapshot_ref.json'].application_id -ne $ApplicationId) {
        throw 'Environment snapshot reference identity is inconsistent.'
    }
    if ($documents['java_base_image_resolution.json'].registry_descriptor_digest -notmatch '^sha256:[0-9a-f]{64}$' -or
        $documents['java_base_image_resolution.json'].platform_manifest_digest -notmatch '^sha256:[0-9a-f]{64}$' -or
        -not $documents['java_base_image_resolution.json'].selected_platform) {
        throw 'Java base-image evidence lacks a registry descriptor or platform manifest digest.'
    }
    if ((Get-Content -LiteralPath (Join-Path $Directory 'application_id.txt') -Raw).Trim() -ne $ApplicationId) {
        throw 'application_id.txt differs from correlated runtime evidence.'
    }
    $eventLogListing = Get-Content `
        -LiteralPath (Join-Path $Directory 'spark_event_log_listing.stdout.txt') `
        -Raw
    if ($eventLogListing -notmatch [regex]::Escape($ApplicationId)) {
        throw 'Spark event-log listing does not contain the smoke application ID.'
    }
    $swapDetectedProperty = $documents['swap_assessment.json'].PSObject.Properties['swap_detected']
    if (-not $swapDetectedProperty -or
        $swapDetectedProperty.Value -isnot [bool] -or
        $swapDetectedProperty.Value) {
        throw 'Host/Docker-VM or LOCAL_YARN cgroup swap activity was observed during the infrastructure smoke interval; evidence is invalid pending investigation.'
    }
}

function Invoke-RestJsonWithPolling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Uri,
        [Parameter(Mandatory)] [string]$Description,
        [scriptblock]$Accept = { param($value) $null -ne $value },
        [int]$TimeoutSeconds = 120,
        [int]$PollIntervalSeconds = 2,
        [int]$RequestTimeoutSeconds = 10
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastObserved = 'no response'
    do {
        try {
            $value = Invoke-RestMethod -Uri $Uri -TimeoutSec $RequestTimeoutSeconds
            $lastObserved = ($value | ConvertTo-Json -Depth 8 -Compress)
            if (& $Accept $value) {
                return $value
            }
        } catch {
            $lastObserved = $_.Exception.Message
        }
        if ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds $PollIntervalSeconds
        }
    } while ((Get-Date) -lt $deadline)

    throw "$Description did not reach the required state within ${TimeoutSeconds}s. Last observed state: $lastObserved"
}

function Get-VersionValue {
    param([Parameter(Mandatory)] [object]$Observation, [Parameter(Mandatory)] [string]$Component)
    $candidateNames = @("${Component}_version_normalized", $Component)
    foreach ($name in $candidateNames) {
        $property = $Observation.normalized.PSObject.Properties[$name]
        if ($property -and $property.Value) {
            return [string]$property.Value
        }
    }
    return $null
}

try {
    if (-not (Test-Path -LiteralPath $EnvFile)) {
        throw "Missing environment file: $EnvFile"
    }
    $EnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
    $settings = Import-LocalYarnEnvironmentFile -Path $EnvFile

    $currentStep = 'ACQUIRE_VERIFICATION_LOCK'
    $verificationLock = Enter-LocalYarnVerificationLock -RepositoryRoot $repositoryRoot

    if (-not $EvidenceDirectory) {
        $activeSession = Get-LocalYarnActiveVerificationSession -RepositoryRoot $repositoryRoot
        if (-not $activeSession) {
            $activeSession = New-LocalYarnVerificationSession -RepositoryRoot $repositoryRoot
            $EvidenceDirectory = $activeSession.evidence_directory
            $statusCanBeUpdated = $true
            throw 'No active pre-start verification session exists. Run host/start.ps1 first so HOST_BASELINE can be captured.'
        }
        $EvidenceDirectory = $activeSession.evidence_directory
    }
    $EvidenceDirectory = (Resolve-Path -LiteralPath $EvidenceDirectory).Path
    $statusPath = Join-Path $EvidenceDirectory 'verification_status.json'
    if (-not (Test-Path -LiteralPath $statusPath)) {
        throw "Missing verification status document: $statusPath"
    }
    $existingStatus = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    if ($existingStatus.status -ne 'INCOMPLETE') {
        throw "Verification session $($existingStatus.verification_id) has status $($existingStatus.status), expected INCOMPLETE."
    }
    $statusCanBeUpdated = $true
    if (-not (Test-Path -LiteralPath (Join-Path $EvidenceDirectory 'host_baseline.json'))) {
        throw 'HOST_BASELINE evidence is missing. Run host/start.ps1 from a stopped cluster before verification.'
    }

    $rmPort = if ($settings.ContainsKey('RESOURCE_MANAGER_UI_PORT')) { [int]$settings['RESOURCE_MANAGER_UI_PORT'] } else { 8088 }
    $historyPort = if ($settings.ContainsKey('HISTORY_SERVER_UI_PORT')) { [int]$settings['HISTORY_SERVER_UI_PORT'] } else { 18080 }
    $imageName = if ($settings.ContainsKey('LOCAL_YARN_IMAGE')) {
        $settings['LOCAL_YARN_IMAGE']
    } else {
        'ai-resource-tuning/local-yarn:spark-3.5.9-hadoop-3.3.6-java11-python3.10.21'
    }
    $script:composeArgs = @('--env-file', $EnvFile, '-f', $composeFile)
    $script:EvidenceDirectory = $EvidenceDirectory

    $currentStep = 'CHECK_DOCKER_DAEMON'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    $dockerInfo = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @('info') -AllowNonZero
    if ($dockerInfo.ExitCode -ne 0) {
        throw 'Docker daemon is not reachable. Runtime verification cannot continue.'
    }

    $currentStep = 'VERIFY_SERVICES_HDFS_YARN'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    [void](Invoke-ComposeEvidence -Name 'compose_ps' -Command @('ps', '--all'))
    [void](Invoke-ComposeEvidence -Name 'service_verification' -Command @('run', '--rm', '--no-deps', 'spark-client', 'verify-services'))
    [void](Invoke-ComposeEvidence -Name 'hdfs_report' -Command @('run', '--rm', '--no-deps', 'spark-client', 'verify-hdfs'))
    [void](Invoke-ComposeEvidence -Name 'yarn_capacity_report' -Command @('run', '--rm', '--no-deps', 'spark-client', 'verify-yarn'))

    $currentStep = 'CAPTURE_IMAGE_AND_RUNTIME_VERSIONS'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    $serviceImages = Get-LocalYarnServiceImageEvidence `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile `
        -IntendedImage $imageName
    Write-LocalYarnJson -Value $serviceImages -Path (Join-Path $EvidenceDirectory 'service_images.json')
    $startedServiceImagesPath = Join-Path $EvidenceDirectory 'started_service_images.json'
    if (-not (Test-Path -LiteralPath $startedServiceImagesPath)) {
        throw 'Missing start-time container identity evidence. Run host/start.ps1 before verification.'
    }
    $startedServiceImages = Get-Content -LiteralPath $startedServiceImagesPath -Raw | ConvertFrom-Json
    Assert-LocalYarnServiceIdentityMatches `
        -Expected $startedServiceImages `
        -Observed $serviceImages `
        -ObservationName 'Pre-smoke service identity check'

    $versionObservations = @(
        Get-LocalYarnVersionObservation -EnvironmentName spark-client -ComposeFile $composeFile -EnvFile $EnvFile
        Get-LocalYarnVersionObservation -EnvironmentName nodemanager-1 -ComposeFile $composeFile -EnvFile $EnvFile
        Get-LocalYarnVersionObservation -EnvironmentName nodemanager-2 -ComposeFile $composeFile -EnvFile $EnvFile
    )
    Write-LocalYarnJson -Value $versionObservations -Path (Join-Path $EvidenceDirectory 'runtime_versions_by_environment.json')
    foreach ($observation in $versionObservations) {
        if ((Get-VersionValue -Observation $observation -Component spark) -ne '3.5.9') {
            throw "Unexpected Spark version in $($observation.environment)."
        }
        if ((Get-VersionValue -Observation $observation -Component hadoop) -ne '3.3.6') {
            throw "Unexpected Hadoop version in $($observation.environment)."
        }
        if ((Get-VersionValue -Observation $observation -Component python) -ne '3.10.21') {
            throw "Unexpected Python version in $($observation.environment)."
        }
        if ((Get-VersionValue -Observation $observation -Component java) -ne '11.0.32+9') {
            throw "Unexpected Java build in $($observation.environment)."
        }
    }

    $currentStep = 'CAPTURE_YARN_RUNTIME_EVIDENCE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    $yarnNodes = Invoke-RestJsonWithPolling `
        -Uri "http://127.0.0.1:$rmPort/ws/v1/cluster/nodes" `
        -Description 'YARN NodeManager registration' `
        -Accept { param($value) @($value.nodes.node | Where-Object { $_.state -eq 'RUNNING' }).Count -eq 2 }
    $yarnNodes | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'yarn_nodes.json') -Encoding utf8

    $nodeEvidence = @()
    foreach ($expectedHost in @('nodemanager-1', 'nodemanager-2')) {
        $node = @($yarnNodes.nodes.node | Where-Object {
            $_.nodeHostName -eq $expectedHost -or ([string]$_.id).StartsWith("${expectedHost}:")
        }) | Select-Object -First 1
        if (-not $node) {
            throw "YARN did not report expected node $expectedHost."
        }
        $usedMemoryProperty = $node.PSObject.Properties['usedMemoryMB']
        $availableMemoryProperty = $node.PSObject.Properties['availMemoryMB']
        $usedVcoresProperty = $node.PSObject.Properties['usedVirtualCores']
        $availableVcoresProperty = $node.PSObject.Properties['availableVirtualCores']
        foreach ($requiredProperty in @(
            $usedMemoryProperty,
            $availableMemoryProperty,
            $usedVcoresProperty,
            $availableVcoresProperty
        )) {
            if ($null -eq $requiredProperty -or $null -eq $requiredProperty.Value) {
                throw "YARN node $expectedHost omitted a resource field required to verify its advertised total capacity."
            }
        }
        $usedMemory = [int64]$usedMemoryProperty.Value
        $availableMemory = [int64]$availableMemoryProperty.Value
        $usedVcores = [int64]$usedVcoresProperty.Value
        $availableVcores = [int64]$availableVcoresProperty.Value
        $totalMemory = $usedMemory + $availableMemory
        $totalVcores = $usedVcores + $availableVcores
        if ($node.state -ne 'RUNNING' -or $totalMemory -ne 2048 -or $totalVcores -ne 2) {
            throw "Unexpected observed capacity for ${expectedHost}: state=$($node.state), memory=${totalMemory}MB, vcores=$totalVcores."
        }
        $nodeEvidence += [pscustomobject][ordered]@{
            expected_host = $expectedHost
            node_id = $node.id
            node_host_name = $node.nodeHostName
            state = $node.state
            total_memory_mb = $totalMemory
            available_memory_mb = $availableMemory
            used_memory_mb = $usedMemory
            total_vcores = $totalVcores
            available_vcores = $availableVcores
            used_vcores = $usedVcores
        }
    }
    $normalizedYarnNodes = [ordered]@{
        nodes = $nodeEvidence
        observed_cluster_total_memory_mb = [int64](($nodeEvidence | Measure-Object total_memory_mb -Sum).Sum)
        observed_cluster_total_vcores = [int64](($nodeEvidence | Measure-Object total_vcores -Sum).Sum)
    }
    Write-LocalYarnJson -Value $normalizedYarnNodes -Path (Join-Path $EvidenceDirectory 'yarn_node_resources.json')

    $yarnConfigResult = Invoke-ComposeEvidence `
        -Name 'yarn_effective_config' `
        -Command @('run', '--rm', '--no-deps', 'spark-client', 'snapshot-yarn-config')
    $yarnConfigJson = $yarnConfigResult.StdOut | Where-Object { $_ -match '^\{.*\}$' } | Select-Object -Last 1
    if (-not $yarnConfigJson) {
        throw 'YARN effective configuration command returned no JSON object.'
    }
    $yarnEffectiveConfig = $yarnConfigJson | ConvertFrom-Json
    Write-LocalYarnJson -Value $yarnEffectiveConfig -Path (Join-Path $EvidenceDirectory 'yarn_effective_config.json')

    $hdfsConfigResult = Invoke-ComposeEvidence `
        -Name 'hdfs_effective_config' `
        -Command @('run', '--rm', '--no-deps', 'spark-client', 'hdfs', 'getconf', '-confKey', 'fs.defaultFS')
    $hdfsDefaultFs = @($hdfsConfigResult.StdOut | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) |
        Select-Object -Last 1
    $hdfsDefaultFs = ([string]$hdfsDefaultFs).Trim()
    if ($hdfsDefaultFs -ne 'hdfs://namenode:8020') {
        throw "Unexpected deployed fs.defaultFS=$hdfsDefaultFs."
    }
    Write-LocalYarnJson -Value ([ordered]@{
        observation_kind = 'OBSERVED_DEPLOYED_CONFIG'
        observed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        source_command = 'hdfs getconf -confKey fs.defaultFS'
        fs_default_fs = $hdfsDefaultFs
    }) -Path (Join-Path $EvidenceDirectory 'hdfs_effective_config.json')

    $currentStep = 'VERIFY_CLUSTER_IDLE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    $idleMetrics = Invoke-RestJsonWithPolling `
        -Uri "http://127.0.0.1:$rmPort/ws/v1/cluster/metrics" `
        -Description 'YARN idle cluster metrics' `
        -Accept {
            param($value)
            $metrics = $value.clusterMetrics
            if (-not $metrics) { return $false }
            foreach ($name in @(
                'appsPending', 'appsRunning',
                'allocatedMB', 'pendingMB', 'reservedMB',
                'allocatedVirtualCores', 'pendingVirtualCores', 'reservedVirtualCores',
                'containersAllocated', 'containersPending', 'containersReserved'
            )) {
                $property = $metrics.PSObject.Properties[$name]
                if (-not $property -or $null -eq $property.Value -or [int64]$property.Value -ne 0) {
                    return $false
                }
            }
            return $true
        }
    Write-LocalYarnJson -Value $idleMetrics -Path (Join-Path $EvidenceDirectory 'yarn_idle_metrics.json')
    $idleApplications = Invoke-RestJsonWithPolling `
        -Uri "http://127.0.0.1:$rmPort/ws/v1/cluster/apps?states=NEW,NEW_SAVING,SUBMITTED,ACCEPTED,RUNNING" `
        -Description 'absence of active YARN applications before smoke' `
        -Accept {
            param($value)
            $appsProperty = $value.PSObject.Properties['apps']
            if (-not $appsProperty) { return $false }
            if ($null -eq $appsProperty.Value) { return $true }
            $appProperty = $appsProperty.Value.PSObject.Properties['app']
            if ($appProperty) {
                return @($appProperty.Value | Where-Object { $_ }).Count -eq 0
            }
            return @($appsProperty.Value.PSObject.Properties).Count -eq 0
        }
    Write-LocalYarnJson -Value $idleApplications -Path (Join-Path $EvidenceDirectory 'yarn_idle_applications.json')

    $currentStep = 'CAPTURE_CLUSTER_IDLE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    [void](Save-LocalYarnHostObservation `
        -Phase CLUSTER_IDLE `
        -VerificationId $existingStatus.verification_id `
        -EvidenceDirectory $EvidenceDirectory `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile)
    $runtimeBefore = (Get-LocalYarnVersionObservation `
        -EnvironmentName spark-client `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile).normalized
    Write-LocalYarnJson -Value $runtimeBefore -Path (Join-Path $EvidenceDirectory 'runtime_before_smoke.json')

    $currentStep = 'RUN_INFRASTRUCTURE_SMOKE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    $smokeResult = Invoke-ComposeEvidence `
        -Name 'spark_submit_output' `
        -Command @('run', '--rm', '--no-deps', 'spark-client', 'verify-spark') `
        -AllowCommandFailure
    $smokeOutput = $smokeResult.Combined -join "`n"
    $applicationMatch = [regex]::Match($smokeOutput, '(?m)^OBSERVED_APPLICATION_ID=(application_\d+_\d+)\s*$')
    if (-not $applicationMatch.Success) {
        $applicationMatch = [regex]::Match($smokeOutput, '(?m)^APPLICATION_ID=(application_\d+_\d+)\s*$')
    }
    if ($applicationMatch.Success) {
        $applicationId = $applicationMatch.Groups[1].Value
        $applicationId | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'application_id.txt') -Encoding ascii
        Set-LocalYarnVerificationStatus `
            -EvidenceDirectory $EvidenceDirectory `
            -Status INCOMPLETE `
            -CurrentStep $currentStep `
            -ApplicationId $applicationId | Out-Null
    }
    if ($smokeResult.ExitCode -ne 0) {
        $lastOutput = @($smokeResult.Combined | Select-Object -Last 20) -join "`n"
        throw "Compose evidence command 'spark_submit_output' exited $($smokeResult.ExitCode). Last observed output:`n$lastOutput"
    }
    if (-not $applicationMatch.Success) {
        throw 'Spark smoke completed without an observable application ID.'
    }
    if ($smokeOutput -notmatch '(?m)^SPARK_SMOKE_VERIFICATION=PASS\s*$') {
        throw 'Spark smoke command exited successfully without its required PASS marker.'
    }

    $currentStep = 'CAPTURE_POST_SMOKE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep -ApplicationId $applicationId | Out-Null
    $runtimeAfter = (Get-LocalYarnVersionObservation `
        -EnvironmentName spark-client `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile).normalized
    Write-LocalYarnJson -Value $runtimeAfter -Path (Join-Path $EvidenceDirectory 'runtime_after_smoke.json')
    [void](Save-LocalYarnHostObservation `
        -Phase POST_SMOKE `
        -VerificationId $existingStatus.verification_id `
        -EvidenceDirectory $EvidenceDirectory `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile)

    $postSmokeServiceImages = Get-LocalYarnServiceImageEvidence `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile `
        -IntendedImage $imageName
    Write-LocalYarnJson `
        -Value $postSmokeServiceImages `
        -Path (Join-Path $EvidenceDirectory 'service_images_post_smoke.json')
    Assert-LocalYarnServiceIdentityMatches `
        -Expected $serviceImages `
        -Observed $postSmokeServiceImages `
        -ObservationName 'Post-smoke service identity check'

    $serviceSwapAssessment = @()
    foreach ($beforeService in @($serviceImages.services)) {
        $afterService = @($postSmokeServiceImages.services | Where-Object {
            $_.service -eq $beforeService.service
        }) | Select-Object -First 1
        $peakBefore = $beforeService.cgroup_swap_peak_bytes
        $peakAfter = $afterService.cgroup_swap_peak_bytes
        $peakDelta = if ($null -ne $peakBefore -and $null -ne $peakAfter) {
            [int64]$peakAfter - [int64]$peakBefore
        } else {
            $null
        }
        $serviceSwapAssessment += [pscustomobject][ordered]@{
            service = $beforeService.service
            current_bytes_after = $afterService.cgroup_swap_current_bytes
            peak_bytes_before = $peakBefore
            peak_bytes_after = $peakAfter
            peak_delta_bytes = $peakDelta
            swap_max_bytes = $afterService.cgroup_swap_max_bytes
            swap_detected = (
                ($null -ne $afterService.cgroup_swap_current_bytes -and [int64]$afterService.cgroup_swap_current_bytes -gt 0) -or
                ($null -ne $peakDelta -and [int64]$peakDelta -gt 0)
            )
        }
    }

    $swapAssessment = [ordered]@{
        pswpin_before = [int64]$runtimeBefore.linux_memory.pswpin
        pswpin_after = [int64]$runtimeAfter.linux_memory.pswpin
        pswpout_before = [int64]$runtimeBefore.linux_memory.pswpout
        pswpout_after = [int64]$runtimeAfter.linux_memory.pswpout
        pswpin_delta = [int64]$runtimeAfter.linux_memory.pswpin - [int64]$runtimeBefore.linux_memory.pswpin
        pswpout_delta = [int64]$runtimeAfter.linux_memory.pswpout - [int64]$runtimeBefore.linux_memory.pswpout
        service_cgroups = $serviceSwapAssessment
    }
    $swapAssessment['host_linux_vm_swap_detected'] = ($swapAssessment.pswpin_delta -gt 0 -or $swapAssessment.pswpout_delta -gt 0)
    $swapAssessment['local_yarn_cgroup_swap_detected'] = @($serviceSwapAssessment | Where-Object { $_.swap_detected }).Count -gt 0
    $swapAssessment['swap_detected'] = (
        $swapAssessment.host_linux_vm_swap_detected -or
        $swapAssessment.local_yarn_cgroup_swap_detected
    )
    Write-LocalYarnJson -Value $swapAssessment -Path (Join-Path $EvidenceDirectory 'swap_assessment.json')

    $currentStep = 'CORRELATE_RUNTIME_RECORDS'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep -ApplicationId $applicationId | Out-Null
    [void](Invoke-ComposeEvidence -Name 'spark_event_log_listing' -Command @('run', '--rm', '--no-deps', 'spark-client', 'hdfs', 'dfs', '-ls', '/spark-history'))

    $yarnApplication = Invoke-RestJsonWithPolling `
        -Uri "http://127.0.0.1:$rmPort/ws/v1/cluster/apps/$applicationId" `
        -Description 'YARN completed application record' `
        -Accept { param($value) $value.app.state -eq 'FINISHED' -and $value.app.finalStatus -eq 'SUCCEEDED' }
    $yarnApplication | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'yarn_application.json') -Encoding utf8

    foreach ($endpoint in @('metrics', 'scheduler')) {
        $acceptEndpoint = if ($endpoint -eq 'metrics') {
            {
                param($value)
                $metrics = $value.clusterMetrics
                if (-not $metrics) { return $false }
                $memory = $metrics.PSObject.Properties['totalMB']
                $vcores = $metrics.PSObject.Properties['totalVirtualCores']
                return $memory -and $vcores -and
                    $null -ne $memory.Value -and $null -ne $vcores.Value -and
                    [int64]$memory.Value -eq 4096 -and [int64]$vcores.Value -eq 4
            }
        } else {
            {
                param($value)
                $type = $value.scheduler.schedulerInfo.PSObject.Properties['type']
                return $type -and $type.Value -eq 'capacityScheduler'
            }
        }
        $payload = Invoke-RestJsonWithPolling `
            -Uri "http://127.0.0.1:$rmPort/ws/v1/cluster/$endpoint" `
            -Description "YARN $endpoint evidence" `
            -Accept $acceptEndpoint
        $payload | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory "yarn_$endpoint.json") -Encoding utf8
    }

    $historyApplications = Invoke-RestJsonWithPolling `
        -Uri "http://127.0.0.1:$historyPort/api/v1/applications?status=completed" `
        -Description 'Spark History Server application appearance' `
        -Accept { param($value) @($value | Where-Object { $_.id -eq $script:applicationId }).Count -gt 0 }
    $historyApplication = @($historyApplications | Where-Object { $_.id -eq $applicationId }) | Select-Object -First 1
    $historyApplication | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'history_application.json') -Encoding utf8

    $historyAttempts = @($historyApplication.attempts)
    $historyAttempt = @($historyAttempts | Where-Object {
        $completedProperty = $_.PSObject.Properties['completed']
        $completedProperty -and $completedProperty.Value -eq $true
    }) | Select-Object -First 1
    if (-not $historyAttempt) {
        $historyAttempt = $historyAttempts | Select-Object -First 1
    }
    $historyAttemptId = $null
    if ($historyAttempt) {
        $attemptIdProperty = $historyAttempt.PSObject.Properties['attemptId']
        if ($attemptIdProperty) {
            $historyAttemptId = [string]$attemptIdProperty.Value
        }
    }
    $historyApplicationKey = $applicationId
    if (-not [string]::IsNullOrWhiteSpace($historyAttemptId)) {
        $historyApplicationKey = "$applicationId/$historyAttemptId"
    }
    $historyEnvironmentUri = "http://127.0.0.1:$historyPort/api/v1/applications/$historyApplicationKey/environment"
    $historyEnvironmentUri | Set-Content `
        -LiteralPath (Join-Path $EvidenceDirectory 'history_environment_endpoint.txt') `
        -Encoding ascii

    $sparkEnvironment = Invoke-RestJsonWithPolling `
        -Uri $historyEnvironmentUri `
        -Description 'Spark effective environment evidence' `
        -Accept { param($value) $null -ne $value.sparkProperties }
    $sparkEnvironment | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'spark_environment.json') -Encoding utf8
    $sparkProperties = @{}
    foreach ($pair in @($sparkEnvironment.sparkProperties)) {
        if ($pair.Count -ge 2) {
            $sparkProperties[[string]$pair[0]] = [string]$pair[1]
        }
    }
    $expectedSparkProperties = [ordered]@{
        'spark.dynamicAllocation.enabled' = 'false'
        'spark.sql.adaptive.enabled' = 'false'
        'spark.sql.shuffle.partitions' = '4'
        'spark.executor.instances' = '2'
        'spark.executor.cores' = '1'
        'spark.executor.memory' = '512m'
        'spark.executor.memoryOverhead' = '384m'
        'spark.driver.memory' = '512m'
        'spark.driver.memoryOverhead' = '384m'
        'spark.master' = 'yarn'
        'spark.submit.deployMode' = 'cluster'
        'spark.eventLog.enabled' = 'true'
        'spark.eventLog.dir' = 'hdfs:///spark-history'
        'spark.yarn.archive' = 'hdfs:///spark/jars/spark-3.5.9-jars.zip'
    }
    foreach ($key in $expectedSparkProperties.Keys) {
        if (-not $sparkProperties.ContainsKey($key) -or $sparkProperties[$key] -ne $expectedSparkProperties[$key]) {
            $observed = if ($sparkProperties.ContainsKey($key)) { $sparkProperties[$key] } else { '<missing>' }
            throw "Unexpected effective Spark property $key=$observed; expected $($expectedSparkProperties[$key])."
        }
    }
    $effectiveSpark = [ordered]@{}
    foreach ($key in $expectedSparkProperties.Keys) {
        $effectiveSpark[$key] = $sparkProperties[$key]
    }
    Write-LocalYarnJson -Value $effectiveSpark -Path (Join-Path $EvidenceDirectory 'spark_effective_config.json')

    $currentStep = 'VERIFY_POST_SMOKE_SERVICE_LIFECYCLE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep -ApplicationId $applicationId | Out-Null
    $finalServiceImages = Get-LocalYarnServiceImageEvidence `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile `
        -IntendedImage $imageName
    Write-LocalYarnJson `
        -Value $finalServiceImages `
        -Path (Join-Path $EvidenceDirectory 'service_images_final.json')
    Assert-LocalYarnServiceIdentityMatches `
        -Expected $postSmokeServiceImages `
        -Observed $finalServiceImages `
        -ObservationName 'Final service identity check'

    $currentStep = 'WRITE_ENVIRONMENT_SNAPSHOT'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep -ApplicationId $applicationId | Out-Null
    $snapshotResult = Invoke-NativeCommand `
        -FilePath 'powershell.exe' `
        -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $snapshotScript,
            '-EnvFile', $EnvFile,
            '-EvidenceDirectory', $EvidenceDirectory,
            '-ApplicationId', $applicationId
        )
    $snapshotMatch = [regex]::Match(
        ($snapshotResult.StdOut -join "`n"),
        '(?m)^ENVIRONMENT_SNAPSHOT=(.+?)\s*$'
    )
    if (-not $snapshotMatch.Success) {
        throw 'Environment snapshot command returned no snapshot path.'
    }
    $snapshotPath = (Resolve-Path -LiteralPath $snapshotMatch.Groups[1].Value.Trim()).Path
    $repositoryPrefix = $repositoryRoot.TrimEnd('\') + '\'
    if (-not $snapshotPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Environment snapshot was written outside the repository: $snapshotPath"
    }
    $snapshotDocument = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
    if ($snapshotDocument.schema_version -ne 'local_yarn_snapshot_v2' -or
        $snapshotDocument.verification_id -ne $existingStatus.verification_id -or
        $snapshotDocument.evidence_classification -ne 'INFRASTRUCTURE_VERIFICATION_ONLY' -or
        $snapshotDocument.observed_runtime_evidence.spark.application_id -ne $applicationId) {
        throw 'Environment snapshot identity/classification does not match the active verification.'
    }
    $relativeSnapshotPath = ($snapshotPath.Substring($repositoryRoot.Length) -replace '\\', '/').TrimStart('/')
    Write-LocalYarnJson -Value ([ordered]@{
        schema_version = 'local_yarn_environment_snapshot_ref_v1'
        evidence_classification = 'INFRASTRUCTURE_VERIFICATION_ONLY'
        verification_id = $existingStatus.verification_id
        application_id = $applicationId
        snapshot_id = $snapshotDocument.snapshot_id
        snapshot_ref = $relativeSnapshotPath
    }) -Path (Join-Path $EvidenceDirectory 'environment_snapshot_ref.json')

    $currentStep = 'VALIDATE_EVIDENCE_BUNDLE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $EvidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep -ApplicationId $applicationId | Out-Null
    Assert-LocalYarnEvidenceBundle `
        -Directory $EvidenceDirectory `
        -VerificationId $existingStatus.verification_id `
        -ApplicationId $applicationId

    Set-LocalYarnVerificationStatus `
        -EvidenceDirectory $EvidenceDirectory `
        -Status COMPLETE `
        -CurrentStep 'COMPLETE' `
        -ApplicationId $applicationId | Out-Null

    Write-Host 'INFRASTRUCTURE_SMOKE_VERIFICATION=PASS'
    Write-Host "APPLICATION_ID=$applicationId"
    Write-Host "EVIDENCE_DIRECTORY=$EvidenceDirectory"
} catch {
    $originalError = $_
    if ($statusCanBeUpdated -and $EvidenceDirectory -and (Test-Path -LiteralPath $EvidenceDirectory)) {
        try {
            Set-LocalYarnVerificationStatus `
                -EvidenceDirectory $EvidenceDirectory `
                -Status FAILED `
                -CurrentStep 'FAILED' `
                -FailedStep $currentStep `
                -FailureReason $_.Exception.Message `
                -ApplicationId $applicationId | Out-Null
        } catch {
            Write-Warning "Unable to update verification status: $($_.Exception.Message)"
        }
        $composeArgsVariable = Get-Variable -Name composeArgs -Scope Script -ErrorAction SilentlyContinue
        if ($composeArgsVariable) {
            try {
                [void](Invoke-ComposeEvidence `
                    -Name 'failure_compose_ps' `
                    -Command @('ps', '--all') `
                    -AllowCommandFailure)
                [void](Invoke-ComposeEvidence `
                    -Name 'failure_compose_logs' `
                    -Command @('logs', '--no-color', '--tail', '200') `
                    -AllowCommandFailure)
            } catch {
                Write-Warning "Unable to preserve failure diagnostics: $($_.Exception.Message)"
            }
        }
    }
    throw $originalError
} finally {
    Exit-LocalYarnVerificationLock -Lock $verificationLock
}
