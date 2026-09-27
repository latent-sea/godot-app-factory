"""Install each app's dependencies from dependencies.json.

    python tooling/install.py            every app under apps/
    python tooling/install.py checklist  just the named apps

For each pinned dependency this fetches exactly that commit once into
.cache/deps/<name>/<commit>/, then replaces the app's copy of the pinned
folder (for gd-chime, apps/<app>/addons/gd_chime/) with a fresh copy of it.
Nothing else from the dependency reaches the app. Running it twice changes
nothing the second time.

An app is a folder under apps/ holding a factory.json.

Standard library only, plus git on the PATH.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMMIT = re.compile(r"[0-9a-f]{40}")
# Written last into a cached checkout, so a fetch cut off halfway is never mistaken for a whole one.
COMPLETE = ".complete"


class InstallError(Exception):
    """Something the person running install has to fix; the message says what."""


@dataclass(frozen=True)
class Pin:
    name: str
    repo: str
    commit: str
    copy: str


def read_pins(root: Path) -> list[Pin]:
    """The dependencies install copies into apps: every entry of dependencies.json with a repo."""
    path = root / "dependencies.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise InstallError(f"{path} is missing") from None
    except json.JSONDecodeError as e:
        raise InstallError(f"{path} is not valid JSON: {e}") from None

    pins = []
    for name, entry in data.items():
        if "repo" not in entry:
            continue  # not a fetched dependency (e.g. the engine version)
        for key in ("repo", "commit", "copy"):
            if not isinstance(entry.get(key), str) or not entry[key]:
                raise InstallError(f"dependencies.json: {name} needs a '{key}'")
        if not COMMIT.fullmatch(entry["commit"]):
            raise InstallError(
                f"dependencies.json: {name}.commit must be a full 40-character commit hash, got '{entry['commit']}'"
            )
        copy = Path(entry["copy"])
        if copy.is_absolute() or ".." in copy.parts:
            raise InstallError(f"dependencies.json: {name}.copy must be a path inside the repo, got '{entry['copy']}'")
        pins.append(Pin(name, entry["repo"], entry["commit"], copy.as_posix()))
    return pins


def find_apps(root: Path, names: list[str]) -> list[Path]:
    """The named apps, or every app when none are named."""
    apps_dir = root / "apps"
    every = sorted(p.parent for p in apps_dir.glob("*/factory.json"))
    if not names:
        return every
    known = {p.name: p for p in every}
    missing = [n for n in names if n not in known]
    if missing:
        have = ", ".join(known) or "none"
        raise InstallError(f"no app named {', '.join(missing)} (apps with a factory.json: {have})")
    return [known[n] for n in names]


def _git(*args: str, cwd: Path) -> str:
    try:
        done = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    except FileNotFoundError:
        raise InstallError("git is not installed or not on the PATH") from None
    if done.returncode != 0:
        raise InstallError(f"git {' '.join(args)} failed:\n{done.stderr.strip()}")
    return done.stdout.strip()


def fetch(root: Path, pin: Pin) -> Path:
    """The pinned folder of the pinned commit, fetched into the cache the first time it is asked for."""
    cached = root / ".cache" / "deps" / pin.name / pin.commit
    if (cached / COMPLETE).exists():
        return cached / pin.copy

    cached.parent.mkdir(parents=True, exist_ok=True)
    if cached.exists():
        shutil.rmtree(cached)  # a fetch that never finished
    with tempfile.TemporaryDirectory(dir=cached.parent) as tmp:
        repo = Path(tmp) / "repo"
        tree = Path(tmp) / "tree"
        repo.mkdir()
        tree.mkdir()
        _git("init", "-q", cwd=repo)
        print(f"install: fetching {pin.name} @ {pin.commit[:7]} from {pin.repo}")
        _git("fetch", "-q", "--depth", "1", pin.repo, pin.commit, cwd=repo)
        got = _git("rev-parse", "FETCH_HEAD", cwd=repo)
        if got != pin.commit:
            raise InstallError(f"{pin.name}: asked for {pin.commit}, fetched {got}")
        if not _git("ls-tree", "-d", "FETCH_HEAD", pin.copy, cwd=repo):
            raise InstallError(f"{pin.name} @ {pin.commit[:7]} has no folder '{pin.copy}'")
        _git("--work-tree", str(tree), "checkout", "FETCH_HEAD", "--", pin.copy, cwd=repo)
        (tree / COMPLETE).write_text(pin.commit + "\n", encoding="utf-8")
        tree.rename(cached)
    return cached / pin.copy


def install_into(app: Path, pin: Pin, source: Path) -> None:
    """Replace the app's copy of the pinned folder with the fetched one."""
    dest = app / pin.copy
    if dest.exists():
        shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, dest)


def install(root: Path, names: list[str]) -> list[Path]:
    pins = read_pins(root)
    apps = find_apps(root, names)
    sources = {pin: fetch(root, pin) for pin in pins}
    for app in apps:
        for pin, source in sources.items():
            install_into(app, pin, source)
        print(f"install: {app.name}: " + ", ".join(f"{p.name} @ {p.commit[:7]}" for p in pins))
    return apps


def main(argv: list[str]) -> int:
    if any(a in ("-h", "--help") for a in argv):
        print(__doc__.strip())
        return 0
    try:
        apps = install(ROOT, argv)
    except InstallError as e:
        print(f"install: error: {e}", file=sys.stderr)
        return 1
    if not apps:
        print("install: no apps found under apps/ (an app is a folder with a factory.json)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
