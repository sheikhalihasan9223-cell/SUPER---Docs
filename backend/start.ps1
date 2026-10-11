$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$settingsFile = Join-Path $PSScriptRoot '.env'
if (Test-Path -LiteralPath $settingsFile) {
    foreach ($line in Get-Content -LiteralPath $settingsFile) {
        if ($line -match '^([A-Z_]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim().Trim('"').Trim("'"), 'Process')
        }
    }
}
& (Join-Path $PSScriptRoot '.venv/Scripts/python.exe') -m uvicorn app:app --host 0.0.0.0 --port 8000
