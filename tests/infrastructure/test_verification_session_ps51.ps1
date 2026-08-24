[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $repositoryRoot 'infrastructure\docker\host\verification-session.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
    ('local-yarn-v1-verification-session-{0}' -f ([guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$firstLock = $null
$reacquiredLock = $null
$holderProcess = $null
try {
    $jsonPath = Join-Path $testRoot 'atomic.json'
    Write-LocalYarnJson -Value ([ordered]@{ revision = 1 }) -Path $jsonPath
    Write-LocalYarnJson -Value ([ordered]@{ revision = 2 }) -Path $jsonPath
    $document = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    Assert-True ($document.revision -eq 2) 'Atomic JSON replacement did not preserve the latest complete document.'
    Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Filter '*.tmp').Count -eq 0) `
        'Atomic JSON replacement left a temporary file behind.'

    $firstLock = Enter-LocalYarnVerificationLock -RepositoryRoot $testRoot
    $contentionObserved = $false
    try {
        $unexpectedLock = Enter-LocalYarnVerificationLock -RepositoryRoot $testRoot
        Exit-LocalYarnVerificationLock -Lock $unexpectedLock
    } catch {
        $contentionObserved = $_.Exception.Message -match 'lifecycle operation already holds'
    }
    Assert-True $contentionObserved 'A second verification lock holder was not rejected.'

    Exit-LocalYarnVerificationLock -Lock $firstLock
    $firstLock = $null
    $reacquiredLock = Enter-LocalYarnVerificationLock -RepositoryRoot $testRoot
    Assert-True ($null -ne $reacquiredLock) 'Verification lock could not be reacquired after release.'
    Exit-LocalYarnVerificationLock -Lock $reacquiredLock
    $reacquiredLock = $null

    $statusPath = Join-Path $testRoot 'status.json'
    Write-LocalYarnJson -Value ([ordered]@{ status = 'INCOMPLETE'; application_id = $null }) -Path $statusPath
    $statusHashBefore = (Get-FileHash -LiteralPath $statusPath -Algorithm SHA256).Hash
    $readyPath = Join-Path $testRoot 'holder.ready'
    $helperPath = Join-Path $repositoryRoot 'infrastructure\docker\host\verification-session.ps1'
    $escapedHelperPath = $helperPath.Replace("'", "''")
    $escapedTestRoot = $testRoot.Replace("'", "''")
    $escapedReadyPath = $readyPath.Replace("'", "''")
    $holderCode = @"
. '$escapedHelperPath'
`$lock = Enter-LocalYarnVerificationLock -RepositoryRoot '$escapedTestRoot'
[System.IO.File]::WriteAllText('$escapedReadyPath', 'ready')
try { Start-Sleep -Seconds 300 } finally { Exit-LocalYarnVerificationLock -Lock `$lock }
"@
    $encodedHolderCode = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($holderCode))
    $holderProcess = Start-Process `
        -FilePath (Join-Path $PSHOME 'powershell.exe') `
        -ArgumentList @('-NoProfile', '-EncodedCommand', $encodedHolderCode) `
        -WindowStyle Hidden `
        -PassThru
    for ($attempt = 1; $attempt -le 100 -and -not (Test-Path -LiteralPath $readyPath); $attempt++) {
        Start-Sleep -Milliseconds 50
    }
    Assert-True (Test-Path -LiteralPath $readyPath) 'Child lock holder did not become ready within 5 seconds.'

    $crossProcessContentionObserved = $false
    try {
        $unexpectedLock = Enter-LocalYarnVerificationLock -RepositoryRoot $testRoot
        Exit-LocalYarnVerificationLock -Lock $unexpectedLock
    } catch {
        $crossProcessContentionObserved = $_.Exception.Message -match 'lifecycle operation already holds'
    }
    Assert-True $crossProcessContentionObserved 'Cross-process verification lock contention was not rejected.'
    $statusHashAfter = (Get-FileHash -LiteralPath $statusPath -Algorithm SHA256).Hash
    Assert-True ($statusHashAfter -eq $statusHashBefore) 'Rejected lock contention changed the shared status document.'

    Stop-Process -Id $holderProcess.Id -Force
    [void]$holderProcess.WaitForExit(5000)
    $holderProcess = $null
    $reacquiredLock = Enter-LocalYarnVerificationLock -RepositoryRoot $testRoot
    Assert-True ($null -ne $reacquiredLock) 'Verification lock was not released after the holder process was killed.'

    Write-Host 'VERIFICATION_SESSION_PS51_REGRESSION=PASS'
} finally {
    if ($holderProcess -and -not $holderProcess.HasExited) {
        Stop-Process -Id $holderProcess.Id -Force -ErrorAction SilentlyContinue
        [void]$holderProcess.WaitForExit(5000)
    }
    Exit-LocalYarnVerificationLock -Lock $firstLock
    Exit-LocalYarnVerificationLock -Lock $reacquiredLock
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
