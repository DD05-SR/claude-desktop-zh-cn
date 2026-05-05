import unittest
from pathlib import Path
import subprocess


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class UserRepoLayoutTests(unittest.TestCase):
    def test_user_download_repo_excludes_maintainer_only_files(self) -> None:
        excluded = [
            "docs/GITHUB_RELEASE.md",
            "locales/manual-overrides.json",
            "patches/test_release_config.py",
            "scripts/_find_mixed.py",
            "scripts/_patch_batch1.py",
            "scripts/_patch_batch2.py",
            "scripts/_patch_bulk.py",
            "scripts/_patch_core_ui.py",
            "scripts/_patch_nav.py",
            "scripts/apply_localization.py",
            "scripts/build_release_assets.py",
            "scripts/package_release.ps1",
            "scripts/restore_asar.py",
            "scripts/rollback_localization.py",
            "scripts/verify_localization.py",
            "tests/test_build_release_assets.py",
            "tests/test_github_release_docs.py",
        ]

        for relative_path in excluded:
            self.assertFalse((PROJECT_ROOT / relative_path).exists(), relative_path)

    def test_user_download_repo_keeps_runtime_entrypoints(self) -> None:
        required = [
            "README.md",
            "docs/USAGE.md",
            "config.json",
            "patches/main-ui-patches.json",
            "scripts/common.ps1",
            "scripts/apply_localization.ps1",
            "scripts/verify_localization.ps1",
            "scripts/rollback_localization.ps1",
            "一键应用.bat",
            "一键校验.bat",
            "一键回滚.bat",
        ]

        for relative_path in required:
            self.assertTrue((PROJECT_ROOT / relative_path).exists(), relative_path)

    def test_compressed_runtime_assets_do_not_contain_corner_watermark(self) -> None:
        css_bundle = PROJECT_ROOT / "patched-assets" / "v1" / "c6a992d55-CjiVONe_.css.zst"
        output = subprocess.run(
            ["zstd", "-d", "-c", str(css_bundle)],
            check=True,
            capture_output=True,
            text=True,
        ).stdout

        self.assertNotIn("by芹菜香", output)
        self.assertNotIn("body::after", output)

    def test_compressed_runtime_assets_keep_signature_only_in_language_label(self) -> None:
        js_bundles = sorted((PROJECT_ROOT / "patched-assets" / "v1").glob("*.js.zst"))
        found = False

        for bundle in js_bundles:
            output = subprocess.run(
                ["zstd", "-d", "-c", str(bundle)],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
            if "简体中文（by芹菜香）" in output:
                self.assertNotIn("Chinese (Simplified)", output)
                found = True
                break

        self.assertTrue(found)


if __name__ == "__main__":
    unittest.main()
