Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

try {
    $config = Get-Config
    $install = Resolve-ClaudeInstall -Config $config
    $backupDir = Get-LatestBackupDirectory -Config $config

    Write-Host "Preparing Claude Desktop localization rollback..." -ForegroundColor Cyan
    Write-Host "Version: $($install.Version)"
    Write-Host "Backup directory: $backupDir"

    foreach ($path in @($install.ResourcesDir, $install.I18nDir, $install.StatsigDir, $install.AssetsDir)) {
        Grant-PathAccess -Path $path
    }

    $restored = 0
    $restored += (Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "root") -DestinationDir $install.ResourcesDir).Count
    $restored += (Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "ion") -DestinationDir $install.I18nDir).Count
    $restored += (Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "ion-overrides") -DestinationDir $install.I18nDir).Count
    $restored += (Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "statsig") -DestinationDir $install.StatsigDir).Count
    $restored += (Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "assets") -DestinationDir $install.AssetsDir).Count

    foreach ($bak in Get-ChildItem -LiteralPath $install.AssetsDir -Filter "*.zst.bak" -File -ErrorAction SilentlyContinue) {
        $target = $bak.FullName -replace '\.bak$', ''
        if (-not (Test-Path -LiteralPath $target)) {
            Rename-Item -LiteralPath $bak.FullName -NewName ([System.IO.Path]::GetFileName($target)) -Force
        }
    }

    Write-Host "Rollback completed. Restored files: $restored" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "Rollback failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
