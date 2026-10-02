"""Export apps as debug APKs, signed with tooling/android/debug.keystore.

    python tooling/export_android.py            every app with an Android export preset
    python tooling/export_android.py checklist  just the named apps
    options: --godot <path>

Writes build/<app>-debug.apk. Run tooling/install.py first. An app without
an Android preset in its export_presets.cfg (a site, made by create_site.py,
has a Web one) is left out, and named, it is an error. An APK that
carries anything only a test needs - a probe, the testkit, tests - is an
error: the export preset's exclude_filter should keep them out, and this
checks it did (development_files).

Needs Godot (see tooling/godot.py) with its Android export templates
installed, and:
  JAVA_HOME     a JDK, 17 or newer
  ANDROID_HOME  an Android SDK with platform-tools and build-tools

Godot reads the SDK location from its editor settings, not from the
environment. When ANDROID_HOME is set and the editor settings name a
different SDK, this rewrites that one setting and says so.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import zipfile
from pathlib import Path

import godot
from install import InstallError, find_apps

ROOT = godot.ROOT
KEYSTORE = ROOT / "tooling" / "android" / "debug.keystore"
SDK_SETTING = "export/android/android_sdk_path"
## What only a test needs, as it would sit in an APK's assets.
DEVELOPMENT = re.compile(r"^assets/(probe\.gd|addons/factory_testkit/|(.*/)?tests/)")


def development_files(apk: Path) -> list[str]:
    """Every file in the APK that only a test needs."""
    with zipfile.ZipFile(apk) as packed:
        return sorted(name for name in packed.namelist() if DEVELOPMENT.match(name))


def point_editor_at_sdk(godot_bin: str, sdk: Path, app: Path) -> None:
    """Make the editor settings name this SDK; creates the settings file on a machine that has none."""
    major_minor = ".".join(godot.pinned_version().split("-")[0].split(".")[:2])
    settings = godot.editor_settings_dir() / f"editor_settings-{major_minor}.tres"
    if not settings.exists():
        # The editor writes its settings file the first time it runs.
        godot.run(godot_bin, app, "--editor", "--quit")
    if not settings.exists():
        raise godot.ToolError(f"Godot did not create its editor settings at {settings}")
    text = settings.read_text(encoding="utf-8")
    line = f'{SDK_SETTING} = "{sdk.as_posix()}"'
    pattern = re.compile(rf"^{re.escape(SDK_SETTING)} = .*$", re.MULTILINE)
    if pattern.search(text):
        updated = pattern.sub(lambda _: line, text)
    else:
        updated = text.replace("[resource]\n", f"[resource]\n{line}\n", 1)
    if updated != text:
        settings.write_text(updated, encoding="utf-8")
        print(f"export: editor settings now name the Android SDK at {sdk}")


def export(godot_bin: str, app: Path) -> Path:
    apk = ROOT / "build" / f"{app.name}-debug.apk"
    apk.parent.mkdir(exist_ok=True)
    apk.unlink(missing_ok=True)
    godot.import_project(godot_bin, app)
    os.environ["GODOT_ANDROID_KEYSTORE_DEBUG_PATH"] = str(KEYSTORE)
    os.environ["GODOT_ANDROID_KEYSTORE_DEBUG_USER"] = "androiddebugkey"
    os.environ["GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD"] = "android"
    done = godot.run(godot_bin, app, "--export-debug", "Android", str(apk))
    if done.returncode != 0 or not apk.exists():
        raise godot.ToolError(f"{app.name}: Android export failed\n{done.stdout}{done.stderr}")
    carried = development_files(apk)
    if carried:
        raise godot.ToolError(f"{app.name}: the APK carries what only a test needs (check exclude_filter in export_presets.cfg): {', '.join(carried[:5])}")
    return apk


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Export debug APKs.")
    parser.add_argument("apps", nargs="*")
    parser.add_argument("--godot")
    args = parser.parse_args(argv)
    try:
        godot_bin = godot.find(args.godot)
        for app in godot.exporting(find_apps(ROOT, args.apps), "Android", bool(args.apps), "export"):
            if os.environ.get("ANDROID_HOME"):
                point_editor_at_sdk(godot_bin, Path(os.environ["ANDROID_HOME"]), app)
            apk = export(godot_bin, app)
            print(f"export: {app.name}: {apk.relative_to(ROOT)} ({apk.stat().st_size // 1024} KB)")
    except (godot.ToolError, InstallError) as e:
        print(f"export: error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
