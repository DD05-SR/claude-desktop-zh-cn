Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

try {
    $config = Get-Config
    $install = Resolve-ClaudeInstall -Config $config
    $report = Get-CompatibilityReport -Install $install

    Write-Host "Claude Desktop compatibility report" -ForegroundColor Cyan
    Write-Host "Version: $($report.version)"
    Write-Host "Resources: $($report.resourcesDir)"
    Write-Host "Resources found: $($report.resourcesFound)"
    Write-Host "I18n found: $($report.i18nFound)"
    Write-Host "Assets found: $($report.assetsFound)"
    Write-Host "Asset files: $($report.assetFileCount)"
    Write-Host "Patch matches: $($report.matched)"
    Write-Host "Already applied: $($report.alreadyApplied)"
    Write-Host "Unmatched patches: $($report.unmatched)"
    Write-Host "Required unmatched: $($report.requiredUnmatched)"
    Write-Host "Recommendation: $($report.recommendation)"

    if ($report.recommendation -eq "APPLY_OK") {
        Write-Host "This version looks compatible enough to apply." -ForegroundColor Green
        exit 0
    }

    Write-Host "This version needs maintenance before applying." -ForegroundColor Yellow
    exit 1
}
catch {
    Write-Host "Compatibility check failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
