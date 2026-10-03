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


class Factory(unittest.TestCase):
    """A factory with two apps and a pin, beside a local upstream; no tests of its own."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)  # runs even when setUp fails further down
        base = Path(tmp.name)

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

    def pin(self, commit: str, **overrides: str) -> None:
        entry = {"repo": self.upstream.as_uri(), "commit": commit, "copy": "addons/lib", **overrides}
        write(self.root / "dependencies.json", json.dumps({"godot": {"version": "4.6.2-stable"}, "lib": entry}))

    def commit_upstream(self, relative: str, text: str) -> str:
        write(self.upstream / relative, text)
        git("add", "-A", cwd=self.upstream)
        git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "next", cwd=self.upstream)
        return git("rev-parse", "HEAD", cwd=self.upstream)



class InstallTest(Factory):
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
        with self.assertRaisesRegex(install.InstallError, "folder inside the repo"):
            install.install(self.root, [])

    def test_copy_of_the_whole_repo_is_refused(self) -> None:
        # '.' would make install_into replace the app itself
        write(self.root / "apps/alpha/alpha.gd", "my work\n")
        for whole in (".", "./"):
            self.pin(self.first, copy=whole)
            with self.subTest(copy=whole), self.assertRaisesRegex(install.InstallError, "folder inside the repo"):
                install.install(self.root, [])
        self.assertEqual((self.root / "apps/alpha/alpha.gd").read_text(), "my work\n")

    def test_moving_the_pin_drops_the_old_commit_from_the_cache(self) -> None:
        install.install(self.root, [])
        second = self.commit_upstream("addons/lib/newer.gd", "newer\n")
        self.pin(second)
        install.install(self.root, [])
        self.assertEqual([p.name for p in (self.root / ".cache/deps/lib").iterdir()], [second])

    def test_a_fetch_killed_halfway_is_cleaned_up_by_the_next(self) -> None:
        # what TemporaryDirectory could not remove: the process died inside it
        write(self.root / ".cache/deps/lib/tmpabc123/repo/.git/HEAD", "ref: refs/heads/main\n")
        install.install(self.root, [])
        self.assertEqual([p.name for p in (self.root / ".cache/deps/lib").iterdir()], [self.first])

    def test_missing_dependencies_file(self) -> None:
        (self.root / "dependencies.json").unlink()
        with self.assertRaisesRegex(install.InstallError, "is missing"):
            install.install(self.root, [])

    def test_half_finished_cache_is_fetched_again(self) -> None:
        broken = self.root / ".cache/deps/lib" / self.first / "addons/lib"
        write(broken / "partial.gd", "cut off\n")  # no completion marker
        install.install(self.root, [])
        self.assertEqual(sorted(files_under(self.root / "apps/alpha/addons/lib")), ["core.gd", "plugin.cfg"])


class ServiceTest(Factory):
    def setUp(self) -> None:
        super().setUp()
        write(self.root / "services/look/look.gd", "extends RefCounted\n")
        write(self.root / "services/look/tests/test_look.gd", "test\n")
        write(self.root / "services/look/look.gd.uid", "uid://abc\n")
        write(self.root / "apps/alpha/factory.json", json.dumps({"name": "alpha", "services": ["look"]}))

    def test_named_services_are_copied_as_factory_addons(self) -> None:
        install.install(self.root, [])
        self.assertEqual(
            files_under(self.root / "apps/alpha/addons/factory_look"),
            {"look.gd": "extends RefCounted\n", "tests/test_look.gd": "test\n"},
        )
        self.assertFalse((self.root / "apps/beta/addons/factory_look").exists(), "beta asked for no services")

    def test_a_changed_service_replaces_the_copy(self) -> None:
        install.install(self.root, [])
        write(self.root / "apps/alpha/addons/factory_look/stale.gd", "stale\n")
        write(self.root / "services/look/look.gd", "extends Node\n")
        install.install(self.root, [])
        self.assertEqual(sorted(files_under(self.root / "apps/alpha/addons/factory_look")), ["look.gd", "tests/test_look.gd"])
        self.assertEqual((self.root / "apps/alpha/addons/factory_look/look.gd").read_text(), "extends Node\n")

    def test_an_unknown_service_is_an_error_naming_the_ones_there_are(self) -> None:
        write(self.root / "apps/alpha/factory.json", json.dumps({"services": ["nope"]}))
        with self.assertRaisesRegex(install.InstallError, "service 'nope', but services/ has look"):
            install.install(self.root, [])

    def test_a_service_without_what_it_needs_is_refused(self) -> None:
        # the review's experiment: settings asked for without the look it is built on
        write(self.root / "services/settings/settings.gd", "extends RefCounted\n")
        write(self.root / "services/settings/service.json", json.dumps({"needs": ["look", "basics"]}))
        write(self.root / "services/basics/basics.gd", "extends RefCounted\n")
        write(self.root / "apps/alpha/factory.json", json.dumps({"services": ["settings", "basics"]}))
        with self.assertRaisesRegex(install.InstallError, "alpha asks for service 'settings', which needs look"):
            install.install(self.root, [])
        self.assertFalse((self.root / "apps/alpha/addons/factory_settings").exists(), "nothing is installed for a refused app")

    def test_a_service_with_what_it_needs_is_installed_without_its_manifest(self) -> None:
        write(self.root / "services/settings/settings.gd", "extends RefCounted\n")
        write(self.root / "services/settings/service.json", json.dumps({"needs": ["look"]}))
        write(self.root / "apps/alpha/factory.json", json.dumps({"services": ["look", "settings"]}))
        install.install(self.root, [])
        self.assertEqual(files_under(self.root / "apps/alpha/addons/factory_settings"), {"settings.gd": "extends RefCounted\n"})

    def test_needs_must_be_a_list(self) -> None:
        write(self.root / "services/look/service.json", json.dumps({"needs": "basics"}))
        with self.assertRaisesRegex(install.InstallError, "'needs' must be a list"):
            install.install(self.root, [])

    def test_services_must_be_a_list(self) -> None:
        write(self.root / "apps/alpha/factory.json", json.dumps({"services": "look"}))
        with self.assertRaisesRegex(install.InstallError, "must be a list"):
            install.install(self.root, [])


class RealServicesTest(unittest.TestCase):
    def test_every_service_names_what_its_code_reaches(self) -> None:
        # a service may reach another only by naming it in its service.json
        for folder in sorted((install.ROOT / "services").iterdir()):
            if folder.is_dir():
                with self.subTest(service=folder.name):
                    reached = install.service_reaches(install.ROOT, folder.name)
                    self.assertLessEqual(reached, set(install.service_needs(install.ROOT, folder.name)), f"{folder.name} reaches {sorted(reached)}")

    def test_the_look_knows_nothing_of_settings_or_the_shell(self) -> None:
        # appearance only: it is handed the text size, and opens no scene
        self.assertEqual(install.service_needs(install.ROOT, "look"), [])

    def test_every_real_app_has_what_its_services_need(self) -> None:
        for app in install.find_apps(install.ROOT, []):
            with self.subTest(app=app.name):
                install.read_services(install.ROOT, app)


class RealPinTest(unittest.TestCase):
    def test_the_committed_pin_is_well_formed(self) -> None:
        # read_pins has checked each pin's shape; this checks gd-chime is pinned as D-001 says
        pins = {p.name: p for p in install.read_pins(install.ROOT)}
        self.assertIn("gd_chime", pins)
        self.assertEqual(pins["gd_chime"].copy, "addons/gd_chime")
        self.assertTrue(pins["gd_chime"].repo.startswith("https://"), pins["gd_chime"].repo)


if __name__ == "__main__":
    unittest.main()
