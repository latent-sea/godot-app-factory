"""export_web.py: what only a test needs is found in a pack, and the front page names every site."""

import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import export_web  # noqa: E402
import godot  # noqa: E402


def pck_with(names: list[str], version: int = 3) -> Path:
    """A pack as Godot writes it: the header, then a directory of each path (its length first, padded to four bytes), place, size, MD5 and flags."""
    path = Path(tempfile.mkdtemp()) / "index.pck"
    directory = struct.pack("<I", len(names))
    for name in names:
        raw = name.encode()
        padded = raw + b"\0" * (-len(raw) % 4)
        directory += struct.pack("<I", len(padded)) + padded + struct.pack("<QQ", 0, 1) + b"\0" * 16 + struct.pack("<I", 0)
    header = b"GDPC" + struct.pack("<iiiiI", version, 4, 6, 2, 0) + struct.pack("<Q", 0)
    if version >= 3:
        # a format 3 pack keeps its directory at the end and says where
        header += struct.pack("<Q", 0)
        header += b"\0" * 64
        files = b"some file's bytes, before the directory"
        header = header[:32] + struct.pack("<Q", len(header) + len(files)) + header[40:]
        path.write_bytes(header + files + directory)
    else:
        path.write_bytes(header + b"\0" * 64 + directory)
    return path


class DevelopmentFilesTest(unittest.TestCase):
    def test_a_clean_pack_carries_nothing_of_the_tests(self) -> None:
        pck = pck_with(["hello.gdc", "addons/factory_look/look.gdc", "addons/gd_chime/components/primitives/carry_walk.gdc", ".godot/global_script_class_cache.cfg"])
        self.assertEqual(export_web.development_files(pck), [])

    def test_probes_testkit_and_tests_are_found(self) -> None:
        for version in (2, 3):
            with self.subTest(version=version):
                pck = pck_with(["res://probe.gd", "res://addons/factory_testkit/walk.gdc", "res://tests/test_app.gdc", "res://addons/factory_look/tests/test_look.gdc", "res://hello.gdc"], version)
                self.assertEqual(export_web.development_files(pck), [
                    "addons/factory_look/tests/test_look.gdc",
                    "addons/factory_testkit/walk.gdc",
                    "probe.gd",
                    "tests/test_app.gdc",
                ])

    def test_a_file_that_is_not_a_pack_is_refused(self) -> None:
        other = Path(tempfile.mkdtemp()) / "index.pck"
        other.write_bytes(b"<!doctype html>")
        with self.assertRaisesRegex(godot.ToolError, "not a Godot pack"):
            export_web.development_files(other)


class FrontPageTest(unittest.TestCase):
    def test_every_site_is_a_link(self) -> None:
        page = export_web.front_page([Path("/x/build/web/hello"), Path("/x/build/web/shop")])
        self.assertIn('<a href="hello/">hello</a>', page)
        self.assertIn('<a href="shop/">shop</a>', page)
        self.assertTrue(page.startswith("<!doctype html>"))


class ExportPlatformsTest(unittest.TestCase):
    def test_the_presets_name_the_platforms(self) -> None:
        app = Path(tempfile.mkdtemp())
        self.assertEqual(godot.export_platforms(app), [])
        (app / "export_presets.cfg").write_text('[preset.0]\n\nname="Android"\nplatform="Android"\n\n[preset.1]\n\nname="Web"\nplatform="Web"\n')
        self.assertEqual(godot.export_platforms(app), ["Android", "Web"])

    def test_an_app_without_the_preset_is_skipped_or_refused_when_named(self) -> None:
        site = Path(tempfile.mkdtemp()) / "hello"
        site.mkdir()
        (site / "export_presets.cfg").write_text('[preset.0]\n\nname="Web"\nplatform="Web"\n')
        self.assertEqual(godot.exporting([site], "Web", named=True, tool="t"), [site])
        self.assertEqual(godot.exporting([site], "Android", named=False, tool="t"), [])
        with self.assertRaisesRegex(godot.ToolError, "no Android preset"):
            godot.exporting([site], "Android", named=True, tool="t")


if __name__ == "__main__":
    unittest.main()
