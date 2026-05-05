Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

try {
    $config = Get-Config
    $issues = @(Get-VerificationIssues -Config $config)
    if ($issues.Count -gt 0) {
        Write-Host "VERIFY FAILED" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host " - $issue"
        }
        exit 1
    }

    Write-Host "VERIFY OK" -ForegroundColor Green
    Write-Host "目标版本: $($config['supportedVersion'])"
    Write-Host "校验内容: root / ion / overrides / statsig / runtime patches"
    exit 0
}
catch {
    Write-Host "校验失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
