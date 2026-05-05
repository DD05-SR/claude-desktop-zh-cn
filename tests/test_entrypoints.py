import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class EntrypointTests(unittest.TestCase):
    def test_user_facing_chinese_launchers_exist(self) -> None:
        for name in ["一键应用.bat", "一键校验.bat", "一键回滚.bat"]:
            self.assertTrue((PROJECT_ROOT / name).exists(), name)

    def test_batch_entrypoints_use_powershell_instead_of_python(self) -> None:
        for name in ["apply.bat", "verify.bat", "rollback.bat", "start.bat"]:
            text = (PROJECT_ROOT / name).read_text(encoding="utf-8")
            self.assertNotIn("py -3", text, name)
            self.assertIn(".ps1", text, name)

    def test_readme_and_usage_are_locked_to_single_version_one_click_flow(self) -> None:
        readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")
        usage = (PROJECT_ROOT / "docs" / "USAGE.md").read_text(encoding="utf-8")

        self.assertIn("1.4758.0.0", readme)
        self.assertIn("一键应用.bat", readme)
        self.assertIn("不需要安装 Python", readme)
        self.assertIn("一键应用.bat", usage)
        self.assertIn("一键回滚.bat", usage)
        self.assertIn("自动请求管理员权限", usage)

    def test_readme_puts_simple_user_tutorial_before_maintenance_details(self) -> None:
        readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("## 三步使用教程", readme)
        self.assertIn("## 下载和准备", readme)
        self.assertIn("Code -> Download ZIP", readme)
        self.assertIn("## PowerShell 快速下载", readme)
        self.assertIn("Invoke-WebRequest", readme)
        self.assertIn("Expand-Archive", readme)
        self.assertIn("## 常见问题", readme)
        self.assertIn("可解压到任意普通目录", readme)
        self.assertIn("会请求管理员权限", readme)
        self.assertLess(readme.index("## 三步使用教程"), readme.index("## 支持范围"))
        self.assertLess(readme.index("## PowerShell 快速下载"), readme.index("## 常见问题"))
        self.assertLess(readme.index("## 常见问题"), readme.index("## 支持范围"))
        self.assertNotIn("## 维护者说明", readme)

    def test_grant_path_access_does_not_use_invalid_takeown_flags(self) -> None:
        common = (PROJECT_ROOT / "scripts" / "common.ps1").read_text(encoding="utf-8-sig")

        self.assertNotIn('@("/D", "Y")', common)
        self.assertNotIn('$takeownArgs += @("/D", "Y")', common)

    def test_runtime_patch_scan_includes_css_assets(self) -> None:
        common = (PROJECT_ROOT / "scripts" / "common.ps1").read_text(encoding="utf-8-sig")

        self.assertIn('*.js', common)
        self.assertIn('*.css', common)

    def test_verification_issues_are_consumed_as_arrays(self) -> None:
        apply_script = (PROJECT_ROOT / "scripts" / "apply_localization.ps1").read_text(
            encoding="utf-8-sig"
        )
        verify_script = (PROJECT_ROOT / "scripts" / "verify_localization.ps1").read_text(
            encoding="utf-8-sig"
        )

        self.assertIn("$issues = @(Get-VerificationIssues -Config $config)", apply_script)
        self.assertIn("$issues = @(Get-VerificationIssues -Config $config)", verify_script)

    def test_apply_script_consumes_patch_changes_as_arrays(self) -> None:
        apply_script = (PROJECT_ROOT / "scripts" / "apply_localization.ps1").read_text(
            encoding="utf-8-sig"
        )

        self.assertIn("$changes = @(Apply-PatchesToFile -Path $assetPath -Patches $patches)", apply_script)

    def test_verification_runtime_patch_check_tolerates_replace_hits(self) -> None:
        common = (PROJECT_ROOT / "scripts" / "common.ps1").read_text(encoding="utf-8-sig")

        self.assertIn('$replace = Decode-PatchText -Value $patch["replace"]', common)
        self.assertIn("$replaceCount = Count-LiteralOccurrences -Text $text -Value $replace", common)
        self.assertIn("if ($replaceCount -gt 0 -and $replaceCount -ge $findCount)", common)

    def test_runtime_patch_flow_also_tracks_compressed_assets(self) -> None:
        common = (PROJECT_ROOT / "scripts" / "common.ps1").read_text(encoding="utf-8-sig")
        apply_script = (PROJECT_ROOT / "scripts" / "apply_localization.ps1").read_text(
            encoding="utf-8-sig"
        )

        self.assertIn("PatchedAssetsDir", common)
        self.assertIn("Get-CompressedAssetPath", common)
        self.assertIn("Get-PatchedCompressedAssetPath", common)
        self.assertIn("Backup-File -Source (Get-CompressedAssetPath -AssetPath $assetPath)", apply_script)
        self.assertIn('Copy-Item -LiteralPath $projectCompressed -Destination $targetCompressed -Force', apply_script)

    def test_runtime_patch_flow_keeps_managed_css_bundle_synced_even_without_manifest_hit(self) -> None:
        common = (PROJECT_ROOT / "scripts" / "common.ps1").read_text(encoding="utf-8-sig")
        apply_script = (PROJECT_ROOT / "scripts" / "apply_localization.ps1").read_text(
            encoding="utf-8-sig"
        )

        self.assertIn("function Get-ManagedPatchedAssets", common)
        self.assertIn('Get-ChildItem -LiteralPath $PatchedAssetsDir -Filter "*.zst" -File', common)
        self.assertIn(
            '$managedAssets = Get-ManagedPatchedAssets -PatchedAssetsDir $artifacts["PatchedAssetsDir"] -AssetsDir $applyTargets["assetsDir"]',
            apply_script,
        )
        self.assertIn('$patchTargets = @($patchTargets + @($managedAssets | ForEach-Object { $_.AssetPath }) | Sort-Object -Unique)', apply_script)

    def test_apply_flow_cleans_legacy_corner_watermark_from_plain_assets(self) -> None:
        common = (PROJECT_ROOT / "scripts" / "common.ps1").read_text(encoding="utf-8-sig")
        apply_script = (PROJECT_ROOT / "scripts" / "apply_localization.ps1").read_text(
            encoding="utf-8-sig"
        )

        self.assertIn("function Remove-LegacyZhCnWatermark", common)
        self.assertIn("Remove-LegacyZhCnWatermark -Path $assetPath", apply_script)


if __name__ == "__main__":
    unittest.main()
