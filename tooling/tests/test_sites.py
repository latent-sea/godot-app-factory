"""install_site, export_web and check_site's reading of a browser, without a browser."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import check_site  # noqa: E402
import export_web  # noqa: E402
import install_site  # noqa: E402
import sites  # noqa: E402


class SitesTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.framework = self.root / "web" / "gd_chime"
        (self.framework / "tests").mkdir(parents=True)
        (self.framework / "gd_chime.js").write_text("export const VERSION = '0';\n")
        (self.framework / "tests" / "test_floor.mjs").write_text("// a test\n")
        self.site = self.root / "sites" / "hello"
        self.site.mkdir(parents=True)
        (self.site / "site.json").write_text(json.dumps({"title": "Hello"}))
        (self.site / "index.html").write_text("<!doctype html>")
        (self.site / "site.js").write_text("// the site\n")
        (self.site / "probe.js").write_text("// the walk\n")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_sites_are_found_by_their_site_json(self) -> None:
        (self.root / "sites" / "not_a_site").mkdir()
        self.assertEqual(sites.find_sites(self.root, []), [self.site])
        with self.assertRaisesRegex(sites.SiteError, "no site named nope"):
            sites.find_sites(self.root, ["nope"])

    def test_install_copies_the_framework_without_its_tests_and_twice_is_the_same(self) -> None:
        install_site.install_into(self.site, self.framework)
        (self.site / "gd_chime" / "stale.js").write_text("left over\n")
        install_site.install_into(self.site, self.framework)
        installed = sorted(p.relative_to(self.site / "gd_chime").as_posix() for p in (self.site / "gd_chime").rglob("*"))
        self.assertEqual(installed, ["gd_chime.js"])

    def test_export_leaves_out_what_only_a_check_needs(self) -> None:
        install_site.install_into(self.site, self.framework)
        out = self.root / "build" / "web"
        made = export_web.export(self.site, out)
        exported = sorted(p.relative_to(made).as_posix() for p in made.rglob("*") if p.is_file())
        self.assertEqual(exported, ["gd_chime/gd_chime.js", "index.html", "site.js"])

    def test_export_refuses_a_site_not_installed(self) -> None:
        with self.assertRaisesRegex(sites.SiteError, "install_site"):
            export_web.export(self.site, self.root / "build" / "web")

    def test_the_front_page_names_every_site(self) -> None:
        page = export_web.front_page([("hello", "Hello"), ("shop", "The <Shop>")])
        self.assertIn('<a href="hello/">Hello</a>', page)
        self.assertIn('<a href="shop/">The &lt;Shop&gt;</a>', page)

    def test_a_folder_is_served_while_the_with_block_lasts(self) -> None:
        with sites.Served(self.site) as served:
            with urllib.request.urlopen(served.url + "site.js") as answer:
                self.assertEqual(answer.read().decode(), "// the site\n")
                self.assertIn("javascript", answer.headers["Content-Type"])


class ReadingTheBrowserTest(unittest.TestCase):
    STDERR = (
        '[1:1:1002/1.1:INFO:CONSOLE:2] "NOT TRUE: one wave is counted", source: http://127.0.0.1:1/gd_chime/walk.js (100)\n'
        '[1:1:1002/1.1:INFO:CONSOLE:101] "PROBE FAILED", source: http://127.0.0.1:1/gd_chime/walk.js (101)\n'
        '[1:1:1002/1.1:ERROR:gpu_init.cc(1)] something of the browser\'s own\n'
    )

    def test_each_console_message_is_read_apart(self) -> None:
        self.assertEqual(check_site.console_lines(self.STDERR), ["NOT TRUE: one wave is counted", "PROBE FAILED"])

    def test_a_run_passes_only_when_it_exited_0_said_its_line_and_reported_no_trouble(self) -> None:
        self.assertIsNone(check_site.verdict("hello", 0, ["PROBE OK"], "PROBE OK"))
        self.assertIn("never printed", check_site.verdict("hello", 0, ["PROBE FAILED"], "PROBE OK"))
        self.assertIn("exited 1", check_site.verdict("hello", 1, ["PROBE OK"], "PROBE OK"))
        self.assertIn("trouble", check_site.verdict("hello", 0, ["Uncaught TypeError: x is undefined", "PROBE OK"], "PROBE OK"))


if __name__ == "__main__":
    unittest.main()
