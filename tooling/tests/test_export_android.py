"""export_android.py: what only a test needs is found in an APK."""

import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import export_android  # noqa: E402


class DevelopmentFilesTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)

    def apk_with(self, names: list[str]) -> Path:
        path = self.tmp / "app.apk"
        with zipfile.ZipFile(path, "w") as packed:
            for name in names:
                packed.writestr(name, "x")
        return path

    def test_a_clean_apk_carries_nothing_of_the_tests(self) -> None:
        apk = self.apk_with(["assets/notes.gdc", "assets/addons/factory_look/look.gdc", "assets/addons/gd_chime/components/primitives/carry_walk.gdc"])
        self.assertEqual(export_android.development_files(apk), [])

    def test_probes_testkit_and_tests_are_found(self) -> None:
        apk = self.apk_with(["assets/probe.gd", "assets/addons/factory_testkit/walk.gdc", "assets/tests/test_app.gdc", "assets/addons/factory_look/tests/test_look.gdc", "assets/notes.gdc"])
        self.assertEqual(export_android.development_files(apk), [
            "assets/addons/factory_look/tests/test_look.gdc",
            "assets/addons/factory_testkit/walk.gdc",
            "assets/probe.gd",
            "assets/tests/test_app.gdc",
        ])


if __name__ == "__main__":
    unittest.main()
