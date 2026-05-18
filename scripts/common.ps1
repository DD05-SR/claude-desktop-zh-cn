Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Web.Extensions

function Read-Utf8Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8Text {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $script:Utf8NoBom)
}

function New-JsonSerializer {
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = 67108864
    return $serializer
}

function Read-JsonObject {
    param([string]$Path)
    return (New-JsonSerializer).DeserializeObject((Read-Utf8Text -Path $Path))
}

function Write-JsonFile {
    param([string]$Path, $Value)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = ConvertTo-Json -InputObject $Value -Depth 12
    Write-Utf8Text -Path $Path -Content ($json + [Environment]::NewLine)
}

function Get-Value {
    param($Object, [string]$Key, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if (($Object.PSObject.Methods.Name -contains "ContainsKey") -and $Object.ContainsKey($Key)) {
            return $Object[$Key]
        }
        if (($null -ne $Object.Keys) -and ($Object.Keys -contains $Key)) {
            return $Object[$Key]
        }
        return $Default
    }
    if ($Object.PSObject.Properties.Name -contains $Key) {
        return $Object.$Key
    }
    return $Default
}

function Get-ProjectRoot {
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Get-Config {
    $config = Read-JsonObject -Path (Join-Path (Get-ProjectRoot) "config.json")
    if (-not (Get-Value $config "locale")) { $config["locale"] = "zh-CN" }
    if (-not (Get-Value $config "backupDirName")) { $config["backupDirName"] = "backups" }
    return $config
}

function Get-Patches {
    return Read-JsonObject -Path (Join-Path (Get-ProjectRoot) "patches\main-ui-patches.json")
}

function Get-RuntimeTranslations {
    $path = Join-Path (Get-ProjectRoot) "locales\runtime-zh-CN.translations.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return @{}
    }
    return Read-JsonObject -Path $path
}

function New-RuntimeTranslationPatches {
    param($Translations)
    $patches = New-Object System.Collections.ArrayList
    $shapes = @(
        @{ Kind = "defaultMessage"; Prefix = 'defaultMessage:"'; Suffix = '"' },
        @{ Kind = "label"; Prefix = 'label:"'; Suffix = '"' },
        @{ Kind = "title"; Prefix = 'title:"'; Suffix = '"' },
        @{ Kind = "cowork"; Prefix = 'cowork:"'; Suffix = '"' },
        @{ Kind = "placeholder"; Prefix = 'placeholder:"'; Suffix = '"' },
        @{ Kind = "aria-label"; Prefix = 'aria-label:"'; Suffix = '"' },
        @{ Kind = "string"; Prefix = '"'; Suffix = '"' }
    )

    foreach ($source in @($Translations.Keys | Sort-Object)) {
        $target = $Translations[$source]
        if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($target)) {
            continue
        }
        foreach ($shape in $shapes) {
            [void]$patches.Add([pscustomobject]@{
                description = "Runtime translation: $source"
                kind = "runtime-translation"
                required = $false
                find = "$($shape.Prefix)$source$($shape.Suffix)"
                replace = "$($shape.Prefix)$target$($shape.Suffix)"
            })
        }
    }
    return @($patches)
}

function Get-EffectivePatches {
    $basePatches = @(Get-Patches)
    $translationPatches = @(New-RuntimeTranslationPatches -Translations (Get-RuntimeTranslations))
    return @($basePatches + $translationPatches)
}

