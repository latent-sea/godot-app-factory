"""Give each site its copy of gd-chime for the web.

    python tooling/install_site.py            every site under sites/
    python tooling/install_site.py hello      just the named sites

Replaces sites/<site>/gd_chime/ with a fresh copy of web/gd_chime/ - the
framework without its tests - so a site is served whole from its own folder
and a fix to the framework reaches every site on its next install. Each
service the site's site.json names ("services": ["backend"]) is copied the
same way, from web/<service>/ to sites/<site>/<service>/; one it no longer
names is taken out. The copies are gitignored; web/ is the only source.
Running it twice changes nothing the second time.

A site is a folder under sites/ holding a site.json.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from sites import FRAMEWORK, ROOT, SERVICES, SiteError, find_sites, read_manifest


def install_into(site: Path, framework: Path = FRAMEWORK) -> Path:
    """Replace the site's copy of the framework with a fresh one; the framework's tests stay behind."""
    dest = site / "gd_chime"
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(framework, dest, ignore=shutil.ignore_patterns("tests", "__pycache__"))
    return dest


def install_services(site: Path, web: Path) -> list[str]:
    """Copy in each service the site names, without its tests; take out any it no longer names."""
    named = read_manifest(site).get("services", [])
    for service in SERVICES:
        dest = site / service
        if dest.exists():
            shutil.rmtree(dest)
        if service in named:
            shutil.copytree(web / service, dest, ignore=shutil.ignore_patterns("tests", "__pycache__"))
    return named


def install(root: Path, names: list[str]) -> list[Path]:
    sites = find_sites(root, names)
    for site in sites:
        install_into(site, root / "web" / "gd_chime")
        services = install_services(site, root / "web")
        print(f"install_site: {site.name}: {', '.join(['gd_chime', *services])}")
    return sites


def main(argv: list[str]) -> int:
    if any(a in ("-h", "--help") for a in argv):
        print(__doc__.strip())
        return 0
    try:
        sites = install(ROOT, argv)
    except SiteError as e:
        print(f"install_site: error: {e}", file=sys.stderr)
        return 1
    if not sites:
        print("install_site: no sites found under sites/ (a site is a folder with a site.json)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
