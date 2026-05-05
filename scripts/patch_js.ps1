$ErrorActionPreference = "Continue"

$base = "C:\Program Files\WindowsApps\Claude_1.5354.0.0_x64__pzs8sxrjxfjjc\app\resources"
$assetsDir = Join-Path $base "ion-dist\assets\v1"

if (-not (Test-Path -LiteralPath $assetsDir)) {
    Write-Host "ERROR: Assets directory not found: $assetsDir" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# The critical patches - must apply for zh-CN to work
$patches = @(
    @{
        desc = "Add zh-CN to language list";
        find = '$z=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"]';
        repl = '$z=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN"]'
    },
    @{
        desc = "Language menu - display Chinese name";
        find = 'const e=n.formatters.getDisplayNames(Bz,SEn),t=new Intl.Collator(Bz);return $z.map(t=>({locale:t,name:e.of(t),localName:n.formatters.getDisplayNames(t,SEn).of(t)})).slice().sort((e,n)=>t.compare(e.name,n.name))';
        repl = 'const e=n.formatters.getDisplayNames(Bz,SEn),t=new Intl.Collator(Bz);return $z.map(t=>({locale:t,name:"zh-CN"===t?"Simplified Chinese":e.of(t),localName:"zh-CN"===t?"Simplified Chinese":n.formatters.getDisplayNames(t,SEn).of(t)})).slice().sort((e,n)=>t.compare(e.name,n.name))'
    },
    @{
        desc = "Chinese font fallback";
        find = ':root{--font-mono: var(--font-anthropic-mono);--font-ui: var(--font-anthropic-sans);--font-ui-serif: var(--font-anthropic-serif);--font-claude-response: var(--font-anthropic-serif);--font-user-message: var(--font-ui);--font-sans-serif: var(--font-ui);--font-serif: var(--font-ui-serif);--font-system: system-ui, sans-serif;--font-dyslexia: var(--font-open-dyslexic), "Comic Sans MS", ui-serif, Georgia, serif}html,body{font-family:var(--font-ui)}';
        repl = ':root{--font-mono: var(--font-anthropic-mono);--font-ui: var(--font-anthropic-sans);--font-ui-serif: var(--font-anthropic-serif);--font-claude-response: var(--font-anthropic-serif);--font-user-message: var(--font-ui);--font-sans-serif: var(--font-ui);--font-serif: var(--font-ui-serif);--font-system: system-ui, sans-serif;--font-dyslexia: var(--font-open-dyslexic), "Comic Sans MS", ui-serif, Georgia, serif}html[lang=zh-CN]{--font-ui:"Anthropic Sans","Microsoft YaHei UI","Microsoft YaHei","PingFang SC","Noto Sans CJK SC",system-ui,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;--font-ui-serif:"Anthropic Sans","Microsoft YaHei UI","Microsoft YaHei","PingFang SC","Noto Sans CJK SC",system-ui,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;--font-claude-response:var(--font-ui);--font-user-message:var(--font-ui)}html,body{font-family:var(--font-ui)}'
    }
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Claude Desktop JS Patch v1.5354.0.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get permissions on assets dir
Write-Host "[1/3] Getting write permissions on assets..." -ForegroundColor Yellow
$null = & takeown.exe /F $assetsDir /A 2>&1
$null = & icacls.exe $assetsDir /grant "*S-1-5-32-544:(OI)(CI)F" /C /Q 2>&1
Write-Host "  [OK]"

# Search and patch JS files
Write-Host ""
Write-Host "[2/3] Searching and patching JS files..." -ForegroundColor Yellow

$jsFiles = @(Get-ChildItem -LiteralPath $assetsDir -Filter "*.js" -File -ErrorAction SilentlyContinue)
Write-Host "  Found $($jsFiles.Count) JS files"

$totalPatched = 0

foreach ($patch in $patches) {
    Write-Host ""
    Write-Host "  Patch: $($patch.desc)" -ForegroundColor Cyan

    $found = $false
    foreach ($file in $jsFiles) {
        try {
            $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        } catch {
            continue
        }

        if ($content.Contains($patch.find)) {
            Write-Host "    [FOUND] $($file.Name)"

            # Check if already patched
            if ($content.Contains($patch.repl)) {
                Write-Host "      -> Already patched" -ForegroundColor Gray
                $found = $true
                continue
            }

            # Apply patch
            $newContent = $content.Replace($patch.find, $patch.repl)
            try {
                # Get permission on the specific file
                $null = & takeown.exe /F $file.FullName /A 2>&1
                $null = & icacls.exe $file.FullName /grant "*S-1-5-32-544:F" /C /Q 2>&1

                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8NoBom)
                Write-Host "      -> PATCHED" -ForegroundColor Green
                $totalPatched++
                $found = $true
            } catch {
                Write-Host "      -> FAILED: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    if (-not $found) {
        Write-Host "    [NOT FOUND] String not found in any JS file" -ForegroundColor Yellow
        Write-Host "    (This may be normal for version 1.5354.0.0)" -ForegroundColor Gray
    }
}

# Also check CSS files for font patch
Write-Host ""
Write-Host "[3/3] Checking CSS files for font patch..." -ForegroundColor Yellow
$cssFiles = @(Get-ChildItem -LiteralPath $assetsDir -Filter "*.css" -File -ErrorAction SilentlyContinue)
Write-Host "  Found $($cssFiles.Count) CSS files"

$fontPatch = $patches[2]  # The font patch
foreach ($file in $cssFiles) {
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    } catch {
        continue
    }

    if ($content.Contains($fontPatch.find)) {
        Write-Host "  [FOUND] $($file.Name)"
        if ($content.Contains($fontPatch.repl)) {
            Write-Host "    -> Already patched" -ForegroundColor Gray
            continue
        }
        $newContent = $content.Replace($fontPatch.find, $fontPatch.repl)
        try {
            $null = & takeown.exe /F $file.FullName /A 2>&1
            $null = & icacls.exe $file.FullName /grant "*S-1-5-32-544:F" /C /Q 2>&1
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8NoBom)
            Write-Host "    -> PATCHED" -ForegroundColor Green
            $totalPatched++
        } catch {
            Write-Host "    -> FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Total patches applied: $totalPatched" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
if ($totalPatched -gt 0) {
    Write-Host "JS patches applied. Restart Claude Desktop." -ForegroundColor Green
} else {
    Write-Host "WARNING: No patches were applied." -ForegroundColor Yellow
    Write-Host "The JS file format in 1.5354.0.0 may differ from 1.4758.0.0." -ForegroundColor Yellow
    Write-Host "You may need an updated patch for this version." -ForegroundColor Yellow
}
Read-Host "Press Enter to exit"
