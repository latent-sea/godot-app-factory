"""Tests for tooling/install.py, against a local git repository standing in for gd-chime.

    python -m unittest discover -s tooling/tests
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import install  # noqa: E402


def git(*args: str, cwd: Path) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def files_under(path: Path) -> dict[str, str]:
    return {p.relative_to(path).as_posix(): p.read_text(encoding="utf-8") for p in sorted(path.rglob("*")) if p.is_file()}


class InstallTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)

        # The upstream: an addon folder beside things that must never reach an app.
        self.upstream = base / "upstream"
        write(self.upstream / "addons/lib/plugin.cfg", "[plugin]\nname=\"lib\"\n")
        write(self.upstream / "addons/lib/core.gd", "extends RefCounted\n")
        write(self.upstream / "demo/demo.gd", "demo\n")
        write(self.upstream / "tests/test.gd", "test\n")
        git("init", "-q", "-b", "main", cwd=self.upstream)
        git("add", "-A", cwd=self.upstream)
        git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "one", cwd=self.upstream)
        self.first = git("rev-parse", "HEAD", cwd=self.upstream)

        # The factory: two apps and a pin.
        self.root = base / "factory"
        for app in ("alpha", "beta"):
            write(self.root / f"apps/{app}/factory.json", json.dumps({"name": app}))
        write(self.root / "apps/not_an_app/readme.txt", "no factory.json here\n")
        self.pin(self.first)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def pin(self, commit: str, **overrides: str) -> None:
        entry = {"repo": self.upstream.as_uri(), "commit": commit, "copy": "addons/lib", **overrides}
        write(self.root / "dependencies.json", json.dumps({"godot": {"version": "4.6.2-stable"}, "lib": entry}))

    def commit_upstream(self, relative: str, text: str) -> str:
        write(self.upstream / relative, text)
        git("add", "-A", cwd=self.upstream)
        git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "next", cwd=self.upstream)
        return git("rev-parse", "HEAD", cwd=self.upstream)

    def test_copies_only_the_pinned_folder_into_every_app(self) -> None:
        apps = install.install(self.root, [])
        self.assertEqual([a.name for a in apps], ["alpha", "beta"])
        for app in ("alpha", "beta"):
            self.assertEqual(
                files_under(self.root / f"apps/{app}/addons"),
                {"lib/plugin.cfg": "[plugin]\nname=\"lib\"\n", "lib/core.gd": "extends RefCounted\n"},
            )
        self.assertFalse((self.root / "apps/not_an_app/addons").exists())

    def test_named_app_only(self) -> None:
        install.install(self.root, ["beta"])
        self.assertTrue((self.root / "apps/beta/addons/lib/core.gd").exists())
        self.assertFalse((self.root / "apps/alpha/addons").exists())

    def test_running_twice_changes_nothing(self) -> None:
        install.install(self.root, [])
        before = files_under(self.root / "apps")
        install.install(self.root, [])
        self.assertEqual(files_under(self.root / "apps"), before)

    def test_second_run_uses_the_cache_without_the_network(self) -> None:
        install.install(self.root, [])
        # Break the remote: a second run must still work from the cache.
        self.pin(self.first, repo=(self.upstream.parent / "gone").as_uri())
        install.install(self.root, [])
        self.assertTrue((self.root / "apps/alpha/addons/lib/core.gd").exists())

    def test_moving_the_pin_replaces_the_copy_and_drops_stale_files(self) -> None:
        install.install(self.root, [])
        write(self.root / "apps/alpha/addons/lib/edited_by_hand.gd", "stale\n")
        (self.upstream / "addons/lib/core.gd").unlink()
        second = self.commit_upstream("addons/lib/newer.gd", "newer\n")
        self.pin(second)
        install.install(self.root, [])
        self.assertEqual(
            sorted(files_under(self.root / "apps/alpha/addons/lib")),
            ["newer.gd", "plugin.cfg"],
        )

    def test_leaves_other_addons_alone(self) -> None:
        write(self.root / "apps/alpha/addons/own_addon/own.gd", "mine\n")
        install.install(self.root, [])
        self.assertEqual((self.root / "apps/alpha/addons/own_addon/own.gd").read_text(), "mine\n")

    def test_unknown_app_is_an_error_naming_the_apps_there_are(self) -> None:
        with self.assertRaisesRegex(install.InstallError, r"no app named gamma .*alpha, beta"):
            install.install(self.root, ["gamma"])

    def test_short_commit_is_refused(self) -> None:
        self.pin(self.first[:7])
        with self.assertRaisesRegex(install.InstallError, "full 40-character commit"):
            install.install(self.root, [])

    def test_commit_that_does_not_exist_is_an_error(self) -> None:
        self.pin("0" * 40)
        with self.assertRaisesRegex(install.InstallError, "git fetch"):
            install.install(self.root, [])
        self.assertFalse((self.root / "apps/alpha/addons").exists())

    def test_missing_folder_in_the_commit_is_an_error(self) -> None:
        self.pin(self.first, copy="addons/nope")
        with self.assertRaisesRegex(install.InstallError, "has no folder 'addons/nope'"):
            install.install(self.root, [])

    def test_copy_path_must_stay_inside(self) -> None:
        self.pin(self.first, copy="../escape")
        with self.assertRaisesRegex(install.InstallError, "path inside the repo"):
            install.install(self.root, [])

    def test_missing_dependencies_file(self) -> None:
        (self.root / "dependencies.json").unlink()
        with self.assertRaisesRegex(install.InstallError, "is missing"):
            install.install(self.root, [])

    def test_half_finished_cache_is_fetched_again(self) -> None:
        broken = self.root / ".cache/deps/lib" / self.first / "addons/lib"
        write(broken / "partial.gd", "cut off\n")  # no completion marker
        install.install(self.root, [])
        self.assertEqual(sorted(files_under(self.root / "apps/alpha/addons/lib")), ["core.gd", "plugin.cfg"])


class RealPinTest(unittest.TestCase):
    def test_the_committed_pin_is_well_formed(self) -> None:
        pins = install.read_pins(install.ROOT)
        self.assertEqual([p.name for p in pins], ["gd_chime"])
        self.assertEqual(pins[0].copy, "addons/gd_chime")


if __name__ == "__main__":
    unittest.main()
