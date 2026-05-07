$ErrorActionPreference = "Continue"

$base = $null
$dirs = @(Get-ChildItem "C:\Program Files\WindowsApps" -Directory -Filter "Claude_*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
foreach ($d in $dirs) {
    $res = Join-Path $d.FullName "app\resources"
    if (Test-Path (Join-Path $res "app.asar")) { $base = $res; break }
}
if (-not $base) { Write-Host "Claude not found" -ForegroundColor Red; Read-Host "Press Enter"; exit 1 }

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$assetsDir = Join-Path $base "ion-dist\assets\v1"
$patchesPath = Join-Path $scriptDir "sidebar_patches.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Read patches from JSON
$patches = Get-Content -Path $patchesPath -Encoding UTF8 | ConvertFrom-Json

Write-Host "=== Patch Sidebar Navigation ===" -ForegroundColor Cyan
Write-Host ""

$ok = 0
$skip = 0
$miss = 0

foreach ($p in $patches) {
    $filePath = Join-Path $assetsDir $p.file
    if (-not (Test-Path $filePath)) { Write-Host "  [N/A] $($p.file) not found" -ForegroundColor Yellow; $miss++; continue }

    $c = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
    if (-not $c.Contains($p.find)) { Write-Host "  [N/A] $($p.desc) - pattern not found" -ForegroundColor Yellow; $skip++; continue }
    if ($c.Contains($p.repl)) { Write-Host "  [OK] $($p.desc) - already patched" -ForegroundColor Gray; $ok++; continue }

    $null = & takeown.exe /F $filePath /A 2>&1
    $null = & icacls.exe $filePath /grant "*S-1-5-32-544:F" /C /Q 2>&1

    $c = $c.Replace($p.find, $p.repl)
    [System.IO.File]::WriteAllText($filePath, $c, $utf8NoBom)
    Write-Host "  [OK] $($p.desc)" -ForegroundColor Green
    $ok++
}

Write-Host ""
Write-Host "Result: Applied=$ok / Skipped already=$skip / Not found=$miss" -ForegroundColor Cyan
Write-Host ""
Write-Host "Restart Claude Desktop to see sidebar changes." -ForegroundColor Green
Read-Host "Press Enter to exit"
