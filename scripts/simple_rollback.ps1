$ErrorActionPreference = "Continue"

# Auto-detect Claude install
$base = $null
$dirs = @(Get-ChildItem "C:\Program Files\WindowsApps" -Directory -Filter "Claude_*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
foreach ($d in $dirs) {
    $res = Join-Path $d.FullName "app\resources"
    if (Test-Path (Join-Path $res "app.asar")) { $base = $res; break }
}
if (-not $base) {
    Write-Host "ERROR: Claude Desktop not found." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$i18nDir = Join-Path $base "ion-dist\i18n"
$assetsDir = Join-Path $base "ion-dist\assets\v1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Claude Desktop Rollback" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$removed = @()
$restored = @()

# Delete zh-CN locale files
$localeFiles = @(
    (Join-Path $base "zh-CN.json"),
    (Join-Path $i18nDir "zh-CN.json"),
    (Join-Path $i18nDir "zh-CN.json.zst"),
    (Join-Path $i18nDir "zh-CN.overrides.json"),
    (Join-Path $i18nDir "zh-CN.overrides.json.zst"),
    (Join-Path $i18nDir "statsig\zh-CN.json"),
    (Join-Path $i18nDir "statsig\zh-CN.json.zst")
)

foreach ($f in $localeFiles) {
    if (Test-Path $f) {
        try { Remove-Item $f -Force -ErrorAction Stop; $removed += $f; Write-Host "  [DEL] $(Split-Path -Leaf $f)" -ForegroundColor Green }
        catch { Write-Host "  [FAIL] $(Split-Path -Leaf $f): $_" -ForegroundColor Red }
    }
}

# Restore .zst from .bak (reverse the rename)
if (Test-Path $assetsDir) {
    $bakFiles = @(Get-ChildItem $assetsDir -Filter "*.js.zst.bak" -File -ErrorAction SilentlyContinue)
    $bakFiles += @(Get-ChildItem $assetsDir -Filter "*.css.zst.bak" -File -ErrorAction SilentlyContinue)
    foreach ($f in $bakFiles) {
        $origName = $f.Name -replace '\.bak$', ''
        $origPath = Join-Path $assetsDir $origName
        try {
            Rename-Item -LiteralPath $f.FullName -NewName $origName -Force -ErrorAction Stop
            Write-Host "  [RESTORE] $origName" -ForegroundColor Green
            $restored += $origPath
        } catch { Write-Host "  [FAIL] $origName: $_" -ForegroundColor Red }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Rollback complete" -ForegroundColor Cyan
Write-Host "  Removed: $($removed.Count) file(s)" -ForegroundColor Cyan
Write-Host "  Restored: $($restored.Count) cache(s)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Restart Claude Desktop to restore English UI." -ForegroundColor Green
Read-Host "Press Enter to exit"