function Get-CompatibilityReport {
    param($Install)
    $resourcesFound = Test-Path -LiteralPath $Install.ResourcesDir -PathType Container
    $i18nFound = Test-Path -LiteralPath $Install.I18nDir -PathType Container
    $assetsFound = Test-Path -LiteralPath $Install.AssetsDir -PathType Container
    $assetFiles = @()
    if ($assetsFound) {
        $assetFiles = @(Get-AssetFiles -AssetsDir $Install.AssetsDir)
    }
    $patchAnalysis = @()
    if ($assetFiles.Count -gt 0) {
        $patchAnalysis = @(Analyze-PatchHits -Patches (Get-EffectivePatches) -AssetFiles $assetFiles)
    }
    $matched = @($patchAnalysis | Where-Object { $_.matched }).Count
    $already = @($patchAnalysis | Where-Object { $_.alreadyPatched }).Count
    $unmatched = @($patchAnalysis | Where-Object { -not $_.matched -and -not $_.alreadyPatched }).Count
    $requiredUnmatched = @($patchAnalysis | Where-Object { $_.required -and -not $_.matched -and -not $_.alreadyPatched }).Count
    $recommendation = "APPLY_OK"
    if (-not $resourcesFound -or -not $i18nFound -or -not $assetsFound) {
        $recommendation = "UNSUPPORTED_STRUCTURE"
    }
    elseif ($requiredUnmatched -gt 0) {
        $recommendation = "NEEDS_MAINTENANCE"
    }

    return [pscustomobject]@{
        version = $Install.Version
        resourcesDir = $Install.ResourcesDir
        resourcesFound = $resourcesFound
        i18nFound = $i18nFound
        assetsFound = $assetsFound
        assetFileCount = $assetFiles.Count
        totalPatches = $patchAnalysis.Count
        matched = $matched
        alreadyApplied = $already
        unmatched = $unmatched
        requiredUnmatched = $requiredUnmatched
        recommendation = $recommendation
    }
}

function Get-ProjectArtifacts {
    $projectRoot = Get-ProjectRoot
    return @{
        RootLocale = Join-Path $projectRoot "locales\root-zh-CN.json"
        IonLocale = Join-Path $projectRoot "locales\ion-zh-CN.json"
        IonLocaleZst = Join-Path $projectRoot "locales\ion-zh-CN.json.zst"
        IonOverrides = Join-Path $projectRoot "locales\ion-zh-CN.overrides.json"
        IonOverridesZst = Join-Path $projectRoot "locales\ion-zh-CN.overrides.json.zst"
        StatsigLocale = Join-Path $projectRoot "locales\statsig\zh-CN.json"
        StatsigLocaleZst = Join-Path $projectRoot "locales\statsig\zh-CN.json.zst"
        MissingTranslations = Join-Path $projectRoot "locales\missing-zh-CN.json"
    }
}

function Assert-PathExists {
    param([string]$Path, [string]$Description, [switch]$Directory)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description does not exist or cannot be accessed: $Path"
    }
    if ($Directory -and -not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Description is not a directory: $Path"
    }
    if (-not $Directory -and -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description is not a file: $Path"
    }
}

function Assert-ProjectArtifacts {
    param($Artifacts)
    foreach ($key in @("RootLocale", "IonLocale", "IonLocaleZst", "IonOverrides", "IonOverridesZst", "StatsigLocale", "StatsigLocaleZst")) {
        Assert-PathExists -Path $Artifacts[$key] -Description "project artifact $key"
    }
}

function Get-VersionFromClaudePackageName {
    param([string]$Name)
    if ($Name -match '^Claude_([0-9]+(?:\.[0-9]+)+)_') {
        return $Matches[1]
    }
    return $null
}

function New-ClaudeInstallInfo {
    param([string]$ResourcesDir, [string]$Version = "")
    $resources = [System.IO.Path]::GetFullPath($ResourcesDir)
    $i18n = Join-Path $resources "ion-dist\i18n"
    $assets = Join-Path $resources "ion-dist\assets\v1"
    return [pscustomobject]@{
        Version = $Version
        ResourcesDir = $resources
        AppAsar = Join-Path $resources "app.asar"
        I18nDir = $i18n
        StatsigDir = Join-Path $i18n "statsig"
        AssetsDir = $assets
        RootLocale = Join-Path $resources "zh-CN.json"
        IonLocale = Join-Path $i18n "zh-CN.json"
        IonLocaleZst = Join-Path $i18n "zh-CN.json.zst"
        IonOverrides = Join-Path $i18n "zh-CN.overrides.json"
        IonOverridesZst = Join-Path $i18n "zh-CN.overrides.json.zst"
        StatsigLocale = Join-Path $i18n "statsig\zh-CN.json"
        StatsigLocaleZst = Join-Path $i18n "statsig\zh-CN.json.zst"
    }
}

