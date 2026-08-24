Set-StrictMode -Version 2.0

function Get-LocalYarnHostObservation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('HOST_BASELINE', 'CLUSTER_IDLE', 'POST_SMOKE')]
        [string]$Phase,
        [Parameter(Mandatory)] [string]$VerificationId,
        [Parameter(Mandatory)] [string]$ComposeFile,
        [Parameter(Mandatory)] [string]$EnvFile
    )

    $operatingSystem = Get-CimInstance Win32_OperatingSystem
    $computerSystem = Get-CimInstance Win32_ComputerSystem
    $processors = @(Get-CimInstance Win32_Processor | Select-Object `
        Name, NumberOfCores, NumberOfLogicalProcessors, LoadPercentage)
    $pageFiles = @(Get-CimInstance Win32_PageFileUsage | Select-Object `
        Name, AllocatedBaseSize, CurrentUsage, PeakUsage)
    $topProcesses = @(Get-Process |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 10 Name, Id, CPU, WorkingSet64)

    $dockerResult = Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList @('info', '--format', '{{json .}}') `
        -AllowNonZero
    $dockerInfo = $null
    if ($dockerResult.ExitCode -eq 0 -and $dockerResult.StdOut.Count -gt 0) {
        try {
            $dockerInfo = ($dockerResult.StdOut -join "`n") | ConvertFrom-Json
        } catch {
            $dockerInfo = $null
        }
    }

    $wslResult = Invoke-NativeCommand `
        -FilePath 'wsl.exe' `
        -ArgumentList @('--status') `
        -AllowNonZero

    $composeArgs = @('--env-file', $EnvFile, '-f', $ComposeFile, 'ps', '--all', '--quiet')
    $composeResult = Invoke-NativeCommand `
        -FilePath 'docker' `
        -ArgumentList (@('compose') + $composeArgs) `
        -AllowNonZero
    $containerIds = @($composeResult.StdOut | Where-Object { $_ -match '^[0-9a-f]{12,64}$' })
    $statsResult = $null
    if ($containerIds.Count -gt 0) {
        $statsResult = Invoke-NativeCommand `
            -FilePath 'docker' `
            -ArgumentList (@('stats', '--no-stream', '--format', '{{json .}}') + $containerIds) `
            -AllowNonZero
    }

    return [ordered]@{
        schema_version = 'local_yarn_host_observation_v1'
        benchmark_environment_id = 'LOCAL_YARN_V1'
        evidence_classification = 'INFRASTRUCTURE_VERIFICATION_ONLY'
        verification_id = $VerificationId
        phase = $Phase
        observed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        host_memory = [ordered]@{
            total_physical_memory_bytes = [int64]$computerSystem.TotalPhysicalMemory
            available_memory_bytes = [int64]$operatingSystem.FreePhysicalMemory * 1024
            os_caption = $operatingSystem.Caption
            os_version = $operatingSystem.Version
            os_architecture = $operatingSystem.OSArchitecture
        }
        cpu = [ordered]@{
            processors = $processors
        }
        pagefile = [ordered]@{
            observations = $pageFiles
            total_allocated_mb = [int64](($pageFiles | Measure-Object AllocatedBaseSize -Sum).Sum)
            total_current_usage_mb = [int64](($pageFiles | Measure-Object CurrentUsage -Sum).Sum)
        }
        background_processes = $topProcesses
        docker = [ordered]@{
            exit_code = $dockerResult.ExitCode
            error = if ($dockerResult.ExitCode -ne 0) { $dockerResult.StdErr -join "`n" } else { $null }
            operating_system = if ($dockerInfo) { $dockerInfo.OperatingSystem } else { $null }
            architecture = if ($dockerInfo) { $dockerInfo.Architecture } else { $null }
            cpus = if ($dockerInfo) { $dockerInfo.NCPU } else { $null }
            memory_bytes = if ($dockerInfo) { $dockerInfo.MemTotal } else { $null }
            compose_container_ids = $containerIds
            stats_json_lines = if ($statsResult) { @($statsResult.StdOut) } else { @() }
            stats_exit_code = if ($statsResult) { $statsResult.ExitCode } else { $null }
        }
        wsl = [ordered]@{
            exit_code = $wslResult.ExitCode
            stdout = @($wslResult.StdOut)
            stderr = @($wslResult.StdErr)
        }
    }
}

function Save-LocalYarnHostObservation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('HOST_BASELINE', 'CLUSTER_IDLE', 'POST_SMOKE')]
        [string]$Phase,
        [Parameter(Mandatory)] [string]$VerificationId,
        [Parameter(Mandatory)] [string]$EvidenceDirectory,
        [Parameter(Mandatory)] [string]$ComposeFile,
        [Parameter(Mandatory)] [string]$EnvFile
    )

    $observation = Get-LocalYarnHostObservation `
        -Phase $Phase `
        -VerificationId $VerificationId `
        -ComposeFile $ComposeFile `
        -EnvFile $EnvFile
    $fileName = '{0}.json' -f $Phase.ToLowerInvariant()
    $path = Join-Path $EvidenceDirectory $fileName
    Write-LocalYarnJson -Value $observation -Path $path
    return $path
}
