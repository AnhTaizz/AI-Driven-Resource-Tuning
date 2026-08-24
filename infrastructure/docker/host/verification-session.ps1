Set-StrictMode -Version 2.0

function Write-LocalYarnJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Value,
        [Parameter(Mandatory)] [string]$Path,
        [int]$Depth = 30
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporaryPath = Join-Path $parent ('.{0}.{1}.tmp' -f `
        (Split-Path -Leaf $Path), `
        ([guid]::NewGuid().ToString('N')))
    $backupPath = "$temporaryPath.backup"
    try {
        $json = $Value | ConvertTo-Json -Depth $Depth
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($temporaryPath, $json, $utf8WithBom)
        if (Test-Path -LiteralPath $Path) {
            [System.IO.File]::Replace($temporaryPath, $Path, $backupPath)
            Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
        } else {
            [System.IO.File]::Move($temporaryPath, $Path)
        }
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Enter-LocalYarnVerificationLock {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$RepositoryRoot)

    $baseDirectory = Join-Path $RepositoryRoot 'artifacts\infrastructure_smoke'
    if (-not (Test-Path -LiteralPath $baseDirectory)) {
        New-Item -ItemType Directory -Path $baseDirectory -Force | Out-Null
    }
    $lockPath = Join-Path $baseDirectory '.verification.lock'
    try {
        return New-Object System.IO.FileStream(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    } catch {
        $candidate = $_.Exception
        while ($candidate -and $candidate -isnot [System.IO.IOException] -and $candidate.InnerException) {
            $candidate = $candidate.InnerException
        }
        $nativeErrorCode = if ($candidate -is [System.IO.IOException]) {
            $candidate.HResult -band 0xFFFF
        } else {
            $null
        }
        if ($nativeErrorCode -in @(32, 33)) {
            throw "Another LOCAL_YARN_V1 lifecycle operation already holds $lockPath. Wait for it to finish before retrying."
        }
        throw
    }
}

function Exit-LocalYarnVerificationLock {
    [CmdletBinding()]
    param([System.IO.FileStream]$Lock)

    if ($null -ne $Lock) {
        $Lock.Dispose()
    }
}

function New-LocalYarnVerificationSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$RepositoryRoot,
        [switch]$DoNotActivate
    )

    $startedAt = (Get-Date).ToUniversalTime()
    $verificationId = 'LOCAL_YARN_V1_{0}_{1}' -f `
        $startedAt.ToString('yyyyMMddTHHmmssfffZ'), `
        ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $baseDirectory = Join-Path $RepositoryRoot 'artifacts\infrastructure_smoke'
    $evidenceDirectory = Join-Path $baseDirectory $verificationId
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null

    $status = [ordered]@{
        schema_version = 'local_yarn_verification_status_v1'
        verification_id = $verificationId
        evidence_classification = 'INFRASTRUCTURE_VERIFICATION_ONLY'
        benchmark_environment_id = 'LOCAL_YARN_V1'
        started_at = $startedAt.ToString('o')
        finished_at = $null
        status = 'INCOMPLETE'
        current_step = 'INITIALIZING'
        failed_step = $null
        failure_reason = $null
        application_id = $null
        local_yarn_v1_status = 'PLANNED'
        c1_status = 'TBD'
        data_gate_status = 'NOT_APPROVED'
    }
    $statusPath = Join-Path $evidenceDirectory 'verification_status.json'
    Write-LocalYarnJson -Value $status -Path $statusPath

    $active = [ordered]@{
        verification_id = $verificationId
        evidence_directory = $evidenceDirectory
        status_path = $statusPath
    }
    if (-not $DoNotActivate) {
        $activePath = Join-Path $baseDirectory '.active-verification.json'
        Write-LocalYarnJson -Value $active -Path $activePath
    }

    return [pscustomobject]$active
}

function Get-LocalYarnActiveVerificationSession {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$RepositoryRoot)

    $activePath = Join-Path $RepositoryRoot 'artifacts\infrastructure_smoke\.active-verification.json'
    if (-not (Test-Path -LiteralPath $activePath)) {
        return $null
    }
    $active = Get-Content -LiteralPath $activePath -Raw | ConvertFrom-Json
    if (-not $active.evidence_directory -or -not (Test-Path -LiteralPath $active.evidence_directory)) {
        throw "Active verification pointer is invalid: $activePath"
    }
    return $active
}

function Set-LocalYarnVerificationStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$EvidenceDirectory,
        [Parameter(Mandatory)] [ValidateSet('INCOMPLETE', 'COMPLETE', 'FAILED')] [string]$Status,
        [Parameter(Mandatory)] [string]$CurrentStep,
        [string]$FailedStep,
        [string]$FailureReason,
        [string]$ApplicationId
    )

    $statusPath = Join-Path $EvidenceDirectory 'verification_status.json'
    if (-not (Test-Path -LiteralPath $statusPath)) {
        throw "Missing verification status document: $statusPath"
    }

    $document = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    $document.status = $Status
    $document.current_step = $CurrentStep
    $document.failed_step = if ($FailedStep) { $FailedStep } else { $null }
    $document.failure_reason = if ($FailureReason) { $FailureReason } else { $null }
    if ($ApplicationId) {
        $document.application_id = $ApplicationId
    }
    $document.finished_at = if ($Status -in @('COMPLETE', 'FAILED')) {
        (Get-Date).ToUniversalTime().ToString('o')
    } else {
        $null
    }
    Write-LocalYarnJson -Value $document -Path $statusPath
    return $document
}
