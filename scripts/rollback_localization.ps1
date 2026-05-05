Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

try {
    $config = Get-Config
    Assert-SupportedInstallation -Config $config
    $backupDir = Get-LatestBackupDirectory -Config $config
    $applyTargets = $config["applyTargets"]

    Grant-PathAccess -Path $applyTargets["rootLocale"]
    Grant-PathAccess -Path $applyTargets["ionLocale"]
    Grant-PathAccess -Path $applyTargets["ionLocaleZst"]
    Grant-PathAccess -Path $applyTargets["ionOverrides"]
    Grant-PathAccess -Path $applyTargets["ionOverridesZst"]
    Grant-PathAccess -Path $applyTargets["statsigLocale"]
    Grant-PathAccess -Path $applyTargets["statsigLocaleZst"]
    Grant-PathAccess -Path $applyTargets["assetsDir"]

    $restoredRoot = Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "root") -DestinationDir (Split-Path -Path $applyTargets["rootLocale"] -Parent)
    $restoredIon = Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "ion") -DestinationDir (Split-Path -Path $applyTargets["ionLocale"] -Parent)
    $restoredOverrides = Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "ion-overrides") -DestinationDir (Split-Path -Path $applyTargets["ionOverrides"] -Parent)
    $restoredStatsig = Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "statsig") -DestinationDir (Split-Path -Path $applyTargets["statsigLocale"] -Parent)
    $restoredAssets = Restore-DirectoryFiles -SourceDir (Join-Path $backupDir "assets") -DestinationDir $applyTargets["assetsDir"]

    Write-Host "已从最近一次备份回滚。" -ForegroundColor Yellow
    Write-Host "备份目录: $backupDir"
    Write-Host "恢复 root 文件数: $($restoredRoot.Count)"
    Write-Host "恢复 ion 文件数: $($restoredIon.Count)"
    Write-Host "恢复 overrides 文件数: $($restoredOverrides.Count)"
    Write-Host "恢复 statsig 文件数: $($restoredStatsig.Count)"
    Write-Host "恢复 assets 文件数: $($restoredAssets.Count)"
    exit 0
}
catch {
    Write-Host "回滚失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
