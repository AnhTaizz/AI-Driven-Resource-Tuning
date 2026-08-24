[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$nativeCommandHelper = Join-Path $repositoryRoot 'infrastructure\docker\host\native-command.ps1'
. $nativeCommandHelper

function Assert-True {
    param([bool]$Condition, [string]$Message)

    if (-not $Condition) {
        throw $Message
    }
}

$windowsPowerShell = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path -LiteralPath $windowsPowerShell)) {
    throw "Windows PowerShell executable was not found at $windowsPowerShell."
}

function ConvertTo-EncodedPowerShellCommand {
    param([string]$Command)

    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
}

$successCommand = @(
    '-NoProfile',
    '-EncodedCommand',
    (ConvertTo-EncodedPowerShellCommand "[Console]::Out.WriteLine('stdout-success'); [Console]::Error.WriteLine('stderr-success'); exit 0")
)
$successItems = @(& {
    Invoke-NativeCommand -FilePath $windowsPowerShell -ArgumentList $successCommand
} 3>&1)
$successResult = @($successItems | Where-Object {
    $_.PSObject.Properties.Name -contains 'ExitCode'
}) | Select-Object -Last 1
$visibleWarnings = @($successItems | Where-Object {
    $_ -is [System.Management.Automation.WarningRecord]
})

Assert-True ($null -ne $successResult) 'The successful native command did not return a result.'
Assert-True ($successResult.ExitCode -eq 0) 'The successful native command did not capture exit code 0.'
Assert-True ($successResult.StdOut -contains 'stdout-success') 'Successful stdout was not captured.'
Assert-True ($successResult.StdErr -contains 'stderr-success') 'Successful stderr was not captured.'
Assert-True ($successResult.Combined -contains 'stdout-success') 'Combined output omitted stdout.'
Assert-True ($successResult.Combined -contains 'stderr-success') 'Combined output omitted stderr.'
Assert-True (@($visibleWarnings | Where-Object { $_.Message -eq 'stderr-success' }).Count -eq 1) 'Captured stderr was not preserved as a visible warning.'
Assert-True ($ErrorActionPreference -eq 'Stop') 'ErrorActionPreference was not restored after a successful native command.'

$failureCommand = @(
    '-NoProfile',
    '-EncodedCommand',
    (ConvertTo-EncodedPowerShellCommand "[Console]::Out.WriteLine('stdout-failure'); [Console]::Error.WriteLine('stderr-failure'); exit 7")
)
$failureThrown = $false
$failureResult = $null
$failureMessage = $null
try {
    [void](Invoke-NativeCommand -FilePath $windowsPowerShell -ArgumentList $failureCommand -NoEcho)
} catch {
    $failureThrown = $true
    $failureResult = $_.Exception.Data['NativeCommandResult']
    $failureMessage = $_.Exception.Message
}

Assert-True $failureThrown 'A non-zero native exit code did not fail.'
Assert-True ($null -ne $failureResult) 'The native failure did not retain its captured result.'
Assert-True ($failureResult.ExitCode -eq 7) 'The native failure did not capture exit code 7.'
Assert-True ($failureResult.StdOut -contains 'stdout-failure') 'Failure stdout was not captured.'
Assert-True ($failureResult.StdErr -contains 'stderr-failure') 'Failure stderr was not captured.'
Assert-True ($failureResult.Combined -contains 'stdout-failure') 'Failure combined output omitted stdout.'
Assert-True ($failureResult.Combined -contains 'stderr-failure') 'Failure combined output omitted stderr.'
Assert-True ($failureMessage -match 'Last observed output' -and $failureMessage -match 'stderr-failure') 'Native failure message omitted its bounded last-output context.'
Assert-True ($ErrorActionPreference -eq 'Stop') 'ErrorActionPreference was not restored after a failing native command.'

$allowedFailure = Invoke-NativeCommand -FilePath $windowsPowerShell -ArgumentList $failureCommand -AllowNonZero -NoEcho
Assert-True ($allowedFailure.ExitCode -eq 7) 'AllowNonZero did not return the native non-zero exit code.'
Assert-True ($ErrorActionPreference -eq 'Stop') 'ErrorActionPreference was not restored after AllowNonZero.'

Write-Host 'NATIVE_COMMAND_PS51_REGRESSION=PASS'
