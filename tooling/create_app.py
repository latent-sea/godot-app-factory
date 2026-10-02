"""Create a new app under apps/ that builds, passes its checks and exports an APK as it stands.

    python tooling/create_app.py shopping_list
    python tooling/create_app.py shopping_list --title "Shopping List"

The name is the app's folder, script and Android package suffix:
lower-case letters, digits and underscores, starting with a letter. The
package is com.latentsea.<name>. The title is what the phone shows; by
default it is the name in words ("shopping_list" -> "Shopping List").

It copies tooling/templates/app/, filling in the name, title and package,
and writes nothing if the folder or the package is already taken. Then:

    python tooling/install.py <name>
    python tooling/check_app.py <name>
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "tooling" / "templates" / "app"
NAME = re.compile(r"[a-z][a-z0-9_]{1,39}")
PACKAGE_PREFIX = "com.latentsea."
# Java keywords can't be a package segment.
RESERVED = {"abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const",
            "continue", "default", "do", "double", "else", "enum", "extends", "final", "finally", "float",
            "for", "goto", "if", "implements", "import", "instanceof", "int", "interface", "long", "native",
            "new", "package", "private", "protected", "public", "return", "short", "static", "strictfp",
            "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "void",
            "volatile", "while", "true", "false", "null"}


class CreateError(Exception):
    """Something the person running create_app has to fix; the message says what."""


def title_of(name: str) -> str:
    return " ".join(word.capitalize() for word in name.split("_") if word)


def check_name(name: str) -> None:
    if not NAME.fullmatch(name) or name.endswith("_") or "__" in name:
        raise CreateError(
            f"'{name}' can't be an app name: use 2-40 lower-case letters, digits and single underscores, starting with a letter"
        )
    if name in RESERVED:
        raise CreateError(f"'{name}' is a Java keyword, so it can't be part of an Android package")


def packages_in_use(root: Path) -> dict[str, str]:
    """Every app's package, to the app that has it."""
    used = {}
    for manifest in (root / "apps").glob("*/factory.json"):
        package = json.loads(manifest.read_text(encoding="utf-8")).get("package")
        if package:
            used[package] = manifest.parent.name
    return used


def create(root: Path, name: str, title: str | None = None, templates: tuple[Path, ...] = (TEMPLATE,)) -> Path:
    """Make apps/<name>/ from the templates, each filled in; a later template's file replaces an earlier one's at the same path."""
    check_name(name)
    title = (title or title_of(name)).strip()
    if not title or '"' in title or "\\" in title:
        raise CreateError("the title can't be empty or hold quotes or backslashes")
    app = root / "apps" / name
    if app.exists():
        raise CreateError(f"apps/{name} already exists")
    package = PACKAGE_PREFIX + name
    taken = packages_in_use(root)
    if package in taken:
        raise CreateError(f"the package {package} is already apps/{taken[package]}'s")

    fills = {
        "{{name}}": name,
        "{{title}}": title,
        "{{package}}": package,
        # A scene node's name: the title without spaces.
        "{{node}}": title.replace(" ", ""),
    }
    sources: dict[Path, Path] = {}
    for template in templates:
        for source in sorted(template.rglob("*")):
            if source.is_file():
                sources[source.relative_to(template)] = source
    for relative, source in sources.items():
        # The app's script is named after the app.
        if relative.as_posix() == "app.gd":
            relative = Path(f"{name}.gd")
        text = source.read_text(encoding="utf-8")
        for placeholder, value in fills.items():
            text = text.replace(placeholder, value)
        if "{{" in text:
            raise CreateError(f"template {source.relative_to(ROOT)} has a placeholder create_app doesn't fill")
        target = app / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    return app


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Create a new app under apps/.")
    parser.add_argument("name")
    parser.add_argument("--title")
    args = parser.parse_args(argv)
    try:
        app = create(ROOT, args.name, args.title)
    except CreateError as e:
        print(f"create_app: error: {e}", file=sys.stderr)
        return 1
    print(f"create_app: made {app.relative_to(ROOT).as_posix()} ({PACKAGE_PREFIX}{args.name})")
    print(f"next: python tooling/install.py {args.name} && python tooling/check_app.py {args.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
