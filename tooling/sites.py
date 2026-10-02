"""What the site tools share: finding sites, finding a browser, serving a folder.

A site is a folder under sites/ holding a site.json. It is a web app on
gd-chime for the web (web/gd_chime/), which install_site.py copies into
the site as sites/<name>/gd_chime/ (gitignored), so a site is served whole
from its own folder and every site wears the same framework.

A browser is needed to check a site: Chrome or Chromium, found as, in order,
--chrome on the command line, the CHROME environment variable, then
google-chrome, chromium or chromium-browser on the PATH. Headless, it
prints the page's console to its own stderr, which is how a probe's
verdict reaches the tools without any driver installed.
"""

from __future__ import annotations

import http.server
import json
import os
import shutil
import threading
from functools import partial
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAMEWORK = ROOT / "web" / "gd_chime"
SITES = ROOT / "sites"
BROWSERS = ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "chrome")


class SiteError(Exception):
    """Something the person running the tool has to fix; the message says what."""


def find_sites(root: Path, names: list[str]) -> list[Path]:
    """The named sites, or every site when none are named."""
    every = sorted(p.parent for p in (root / "sites").glob("*/site.json"))
    if not names:
        return every
    known = {p.name: p for p in every}
    missing = [n for n in names if n not in known]
    if missing:
        have = ", ".join(known) or "none"
        raise SiteError(f"no site named {', '.join(missing)} (sites with a site.json: {have})")
    return [known[n] for n in names]


def read_manifest(site: Path) -> dict:
    path = site / "site.json"
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise SiteError(f"{path} is not valid JSON: {e}") from None
    if not isinstance(manifest.get("title"), str) or not manifest["title"]:
        raise SiteError(f"{path} needs a 'title'")
    return manifest


def find_browser(given: str | None = None) -> str:
    candidate = given or os.environ.get("CHROME")
    if candidate:
        if not Path(candidate).exists():
            raise SiteError(f"no browser at {candidate}")
        return candidate
    for name in BROWSERS:
        found = shutil.which(name)
        if found:
            return found
    raise SiteError("no browser found: pass --chrome <path>, set CHROME, or put google-chrome or chromium on the PATH")


class Served:
    """A folder served over HTTP on a free port of localhost, for as long as the with-block lasts.

    A page of ES modules cannot be opened from a file: URL (the browser
    refuses the imports), so a check serves the site the way a host would.
    """

    def __init__(self, folder: Path) -> None:
        self.folder = folder
        self.url = ""
        self._server: http.server.ThreadingHTTPServer | None = None

    def __enter__(self) -> "Served":
        handler = partial(QuietHandler, directory=str(self.folder))
        self._server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        self.url = f"http://127.0.0.1:{self._server.server_address[1]}/"
        threading.Thread(target=self._server.serve_forever, daemon=True).start()
        return self

    def __exit__(self, *_: object) -> None:
        assert self._server is not None
        self._server.shutdown()
        self._server.server_close()


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json"}

    def log_message(self, *_: object) -> None:
        pass
