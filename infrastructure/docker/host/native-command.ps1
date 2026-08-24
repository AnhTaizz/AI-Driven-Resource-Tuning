function Invoke-NativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [AllowEmptyCollection()]
        [string[]]$ArgumentList = @(),

        [switch]$AllowNonZero,

        [switch]$NoEcho
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $rawOutput = @()
    $exitCode = $null

    try {
        # Windows PowerShell 5.1 promotes native stderr records to errors when the
        # caller uses ErrorActionPreference=Stop. Capture them without allowing a
        # warning from an otherwise successful native process to terminate it.
        $ErrorActionPreference = 'Continue'
        $rawOutput = @(& $FilePath @ArgumentList 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $stdout = New-Object 'System.Collections.Generic.List[string]'
    $stderr = New-Object 'System.Collections.Generic.List[string]'
    $combined = New-Object 'System.Collections.Generic.List[string]'

    foreach ($entry in $rawOutput) {
        $line = $entry.ToString()
        [void]$combined.Add($line)

        if ($entry -is [System.Management.Automation.ErrorRecord]) {
            [void]$stderr.Add($line)
            if (-not $NoEcho) {
                Write-Warning $line
            }
        } else {
            [void]$stdout.Add($line)
            if (-not $NoEcho) {
                Write-Host $line
            }
        }
    }

    $result = [pscustomobject][ordered]@{
        FilePath = $FilePath
        ArgumentList = [string[]]@($ArgumentList)
        ExitCode = [int]$exitCode
        StdOut = [string[]]@($stdout)
        StdErr = [string[]]@($stderr)
        Combined = [string[]]@($combined)
    }

    if ($result.ExitCode -ne 0 -and -not $AllowNonZero) {
        $lastOutput = @($result.Combined | Select-Object -Last 10) -join "`n"
        $message = "Native command '$FilePath' failed with exit code $($result.ExitCode)."
        if (-not [string]::IsNullOrWhiteSpace($lastOutput)) {
            $message += " Last observed output:`n$lastOutput"
        }
        $exception = New-Object System.InvalidOperationException(
            $message
        )
        $exception.Data['NativeCommandResult'] = $result
        throw $exception
    }

    return $result
}
