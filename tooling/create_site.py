"""Create a new site under apps/: an app for the web, saying "Hello, world." as it stands.

    python tooling/create_site.py hello
    python tooling/create_site.py hello --title "Hello"

A site is an app (apps/<name>/ with a factory.json, the same services, the
same tests and probe) whose export preset is for the Web rather than
Android, so install.py and check_app.py take it as any app, and
export_web.py makes the pages a browser opens. It is tooling/templates/app/
with tooling/templates/site/ laid over it, filled in by create_app's
create(). The name is the site's folder and script, as an app's; it has no
Android package. Then:

    python tooling/install.py <name>
    python tooling/check_app.py <name>
    python tooling/export_web.py <name>
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from create_app import ROOT, TEMPLATE, CreateError, create

SITE_TEMPLATE = ROOT / "tooling" / "templates" / "site"


def create_site(root: Path, name: str, title: str | None = None) -> Path:
    return create(root, name, title, templates=(TEMPLATE, SITE_TEMPLATE))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Create a new site under apps/.")
    parser.add_argument("name")
    parser.add_argument("--title")
    args = parser.parse_args(argv)
    try:
        site = create_site(ROOT, args.name, args.title)
    except CreateError as e:
        print(f"create_site: error: {e}", file=sys.stderr)
        return 1
    print(f"create_site: made {site.relative_to(ROOT).as_posix()}")
    print(f"next: python tooling/install.py {args.name} && python tooling/check_app.py {args.name} && python tooling/export_web.py {args.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
