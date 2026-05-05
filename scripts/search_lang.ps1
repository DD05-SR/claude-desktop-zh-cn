$ErrorActionPreference = "Continue"

$base = "C:\Program Files\WindowsApps\Claude_1.5354.0.0_x64__pzs8sxrjxfjjc\app\resources"
$assetsDir = Join-Path $base "ion-dist\assets\v1"

if (-not (Test-Path -LiteralPath $assetsDir)) {
    Write-Host "ERROR: Assets dir not found" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Searching for language-related patterns in JS files..."
Write-Host ""

$jsFiles = @(Get-ChildItem -LiteralPath $assetsDir -Filter "*.js" -File -ErrorAction SilentlyContinue)

# Search patterns
$searches = @(
    'en-US.*de-DE',
    'en-US.*fr-FR.*ko-KR',
    'supportedLocales',
    'getDisplayNames',
    'Intl\.Collator',
    'locale.*en-US',
    'availableLocales',
    'SUPPORTED_LOCALES',
    'languageList',
    'langList'
)

foreach ($search in $searches) {
    Write-Host "--- Searching: $search ---" -ForegroundColor Cyan
    $found = $false
    foreach ($file in $jsFiles) {
        try {
            $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        } catch { continue }

        if ($content -match $search) {
            Write-Host "  FOUND in: $($file.Name)" -ForegroundColor Green
            # Extract context around the match
            $idx = [regex]::Match($content, $search).Index
            $start = [Math]::Max(0, $idx - 100)
            $len = [Math]::Min(400, $content.Length - $start)
            $context = $content.Substring($start, $len)
            Write-Host "  Context: ...$context..." -ForegroundColor Gray
            Write-Host ""
            $found = $true
        }
    }
    if (-not $found) {
        Write-Host "  Not found" -ForegroundColor Yellow
        Write-Host ""
    }
}

Write-Host ""
Read-Host "Press Enter to exit"
