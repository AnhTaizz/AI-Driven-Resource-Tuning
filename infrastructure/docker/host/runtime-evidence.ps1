Set-StrictMode -Version 2.0

function Get-LocalYarnServiceImageEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ComposeFile,
        [Parameter(Mandatory)] [string]$EnvFile,
        [Parameter(Mandatory)] [string]$IntendedImage,
        [switch]$SkipLifecycleValidation,
        [string[]]$Services = @(
            'namenode',
            'datanode-1',
            'datanode-2',
            'hdfs-init',
            'resourcemanager',
            'nodemanager-1',
            'nodemanager-2',
            'history-server'
        )
    )

    $intendedResult = Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList @('image', 'inspect', '--format', '{{json .}}', $IntendedImage)
    $intendedJson = $intendedResult.StdOut | Where-Object { $_ -match '^\{.*\}$' } | Select-Object -Last 1
    if (-not $intendedJson) {
        throw "Unable to inspect intended LOCAL_YARN_V1 image $IntendedImage."
    }
    $intendedInspect = $intendedJson | ConvertFrom-Json
    $composePrefix = @('compose', '--env-file', $EnvFile, '-f', $ComposeFile)
    $observed = @()

    foreach ($service in $Services) {
        $psResult = Invoke-NativeCommand `
            -FilePath 'docker' `
            -ArgumentList ($composePrefix + @('ps', '--all', '--quiet', $service))
        $containerIds = @($psResult.StdOut | Where-Object { $_ -match '^[0-9a-f]{12,64}$' })
        if ($containerIds.Count -ne 1) {
            throw "Expected exactly one container for service $service, observed $($containerIds.Count)."
        }
        $containerId = $containerIds[0]

        $inspectResult = Invoke-NativeCommand `
            -FilePath 'docker' `
            -ArgumentList @('container', 'inspect', '--format', '{{json .}}', $containerId)
        $inspectJson = $inspectResult.StdOut | Where-Object { $_ -match '^\{.*\}$' } | Select-Object -Last 1
        if (-not $inspectJson) {
            throw "Container inspect returned no JSON for service $service."
        }
        $inspect = $inspectJson | ConvertFrom-Json
        $health = $null
        $healthProperty = $inspect.State.PSObject.Properties['Health']
        if ($healthProperty -and $healthProperty.Value) {
            $healthStatusProperty = $healthProperty.Value.PSObject.Properties['Status']
            if ($healthStatusProperty) {
                $health = [string]$healthStatusProperty.Value
            }
        }

        $imageResult = Invoke-NativeCommand `
            -FilePath 'docker' `
            -ArgumentList @('image', 'inspect', '--format', '{{json .}}', $inspect.Image)
        $imageJson = $imageResult.StdOut | Where-Object { $_ -match '^\{.*\}$' } | Select-Object -Last 1
        if (-not $imageJson) {
            throw "Image inspect returned no JSON for service $service."
        }
        $actualImage = $imageJson | ConvertFrom-Json
        $actualRepoDigestsProperty = $actualImage.PSObject.Properties['RepoDigests']
        [string[]]$actualRepoDigests = @()
        if ($actualRepoDigestsProperty) {
            $actualRepoDigests = [string[]]@($actualRepoDigestsProperty.Value | Where-Object { $_ })
        }

        $cgroupSwapCurrentBytes = $null
        $cgroupSwapPeakBytes = $null
        $cgroupSwapMaxBytes = $null
        if ($inspect.State.Status -eq 'running') {
            $swapResult = Invoke-NativeCommand `
                -FilePath 'docker' `
                -ArgumentList @(
                    'container', 'exec', $containerId,
                    'cat',
                    '/sys/fs/cgroup/memory.swap.current',
                    '/sys/fs/cgroup/memory.swap.peak',
                    '/sys/fs/cgroup/memory.swap.max'
                ) `
                -AllowNonZero `
                -NoEcho
            if ($swapResult.ExitCode -eq 0 -and $swapResult.StdOut.Count -eq 3) {
                $cgroupSwapCurrentBytes = [int64]$swapResult.StdOut[0]
                $cgroupSwapPeakBytes = [int64]$swapResult.StdOut[1]
                $cgroupSwapMaxBytes = if ($swapResult.StdOut[2] -eq 'max') {
                    $null
                } else {
                    [int64]$swapResult.StdOut[2]
                }
            }
        }

        $observed += [pscustomobject][ordered]@{
            service = $service
            compose_service = $inspect.Config.Labels.'com.docker.compose.service'
            container_name = ([string]$inspect.Name).TrimStart('/')
            container_id = $inspect.Id
            image_reference = $inspect.Config.Image
            actual_image_id = $inspect.Image
            actual_image_repo_digests = $actualRepoDigests
            intended_image_reference = $IntendedImage
            intended_image_id = $intendedInspect.Id
            common_image_match = ($inspect.Image -eq $intendedInspect.Id)
            state = $inspect.State.Status
            health = $health
            exit_code = $inspect.State.ExitCode
            restart_count = [int]$inspect.RestartCount
            started_at = $inspect.State.StartedAt
            finished_at = $inspect.State.FinishedAt
            cgroup_swap_current_bytes = $cgroupSwapCurrentBytes
            cgroup_swap_peak_bytes = $cgroupSwapPeakBytes
            cgroup_swap_max_bytes = $cgroupSwapMaxBytes
        }
    }

    $mismatches = @($observed | Where-Object { -not $_.common_image_match })
    if ($mismatches.Count -gt 0) {
        throw "Services do not use the intended common image: $((@($mismatches.service) -join ', '))."
    }
    if (-not $SkipLifecycleValidation) {
        $invalidLifecycle = @($observed | Where-Object {
            if ($_.service -eq 'hdfs-init') {
                return $_.state -ne 'exited' -or $_.exit_code -ne 0 -or $_.restart_count -ne 0
            }
            return $_.state -ne 'running' -or $_.health -ne 'healthy' -or $_.restart_count -ne 0
        })
        if ($invalidLifecycle.Count -gt 0) {
            $summary = @($invalidLifecycle | ForEach-Object {
                "$($_.service):state=$($_.state),health=$($_.health),exit=$($_.exit_code),restarts=$($_.restart_count)"
            }) -join '; '
            throw "LOCAL_YARN_V1 service lifecycle check failed: $summary"
        }
    }

    $intendedRepoDigestsProperty = $intendedInspect.PSObject.Properties['RepoDigests']
    [string[]]$intendedRepoDigests = @()
    if ($intendedRepoDigestsProperty) {
        $intendedRepoDigests = [string[]]@($intendedRepoDigestsProperty.Value | Where-Object { $_ })
    }

    return [ordered]@{
        intended_image = [ordered]@{
            reference = $IntendedImage
            image_id = $intendedInspect.Id
            repo_digests = $intendedRepoDigests
            java_base_image = $intendedInspect.Config.Labels.'local_yarn.java_base_image'
            java_base_image_source = $intendedInspect.Config.Labels.'local_yarn.java_base_image_source'
            created = $intendedInspect.Created
            architecture = $intendedInspect.Architecture
            os = $intendedInspect.Os
        }
        services = $observed
    }
}

