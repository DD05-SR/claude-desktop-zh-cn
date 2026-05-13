import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class EntrypointTests(unittest.TestCase):
    def test_user_facing_launchers_call_adaptive_scripts(self) -> None:
        launchers = {
            "汉化应用.bat": "scripts\\apply_localization.ps1",
            "汉化回滚.bat": "scripts\\rollback_localization.ps1",
        }

        for name, script in launchers.items():
            text = (PROJECT_ROOT / name).read_text(encoding="utf-8")
            self.assertIn(script, text)
            self.assertNotIn("apply_all.ps1", text)
            self.assertNotIn("simple_rollback.ps1", text)

    def test_runtime_entrypoints_exist(self) -> None:
        required = [
            "README.md",
            "docs/USAGE.md",
            "config.json",
            "patches/main-ui-patches.json",
            "scripts/common.ps1",
            "scripts/detect_install.ps1",
            "scripts/scan_missing.ps1",
            "scripts/apply_localization.ps1",
            "scripts/verify_localization.ps1",
            "scripts/rollback_localization.ps1",
            "汉化应用.bat",
            "汉化回滚.bat",
        ]

        for relative_path in required:
            self.assertTrue((PROJECT_ROOT / relative_path).exists(), relative_path)

    def test_active_powershell_entrypoints_are_ascii_safe_for_windows_powershell(self) -> None:
        scripts = [
            "scripts/common.ps1",
            "scripts/detect_install.ps1",
            "scripts/scan_missing.ps1",
            "scripts/apply_localization.ps1",
            "scripts/verify_localization.ps1",
            "scripts/rollback_localization.ps1",
        ]

        for relative_path in scripts:
            text = (PROJECT_ROOT / relative_path).read_text(encoding="utf-8")
            self.assertTrue(text.isascii(), relative_path)

    def test_readme_describes_version_adaptive_flow(self) -> None:
        readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("自动发现", readme)
        self.assertIn("缺失汉化清单", readme)
        self.assertIn("scripts/scan_missing.ps1", readme)
        self.assertNotIn("文件名哈希需与你的 Claude 版本匹配", readme)


if __name__ == "__main__":
    unittest.main()