function Test-ClaudeInstallInfo {
    param($Install)
    return (
        (Test-Path -LiteralPath $Install.AppAsar -PathType Leaf) -and
        (Test-Path -LiteralPath $Install.I18nDir -PathType Container) -and
        (Test-Path -LiteralPath $Install.AssetsDir -PathType Container)
    )
}

function Find-ClaudeInstall {
    param(
        [string]$WindowsAppsRoot = "C:\Program Files\WindowsApps",
        [string]$ManualInstallRoot = $null
    )

    if ($ManualInstallRoot) {
        $manual = New-ClaudeInstallInfo -ResourcesDir $ManualInstallRoot -Version "manual"
        if (-not (Test-ClaudeInstallInfo -Install $manual)) {
            throw "Manual Claude resources directory is incomplete: $ManualInstallRoot"
        }
        return $manual
    }

    Assert-PathExists -Path $WindowsAppsRoot -Description "WindowsApps search directory" -Directory
    $candidates = New-Object System.Collections.ArrayList
    foreach ($dir in Get-ChildItem -LiteralPath $WindowsAppsRoot -Directory -Filter "Claude_*" -ErrorAction SilentlyContinue) {
        $versionText = Get-VersionFromClaudePackageName -Name $dir.Name
        if (-not $versionText) { continue }
        $install = New-ClaudeInstallInfo -ResourcesDir (Join-Path $dir.FullName "app\resources") -Version $versionText
        if (Test-ClaudeInstallInfo -Install $install) {
            [void]$candidates.Add($install)
        }
    }

    if ($candidates.Count -eq 0) {
        throw "No usable Claude Desktop installation found in $WindowsAppsRoot."
    }

    return @($candidates | Sort-Object @{ Expression = { [version]$_.Version }; Descending = $true })[0]
}

function Resolve-ClaudeInstall {
    param($Config)
    $emptyDiscovery = @{}
    $discovery = Get-Value -Object $Config -Key "installDiscovery" -Default $emptyDiscovery
    $windowsAppsRoot = Get-Value -Object $discovery -Key "windowsAppsRoot" -Default "C:\Program Files\WindowsApps"
    $manualInstallRoot = Get-Value -Object $discovery -Key "manualInstallRoot" -Default $null
    return Find-ClaudeInstall -WindowsAppsRoot $windowsAppsRoot -ManualInstallRoot $manualInstallRoot
}

function Get-ApplyTargets {
    param($Install)
    return @{
        rootLocale = $Install.RootLocale
        ionLocale = $Install.IonLocale
        ionLocaleZst = $Install.IonLocaleZst
        ionOverrides = $Install.IonOverrides
        ionOverridesZst = $Install.IonOverridesZst
        statsigLocale = $Install.StatsigLocale
        statsigLocaleZst = $Install.StatsigLocaleZst
        assetsDir = $Install.AssetsDir
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-BackupRoot {
    param($Config)
    return Join-Path (Get-ProjectRoot) (Get-Value $Config "backupDirName" "backups")
}

function Get-Timestamp {
    return Get-Date -Format "yyyyMMdd-HHmmss"
}

function New-BackupRunDirectory {
    param($Config)
    $backupRoot = Get-BackupRoot -Config $Config
    Ensure-Directory -Path $backupRoot
    $runDir = Join-Path $backupRoot (Get-Timestamp)
    Ensure-Directory -Path $runDir
    return $runDir
}

function Get-LatestBackupDirectory {
    param($Config)
    $backupRoot = Get-BackupRoot -Config $Config
    Assert-PathExists -Path $backupRoot -Description "backup directory" -Directory
    $latest = Get-ChildItem -LiteralPath $backupRoot -Directory | Sort-Object Name | Select-Object -Last 1
    if ($null -eq $latest) { throw "No backup directory is available for rollback." }
    return $latest.FullName
}

function Backup-File {
    param([string]$Source, [string]$BackupDir)
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return }
    Ensure-Directory -Path $BackupDir
    $destination = Join-Path $BackupDir ([System.IO.Path]::GetFileName($Source))
    $sourceStream = [System.IO.File]::OpenRead($Source)
    try {
        $destinationStream = [System.IO.File]::Create($destination)
        try {
            $sourceStream.CopyTo($destinationStream)
        }
        finally {
            $destinationStream.Dispose()
        }
    }
    finally {
        $sourceStream.Dispose()
    }
    [System.IO.File]::SetAttributes($destination, [System.IO.FileAttributes]::Normal)
}

function Restore-DirectoryFiles {
    param([string]$SourceDir, [string]$DestinationDir)
    $restored = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) { return $restored }
    Ensure-Directory -Path $DestinationDir
    foreach ($item in Get-ChildItem -LiteralPath $SourceDir -File) {
        $destination = Join-Path $DestinationDir $item.Name
        Copy-FileWithAccess -Source $item.FullName -Destination $destination
        [void]$restored.Add($destination)
    }
    return $restored
}

