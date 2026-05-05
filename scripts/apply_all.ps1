$ErrorActionPreference = "Continue"

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$projectRoot = Split-Path -Parent $scriptDir
$base = "C:\Program Files\WindowsApps\Claude_1.5354.0.0_x64__pzs8sxrjxfjjc\app\resources"
$assetsDir = Join-Path $base "ion-dist\assets\v1"
$targetFile = "index-BNbM_KX7.js"

if (-not (Test-Path -LiteralPath $base)) {
    Write-Host "ERROR: Claude not found at $base" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Claude Desktop ZH-CN Patch v2" -ForegroundColor Cyan
Write-Host "  Target: 1.5354.0.0 (HP/VP variables)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# PART 1: Copy locale files
# ============================================================
Write-Host "--- PART 1: Locale files ---" -ForegroundColor Cyan

$copies = @(
    @{Src=(Join-Path $projectRoot "locales\root-zh-CN.json");                       Dst=(Join-Path $base "zh-CN.json");                         Name="root zh-CN"},
    @{Src=(Join-Path $projectRoot "locales\ion-zh-CN.json");                        Dst=(Join-Path $base "ion-dist\i18n\zh-CN.json");           Name="ion zh-CN"},
    @{Src=(Join-Path $projectRoot "locales\ion-zh-CN.json.zst");                    Dst=(Join-Path $base "ion-dist\i18n\zh-CN.json.zst");       Name="ion zh-CN.zst"},
    @{Src=(Join-Path $projectRoot "locales\ion-zh-CN.overrides.json");              Dst=(Join-Path $base "ion-dist\i18n\zh-CN.overrides.json"); Name="ion overrides"},
    @{Src=(Join-Path $projectRoot "locales\ion-zh-CN.overrides.json.zst");          Dst=(Join-Path $base "ion-dist\i18n\zh-CN.overrides.json.zst"); Name="ion overrides.zst"},
    @{Src=(Join-Path $projectRoot "locales\statsig\zh-CN.json");                   Dst=(Join-Path $base "ion-dist\i18n\statsig\zh-CN.json");   Name="statsig zh-CN"},
    @{Src=(Join-Path $projectRoot "locales\statsig\zh-CN.json.zst");               Dst=(Join-Path $base "ion-dist\i18n\statsig\zh-CN.json.zst"); Name="statsig zh-CN.zst"}
)

$permTargets = @($base, (Join-Path $base "ion-dist\i18n"), (Join-Path $base "ion-dist\i18n\statsig"))
foreach ($p in $permTargets) {
    if (Test-Path -LiteralPath $p) {
        $null = & takeown.exe /F $p /A 2>&1
        $null = & icacls.exe $p /grant "*S-1-5-32-544:(OI)(CI)F" /C /Q 2>&1
    }
}

$localeOk = 0
foreach ($c in $copies) {
    if (-not (Test-Path -LiteralPath $c.Src)) { Write-Host "  [MISS] $($c.Src)" -ForegroundColor Red; continue }
    $parent = Split-Path -Parent $c.Dst
    if (-not (Test-Path -LiteralPath $parent)) { Write-Host "  [SKIP] $parent" -ForegroundColor Yellow; continue }
    try {
        Copy-Item -LiteralPath $c.Src -Destination $c.Dst -Force -ErrorAction Stop
        Write-Host "  [OK] $($c.Name)" -ForegroundColor Green
        $localeOk++
    } catch {
        Write-Host "  [FAIL] $($c.Name)" -ForegroundColor Red
    }
}
Write-Host "  Locale: $localeOk / $($copies.Count)"
Write-Host ""

# ============================================================
# PART 2: JS/CSS patches for 1.5354.0.0
# ============================================================
Write-Host "--- PART 2: JS patches (1.5354.0.0 specific) ---" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $assetsDir)) {
    Write-Host "  [SKIP] Assets dir not found" -ForegroundColor Yellow
} else {
    $null = & takeown.exe /F $assetsDir /A 2>&1
    $null = & icacls.exe $assetsDir /grant "*S-1-5-32-544:(OI)(CI)F" /C /Q 2>&1

    # ============================================================
    # PATCH 1: Add zh-CN to language list (MOST CRITICAL)
    # ============================================================
    Write-Host "  [PATCH 1] Add zh-CN to language list..." -ForegroundColor Yellow
    $idxFile = Join-Path $assetsDir "index-BNbM_KX7.js"
    if (Test-Path -LiteralPath $idxFile) {
        $null = & takeown.exe /F $idxFile /A 2>&1
        $null = & icacls.exe $idxFile /grant "*S-1-5-32-544:F" /C /Q 2>&1

        $content = [System.IO.File]::ReadAllText($idxFile, [System.Text.Encoding]::UTF8)

        # Patch 1a: Add zh-CN to HP array
        $find1 = 'HP=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"]'
        $repl1 = 'HP=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN"]'

        if ($content.Contains($find1)) {
            if ($content.Contains($repl1)) {
                Write-Host "    Already patched" -ForegroundColor Gray
            } else {
                $content = $content.Replace($find1, $repl1)
                Write-Host "    PATCHED: Added zh-CN to HP array" -ForegroundColor Green
            }
        } else {
            Write-Host "    Pattern not found - trying alternative..." -ForegroundColor Yellow
            # Try with different spacing
            $alt1 = 'HP=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"]'
            if ($content -match 'HP=\[([^\]]+)\]') {
                Write-Host "    Found HP array: $($matches[0])" -ForegroundColor Gray
                $orig = $matches[0]
                if ($orig.Contains('"zh-CN"')) {
                    Write-Host "    zh-CN already in HP array" -ForegroundColor Gray
                } else {
                    $new = $orig -replace '\]$', ',"zh-CN"]'
                    $content = $content.Replace($orig, $new)
                    Write-Host "    PATCHED via regex: Added zh-CN" -ForegroundColor Green
                }
            }
        }

        # Patch 1b: Add Chinese display name in language menu
        $find2 = 'HP.map(t=>({locale:t,name:e.of(t),localName:n.formatters.getDisplayNames(t,NIn).of(t)})).slice().sort((e,n)=>t.compare(e.name,n.name))'
        $repl2 = 'HP.map(t=>({locale:t,name:"zh-CN"===t?"Simplified Chinese":e.of(t),localName:"zh-CN"===t?"Simplified Chinese":n.formatters.getDisplayNames(t,NIn).of(t)})).slice().sort((e,n)=>t.compare(e.name,n.name))'

        if ($content.Contains($find2)) {
            if ($content.Contains($repl2)) {
                Write-Host "    Language menu already patched" -ForegroundColor Gray
            } else {
                $content = $content.Replace($find2, $repl2)
                Write-Host "    PATCHED: Language menu display name" -ForegroundColor Green
            }
        } else {
            Write-Host "    Language menu pattern not found" -ForegroundColor Yellow
        }

        # Save the patched file
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($idxFile, $content, $utf8)
        Write-Host "    Saved: index-BNbM_KX7.js" -ForegroundColor Green
    } else {
        Write-Host "    index-BNbM_KX7.js not found!" -ForegroundColor Red
    }

    # ============================================================
    # PATCH 2: CSS font fallback
    # ============================================================
    Write-Host ""
    Write-Host "  [PATCH 2] CSS font fallback..." -ForegroundColor Yellow
    $cssFiles = @(Get-ChildItem -LiteralPath $assetsDir -Filter "*.css" -File)
    $fontFind = ':root{--font-mono: var(--font-anthropic-mono);--font-ui: var(--font-anthropic-sans);--font-ui-serif: var(--font-anthropic-serif);--font-claude-response: var(--font-anthropic-serif);--font-user-message: var(--font-ui);--font-sans-serif: var(--font-ui);--font-serif: var(--font-ui-serif);--font-system: system-ui, sans-serif;--font-dyslexia: var(--font-open-dyslexic), "Comic Sans MS", ui-serif, Georgia, serif}html,body{font-family:var(--font-ui)}'
    $fontRepl = ':root{--font-mono: var(--font-anthropic-mono);--font-ui: var(--font-anthropic-sans);--font-ui-serif: var(--font-anthropic-serif);--font-claude-response: var(--font-anthropic-serif);--font-user-message: var(--font-ui);--font-sans-serif: var(--font-ui);--font-serif: var(--font-ui-serif);--font-system: system-ui, sans-serif;--font-dyslexia: var(--font-open-dyslexic), "Comic Sans MS", ui-serif, Georgia, serif}html[lang=zh-CN]{--font-ui:"Anthropic Sans","Microsoft YaHei UI","Microsoft YaHei","PingFang SC","Noto Sans CJK SC",system-ui,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;--font-ui-serif:"Anthropic Sans","Microsoft YaHei UI","Microsoft YaHei","PingFang SC","Noto Sans CJK SC",system-ui,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;--font-claude-response:var(--font-ui);--font-user-message:var(--font-ui)}html,body{font-family:var(--font-ui)}'

    $cssPatched = $false
    foreach ($file in $cssFiles) {
        try { $c = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8) } catch { continue }
        if ($c.Contains($fontFind) -and -not $c.Contains($fontRepl)) {
            $null = & takeown.exe /F $file.FullName /A 2>&1
            $null = & icacls.exe $file.FullName /grant "*S-1-5-32-544:F" /C /Q 2>&1
            $c = $c.Replace($fontFind, $fontRepl)
            $utf8 = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($file.FullName, $c, $utf8)
            Write-Host "    PATCHED: $($file.Name)" -ForegroundColor Green
            $cssPatched = $true
            break
        } elseif ($c.Contains($fontRepl)) {
            Write-Host "    Already patched in $($file.Name)" -ForegroundColor Gray
            $cssPatched = $true
            break
        }
    }
    if (-not $cssPatched) {
        Write-Host "    Font pattern not found in any CSS file" -ForegroundColor Yellow
    }

    # ============================================================
    # PATCH 3: Sidebar translations (from previous run, already applied)
    # ============================================================
    Write-Host ""
    Write-Host "  [PATCH 3] Sidebar translations (already applied in previous run)" -ForegroundColor Gray
}

