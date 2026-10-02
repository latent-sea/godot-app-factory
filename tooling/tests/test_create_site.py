"""Tests for tooling/create_site.py, against the real templates, into a temporary factory."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import create_app  # noqa: E402
import create_site  # noqa: E402
import godot  # noqa: E402


class CreateSiteTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "apps").mkdir()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_makes_the_same_files_as_an_app_with_everything_filled_in(self) -> None:
        site = create_site.create_site(self.root, "hello")
        made = sorted(p.relative_to(site).as_posix() for p in site.rglob("*") if p.is_file())
        self.assertEqual(made, [
            "export_presets.cfg", "factory.json", "hello.gd", "icon.svg", "main.tscn", "probe.gd",
            "project.godot", "tests/test_app.gd",
        ])
        for path in site.rglob("*"):
            if path.is_file():
                self.assertNotIn("{{", path.read_text(encoding="utf-8"), path.name)

    def test_it_is_for_the_web_and_says_hello(self) -> None:
        site = create_site.create_site(self.root, "hello", "Hello There")
        manifest = json.loads((site / "factory.json").read_text())
        self.assertEqual(manifest, {"name": "Hello There", "services": ["look", "basics", "settings", "shell", "testkit"]})
        self.assertEqual(godot.export_platforms(site), ["Web"])
        presets = (site / "export_presets.cfg").read_text()
        self.assertIn('export_path="../../build/web/hello/index.html"', presets)
        self.assertIn("variant/thread_support=false", presets)
        self.assertIn('exclude_filter="tests/*, addons/factory_*/tests/*, probe.gd, addons/factory_testkit/*"', presets)
        project = (site / "project.godot").read_text()
        self.assertIn('config/name="Hello There"', project)
        self.assertIn('renderer/rendering_method.web="gl_compatibility"', project)
        self.assertIn('"Hello, world."', (site / "hello.gd").read_text())
        self.assertIn('shows("Hello, world.")', (site / "probe.gd").read_text())
        self.assertIn('path="res://hello.gd"', (site / "main.tscn").read_text())

    def test_the_site_template_only_lays_over_the_app_template(self) -> None:
        app_files = {p.relative_to(create_app.TEMPLATE) for p in create_app.TEMPLATE.rglob("*") if p.is_file()}
        site_files = {p.relative_to(create_site.SITE_TEMPLATE) for p in create_site.SITE_TEMPLATE.rglob("*") if p.is_file()}
        self.assertTrue(site_files <= app_files, f"a site file with no app file under it: {site_files - app_files}")

    def test_bad_names_and_taken_names_are_refused(self) -> None:
        with self.assertRaises(create_app.CreateError):
            create_site.create_site(self.root, "Hello")
        create_site.create_site(self.root, "hello")
        with self.assertRaisesRegex(create_app.CreateError, "already exists"):
            create_app.create(self.root, "hello")
        with self.assertRaisesRegex(create_app.CreateError, "already exists"):
            create_site.create_site(self.root, "hello")


if __name__ == "__main__":
    unittest.main()