function Grant-PathAccess {
    param([string]$Path)
    $target = $Path
    if (-not (Test-Path -LiteralPath $target)) {
        $target = Split-Path -Path $Path -Parent
    }
    if (-not (Test-Path -LiteralPath $target)) {
        throw "Cannot locate permission target: $Path"
    }
    & takeown.exe /F $target /A | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "takeown failed: $target" }
    $isDirectory = Test-Path -LiteralPath $target -PathType Container
    $adminGrant = "*S-1-5-32-544:F"
    if ($isDirectory) {
        $adminGrant = "*S-1-5-32-544:(OI)(CI)F"
    }
    & icacls.exe $target /grant $adminGrant /C | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "icacls failed: $target" }
    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $userGrant = "*${currentSid}:F"
    if ($isDirectory) {
        $userGrant = "*${currentSid}:(OI)(CI)F"
    }
    & icacls.exe $target /grant $userGrant /C | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "icacls current user failed: $target" }
}

function Copy-FileWithAccess {
    param([string]$Source, [string]$Destination)
    $parent = Split-Path -Path $Destination -Parent
    if ($parent) {
        Grant-PathAccess -Path $parent
    }
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        Grant-PathAccess -Path $Destination
        [System.IO.File]::SetAttributes($Destination, [System.IO.FileAttributes]::Normal)
    }
    [System.IO.File]::Copy($Source, $Destination, $true)
    [System.IO.File]::SetAttributes($Destination, [System.IO.FileAttributes]::Normal)
}

function Decode-PatchText {
    param([string]$Value)
    return [System.Text.RegularExpressions.Regex]::Unescape($Value)
}