# ============================================================
# PART 3: Disable .zst overrides for patched files
# ============================================================
Write-Host ""
Write-Host "--- PART 3: Disable .zst overrides ---" -ForegroundColor Cyan

$patchedJsFiles = @(
    "index-BNbM_KX7.js",
    "c705e2e19-DNqnLQ0E.js",
    "c1b9abf13-C9VBbaXS.js",
    "c11959232-DOs6p9wB.js",
    "c63a78ed4-DfFjk6Ra.js",
    "c6a992d55-Bc-2Iftn.css"
)

$zstRemoved = 0
foreach ($f in $patchedJsFiles) {
    $z = Join-Path $assetsDir "$f.zst"
    if (Test-Path -LiteralPath $z) {
        $null = & takeown.exe /F $z /A 2>&1
        $null = & icacls.exe $z /grant "*S-1-5-32-544:F" /C /Q 2>&1
        try {
            Rename-Item -LiteralPath $z -NewName "$f.zst.bak" -Force -ErrorAction Stop
            Write-Host "  [OK] $f.zst -> .bak" -ForegroundColor Green
            $zstRemoved++
        } catch {
            Write-Host "  [FAIL] $f.zst: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [N/A] $f.zst" -ForegroundColor Gray
    }
}
Write-Host "  ZST overrides disabled: $zstRemoved"

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  COMPLETE" -ForegroundColor Cyan
Write-Host "  Locale: $localeOk/$($copies.Count) | ZST: $zstRemoved" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Now do this:" -ForegroundColor Green
Write-Host "  1. Fully QUIT Claude Desktop (tray -> Quit)" -ForegroundColor Yellow
Write-Host "  2. Launch Claude Desktop" -ForegroundColor Yellow
Write-Host "  3. Settings -> Language -> select Chinese" -ForegroundColor Yellow
Write-Host ""

# Also try clearing Electron cache
$cachePath = "$env:LOCALAPPDATA\AnthropicClaude\Cache"
if (Test-Path $cachePath) {
    Write-Host "Found app cache. Clear it? This may help." -ForegroundColor Yellow
    Write-Host "  $cachePath" -ForegroundColor Gray
    Write-Host "  (Delete this folder manually if restart doesn't work)" -ForegroundColor Gray
}
Write-Host ""
Read-Host "Press Enter to exit"
