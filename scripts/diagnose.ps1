Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Claude Desktop 安装目录诊断" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$base = "C:\Program Files\WindowsApps"

Write-Host "[1] 搜索 WindowsApps 中的 Claude 目录..." -ForegroundColor Yellow
$pkgs = @(Get-ChildItem -LiteralPath $base -Directory -Filter "Claude_*" -ErrorAction SilentlyContinue)

if ($pkgs.Count -eq 0) {
    Write-Host "未找到任何 Claude 目录！" -ForegroundColor Red
    Write-Host ""
    Write-Host "尝试列出 WindowsApps 下所有与 claude 相关的目录:" -ForegroundColor Yellow
    Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*laude*" -or $_.Name -like "*nthropic*" } | ForEach-Object { Write-Host "  $($_.Name)" }
    Read-Host "按回车退出"
    exit 1
}

foreach ($pkg in $pkgs) {
    Write-Host "" -ForegroundColor Green
    Write-Host "找到: $($pkg.FullName)" -ForegroundColor Green
    Write-Host ""

    $res = Join-Path $pkg.FullName "app\resources"
    if (Test-Path -LiteralPath $res) {
        Write-Host "  [OK] resources 目录存在" -ForegroundColor Green
        Write-Host "  $res" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  resources 下的文件:" -ForegroundColor Yellow
        Get-ChildItem -LiteralPath $res -File -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $($_.Name)" }
        Write-Host ""
        Write-Host "  resources 下的文件夹:" -ForegroundColor Yellow
        Get-ChildItem -LiteralPath $res -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    [$($_.Name)]" }

        # Check ion-dist
        $ionDist = Join-Path $res "ion-dist"
        if (Test-Path -LiteralPath $ionDist) {
            Write-Host ""
            Write-Host "  [OK] ion-dist 存在" -ForegroundColor Green
            Get-ChildItem -LiteralPath $ionDist -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    [$($_.Name)]" }

            # Check i18n
            $ionI18n = Join-Path $ionDist "i18n"
            if (Test-Path -LiteralPath $ionI18n) {
                Write-Host ""
                Write-Host "  [OK] ion-dist\i18n 存在" -ForegroundColor Green
                Get-ChildItem -LiteralPath $ionI18n -File -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $($_.Name)" }
                Get-ChildItem -LiteralPath $ionI18n -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    [$($_.Name)]" }
            } else {
                Write-Host "  [FAIL] ion-dist\i18n 不存在" -ForegroundColor Red
            }

            # Check assets
            $assetsV1 = Join-Path $ionDist "assets\v1"
            if (Test-Path -LiteralPath $assetsV1) {
                $fileCount = @(Get-ChildItem -LiteralPath $assetsV1 -File -ErrorAction SilentlyContinue).Count
                Write-Host ""
                Write-Host "  [OK] ion-dist\assets\v1 存在 ($fileCount 个文件)" -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "  [FAIL] ion-dist\assets\v1 不存在" -ForegroundColor Red
                $assetsDir = Join-Path $ionDist "assets"
                if (Test-Path -LiteralPath $assetsDir) {
                    Write-Host "  assets 下的文件夹:"
                    Get-ChildItem -LiteralPath $assetsDir -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    [$($_.Name)]" }
                }
            }
        } else {
            Write-Host ""
            Write-Host "  [FAIL] ion-dist 不存在" -ForegroundColor Red
        }
    } else {
        Write-Host "  [FAIL] resources 目录不存在" -ForegroundColor Red
        $app = Join-Path $pkg.FullName "app"
        if (Test-Path -LiteralPath $app) {
            Write-Host "  app 目录下的内容:"
            Get-ChildItem -LiteralPath $app -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    [$($_.Name)]" }
            Get-ChildItem -LiteralPath $app -File -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $($_.Name)" }
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "诊断完成" -ForegroundColor Cyan
Read-Host "按回车退出"
