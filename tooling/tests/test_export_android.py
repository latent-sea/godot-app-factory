"""export_android.py: what only a test needs is found in an APK."""

import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import export_android  # noqa: E402


def apk_with(names: list[str]) -> Path:
    path = Path(tempfile.mkdtemp()) / "app.apk"
    with zipfile.ZipFile(path, "w") as packed:
        for name in names:
            packed.writestr(name, "x")
    return path


class DevelopmentFilesTest(unittest.TestCase):
    def test_a_clean_apk_carries_nothing_of_the_tests(self) -> None:
        apk = apk_with(["assets/notes.gdc", "assets/addons/factory_look/look.gdc", "assets/addons/gd_chime/components/primitives/carry_walk.gdc"])
        self.assertEqual(export_android.development_files(apk), [])

    def test_probes_testkit_and_tests_are_found(self) -> None:
        apk = apk_with(["assets/probe.gd", "assets/addons/factory_testkit/walk.gdc", "assets/tests/test_app.gdc", "assets/addons/factory_look/tests/test_look.gdc", "assets/notes.gdc"])
        self.assertEqual(export_android.development_files(apk), [
            "assets/addons/factory_look/tests/test_look.gdc",
            "assets/addons/factory_testkit/walk.gdc",
            "assets/probe.gd",
            "assets/tests/test_app.gdc",
        ])


if __name__ == "__main__":
    unittest.main()
