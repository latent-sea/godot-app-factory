"""Export sites - apps with a Web export preset - as the pages a browser opens.

    python tooling/export_web.py            every app with a Web export preset
    python tooling/export_web.py hello      just the named apps
    options: --godot <path>

Writes build/web/<app>/index.html with the engine, the script and the
packed project beside it, and build/web/index.html naming every site, so
build/web/ is served whole: CI publishes it to GitHub Pages, and here

    python3 -m http.server --directory build/web 8000

serves it at http://localhost:8000/<app>/. The preset exports without
threads (variant/thread_support), so any static host serves a site and
no cross-origin isolation headers are needed. Run tooling/install.py
first. A site that carries anything only a test needs - a probe, the
testkit, tests - is an error: the preset's exclude_filter should keep
them out of the pack, and this checks it did (development_files).

Needs Godot (see tooling/godot.py) with its Web export templates installed.
"""

from __future__ import annotations

import argparse
import html
import re
import shutil
import struct
import sys
from pathlib import Path

import godot
from install import InstallError, find_apps

ROOT = godot.ROOT
OUT = ROOT / "build" / "web"
## What only a test needs, as the pack names it.
DEVELOPMENT = re.compile(r"^(probe\.gd|addons/factory_testkit/|(.*/)?tests/)")


def packed_files(pck: Path) -> list[str]:
    """Every file a pack (.pck) holds, by its path in the project, from the pack's own directory.

    The pack begins "GDPC", its format version, the engine's version and
    flags, then where the files begin. Format 2 (Godot 4.0 to 4.4) puts the
    directory right after the header; format 3 (4.5 on) says where it is.
    Either way the directory is a count, then for each file its path (its
    length first, padded to four bytes), offset, size, MD5 and flags.
    """
    data = pck.read_bytes()
    if data[:4] != b"GDPC":
        raise godot.ToolError(f"{pck} is not a Godot pack")
    version, = struct.unpack_from("<i", data, 4)
    at = 4 + 4 * 4 + 4  # magic, format, major, minor, patch, flags
    at += 8  # where the files begin
    if version >= 3:
        at, = struct.unpack_from("<Q", data, at)
    else:
        at += 16 * 4  # reserved
    count, = struct.unpack_from("<I", data, at)
    at += 4
    names = []
    for _ in range(count):
        length, = struct.unpack_from("<I", data, at)
        at += 4
        name = data[at:at + length].rstrip(b"\0").decode("utf-8")
        at += length + 8 + 8 + 16 + 4  # offset, size, md5, flags
        names.append(name.removeprefix("res://"))
    return names


def development_files(pck: Path) -> list[str]:
    """Every file in the pack that only a test needs."""
    return sorted(name for name in packed_files(pck) if DEVELOPMENT.match(name))


def export(godot_bin: str, app: Path) -> Path:
    """The site's folder, made afresh: build/web/<app>/."""
    site = OUT / app.name
    if site.exists():
        shutil.rmtree(site)
    site.mkdir(parents=True)
    godot.import_project(godot_bin, app)
    page = site / "index.html"
    done = godot.run(godot_bin, app, "--export-release", "Web", str(page))
    if done.returncode != 0 or not page.exists():
        raise godot.ToolError(f"{app.name}: Web export failed\n{done.stdout}{done.stderr}")
    carried = development_files(site / "index.pck")
    if carried:
        raise godot.ToolError(f"{app.name}: the site carries what only a test needs (check exclude_filter in export_presets.cfg): {', '.join(carried[:5])}")
    return site


def front_page(sites: list[Path]) -> str:
    """One page naming every exported site, for the root of build/web/."""
    items = "\n".join(f'    <li><a href="{html.escape(site.name)}/">{html.escape(site.name)}</a></li>' for site in sites)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sites</title>
<style>
  body {{ margin: 0; min-height: 100vh; display: grid; place-items: center; background: #121829; color: #e8ecf8; font: 20px/1.5 system-ui, sans-serif; }}
  a {{ color: #19c3b3; }}
  ul {{ list-style: none; padding: 0; }}
</style>
</head>
<body>
<main>
  <h1>Sites</h1>
  <ul>
{items}
  </ul>
</main>
</body>
</html>
"""


def size_of(site: Path) -> int:
    return sum(path.stat().st_size for path in site.rglob("*") if path.is_file())


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Export sites for the web.")
    parser.add_argument("apps", nargs="*")
    parser.add_argument("--godot")
    args = parser.parse_args(argv)
    try:
        godot_bin = godot.find(args.godot)
        sites = []
        for app in godot.exporting(find_apps(ROOT, args.apps), "Web", bool(args.apps), "export_web"):
            site = export(godot_bin, app)
            sites.append(site)
            print(f"export_web: {app.name}: {site.relative_to(ROOT).as_posix()}/ ({size_of(site) // 1024} KB)")
        if sites:
            # Every site exported so far is listed, the ones made this run and the ones made before.
            every = sorted(p for p in OUT.iterdir() if (p / "index.html").exists())
            (OUT / "index.html").write_text(front_page(every), encoding="utf-8")
    except (godot.ToolError, InstallError) as e:
        print(f"export_web: error: {e}", file=sys.stderr)
        return 1
    if not sites:
        print("export_web: no app has a Web preset (tooling/create_site.py makes one)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
