$ErrorActionPreference = "Continue"

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$projectRoot = Split-Path -Parent $scriptDir

$base = "C:\Program Files\WindowsApps\Claude_1.5354.0.0_x64__pzs8sxrjxfjjc\app\resources"
if (-not (Test-Path -LiteralPath $base)) {
    Write-Host "ERROR: Claude 1.5354.0.0 not found at: $base" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$copies = @(
    @{Src=(Join-Path $projectRoot "locales\root-zh-CN.json");                       Dst=(Join-Path $base "zh-CN.json");                         Name="root zh-CN"},
    @{Src=(Join-Path $projectRoot "locales\ion-zh-CN.json");                        Dst=(Join-Path $base "ion-dist\i18n\zh-CN.json");           Name="ion zh-CN"},
    @{Src=(Join-Path $projectRoot "locales\ion-zh-CN.json.zst");                    Dst=(Join-Path $base "ion-dist\i18n\zh-CN.json.zst");       Name="ion zh-CN.zst"},
    @{Src=(Join-Path $projectRoot "locales\ion-zh-CN.overrides.json");              Dst=(Join-Path $base "ion-dist\i18n\zh-CN.overrides.json"); Name="ion overrides"},
    @{Src=(Join-Path $projectRoot "locales\ion-zh-CN.overrides.json.zst");          Dst=(Join-Path $base "ion-dist\i18n\zh-CN.overrides.json.zst"); Name="ion overrides.zst"},
    @{Src=(Join-Path $projectRoot "locales\statsig\zh-CN.json");                   Dst=(Join-Path $base "ion-dist\i18n\statsig\zh-CN.json");   Name="statsig zh-CN"},
    @{Src=(Join-Path $projectRoot "locales\statsig\zh-CN.json.zst");               Dst=(Join-Path $base "ion-dist\i18n\statsig\zh-CN.json.zst"); Name="statsig zh-CN.zst"}
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Claude Desktop ZH-CN Patch v1.5354.0.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check source files
Write-Host "[1/4] Checking source files..." -ForegroundColor Yellow
foreach ($c in $copies) {
    if (Test-Path -LiteralPath $c.Src) {
        Write-Host "  [OK] $($c.Name)"
    } else {
        Write-Host "  [MISSING] $($c.Name) -> $($c.Src)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Source files missing. Please verify the patch package is complete." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Step 2: Check target directory
Write-Host ""
Write-Host "[2/4] Checking target directory..." -ForegroundColor Yellow
Write-Host "  [OK] $base"

# Step 3: Permissions
Write-Host ""
Write-Host "[3/4] Getting write permissions..." -ForegroundColor Yellow

$permTargets = @(
    $base,
    (Join-Path $base "ion-dist\i18n"),
    (Join-Path $base "ion-dist\i18n\statsig")
)
foreach ($p in $permTargets) {
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $null = & takeown.exe /F $p /A 2>&1
    $null = & icacls.exe $p /grant "*S-1-5-32-544:(OI)(CI)F" /C /Q 2>&1
    $displayPath = $p.Substring($p.Length - [Math]::Min(50, $p.Length))
    Write-Host "  [OK] ...$displayPath"
}

foreach ($c in $copies) {
    if (Test-Path -LiteralPath $c.Dst) {
        $null = & takeown.exe /F $c.Dst /A 2>&1
        $null = & icacls.exe $c.Dst /grant "*S-1-5-32-544:F" /C /Q 2>&1
    }
}

# Step 4: Copy
Write-Host ""
Write-Host "[4/4] Writing zh-CN files..." -ForegroundColor Yellow
$ok = 0
$fail = 0
foreach ($c in $copies) {
    $parent = Split-Path -Parent $c.Dst
    if (-not (Test-Path -LiteralPath $parent)) {
        Write-Host "  [SKIP] Target dir not found: $parent" -ForegroundColor Yellow
        $fail++
        continue
    }
    try {
        Copy-Item -LiteralPath $c.Src -Destination $c.Dst -Force -ErrorAction Stop
        Write-Host "  [OK] $($c.Name)"
        $ok++
    } catch {
        Write-Host "  [FAIL] $($c.Name): $($_.Exception.Message)" -ForegroundColor Red
        $fail++
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($fail -eq 0) {
    Write-Host "  All OK ($ok files written)" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Done! Restart Claude Desktop to see the changes." -ForegroundColor Green
    Write-Host "Note: Frontend JS patches skipped (version mismatch)." -ForegroundColor Yellow
    Write-Host "Some dynamic UI text may still appear in English." -ForegroundColor Yellow
} else {
    Write-Host "  OK: $ok / FAIL: $fail" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Some files failed. Please ensure:" -ForegroundColor Red
    Write-Host "  1. Claude Desktop is fully closed (check system tray)" -ForegroundColor Red
    Write-Host "  2. You are running as Administrator" -ForegroundColor Red
}
Write-Host ""
Read-Host "Press Enter to exit"
