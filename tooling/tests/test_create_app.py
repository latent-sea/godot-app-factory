"""Tests for tooling/create_app.py, against the real templates, into a temporary factory."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import create_app  # noqa: E402


class CreateAppTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "apps").mkdir()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_makes_every_file_with_everything_filled_in(self) -> None:
        app = create_app.create(self.root, "shopping_list")
        made = sorted(p.relative_to(app).as_posix() for p in app.rglob("*") if p.is_file())
        self.assertEqual(made, [
            "export_presets.cfg", "factory.json", "icon.svg", "main.tscn", "probe.gd",
            "project.godot", "shopping_list.gd", "tests/test_app.gd",
        ])
        for path in app.rglob("*"):
            if path.is_file():
                self.assertNotIn("{{", path.read_text(encoding="utf-8"), path.name)

    def test_identity_comes_from_the_name(self) -> None:
        app = create_app.create(self.root, "shopping_list")
        manifest = json.loads((app / "factory.json").read_text())
        self.assertEqual(manifest, {"name": "Shopping List", "package": "com.latentsea.shopping_list", "services": ["look", "basics", "testkit"]})
        self.assertIn('config/name="Shopping List"', (app / "project.godot").read_text())
        presets = (app / "export_presets.cfg").read_text()
        self.assertIn('package/unique_name="com.latentsea.shopping_list"', presets)
        self.assertIn('export_path="../../build/shopping_list-debug.apk"', presets)
        self.assertIn('path="res://shopping_list.gd"', (app / "main.tscn").read_text())
        self.assertIn('[node name="ShoppingList"', (app / "main.tscn").read_text())

    def test_a_title_can_be_given(self) -> None:
        app = create_app.create(self.root, "tally", "Tally Counter")
        self.assertEqual(json.loads((app / "factory.json").read_text())["name"], "Tally Counter")

    def test_bad_names_are_refused(self) -> None:
        for bad in ["Shopping", "2go", "a", "has-dash", "trailing_", "double__score", "x" * 41, "class"]:
            with self.subTest(bad=bad), self.assertRaises(create_app.CreateError):
                create_app.create(self.root, bad)
        self.assertEqual(list((self.root / "apps").iterdir()), [], "nothing is written for a bad name")

    def test_an_existing_app_is_never_overwritten(self) -> None:
        create_app.create(self.root, "tally")
        (self.root / "apps/tally/tally.gd").write_text("my work\n")
        with self.assertRaisesRegex(create_app.CreateError, "already exists"):
            create_app.create(self.root, "tally")
        self.assertEqual((self.root / "apps/tally/tally.gd").read_text(), "my work\n")

    def test_a_package_already_in_use_is_refused(self) -> None:
        (self.root / "apps/old").mkdir()
        (self.root / "apps/old/factory.json").write_text(json.dumps({"package": "com.latentsea.tally"}))
        with self.assertRaisesRegex(create_app.CreateError, "already apps/old's"):
            create_app.create(self.root, "tally")

    def test_quotes_in_a_title_are_refused(self) -> None:
        with self.assertRaisesRegex(create_app.CreateError, "quotes"):
            create_app.create(self.root, "tally", 'Say "hi"')


if __name__ == "__main__":
    unittest.main()
