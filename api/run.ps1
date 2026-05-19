$ErrorActionPreference = "Stop"

$apiDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $apiDir

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
}

python app.py
