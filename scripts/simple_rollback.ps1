$ErrorActionPreference = "Continue"

$base = "C:\Program Files\WindowsApps\Claude_1.5354.0.0_x64__pzs8sxrjxfjjc\app\resources"

$targets = @(
    (Join-Path $base "zh-CN.json"),
    (Join-Path $base "ion-dist\i18n\zh-CN.json"),
    (Join-Path $base "ion-dist\i18n\zh-CN.json.zst"),
    (Join-Path $base "ion-dist\i18n\zh-CN.overrides.json"),
    (Join-Path $base "ion-dist\i18n\zh-CN.overrides.json.zst"),
    (Join-Path $base "ion-dist\i18n\statsig\zh-CN.json"),
    (Join-Path $base "ion-dist\i18n\statsig\zh-CN.json.zst")
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Claude Desktop Rollback" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$delCount = 0
foreach ($t in $targets) {
    if (Test-Path -LiteralPath $t) {
        try {
            Remove-Item -LiteralPath $t -Force -ErrorAction Stop
            Write-Host "  [OK] Deleted: $(Split-Path -Leaf $t)" -ForegroundColor Green
            $delCount++
        } catch {
            Write-Host "  [FAIL] Cannot delete: $(Split-Path -Leaf $t) - $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [N/A] Not found: $(Split-Path -Leaf $t)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Deleted $delCount file(s). Restart Claude Desktop to restore English UI." -ForegroundColor Green
Read-Host "Press Enter to exit"
