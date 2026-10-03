"""Create a new site under sites/: a web app on gd-chime for the web, saying hello.

    python tooling/create_site.py hello
    python tooling/create_site.py hello --title "Hello There"

The name is the site's folder and the app's name: lower-case letters,
digits and underscores, starting with a letter, as an app's. The title is
what the page and its first screen say; by default it is the name in words.

It copies tooling/templates/site/, filling in the name and the title, and
writes nothing if the folder is already taken. Then:

    python tooling/install_site.py <name>
    python tooling/check_site.py <name>
    python tooling/export_web.py <name>
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from create_app import CreateError, check_name, title_of

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "tooling" / "templates" / "site"
## What a title may not hold: it is written into a script's string and into the page.
UNSAFE = set('"\\<>&`$')


def create_site(root: Path, name: str, title: str | None = None, template: Path = TEMPLATE) -> Path:
    check_name(name)
    title = (title or title_of(name)).strip()
    if not title or UNSAFE & set(title):
        raise CreateError("the title can't be empty or hold quotes, backslashes, backticks, dollars, <, > or &")
    site = root / "sites" / name
    if site.exists():
        raise CreateError(f"sites/{name} already exists")
    fills = {"{{name}}": name, "{{title}}": title}
    made = {}
    for source in sorted(template.rglob("*")):
        if not source.is_file():
            continue
        text = source.read_text(encoding="utf-8")
        for placeholder, value in fills.items():
            text = text.replace(placeholder, value)
        if "{{" in text:
            raise CreateError(f"template {source.relative_to(template)} has a placeholder create_site doesn't fill")
        made[site / source.relative_to(template)] = text
    for target, text in made.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    return site


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Create a new site under sites/.")
    parser.add_argument("name")
    parser.add_argument("--title")
    args = parser.parse_args(argv)
    try:
        site = create_site(ROOT, args.name, args.title)
    except CreateError as e:
        print(f"create_site: error: {e}", file=sys.stderr)
        return 1
    print(f"create_site: made {site.relative_to(ROOT).as_posix()}")
    print(f"next: python tooling/install_site.py {args.name} && python tooling/check_site.py {args.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
