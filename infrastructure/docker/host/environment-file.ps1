Set-StrictMode -Version 2.0

function Import-LocalYarnEnvironmentFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing environment file: $Path"
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $settings = @{}
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $resolvedPath) {
        $lineNumber++
        if ($line -match '^\s*(?:#.*)?$') {
            continue
        }
        if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            throw "Invalid environment assignment at ${resolvedPath}:$lineNumber."
        }

        $name = $matches[1]
        $value = $matches[2].Trim()
        if ($settings.ContainsKey($name)) {
            throw "Duplicate environment variable $name at ${resolvedPath}:$lineNumber."
        }

        $settings[$name] = $value
        # Compose gives process variables precedence over --env-file. Apply the
        # selected file explicitly so host checks and Compose resolve one config.
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }

    return $settings
}