function Count-LiteralOccurrences {
    param([string]$Text, [string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return 0 }
    return [System.Text.RegularExpressions.Regex]::Matches(
        $Text,
        [System.Text.RegularExpressions.Regex]::Escape($Value)
    ).Count
}

function Get-AssetFiles {
    param([string]$AssetsDir)
    $files = New-Object System.Collections.ArrayList
    foreach ($pattern in @("*.js", "*.css")) {
        foreach ($file in Get-ChildItem -LiteralPath $AssetsDir -Filter $pattern -File -ErrorAction SilentlyContinue) {
            [void]$files.Add($file)
        }
    }
    return @($files | Sort-Object FullName)
}

function Get-CompressedAssetPath {
    param([string]$AssetPath)
    return "$AssetPath.zst"
}

function Analyze-PatchHits {
    param($Patches, $AssetFiles)
    $results = New-Object System.Collections.ArrayList
    foreach ($patch in $Patches) {
        $find = Decode-PatchText -Value (Get-Value $patch "find")
        $replace = Decode-PatchText -Value (Get-Value $patch "replace")
        $matchedFiles = New-Object System.Collections.ArrayList
        $replacedFiles = New-Object System.Collections.ArrayList
        $totalHits = 0
        $totalReplacedHits = 0

        foreach ($file in $AssetFiles) {
            $text = Read-Utf8Text -Path $file.FullName
            $hitCount = Count-LiteralOccurrences -Text $text -Value $find
            $replacedCount = Count-LiteralOccurrences -Text $text -Value $replace
            if ($hitCount -gt 0) {
                [void]$matchedFiles.Add([pscustomobject]@{ file = $file.FullName; count = $hitCount })
                $totalHits += $hitCount
            }
            if ($replacedCount -gt 0) {
                [void]$replacedFiles.Add([pscustomobject]@{ file = $file.FullName; count = $replacedCount })
                $totalReplacedHits += $replacedCount
            }
        }

        [void]$results.Add([pscustomobject]@{
            description = Get-Value $patch "description"
            kind = Get-Value $patch "kind" "runtime"
            required = [bool](Get-Value $patch "required" $false)
            find = Get-Value $patch "find"
            replace = Get-Value $patch "replace"
            matched = $totalHits -gt 0
            alreadyPatched = $totalHits -eq 0 -and $totalReplacedHits -gt 0
            totalHits = $totalHits
            totalReplacedHits = $totalReplacedHits
            files = @($matchedFiles)
            replacedFiles = @($replacedFiles)
        })
    }
    return @($results)
}

function Get-PatchTargetFiles {
    param($PatchAnalysis)
    $targets = @{}
    foreach ($result in $PatchAnalysis) {
        foreach ($fileInfo in @($result.files) + @($result.replacedFiles)) {
            if ($null -ne $fileInfo -and $fileInfo.file) {
                $targets[$fileInfo.file] = $true
            }
        }
    }
    return @($targets.Keys)
}

function Apply-PatchesToFile {
    param([string]$Path, $Patches)
    $text = Read-Utf8Text -Path $Path
    $changes = New-Object System.Collections.ArrayList
    foreach ($patch in $Patches) {
        $find = Decode-PatchText -Value (Get-Value $patch "find")
        $replace = Decode-PatchText -Value (Get-Value $patch "replace")
        if ($find -eq $replace) { continue }
        $count = Count-LiteralOccurrences -Text $text -Value $find
        if ($count -gt 0) {
            $text = $text.Replace($find, $replace)
            [void]$changes.Add([pscustomobject]@{
                description = Get-Value $patch "description"
                count = $count
            })
        }
    }
    if ($changes.Count -gt 0) {
        Write-Utf8Text -Path $Path -Content $text
    }
    return @($changes)
}

function Get-RequiredPatchIssues {
    param($PatchAnalysis)
    $issues = New-Object System.Collections.ArrayList
    foreach ($result in $PatchAnalysis) {
        if ($result.required -and -not $result.matched -and -not $result.alreadyPatched) {
            [void]$issues.Add("Required patch did not match and needs maintenance: $($result.description)")
        }
    }
    return @($issues)
}

function Test-VisibleEnglishText {
    param([string]$Value, [string]$Kind = "defaultMessage")
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -match '[\u4e00-\u9fff]') { return $false }
    if ($Value.Length -gt 80) { return $false }
    if ($Value -notmatch '[A-Za-z]') { return $false }
    if ($Value -match '[{}%]') { return $false }
    if ($Value -match '<[^>]+>') { return $false }
    if ($Value -match '[\\/]|\.([A-Za-z0-9]{1,8})(\s|$)') { return $false }
    if ($Value -cmatch '^[A-Z0-9_./:-]+$') { return $false }
    if ($Value -cmatch '^[A-Za-z0-9_.:-]+$' -and $Value -match '[_.:-]') { return $false }
    if ($Value -match '\b(API|URL|URI|HTTP|HTTPS|JSON|JWT|OAuth|CORS|SDK|CLI|MCP|DOM|CSS|HTML|JS|TS|SQL|SCIM|HIPAA|CVC|UUID|ID)\b') { return $false }
    if ($Value -match '\b(Opus|Sonnet|Haiku|Gemini|Llama|Mistral|Bedrock|Vertex|Foundry|GPT|AWS|Azure|GCP)\b') { return $false }
    if ($Value -match 'https?://') { return $false }
    if ($Value -match '\bhttps\b') { return $false }
    if ($Value -match '^[0-9]+[dhms]$') { return $false }
    if ($Value -match '^(Sundays|Mondays|Tuesdays|Wednesdays|Thursdays|Fridays|Saturdays)$') { return $false }
    if ($Value -match '^(Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday)$') { return $false }
    if ($Value -match '^(January|February|March|April|May|June|July|August|September|October|November|December)$') { return $false }
    if ($Value -match '^Aria label ') { return $false }
    if ($Value -match '^MCP server ') { return $false }
    if ($Value -cmatch '^[a-z][a-z0-9-]*$') { return $false }
    if ($Value -cmatch '^[A-Za-z0-9]+(Route|Icon|Content|Layout|Provider|Context|Component|Props|State|Type|Code|List|Map)$') { return $false }
    if ($Value -cmatch '^[A-Za-z]+[A-Z][A-Za-z0-9]+$' -and $Value -notmatch '\s') { return $false }
    if ($Value -in @("div", "span", "section", "article", "button", "input", "textarea", "label", "form", "main", "nav", "header", "footer", "code")) { return $false }
    if ($Kind -eq "string") {
        if ($Value -notmatch '\s') { return $false }
        if ($Value -cmatch '^[A-Z][a-z]+( [A-Z][a-z]+)*$' -and $Value.Length -lt 18) { return $false }
        if ($Value -match '\b(error|failed|loading|choose|select|create|delete|enable|disable|open|close|save|cancel|try|search|settings|session|task|folder|branch|workspace|privacy|notification|permission|account|message|conversation|schedule|routine|connect|install|update|review|payment|billing)\b') {
            return $true
        }
        return $false
    }
    return $true
}

