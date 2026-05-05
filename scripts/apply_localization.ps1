Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

try {
    Write-Host "[1/7] 读取配置..." -ForegroundColor Cyan
    $config = Get-Config
    $artifacts = Get-ProjectArtifacts

    Write-Host "[2/7] 检查目标版本与项目资源..." -ForegroundColor Cyan
    Assert-SupportedInstallation -Config $config
    Assert-ProjectArtifacts -Artifacts $artifacts

    Write-Host "[3/7] 创建备份目录并分析补丁命中..." -ForegroundColor Cyan
    $runDir = New-BackupRunDirectory -Config $config
    $applyTargets = $config["applyTargets"]
    $patches = Get-Patches
    $assetFiles = Get-AssetFiles -AssetsDir $applyTargets["assetsDir"]
    $patchAnalysis = Analyze-PatchHits -Patches $patches -AssetFiles $assetFiles
    $managedAssets = Get-ManagedPatchedAssets -PatchedAssetsDir $artifacts["PatchedAssetsDir"] -AssetsDir $applyTargets["assetsDir"]
    $managedAssetMap = @{}
    foreach ($managedAsset in $managedAssets) {
        $managedAssetMap[$managedAsset.AssetPath] = $managedAsset
    }
    $patchTargets = @(Get-PatchTargetFiles -PatchAnalysis $patchAnalysis)
    $patchTargets = @($patchTargets + @($managedAssets | ForEach-Object { $_.AssetPath }) | Sort-Object -Unique)

    Write-Host "[4/7] 备份当前目标文件..." -ForegroundColor Cyan
    Backup-File -Source $applyTargets["rootLocale"] -BackupDir (Join-Path $runDir "root")
    Backup-File -Source $applyTargets["ionLocale"] -BackupDir (Join-Path $runDir "ion")
    Backup-File -Source $applyTargets["ionLocaleZst"] -BackupDir (Join-Path $runDir "ion")
    Backup-File -Source $applyTargets["ionOverrides"] -BackupDir (Join-Path $runDir "ion-overrides")
    Backup-File -Source $applyTargets["ionOverridesZst"] -BackupDir (Join-Path $runDir "ion-overrides")
    Backup-File -Source $applyTargets["statsigLocale"] -BackupDir (Join-Path $runDir "statsig")
    Backup-File -Source $applyTargets["statsigLocaleZst"] -BackupDir (Join-Path $runDir "statsig")

    foreach ($assetPath in $patchTargets) {
        Backup-File -Source $assetPath -BackupDir (Join-Path $runDir "assets")
        Backup-File -Source (Get-CompressedAssetPath -AssetPath $assetPath) -BackupDir (Join-Path $runDir "assets")
    }

    Write-Host "[5/7] 请求目标文件写权限..." -ForegroundColor Cyan
    foreach ($path in @(
            $applyTargets["rootLocale"],
            $applyTargets["ionLocale"],
            $applyTargets["ionLocaleZst"],
            $applyTargets["ionOverrides"],
            $applyTargets["ionOverridesZst"],
            $applyTargets["statsigLocale"],
            $applyTargets["statsigLocaleZst"]
        )) {
        Grant-PathAccess -Path $path
    }
    foreach ($assetPath in $patchTargets) {
        Grant-PathAccess -Path $assetPath
        Grant-PathAccess -Path (Get-CompressedAssetPath -AssetPath $assetPath)
    }

    Write-Host "[6/7] 写入 zh-CN 资源并应用运行时补丁..." -ForegroundColor Cyan
    Copy-Item -LiteralPath $artifacts["RootLocale"] -Destination $applyTargets["rootLocale"] -Force
    Copy-Item -LiteralPath $artifacts["IonLocale"] -Destination $applyTargets["ionLocale"] -Force
    Copy-Item -LiteralPath $artifacts["IonLocaleZst"] -Destination $applyTargets["ionLocaleZst"] -Force
    Copy-Item -LiteralPath $artifacts["IonOverrides"] -Destination $applyTargets["ionOverrides"] -Force
    Copy-Item -LiteralPath $artifacts["IonOverridesZst"] -Destination $applyTargets["ionOverridesZst"] -Force
    Copy-Item -LiteralPath $artifacts["StatsigLocale"] -Destination $applyTargets["statsigLocale"] -Force
    Copy-Item -LiteralPath $artifacts["StatsigLocaleZst"] -Destination $applyTargets["statsigLocaleZst"] -Force

    $fileReport = New-Object System.Collections.ArrayList
    $compressedAssetReport = New-Object System.Collections.ArrayList
    foreach ($assetPath in $patchTargets) {
        $changes = @(Apply-PatchesToFile -Path $assetPath -Patches $patches)
        if (Remove-LegacyZhCnWatermark -Path $assetPath) {
            $changes += [pscustomobject]@{
                description = "清理旧版角落署名残留"
                count       = 1
            }
        }

        if (@($changes).Count -gt 0) {
            [void]$fileReport.Add([pscustomobject]@{
                    file    = $assetPath
                    changes = @($changes)
                })
        }

        if ($managedAssetMap.ContainsKey($assetPath)) {
            $projectCompressed = $managedAssetMap[$assetPath].CompressedPath
        }
        else {
            $projectCompressed = Get-PatchedCompressedAssetPath -PatchedAssetsDir $artifacts["PatchedAssetsDir"] -AssetPath $assetPath
        }
        $targetCompressed = Get-CompressedAssetPath -AssetPath $assetPath
        if (Test-Path -LiteralPath $projectCompressed -PathType Leaf) {
            Copy-Item -LiteralPath $projectCompressed -Destination $targetCompressed -Force
            [void]$compressedAssetReport.Add([pscustomobject]@{
                    file = $targetCompressed
                })
        }
    }

    $matchedPatches = @($patchAnalysis | Where-Object { $_.matched }).Count
    $alreadyPatchedPatches = @($patchAnalysis | Where-Object { $_.alreadyPatched }).Count
    $unmatchedPatches = @(
        $patchAnalysis | Where-Object { -not $_.matched -and -not $_.alreadyPatched }
    ).Count

    $summary = [pscustomobject]@{
        totalPatches          = $patches.Count
        matchedPatches        = $matchedPatches
        alreadyPatchedPatches = $alreadyPatchedPatches
        unmatchedPatches      = $unmatchedPatches
        patchedFiles          = $fileReport.Count
        syncedCompressedAssets = $compressedAssetReport.Count
    }

    $copiedLocales = [pscustomobject]@{
        rootLocale       = $applyTargets["rootLocale"]
        ionLocale        = $applyTargets["ionLocale"]
        ionLocaleZst     = $applyTargets["ionLocaleZst"]
        ionOverrides     = $applyTargets["ionOverrides"]
        ionOverridesZst  = $applyTargets["ionOverridesZst"]
        statsigLocale    = $applyTargets["statsigLocale"]
        statsigLocaleZst = $applyTargets["statsigLocaleZst"]
    }

    $report = [pscustomobject]@{
        summary       = $summary
        patches       = @($patchAnalysis)
        files         = @($fileReport)
        compressedAssets = @($compressedAssetReport)
        copiedLocales = $copiedLocales
    }
    Write-JsonFile -Path (Join-Path $runDir "apply-report.json") -Value $report

    Write-Host "[7/7] 执行自动校验..." -ForegroundColor Cyan
    $issues = @(Get-VerificationIssues -Config $config)
    if ($issues.Count -gt 0) {
        Write-Host "应用完成，但自动校验未通过。" -ForegroundColor Yellow
        foreach ($issue in $issues) {
            Write-Host " - $issue"
        }
        exit 1
    }

    Write-Host "Claude Desktop 1.4758.0.0 汉化已应用完成。" -ForegroundColor Green
    Write-Host "备份目录: $runDir"
    Write-Host "已写入 root / ion / overrides / statsig 中文资源。"
    Write-Host "已自动校验通过。"
    exit 0
}
catch {
    Write-Host "应用失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "异常类型: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    if ($_.InvocationInfo) {
        Write-Host "出错位置: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
        Write-Host "出错语句: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    }
    if ($_.ScriptStackTrace) {
        Write-Host "调用栈:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    exit 1
}
