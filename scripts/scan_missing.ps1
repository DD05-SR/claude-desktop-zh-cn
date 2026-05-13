Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

try {
    $config = Get-Config
    $install = Resolve-ClaudeInstall -Config $config
    $outputPath = Join-Path (Get-ProjectRoot) (Get-Value $config "missingTranslationsPath" "locales\missing-zh-CN.json")
    $items = @(Scan-MissingTranslations -AssetsDir $install.AssetsDir -OutputPath $outputPath)

    Write-Host "Missing translation scan completed." -ForegroundColor Green
    Write-Host "Claude version: $($install.Version)"
    Write-Host "English candidates: $($items.Count)"
    Write-Host "Output file: $outputPath"
    exit 0
}
catch {
    Write-Host "Scan failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
