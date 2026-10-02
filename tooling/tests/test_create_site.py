"""Tests for tooling/create_site.py, against the real template, into a temporary factory."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import create_app  # noqa: E402
import create_site  # noqa: E402


class CreateSiteTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "sites").mkdir()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_makes_every_file_with_everything_filled_in(self) -> None:
        site = create_site.create_site(self.root, "hello")
        made = sorted(p.relative_to(site).as_posix() for p in site.rglob("*") if p.is_file())
        self.assertEqual(made, ["index.html", "probe.js", "site.js", "site.json"])
        for path in site.rglob("*"):
            self.assertNotIn("{{", path.read_text(encoding="utf-8"), path.name)

    def test_it_says_hello_on_gd_chime_for_the_web(self) -> None:
        site = create_site.create_site(self.root, "hello", "Hello There")
        self.assertEqual(json.loads((site / "site.json").read_text()), {"title": "Hello There"})
        page = (site / "index.html").read_text()
        self.assertIn("<title>Hello There</title>", page)
        self.assertIn('<script type="module" src="site.js"></script>', page)
        script = (site / "site.js").read_text()
        self.assertIn('from "./gd_chime/gd_chime.js"', script)
        self.assertIn('Phrase.of("Hello, world.")', script)
        self.assertIn('ui.app("hello"', script)
        self.assertIn('import("./probe.js")', script, "the probe is loaded only when walked")
        self.assertIn('this.shows("Hello There")', (site / "probe.js").read_text())

    def test_bad_names_are_refused_as_an_app_s_are(self) -> None:
        for bad in ["Hello", "2go", "has-dash", "class"]:
            with self.subTest(bad=bad), self.assertRaises(create_app.CreateError):
                create_site.create_site(self.root, bad)
        self.assertEqual(list((self.root / "sites").iterdir()), [], "nothing is written for a bad name")

    def test_a_title_that_could_break_the_page_or_the_script_is_refused(self) -> None:
        for bad in ['Say "hi"', "a<b", "Tom & Jerry", "`x`", "${x}", "back\\slash"]:
            with self.subTest(bad=bad), self.assertRaisesRegex(create_app.CreateError, "title"):
                create_site.create_site(self.root, "hello", bad)

    def test_an_existing_site_is_never_overwritten(self) -> None:
        create_site.create_site(self.root, "hello")
        (self.root / "sites/hello/site.js").write_text("my work\n")
        with self.assertRaisesRegex(create_app.CreateError, "already exists"):
            create_site.create_site(self.root, "hello")
        self.assertEqual((self.root / "sites/hello/site.js").read_text(), "my work\n")


if __name__ == "__main__":
    unittest.main()
