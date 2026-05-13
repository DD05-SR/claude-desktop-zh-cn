$ErrorActionPreference = "Continue"

# DEPRECATED: use scripts\apply_localization.ps1. This legacy helper is kept only
# for users who downloaded older releases.

# ============================================================
# Safe Chinese Localization Script for Claude Desktop
# Strategy: backup everything before modification.
# No deletions. No regex on fragile code. Rename .zst -> .bak (not delete).
# ============================================================

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$projectRoot = Split-Path -Parent $scriptDir
$backupRoot = Join-Path $projectRoot "backups"
$backupDir = Join-Path $backupRoot (Get-Date -Format "yyyyMMdd-HHmmss")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ============================================================
# Find Claude installation
# ============================================================
Write-Host "[1/5] Locating Claude Desktop..." -ForegroundColor Cyan
$base = $null
$dirs = @(Get-ChildItem "C:\Program Files\WindowsApps" -Directory -Filter "Claude_*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
foreach ($d in $dirs) {
    $res = Join-Path $d.FullName "app\resources"
    if (Test-Path (Join-Path $res "app.asar")) { $base = $res; break }
}
if (-not $base) {
    Write-Host "  [FAIL] Claude Desktop not found in WindowsApps." -ForegroundColor Red
    Write-Host "  Make sure it is installed from https://claude.ai/download" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
$version = ($base -replace '.*Claude_([0-9.]+).*', '$1')
Write-Host "  [OK] Claude v$version" -ForegroundColor Green
Write-Host "  Path: $base" -ForegroundColor Gray

$assetsDir = Join-Path $base "ion-dist\assets\v1"
$i18nDir = Join-Path $base "ion-dist\i18n"
if (-not (Test-Path $assetsDir)) { Write-Host "  [FAIL] Assets dir not found" -ForegroundColor Red; Read-Host "Press Enter"; exit 1 }

# ============================================================
# PART 0: Backup
# ============================================================
Write-Host ""
Write-Host "[2/5] Backing up original files..." -ForegroundColor Cyan
try {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    # Backup i18n files
    foreach ($f in @("zh-CN.json","zh-CN.json.zst","zh-CN.overrides.json","zh-CN.overrides.json.zst")) {
        $fp = Join-Path $i18nDir $f
        if (Test-Path $fp) { Copy-Item $fp (Join-Path $backupDir $f) -Force }
    }
    $sf = Join-Path $base "zh-CN.json"
    if (Test-Path $sf) { Copy-Item $sf (Join-Path $backupDir "root-zh-CN.json") -Force }
    $sDir = Join-Path $i18nDir "statsig"
    $sf2 = Join-Path $sDir "zh-CN.json"
    if (Test-Path $sf2) { Copy-Item $sf2 (Join-Path $backupDir "statsig-zh-CN.json") -Force }
    Write-Host "  [OK] Backup at: $backupDir" -ForegroundColor Green
} catch { Write-Host "  [WARN] Backup failed: $_" -ForegroundColor Yellow }

# ============================================================
# PART 1: Copy locale files (SAFE)
# ============================================================
Write-Host ""
Write-Host "[3/5] Granting write permissions..." -ForegroundColor Cyan
$permDirs = @(
    $base,
    (Join-Path $base "ion-dist\i18n"),
    (Join-Path $base "ion-dist\i18n\statsig")
)
foreach ($p in $permDirs) {
    if (Test-Path $p) {
        $null = & takeown.exe /F $p /A 2>&1
        $null = & icacls.exe $p /grant "*S-1-5-32-544:(OI)(CI)F" /C /Q 2>&1
        Write-Host "  [OK] $(Split-Path -Leaf $p)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "[4/5] Copying zh-CN locale files..." -ForegroundColor Cyan

$localeItems = @(
    @{Src="locales\root-zh-CN.json";                    Dst=(Join-Path $base "zh-CN.json");                         Name="root zh-CN"},
    @{Src="locales\ion-zh-CN.json";                     Dst=(Join-Path $i18nDir "zh-CN.json");                     Name="ion zh-CN"},
    @{Src="locales\ion-zh-CN.json.zst";                 Dst=(Join-Path $i18nDir "zh-CN.json.zst");                 Name="ion zh-CN.zst"},
    @{Src="locales\ion-zh-CN.overrides.json";           Dst=(Join-Path $i18nDir "zh-CN.overrides.json");           Name="ion overrides"},
    @{Src="locales\ion-zh-CN.overrides.json.zst";       Dst=(Join-Path $i18nDir "zh-CN.overrides.json.zst");       Name="ion overrides.zst"},
    @{Src="locales\statsig\zh-CN.json";                Dst=(Join-Path $i18nDir "statsig\zh-CN.json");              Name="statsig zh-CN"},
    @{Src="locales\statsig\zh-CN.json.zst";            Dst=(Join-Path $i18nDir "statsig\zh-CN.json.zst");          Name="statsig zh-CN.zst"}
)

$localeOk = 0
foreach ($item in $localeItems) {
    $srcPath = Join-Path $projectRoot $item.Src
    if (-not (Test-Path $srcPath)) { Write-Host "  [MISS] source $($item.Name)" -ForegroundColor Red; continue }
    $dstParent = Split-Path -Parent $item.Dst
    if (-not (Test-Path $dstParent)) { Write-Host "  [SKIP] dir missing: $dstParent" -ForegroundColor Yellow; continue }
    try {
        Copy-Item -LiteralPath $srcPath -Destination $item.Dst -Force -ErrorAction Stop
        Write-Host "  [OK] $($item.Name)" -ForegroundColor Green
        $localeOk++
    } catch { Write-Host "  [FAIL] $($item.Name): $_" -ForegroundColor Red }
}
Write-Host "  Locale files: $localeOk / $($localeItems.Count)"

# ============================================================
# PART 2: Patch JS - ONLY add zh-CN to language list (ESSENTIAL)
# Strategy: find .js file with language array, patch it,
# rename .zst to .bak (so app loads our patched .js).
# ============================================================
Write-Host ""
Write-Host "[5/6] Patching JS runtime (language list)..." -ForegroundColor Cyan

$jsFiles = @(Get-ChildItem $assetsDir -Filter "*.js" -File)
$searchPat = '=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"]'
$targetJs = $null

foreach ($f in $jsFiles) {
    try { $c = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) } catch { continue }
    if ($c.Contains($searchPat)) {
        $targetJs = $f.FullName
        Write-Host "  [FOUND] Language list in: $($f.Name)" -ForegroundColor Green
        break
    }
}

if (-not $targetJs) {
    Write-Host "  [FAIL] Could not find language list in any JS file." -ForegroundColor Red
    Write-Host "  This version ($version) uses a different code format." -ForegroundColor Yellow
} else {
    # Read the file
    $content = [System.IO.File]::ReadAllText($targetJs, [System.Text.Encoding]::UTF8)

    # Backup original .js
    $fileName = Split-Path -Leaf $targetJs
    $jsBackup = (Join-Path $backupDir $fileName) + ".original"
    [System.IO.File]::WriteAllText($jsBackup, $content, $utf8NoBom)

    # Get permissions
    $null = & takeown.exe /F $assetsDir /A 2>&1
    $null = & icacls.exe $assetsDir /grant "*S-1-5-32-544:(OI)(CI)F" /C /Q 2>&1
    $null = & takeown.exe /F $targetJs /A 2>&1
    $null = & icacls.exe $targetJs /grant "*S-1-5-32-544:F" /C /Q 2>&1

    # PATCH 1: Add zh-CN to language list
    $patched = $false
    $repl1 = $searchPat -replace '\]$', ',"zh-CN"]'
    if ($content.Contains($searchPat)) {
        if ($content.Contains($repl1)) {
            Write-Host "  Already patched (zh-CN in list)" -ForegroundColor Gray
        } else {
            $content = $content.Replace($searchPat, $repl1)
            Write-Host "  [OK] Added zh-CN to language list" -ForegroundColor Green
            $patched = $true
        }
    }

    # PATCH 2: Language menu display name (skip - complex encoding issues)
    Write-Host "  [SKIP] Display name patch (handled separately)" -ForegroundColor Gray

    # Save patched .js
    if ($patched) {
        [System.IO.File]::WriteAllText($targetJs, $content, $utf8NoBom)
        Write-Host "  Saved: $(Split-Path -Leaf $targetJs)" -ForegroundColor Green

        # Rename .zst to .bak (so app uses our patched .js instead of cached .zst)
        $jsZst = $targetJs + ".zst"
        $jsZstBak = $targetJs + ".zst.bak"
        if (Test-Path $jsZst) {
            $null = & takeown.exe /F $jsZst /A 2>&1
            $null = & icacls.exe $jsZst /grant "*S-1-5-32-544:F" /C /Q 2>&1
            try {
                if (Test-Path $jsZstBak) {
                    Remove-Item $jsZstBak -Force -ErrorAction SilentlyContinue
                }
                Rename-Item -LiteralPath $jsZst -NewName ($fileName + ".zst.bak") -Force -ErrorAction Stop
                Write-Host "  [OK] Disabled .zst cache (app will use patched .js)" -ForegroundColor Green
            } catch { Write-Host "  [WARN] Could not rename .zst: $_" -ForegroundColor Yellow }
        }
    } else {
        Write-Host "  No changes needed" -ForegroundColor Gray
    }
}

# ============================================================
# Clear cache
# ============================================================
Write-Host ""
Write-Host "[6/6] Clearing app cache..." -ForegroundColor Cyan
$localAppData = [Environment]::GetFolderPath("LocalApplicationData")
$cachePaths = @(
    (Join-Path $localAppData "AnthropicClaude\Cache"),
    (Join-Path $localAppData "AnthropicClaude\Code Cache"),
    (Join-Path $localAppData "AnthropicClaude\GPUCache")
)
$cleared = 0
foreach ($cp in $cachePaths) {
    if (Test-Path $cp) {
        try {
            Get-ChildItem $cp -File -ErrorAction Stop | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Cleared: $(Split-Path -Leaf $cp)" -ForegroundColor Green
            $cleared++
        } catch { Write-Host "  [WARN] Could not clear: $(Split-Path -Leaf $cp)" -ForegroundColor Yellow }
    } else { Write-Host "  [N/A] $(Split-Path -Leaf $cp)" -ForegroundColor Gray }
}

# ============================================================
# Part 7: Sidebar hardcoded string patches
# ============================================================
Write-Host ""
Write-Host "[7/7] Patching sidebar hardcoded strings..." -ForegroundColor Cyan

$patchesPath = Join-Path $scriptDir "sidebar_patches.json"
if (Test-Path $patchesPath) {
    $sbPatches = Get-Content -Path $patchesPath -Encoding UTF8 | ConvertFrom-Json
    $sbOk = 0; $sbSkip = 0; $sbMiss = 0
    $null = & takeown.exe /F $assetsDir /A 2>&1
    $null = & icacls.exe $assetsDir /grant "*S-1-5-32-544:(OI)(CI)F" /C /Q 2>&1

    foreach ($p in $sbPatches) {
        $fp = Join-Path $assetsDir $p.file
        if (-not (Test-Path $fp)) { $sbMiss++; continue }
        $c = [System.IO.File]::ReadAllText($fp, [System.Text.Encoding]::UTF8)
        if (-not $c.Contains($p.find)) { $sbSkip++; continue }
        if ($c.Contains($p.repl)) { $sbOk++; continue }
        $null = & takeown.exe /F $fp /A 2>&1
        $null = & icacls.exe $fp /grant "*S-1-5-32-544:F" /C /Q 2>&1
        $c = $c.Replace($p.find, $p.repl)
        [System.IO.File]::WriteAllText($fp, $c, $utf8NoBom)
        $sbOk++
    }
    Write-Host "  Sidebar: OK=$sbOk / Already=$sbSkip / N/A=$sbMiss" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] sidebar_patches.json not found" -ForegroundColor Yellow
}

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DONE - Claude Desktop v$version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "What was done:" -ForegroundColor Green
Write-Host "  - Locale files ($localeOk items)"
Write-Host "  - JS language list (zh-CN added)"
Write-Host "  - Sidebar translations"
Write-Host "  - Cache cleared ($cleared items)"
Write-Host ""
if (Test-Path (Join-Path $backupDir "root-zh-CN.json")) {
    Write-Host "Backup: $backupDir" -ForegroundColor Gray
}
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Fully quit Claude (tray icon -> Quit)" -ForegroundColor Yellow
Write-Host "  2. Launch Claude Desktop" -ForegroundColor Yellow
Write-Host "  3. Go to Settings -> Language, check if 'Chinese' appears" -ForegroundColor Yellow
Write-Host ""
Write-Host "If app goes blank:" -ForegroundColor Red
Write-Host "  Run rollback: right-click 'HanHua HuiGun.bat' -> Run as admin" -ForegroundColor Red
Write-Host ""
Read-Host "Press Enter to exit"
