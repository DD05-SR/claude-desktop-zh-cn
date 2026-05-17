import json
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
POWERSHELL = "powershell"


def run_ps(command: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [POWERSHELL, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


class AdaptiveLocalizationTests(unittest.TestCase):
    def test_config_uses_dynamic_install_discovery_defaults(self) -> None:
        config = json.loads((PROJECT_ROOT / "config.json").read_text(encoding="utf-8"))

        self.assertNotIn("supportedInstallRoot", config)
        self.assertNotIn("applyTargets", config)
        self.assertEqual(config["installDiscovery"]["windowsAppsRoot"], r"C:\Program Files\WindowsApps")
        self.assertIsNone(config["installDiscovery"]["manualInstallRoot"])
        self.assertEqual(config["locale"], "zh-CN")

    def test_patch_manifest_is_file_agnostic_and_marks_required_rules(self) -> None:
        patches = json.loads((PROJECT_ROOT / "patches" / "main-ui-patches.json").read_text(encoding="utf-8"))

        self.assertGreaterEqual(len(patches), 5)
        self.assertTrue(any(item["required"] for item in patches))
        self.assertTrue(all("file" not in item for item in patches))
        self.assertTrue(all({"description", "find", "replace", "kind", "required"} <= set(item) for item in patches))

        patch_text = "\n".join(item["find"] + "\n" + item["replace"] for item in patches)
        self.assertIn('"zh-CN"', patch_text)
        self.assertIn('defaultMessage:"Projects"', patch_text)
        self.assertIn('defaultMessage:"Scheduled"', patch_text)
        self.assertIn('defaultMessage:"Customize"', patch_text)
        self.assertIn('defaultMessage:"New task"', patch_text)

    def test_runtime_translation_table_contains_visible_settings_copy(self) -> None:
        translations = json.loads((PROJECT_ROOT / "locales" / "runtime-zh-CN.translations.json").read_text(encoding="utf-8"))

        self.assertEqual(translations["Configure third-party inference"], "配置第三方推理")
        self.assertEqual(translations["Sandbox & workspace"], "沙盒与工作区")
        self.assertEqual(translations["Gateway base URL"], "网关基础 URL")
        self.assertEqual(translations["View as JSON"], "以 JSON 查看")

    def test_runtime_translations_generate_literal_patches_for_visible_message_shapes(self) -> None:
        command = (
            f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
            "$translations = @{ 'Configure third-party inference' = '配置第三方推理'; 'Gateway base URL' = '网关基础 URL' }; "
            "$patches = New-RuntimeTranslationPatches -Translations $translations; "
            "$patches | ConvertTo-Json -Compress"
        )
        result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        patches = json.loads(result.stdout)
        patch_text = "\n".join(item["find"] + "\n" + item["replace"] for item in patches)
        self.assertIn('defaultMessage:"Configure third-party inference"', patch_text)
        self.assertIn('defaultMessage:"配置第三方推理"', patch_text)
        self.assertIn('title:"Gateway base URL"', patch_text)
        self.assertIn('title:"网关基础 URL"', patch_text)

    def test_compatibility_report_summarizes_install_assets_and_patch_health(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            resources = Path(td) / "Claude_1.20.0.0_x64__pzs8sxrjxfjjc" / "app" / "resources"
            assets = resources / "ion-dist" / "assets" / "v1"
            i18n = resources / "ion-dist" / "i18n" / "statsig"
            assets.mkdir(parents=True)
            i18n.mkdir(parents=True)
            (resources / "app.asar").write_text("", encoding="utf-8")
            (assets / "index-test.js").write_text('=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"]', encoding="utf-8")

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"$install = Find-ClaudeInstall -WindowsAppsRoot '{td}'; "
                "$report = Get-CompatibilityReport -Install $install; "
                "$report | ConvertTo-Json -Compress -Depth 8"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        report = json.loads(result.stdout)
        self.assertEqual(report["version"], "1.20.0.0")
        self.assertTrue(report["resourcesFound"])
        self.assertTrue(report["i18nFound"])
        self.assertTrue(report["assetsFound"])
        self.assertGreaterEqual(report["assetFileCount"], 1)
        self.assertEqual(report["requiredUnmatched"], 0)
        self.assertEqual(report["recommendation"], "APPLY_OK")

    def test_effective_patches_include_runtime_translation_table(self) -> None:
        command = (
            f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
            "$patches = Get-EffectivePatches; "
            "$patches | Where-Object { $_.find -eq 'defaultMessage:\"Configure third-party inference\"' } | "
            "Select-Object -First 1 | ConvertTo-Json -Compress"
        )
        result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        patch = json.loads(result.stdout)
        self.assertEqual(patch["replace"], 'defaultMessage:"配置第三方推理"')

    def test_find_claude_install_selects_latest_valid_version(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            for version in ["1.9.0.0", "1.10.0.0"]:
                resources = root / f"Claude_{version}_x64__pzs8sxrjxfjjc" / "app" / "resources"
                (resources / "ion-dist" / "assets" / "v1").mkdir(parents=True)
                (resources / "ion-dist" / "i18n" / "statsig").mkdir(parents=True)
                (resources / "app.asar").write_text("", encoding="utf-8")

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"$install = Find-ClaudeInstall -WindowsAppsRoot '{root}'; "
                "$install | ConvertTo-Json -Compress"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        install = json.loads(result.stdout)
        self.assertEqual(install["Version"], "1.10.0.0")
        self.assertTrue(install["ResourcesDir"].endswith(r"Claude_1.10.0.0_x64__pzs8sxrjxfjjc\app\resources"))
        self.assertTrue(install["AssetsDir"].endswith(r"ion-dist\assets\v1"))

    def test_get_value_reads_javascriptserializer_dictionaries_by_key(self) -> None:
        command = (
            f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
            "$serializer = New-JsonSerializer; "
            "$config = $serializer.DeserializeObject('{\"installDiscovery\":{\"windowsAppsRoot\":\"C:\\\\Apps\"}}'); "
            "$discovery = Get-Value -Object $config -Key 'installDiscovery' -Default @{}; "
            "Get-Value -Object $discovery -Key 'windowsAppsRoot' -Default 'missing'"
        )
        result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(result.stdout.strip(), r"C:\Apps")

    def test_backup_file_copies_bytes_without_copy_item_metadata_preservation(self) -> None:
        common = (PROJECT_ROOT / "scripts" / "common.ps1").read_text(encoding="utf-8")
        backup_body = common.split("function Backup-File", 1)[1].split("function Restore-DirectoryFiles", 1)[0]

        self.assertIn("OpenRead", backup_body)
        self.assertIn("Create", backup_body)
        self.assertNotIn("Copy-Item", backup_body)

    def test_apply_patches_scans_all_assets_without_file_names(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            asset = Path(td) / "renamed-by-new-version.js"
            asset.write_text(
                'formatMessage({defaultMessage:"Projects",id:"UxTJRaKagI"});'
                'formatMessage({defaultMessage:"New task",id:"K4O03zh0vo"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                "$patches = @("
                "@{description='projects'; find='defaultMessage:\"Projects\"'; replace='defaultMessage:\"PROJECTS_ZH\"'; kind='runtime'; required=$true},"
                "@{description='new task'; find='defaultMessage:\"New task\"'; replace='defaultMessage:\"NEW_TASK_ZH\"'; kind='runtime'; required=$false}"
                "); "
                f"$files = Get-AssetFiles -AssetsDir '{td}'; "
                "$analysis = Analyze-PatchHits -Patches $patches -AssetFiles $files; "
                "$targets = Get-PatchTargetFiles -PatchAnalysis $analysis; "
                "foreach ($target in $targets) { Apply-PatchesToFile -Path $target -Patches $patches | Out-Null }; "
                f"Get-Content -LiteralPath '{asset}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn('defaultMessage:"PROJECTS_ZH"', result.stdout)
        self.assertIn('defaultMessage:"NEW_TASK_ZH"', result.stdout)

    def test_scan_missing_translations_writes_reviewable_json(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            asset = Path(td) / "chunk.js"
            output = Path(td) / "missing-zh-CN.json"
            asset.write_text(
                'formatMessage({defaultMessage:"Archive",id:"archive"});'
                'formatMessage({defaultMessage:"OPENAI_API_KEY",id:"env"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{td}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing = json.loads(result.stdout)
        self.assertEqual(missing[0]["text"], "Archive")
        self.assertEqual(missing[0]["translation"], "")
        self.assertTrue(missing[0]["file"].endswith("chunk.js"))

    def test_scan_missing_translations_filters_non_ui_identifiers(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            asset = Path(td) / "chunk.js"
            output = Path(td) / "missing-zh-CN.json"
            asset.write_text(
                '"div";"span";"CodeSessionRoute";"GatewayIcon";'
                'formatMessage({defaultMessage:"Fresh visible error",id:"connection"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{td}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing_texts = {item["text"] for item in json.loads(result.stdout)}
        self.assertIn("Fresh visible error", missing_texts)
        self.assertNotIn("div", missing_texts)
        self.assertNotIn("span", missing_texts)
        self.assertNotIn("CodeSessionRoute", missing_texts)
        self.assertNotIn("GatewayIcon", missing_texts)

    def test_scan_missing_translations_filters_common_internal_strings(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            asset = Path(td) / "chunk.js"
            output = Path(td) / "missing-zh-CN.json"
            asset.write_text(
                '"Sundays";"Mondays";"{pct}%";"Aria label for actions mode icon in command palette";'
                '"must use https";"MCP server names must be unique";'
                'formatMessage({defaultMessage:"Fresh visible settings copy",id:"visible"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{td}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing_texts = {item["text"] for item in json.loads(result.stdout)}
        self.assertIn("Fresh visible settings copy", missing_texts)
        self.assertNotIn("Sundays", missing_texts)
        self.assertNotIn("Mondays", missing_texts)
        self.assertNotIn("{pct}%", missing_texts)
        self.assertNotIn("Aria label for actions mode icon in command palette", missing_texts)
        self.assertNotIn("must use https", missing_texts)
        self.assertNotIn("MCP server names must be unique", missing_texts)

    def test_scan_missing_translations_skips_terms_already_in_runtime_table(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            asset = Path(td) / "chunk.js"
            output = Path(td) / "missing-zh-CN.json"
            asset.write_text(
                'formatMessage({defaultMessage:"Configure third-party inference",id:"known"});'
                'formatMessage({defaultMessage:"Untranslated visible copy",id:"new"});',
                encoding="utf-8",
            )

            command = (
                f". '{PROJECT_ROOT / 'scripts' / 'common.ps1'}'; "
                f"Scan-MissingTranslations -AssetsDir '{td}' -OutputPath '{output}' | Out-Null; "
                f"Get-Content -LiteralPath '{output}' -Raw"
            )
            result = run_ps(command)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        missing_texts = {item["text"] for item in json.loads(result.stdout)}
        self.assertNotIn("Configure third-party inference", missing_texts)
        self.assertIn("Untranslated visible copy", missing_texts)


if __name__ == "__main__":
    unittest.main()
