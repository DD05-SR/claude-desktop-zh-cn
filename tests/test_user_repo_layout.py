import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class UserRepoLayoutTests(unittest.TestCase):
    def test_user_download_repo_keeps_adaptive_runtime_files(self) -> None:
        required = [
            "README.md",
            "docs/USAGE.md",
            "config.json",
            "locales/ion-zh-CN.json",
            "locales/ion-zh-CN.overrides.json",
            "locales/statsig/zh-CN.json",
            "patches/main-ui-patches.json",
            "scripts/common.ps1",
            "scripts/detect_install.ps1",
            "scripts/scan_missing.ps1",
            "scripts/apply_localization.ps1",
            "scripts/verify_localization.ps1",
            "scripts/rollback_localization.ps1",
        ]

        for relative_path in required:
            self.assertTrue((PROJECT_ROOT / relative_path).exists(), relative_path)

    def test_legacy_fixed_version_helpers_are_not_primary_entrypoints(self) -> None:
        for relative_path in ["scripts/apply_all.ps1", "scripts/patch_sidebar.ps1", "scripts/patch_js.ps1"]:
            if (PROJECT_ROOT / relative_path).exists():
                text = (PROJECT_ROOT / relative_path).read_text(encoding="utf-8-sig")
                self.assertIn("deprecated", text.lower(), relative_path)


if __name__ == "__main__":
    unittest.main()
