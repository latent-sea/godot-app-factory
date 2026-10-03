"""Export sites as the static files a host serves.

    python tooling/export_web.py            every site under sites/
    python tooling/export_web.py hello      just the named sites

Copies each site to build/web/<site>/ - the page, its scripts, its copy of
the framework - leaving out what only a check needs (probe.js, tests/,
site.json), and writes build/web/index.html naming every site, so
build/web/ is served whole: CI publishes it to GitHub Pages from main. To
look at it here:

    python3 -m http.server --directory build/web 8000

then open http://localhost:8000/<site>/. Run tooling/install_site.py
first; a site without its gd_chime/ is refused.
"""

from __future__ import annotations

import argparse
import html
import shutil
import sys
from pathlib import Path

from sites import ROOT, SiteError, find_sites, read_manifest

OUT = ROOT / "build" / "web"
## What only a check needs: a site's walk of itself and its tests never reach a host.
DEVELOPMENT = shutil.ignore_patterns("probe.js", "tests", "site.json", "__pycache__", ".DS_Store")


def export(site: Path, out: Path = OUT) -> Path:
    """The site's folder under build/web/, made afresh."""
    if not (site / "gd_chime").is_dir():
        raise SiteError(f"{site.name} has no gd_chime/: run tooling/install_site.py first")
    if not (site / "index.html").is_file():
        raise SiteError(f"{site.name} has no index.html")
    dest = out / site.name
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(site, dest, ignore=DEVELOPMENT)
    return dest


def front_page(sites: list[tuple[str, str]]) -> str:
    """One page naming every exported site, (folder, title) each, for the root of build/web/."""
    items = "\n".join(f'    <li><a href="{html.escape(folder)}/">{html.escape(title)}</a></li>' for folder, title in sites)
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


def size_of(folder: Path) -> int:
    return sum(path.stat().st_size for path in folder.rglob("*") if path.is_file())


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Export sites as static files.")
    parser.add_argument("sites", nargs="*")
    args = parser.parse_args(argv)
    try:
        sites = find_sites(ROOT, args.sites)
        for site in sites:
            dest = export(site)
            print(f"export_web: {site.name}: {dest.relative_to(ROOT).as_posix()}/ ({size_of(dest) // 1024} KB)")
        if sites:
            # every site exported so far is listed, the ones made this run and the ones made before
            every = [(p.name, read_manifest(ROOT / "sites" / p.name).get("title", p.name)) for p in sorted(OUT.iterdir())
                     if (p / "index.html").exists() and (ROOT / "sites" / p.name / "site.json").exists()]
            (OUT / "index.html").write_text(front_page(every), encoding="utf-8")
    except SiteError as e:
        print(f"export_web: error: {e}", file=sys.stderr)
        return 1
    if not sites:
        print("export_web: no sites found under sites/ (tooling/create_site.py makes one)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
