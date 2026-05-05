$ErrorActionPreference = "Continue"

$base = "C:\Program Files\WindowsApps\Claude_1.5354.0.0_x64__pzs8sxrjxfjjc\app\resources"
$assetsDir = Join-Path $base "ion-dist\assets\v1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Fix: Disable .zst cache for patched JS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if the patched JS file has a .zst sibling
$jsFile = Join-Path $assetsDir "index-BNbM_KX7.js"
$zstFile = Join-Path $assetsDir "index-BNbM_KX7.js.zst"

if (Test-Path -LiteralPath $zstFile) {
    Write-Host "Found: index-BNbM_KX7.js.zst" -ForegroundColor Yellow
    Write-Host "This cached version overrides our patched .js file!" -ForegroundColor Red

    # Get permissions
    $null = & takeown.exe /F $zstFile /A 2>&1
    $null = & icacls.exe $zstFile /grant "*S-1-5-32-544:F" /C /Q 2>&1

    # Rename to .bak
    $bakFile = $zstFile + ".bak"
    try {
        Move-Item -LiteralPath $zstFile -Destination $bakFile -Force -ErrorAction Stop
        Write-Host "  Renamed to: index-BNbM_KX7.js.zst.bak" -ForegroundColor Green
        Write-Host "  App should now use our patched .js file" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED to rename: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "No .zst file found for index-BNbM_KX7.js" -ForegroundColor Yellow
}

# Also check for other asset files that were patched in previous runs
$patchedFiles = @(
    "c705e2e19-DNqnLQ0E.js",
    "c1b9abf13-C9VBbaXS.js",
    "c11959232-DOs6p9wB.js",
    "c63a78ed4-DfFjk6Ra.js",
    "c6a992d55-Bc-2Iftn.css"
)

Write-Host ""
Write-Host "Checking other patched files for .zst overrides..." -ForegroundColor Yellow
foreach ($f in $patchedFiles) {
    $z = Join-Path $assetsDir "$f.zst"
    if (Test-Path -LiteralPath $z) {
        $null = & takeown.exe /F $z /A 2>&1
        $null = & icacls.exe $z /grant "*S-1-5-32-544:F" /C /Q 2>&1
        try {
            Move-Item -LiteralPath $z -Destination "$z.bak" -Force -ErrorAction Stop
            Write-Host "  [OK] $f.zst -> .bak" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] $f.zst" -ForegroundColor Red
        }
    } else {
        Write-Host "  [N/A] $f.zst (no override)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Done. Now try:" -ForegroundColor Green
Write-Host "1. Fully quit Claude Desktop" -ForegroundColor Yellow
Write-Host "2. Clear app cache (if possible)" -ForegroundColor Yellow
Write-Host "3. Launch Claude Desktop" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
