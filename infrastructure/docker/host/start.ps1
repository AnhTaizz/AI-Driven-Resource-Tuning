[CmdletBinding()]
param(
    [string]$EnvFile,
    [switch]$SkipPortCheck
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$composeFile = Join-Path $repositoryRoot 'infrastructure\docker\compose.yaml'
$staticTest = Join-Path $repositoryRoot 'tests\infrastructure\test_local_yarn_v1_contract.ps1'
. (Join-Path $PSScriptRoot 'native-command.ps1')
. (Join-Path $PSScriptRoot 'verification-session.ps1')
. (Join-Path $PSScriptRoot 'host-observation.ps1')
. (Join-Path $PSScriptRoot 'runtime-evidence.ps1')
. (Join-Path $PSScriptRoot 'environment-file.ps1')

if (-not $EnvFile) {
    $EnvFile = Join-Path $repositoryRoot 'configs\environments\local_yarn_v1.env'
}

$session = $null
$evidenceDirectory = $null
$currentStep = 'VALIDATE_INPUT'
$verificationLock = $null

try {
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

    $currentStep = 'CHECK_DOCKER_DAEMON'
    $dockerInfo = Invoke-NativeCommand -FilePath 'docker' -ArgumentList @('info') -AllowNonZero
    if ($dockerInfo.ExitCode -ne 0) {
        $session = New-LocalYarnVerificationSession -RepositoryRoot $repositoryRoot -DoNotActivate
        $evidenceDirectory = $session.evidence_directory
        $dockerInfo.Combined | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'docker_info.txt') -Encoding utf8
        $dockerInfo.StdOut | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'docker_info.stdout.txt') -Encoding utf8
        $dockerInfo.StdErr | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'docker_info.stderr.txt') -Encoding utf8
        Write-Warning "VERIFICATION_ID=$($session.verification_id)"
        Write-Warning "FAILED_EVIDENCE_DIRECTORY=$evidenceDirectory"
        throw 'Docker daemon is not reachable. Start Docker Desktop/WSL2 and retry.'
    }

    $currentStep = 'ACQUIRE_VERIFICATION_LOCK'
    $verificationLock = Enter-LocalYarnVerificationLock -RepositoryRoot $repositoryRoot

    $composeArgs = @('--env-file', $EnvFile, '-f', $composeFile)
    $runningResult = Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList (@('compose') + $composeArgs + @('ps', '--status', 'running', '--quiet'))
    $runningContainers = @($runningResult.StdOut | Where-Object { $_ -match '^[0-9a-f]{12,64}$' })
    if ($runningContainers.Count -gt 0) {
        throw 'LOCAL_YARN_V1 already has running services. Stop them before start.ps1 so HOST_BASELINE is genuinely pre-start.'
    }

    # Activate a new session only after the stopped-cluster preflight succeeds.
    # This preserves an existing INCOMPLETE session when start.ps1 is invoked
    # accidentally while its cluster is already waiting for verify.ps1.
    $session = New-LocalYarnVerificationSession -RepositoryRoot $repositoryRoot
    $evidenceDirectory = $session.evidence_directory
    $dockerInfo.Combined | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'docker_info.txt') -Encoding utf8
    $dockerInfo.StdOut | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'docker_info.stdout.txt') -Encoding utf8
    $dockerInfo.StdErr | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'docker_info.stderr.txt') -Encoding utf8

    $currentStep = 'CAPTURE_HOST_BASELINE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $evidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    $hostBaselinePath = Save-LocalYarnHostObservation `
        -Phase HOST_BASELINE `
        -VerificationId $session.verification_id `
        -EvidenceDirectory $evidenceDirectory `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile

    $currentStep = 'STATIC_CONTRACT'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $evidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    [void](Invoke-NativeCommand `
        -FilePath 'powershell.exe' `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $staticTest, '-EnvFile', $EnvFile))

    $currentStep = 'RESOLVE_JAVA_BASE_IMAGE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $evidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    $javaBaseTag = if ($settings.ContainsKey('JAVA_BASE_IMAGE')) {
        $settings['JAVA_BASE_IMAGE']
    } else {
        'eclipse-temurin:11.0.32_9-jdk-jammy'
    }
    if ($javaBaseTag -match '@sha256:') {
        $resolvedJavaBase = $javaBaseTag
    } else {
        $pullSucceeded = $false
        $lastPullResult = $null
        for ($pullAttempt = 1; $pullAttempt -le 3; $pullAttempt++) {
            $lastPullResult = Invoke-NativeCommand `
                -FilePath 'docker' `
                -ArgumentList @('pull', $javaBaseTag) `
                -AllowNonZero
            $lastPullResult.Combined | Set-Content `
                -LiteralPath (Join-Path $evidenceDirectory "java_base_image_pull_attempt_$pullAttempt.txt") `
                -Encoding utf8
            if ($lastPullResult.ExitCode -eq 0) {
                $pullSucceeded = $true
                break
            }
            if ($pullAttempt -lt 3) {
                Start-Sleep -Seconds 2
            }
        }
        if (-not $pullSucceeded) {
            $lastOutput = @($lastPullResult.Combined | Select-Object -Last 20) -join "`n"
            throw "Unable to pull Java base image $javaBaseTag after 3 attempts. Last observed output:`n$lastOutput"
        }
        $inspectResult = Invoke-NativeCommand `
            -FilePath 'docker' `
            -ArgumentList @('image', 'inspect', '--format', '{{index .RepoDigests 0}}', $javaBaseTag)
        $resolvedJavaBase = ($inspectResult.StdOut -join '').Trim()
        if (-not $resolvedJavaBase -or $resolvedJavaBase -notmatch '@sha256:[0-9a-f]{64}$') {
            throw "Unable to resolve an immutable digest for $javaBaseTag."
        }
    }
    $env:JAVA_BASE_IMAGE = $resolvedJavaBase
    $env:JAVA_BASE_IMAGE_SOURCE = $javaBaseTag
    $currentStep = 'RESOLVE_JAVA_PLATFORM_MANIFEST'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $evidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    $serverPlatformResult = Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList @('version', '--format', '{{.Server.Os}}/{{.Server.Arch}}')
    $serverPlatform = ($serverPlatformResult.StdOut -join '').Trim()
    if ($serverPlatform -notmatch '^(?<os>[a-z0-9_-]+)/(?<architecture>[a-z0-9_-]+)$') {
        throw "Unable to identify the Docker Engine platform from '$serverPlatform'."
    }
    $platformOs = $Matches['os']
    $platformArchitecture = $Matches['architecture']

    $manifestResult = $null
    $manifestResolved = $false
    for ($manifestAttempt = 1; $manifestAttempt -le 3; $manifestAttempt++) {
        $manifestResult = Invoke-NativeCommand `
            -FilePath 'docker' `
            -ArgumentList @('buildx', 'imagetools', 'inspect', '--raw', $resolvedJavaBase) `
            -AllowNonZero
        $manifestResult.Combined | Set-Content `
            -LiteralPath (Join-Path $evidenceDirectory "java_base_manifest_attempt_$manifestAttempt.txt") `
            -Encoding utf8
        if ($manifestResult.ExitCode -eq 0) {
            $manifestResolved = $true
            break
        }
        if ($manifestAttempt -lt 3) {
            Start-Sleep -Seconds 2
        }
    }
    if (-not $manifestResolved) {
        $lastOutput = @($manifestResult.Combined | Select-Object -Last 20) -join "`n"
        throw "Unable to resolve the platform manifest for $resolvedJavaBase after 3 attempts. Last observed output:`n$lastOutput"
    }
    $manifestText = ($manifestResult.StdOut -join "`n").Trim()
    try {
        $manifestDocument = $manifestText | ConvertFrom-Json
    } catch {
        throw "OCI manifest inspection returned invalid JSON: $($_.Exception.Message)"
    }
    $descriptorDigestMatch = [regex]::Match($resolvedJavaBase, '@(sha256:[0-9a-f]{64})$')
    if (-not $descriptorDigestMatch.Success) {
        throw "Resolved Java base reference lacks an immutable descriptor digest: $resolvedJavaBase"
    }
    $registryDescriptorDigest = $descriptorDigestMatch.Groups[1].Value
    $manifestListProperty = $manifestDocument.PSObject.Properties['manifests']
    if ($manifestListProperty) {
        $platformMatches = @($manifestDocument.manifests | Where-Object {
            $_.platform.os -eq $platformOs -and
            $_.platform.architecture -eq $platformArchitecture
        })
        if ($platformMatches.Count -ne 1) {
            throw "Expected exactly one OCI manifest for $serverPlatform, observed $($platformMatches.Count)."
        }
        $platformManifestDigest = [string]$platformMatches[0].digest
        $platformManifestMediaType = [string]$platformMatches[0].mediaType
    } else {
        $platformManifestDigest = $registryDescriptorDigest
        $platformManifestMediaType = [string]$manifestDocument.mediaType
    }
    if ($platformManifestDigest -notmatch '^sha256:[0-9a-f]{64}$') {
        throw "OCI platform manifest for $serverPlatform has an invalid digest: $platformManifestDigest"
    }
    $baseRepository = $resolvedJavaBase.Substring(0, $resolvedJavaBase.LastIndexOf('@'))
    $platformManifestReference = "$baseRepository@$platformManifestDigest"
    $env:JAVA_BASE_IMAGE = $platformManifestReference
    Write-LocalYarnJson -Value ([ordered]@{
        observation_kind = 'OBSERVED_LOCAL_IMAGE_RESOLUTION'
        observed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        source_reference = $javaBaseTag
        resolved_reference = $platformManifestReference
        registry_descriptor_reference = $resolvedJavaBase
        registry_descriptor_digest = $registryDescriptorDigest
        registry_descriptor_media_type = [string]$manifestDocument.mediaType
        selected_platform = $serverPlatform
        platform_manifest_digest = $platformManifestDigest
        platform_manifest_media_type = $platformManifestMediaType
        platform_manifest_reference = $platformManifestReference
        resolution_source = 'docker buildx imagetools inspect --raw'
    }) -Path (Join-Path $evidenceDirectory 'java_base_image_resolution.json')
    Write-Host "Resolved Java base registry descriptor: $resolvedJavaBase"
    Write-Host "Pinned Java base build reference: $platformManifestReference"

    if (-not $SkipPortCheck) {
        $nameNodePort = if ($settings.ContainsKey('NAMENODE_UI_PORT')) { [int]$settings['NAMENODE_UI_PORT'] } else { 9870 }
        $resourceManagerPort = if ($settings.ContainsKey('RESOURCE_MANAGER_UI_PORT')) { [int]$settings['RESOURCE_MANAGER_UI_PORT'] } else { 8088 }
        $historyServerPort = if ($settings.ContainsKey('HISTORY_SERVER_UI_PORT')) { [int]$settings['HISTORY_SERVER_UI_PORT'] } else { 18080 }
        foreach ($port in @($nameNodePort, $resourceManagerPort, $historyServerPort)) {
            if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) {
                throw "Host port $port is already in use. Override it in the local environment file."
            }
        }
    }

    # Every service consumes the same tagged runtime image. Build one canonical
    # service target so Compose does not export the identical multi-GB image once
    # per daemon before startup.
    $currentStep = 'BUILD_COMMON_IMAGE'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $evidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    [void](Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList (@('compose') + $composeArgs + @('build', 'namenode')))

    $currentStep = 'START_CLUSTER'
    Set-LocalYarnVerificationStatus -EvidenceDirectory $evidenceDirectory -Status INCOMPLETE -CurrentStep $currentStep | Out-Null
    [void](Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList (@('compose') + $composeArgs + @('up', '--detach', '--no-build', '--force-recreate')))
    [void](Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList (@('compose') + $composeArgs + @('ps', '--all')))

    $startedServices = Get-LocalYarnServiceImageEvidence `
        -ComposeFile $composeFile `
        -EnvFile $EnvFile `
        -IntendedImage $imageName `
        -SkipLifecycleValidation
    Write-LocalYarnJson `
        -Value $startedServices `
        -Path (Join-Path $evidenceDirectory 'started_service_images.json')

    Set-LocalYarnVerificationStatus `
        -EvidenceDirectory $evidenceDirectory `
        -Status INCOMPLETE `
        -CurrentStep 'CLUSTER_STARTED_PENDING_VERIFICATION' | Out-Null

    Write-Host 'LOCAL_YARN_V1 services started. Run host/verify.ps1 before requesting VERIFIED review.'
    Write-Host "VERIFICATION_ID=$($session.verification_id)"
    Write-Host "EVIDENCE_DIRECTORY=$evidenceDirectory"
    Write-Host "HOST_BASELINE=$hostBaselinePath"
} catch {
    if ($evidenceDirectory -and (Test-Path -LiteralPath $evidenceDirectory)) {
        try {
            Set-LocalYarnVerificationStatus `
                -EvidenceDirectory $evidenceDirectory `
                -Status FAILED `
                -CurrentStep 'FAILED' `
                -FailedStep $currentStep `
                -FailureReason $_.Exception.Message | Out-Null
        } catch {
            Write-Warning "Unable to update verification status: $($_.Exception.Message)"
        }
    }
    throw
} finally {
    Exit-LocalYarnVerificationLock -Lock $verificationLock
}
