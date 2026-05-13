Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

try {
    $config = Get-Config
    $install = Resolve-ClaudeInstall -Config $config
    Write-Host "Claude Desktop detected" -ForegroundColor Green
    Write-Host "Version: $($install.Version)"
    Write-Host "Resources: $($install.ResourcesDir)"
    Write-Host "Assets: $($install.AssetsDir)"
    Write-Host "I18n: $($install.I18nDir)"
    exit 0
}
catch {
    Write-Host "Detect failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