function Scan-MissingTranslations {
    param([string]$AssetsDir, [string]$OutputPath)
    $seen = @{}
    $knownTranslations = Get-RuntimeTranslations
    $items = New-Object System.Collections.ArrayList
    $patterns = @(
        @{ kind = "defaultMessage"; regex = 'defaultMessage:"([^"]+)"' },
        @{ kind = "label"; regex = 'label:"([^"]+)"' },
        @{ kind = "title"; regex = 'title:"([^"]+)"' },
        @{ kind = "cowork"; regex = 'cowork:"([^"]+)"' }
    )

    foreach ($file in (Get-AssetFiles -AssetsDir $AssetsDir)) {
        $text = Read-Utf8Text -Path $file.FullName
        foreach ($pattern in $patterns) {
            foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($text, $pattern.regex)) {
                $value = [System.Text.RegularExpressions.Regex]::Unescape($match.Groups[1].Value)
                if (-not (Test-VisibleEnglishText -Value $value -Kind $pattern.kind)) { continue }
                if ((Get-Value -Object $knownTranslations -Key $value -Default $null)) { continue }
                $key = $value
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true
                [void]$items.Add([ordered]@{
                    text = $value
                    translation = ""
                    kind = $pattern.kind
                    file = $file.FullName
                })
            }
        }
        foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($text, '"([A-Za-z][A-Za-z ]{2,60})"')) {
            $value = $match.Groups[1].Value
            if (-not (Test-VisibleEnglishText -Value $value -Kind "string")) { continue }
            if ((Get-Value -Object $knownTranslations -Key $value -Default $null)) { continue }
            $key = $value
            if ($seen.ContainsKey($key)) { continue }
            $seen[$key] = $true
            [void]$items.Add([ordered]@{
                text = $value
                translation = ""
                kind = "string"
                file = $file.FullName
            })
        }
    }

    Write-JsonFile -Path $OutputPath -Value @($items)
    return @($items)
}

function Get-VerificationIssues {
    param($Config, $Install = $null)
    if ($null -eq $Install) {
        $Install = Resolve-ClaudeInstall -Config $Config
    }
    $artifacts = Get-ProjectArtifacts
    Assert-ProjectArtifacts -Artifacts $artifacts
    $issues = New-Object System.Collections.ArrayList

    $assetFiles = Get-AssetFiles -AssetsDir $Install.AssetsDir
    $patchAnalysis = Analyze-PatchHits -Patches (Get-EffectivePatches) -AssetFiles $assetFiles
    foreach ($issue in Get-RequiredPatchIssues -PatchAnalysis $patchAnalysis) {
        [void]$issues.Add($issue)
    }
    return @($issues)
}
