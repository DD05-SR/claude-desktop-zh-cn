Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

try {
    Write-Host "[1/7] Loading config and detecting Claude Desktop..." -ForegroundColor Cyan
    $config = Get-Config
    $install = Resolve-ClaudeInstall -Config $config
    $artifacts = Get-ProjectArtifacts
    Assert-ProjectArtifacts -Artifacts $artifacts
    Write-Host "  Version: $($install.Version)" -ForegroundColor Green
    Write-Host "  resources: $($install.ResourcesDir)" -ForegroundColor Gray

    Write-Host "[2/7] Scanning runtime patch matches..." -ForegroundColor Cyan
    $patches = Get-EffectivePatches
    $assetFiles = Get-AssetFiles -AssetsDir $install.AssetsDir
    $patchAnalysis = Analyze-PatchHits -Patches $patches -AssetFiles $assetFiles
    $requiredIssues = @(Get-RequiredPatchIssues -PatchAnalysis $patchAnalysis)
    $matchedPatches = @($patchAnalysis | Where-Object { $_.matched }).Count
    $alreadyPatchedPatches = @($patchAnalysis | Where-Object { $_.alreadyPatched }).Count
    $unmatchedPatches = @($patchAnalysis | Where-Object { -not $_.matched -and -not $_.alreadyPatched }).Count
    Write-Host "  Matched: ${matchedPatches}; already applied: ${alreadyPatchedPatches}; unmatched: ${unmatchedPatches}"
    if ($requiredIssues.Count -gt 0) {
        foreach ($issue in $requiredIssues) { Write-Host "  - $issue" -ForegroundColor Yellow }
        throw "Required patch did not match. This Claude version needs maintenance before applying."
    }

    Write-Host "[3/7] Generating missing translation list..." -ForegroundColor Cyan
    $missingPath = Join-Path (Get-ProjectRoot) (Get-Value $config "missingTranslationsPath" "locales\missing-zh-CN.json")
    $missing = @(Scan-MissingTranslations -AssetsDir $install.AssetsDir -OutputPath $missingPath)
    Write-Host "  English candidates: $($missing.Count)"
    Write-Host "  List: $missingPath" -ForegroundColor Gray

    Write-Host "[4/7] Creating backup..." -ForegroundColor Cyan
    $runDir = New-BackupRunDirectory -Config $config
    foreach ($entry in @(
        @{ Source = $install.RootLocale; Dir = "root" },
        @{ Source = $install.IonLocale; Dir = "ion" },
        @{ Source = $install.IonLocaleZst; Dir = "ion" },
        @{ Source = $install.IonOverrides; Dir = "ion-overrides" },
        @{ Source = $install.IonOverridesZst; Dir = "ion-overrides" },
        @{ Source = $install.StatsigLocale; Dir = "statsig" },
        @{ Source = $install.StatsigLocaleZst; Dir = "statsig" }
    )) {
        Backup-File -Source $entry.Source -BackupDir (Join-Path $runDir $entry.Dir)
    }
    $patchTargets = @(Get-PatchTargetFiles -PatchAnalysis $patchAnalysis)
    foreach ($assetPath in $patchTargets) {
        Backup-File -Source $assetPath -BackupDir (Join-Path $runDir "assets")
        Backup-File -Source (Get-CompressedAssetPath -AssetPath $assetPath) -BackupDir (Join-Path $runDir "assets")
    }
    Write-Host "  Backup directory: $runDir" -ForegroundColor Gray

    Write-Host "[5/7] Requesting write permissions..." -ForegroundColor Cyan
    foreach ($path in @($install.ResourcesDir, $install.I18nDir, $install.StatsigDir, $install.AssetsDir)) {
        Grant-PathAccess -Path $path
    }
    foreach ($assetPath in $patchTargets) {
        Grant-PathAccess -Path $assetPath
        $compressed = Get-CompressedAssetPath -AssetPath $assetPath
        if (Test-Path -LiteralPath $compressed) { Grant-PathAccess -Path $compressed }
    }

    Write-Host "[6/7] Copying zh-CN resources and applying runtime patches..." -ForegroundColor Cyan
    Copy-FileWithAccess -Source $artifacts.RootLocale -Destination $install.RootLocale
    Copy-FileWithAccess -Source $artifacts.IonLocale -Destination $install.IonLocale
    Copy-FileWithAccess -Source $artifacts.IonLocaleZst -Destination $install.IonLocaleZst
    Copy-FileWithAccess -Source $artifacts.IonOverrides -Destination $install.IonOverrides
    Copy-FileWithAccess -Source $artifacts.IonOverridesZst -Destination $install.IonOverridesZst
    Copy-FileWithAccess -Source $artifacts.StatsigLocale -Destination $install.StatsigLocale
    Copy-FileWithAccess -Source $artifacts.StatsigLocaleZst -Destination $install.StatsigLocaleZst

    $fileReport = New-Object System.Collections.ArrayList
    foreach ($assetPath in $patchTargets) {
        $changes = @(Apply-PatchesToFile -Path $assetPath -Patches $patches)
        if ($changes.Count -gt 0) {
            [void]$fileReport.Add([pscustomobject]@{ file = $assetPath; changes = $changes })
            $compressed = Get-CompressedAssetPath -AssetPath $assetPath
            if (Test-Path -LiteralPath $compressed) {
                Rename-Item -LiteralPath $compressed -NewName ((Split-Path -Leaf $compressed) + ".bak") -Force
            }
        }
    }

    $report = [pscustomobject]@{
        install = $install
        summary = [pscustomobject]@{
            totalPatches = $patches.Count
            matchedPatches = $matchedPatches
            alreadyPatchedPatches = $alreadyPatchedPatches
            unmatchedPatches = $unmatchedPatches
            missingTranslationCandidates = $missing.Count
            patchedFiles = $fileReport.Count
        }
        patches = $patchAnalysis
        files = $fileReport
        missingTranslations = $missingPath
    }
    Write-JsonFile -Path (Join-Path $runDir "apply-report.json") -Value $report

    Write-Host "[7/7] Running verification..." -ForegroundColor Cyan
    $issues = @(Get-VerificationIssues -Config $config -Install $install)
    if ($issues.Count -gt 0) {
        Write-Host "Apply completed, but verification found issues:" -ForegroundColor Yellow
        foreach ($issue in $issues) { Write-Host " - $issue" -ForegroundColor Yellow }
        exit 1
    }

    Write-Host "Localization applied." -ForegroundColor Green
    Write-Host "Backup directory: $runDir"
    Write-Host "Missing translation list: $missingPath"
    exit 0
}
catch {
    Write-Host "Apply failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
