$ErrorActionPreference = "Continue"

$base = $null
$dirs = @(Get-ChildItem "C:\Program Files\WindowsApps" -Directory -Filter "Claude_*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
foreach ($d in $dirs) {
    $res = Join-Path $d.FullName "app\resources"
    if (Test-Path (Join-Path $res "app.asar")) { $base = $res; break }
}
$assetsDir = Join-Path $base "ion-dist\assets\v1"
$jsFiles = @(Get-ChildItem $assetsDir -Filter "*.js" -File)

Write-Host "=== Search sidebar text in JS files ===" -ForegroundColor Cyan
Write-Host ""

$patterns = @(
    'New task',
    '"Projects"',
    '"Scheduled"',
    '"Customize"'
)

foreach ($pat in $patterns) {
    Write-Host "--- Searching: $pat ---" -ForegroundColor Yellow
    foreach ($f in $jsFiles) {
        try { $c = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) } catch { continue }
        if ($c -match [regex]::Escape($pat)) {
            Write-Host "  FOUND in: $($f.Name)" -ForegroundColor Green
            $idx = [regex]::Match($c, [regex]::Escape($pat)).Index
            $start = [Math]::Max(0, $idx - 80)
            $len = [Math]::Min(250, $c.Length - $start)
            Write-Host "  Context: $($c.Substring($start, $len))" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

Write-Host "=== Done ===" -ForegroundColor Cyan
Read-Host "Press Enter to exit"