function Get-LocalYarnVersionObservation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateSet('spark-client', 'nodemanager-1', 'nodemanager-2')]
        [string]$EnvironmentName,
        [Parameter(Mandatory)] [string]$ComposeFile,
        [Parameter(Mandatory)] [string]$EnvFile
    )

    $composePrefix = @('compose', '--env-file', $EnvFile, '-f', $ComposeFile)
    if ($EnvironmentName -eq 'spark-client') {
        $arguments = $composePrefix + @('run', '--rm', '--no-deps', 'spark-client', 'version-report')
    } else {
        $arguments = $composePrefix + @(
            'exec', '-T', $EnvironmentName, '/opt/local-yarn/bin/snapshot-container.sh'
        )
    }

    $result = Invoke-NativeCommand -FilePath 'docker' -ArgumentList $arguments
    $jsonLine = $result.StdOut | Where-Object { $_ -match '^\{.*\}$' } | Select-Object -Last 1
    if (-not $jsonLine) {
        throw "Version observation for $EnvironmentName returned no JSON object."
    }
    $versions = $jsonLine | ConvertFrom-Json
    return [ordered]@{
        environment = $EnvironmentName
        observed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        normalized = $versions
        raw_stdout = @($result.StdOut)
        raw_stderr = @($result.StdErr)
    }
}
