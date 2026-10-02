"""Finding and running the pinned Godot, shared by the factory's tools.

Godot is found as, in order: --godot on the command line, the GODOT
environment variable, then `godot` on the PATH. Whichever it is, its
version must be the one dependencies.json pins.
"""

from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class ToolError(Exception):
    """Something the person running the tool has to fix; the message says what."""


def pinned_version(root: Path = ROOT) -> str:
    """The pinned engine version, as a release tag: '4.6.2-stable'."""
    return json.loads((root / "dependencies.json").read_text(encoding="utf-8"))["godot"]["version"]


def find(given: str | None = None, root: Path = ROOT) -> str:
    """The Godot executable to run, checked against the pinned version."""
    candidate = given or os.environ.get("GODOT") or shutil.which("godot")
    if not candidate:
        raise ToolError("Godot not found: pass --godot <path>, set GODOT, or put godot on the PATH")
    try:
        done = subprocess.run([candidate, "--headless", "--version"], capture_output=True, text=True, timeout=120)
    except (FileNotFoundError, PermissionError):
        raise ToolError(f"cannot run Godot at {candidate}") from None
    # '4.6.2.stable.official.71f334935' against the tag '4.6.2-stable'
    have = done.stdout.strip().splitlines()[-1] if done.stdout.strip() else ""
    want = pinned_version(root).replace("-", ".")
    if not have.startswith(want + "."):
        raise ToolError(f"Godot at {candidate} is {have or 'unknown'}, but dependencies.json pins {want}")
    return candidate


def run(godot: str, app: Path, *args: str, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    """Run Godot headless on an app's project, output captured. A run past its timeout exits -1."""
    command = [godot, "--headless", "--path", str(app), *args]
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        err = e.stderr.decode(errors="replace") if isinstance(e.stderr, bytes) else (e.stderr or "")
        return subprocess.CompletedProcess(command, -1, out, err + f"\nstill running after {timeout}s; stopped\n")


def import_project(godot: str, app: Path) -> None:
    """Godot's import pass: registers global class names (ChimeApp, GdChime) and imports assets."""
    done = run(godot, app, "--import")
    if done.returncode != 0:
        raise ToolError(f"{app.name}: import failed\n{done.stdout}{done.stderr}")


def editor_settings_dir() -> Path:
    """Where the Godot editor keeps its settings on this machine."""
    system = platform.system()
    if system == "Windows":
        return Path(os.environ["APPDATA"]) / "Godot"
    if system == "Darwin":
        return Path.home() / "Library" / "Application Support" / "Godot"
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "godot"
