"""Check sites: run the framework's tests, then walk each site in a browser.

    python tooling/check_site.py            every site under sites/
    python tooling/check_site.py hello      just the named sites
    options: --chrome <path>  --node <path>

Run tooling/install_site.py first.

The framework's tests (web/gd_chime/tests/test_*.mjs) and the services'
(web/<service>/tests/test_*.mjs) run under Node's own test runner and must
all pass, and its own page (tests/ui/), which uses
every primitive, walks itself in the browser. Then each site is served from its folder
and opened headless in Chrome at index.html?probe, which makes the site
walk itself (its probe.js) instead of waiting for a reader: it prints
PROBE OK to the console, or every claim that did not hold. The browser
prints the page's console to its stderr, which is read here.

A run counts as passing only when three things agree: the process exited
0, the page printed its pass line, and nothing in the output looks like an
error. Any one of them can be true while the check did not really run.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

from sites import FRAMEWORK, ROOT, SERVICES, Served, SiteError, find_browser, find_sites

## A console message as Chrome prints it to its stderr, at any level: the message in quotes, then where it came from.
CONSOLE = re.compile(r':CONSOLE[^\]]*\] "(.*?)", source: ', re.DOTALL)
## Output that means something went wrong even when the process exited 0.
TROUBLE = re.compile(r"^(Uncaught|NOT TRUE|FAIL|Error|TypeError|ReferenceError|SyntaxError)\b|Failed to load", re.MULTILINE)
## How long of the page's own time a probe may take, in milliseconds: the browser runs it through at once.
BUDGET = 20000


def console_lines(stderr: str) -> list[str]:
    """What the page said, line by line, out of everything the browser printed."""
    lines = []
    for message in CONSOLE.findall(stderr):
        lines.extend(message.split("\\n"))
    return lines


def verdict(name: str, returncode: int, said: list[str], pass_line: str) -> str | None:
    """Why this run does not count as passing, or None when it does."""
    reasons = []
    if returncode != 0:
        reasons.append(f"exited {returncode}")
    if pass_line not in said:
        reasons.append(f"never printed '{pass_line}'")
    if TROUBLE.search("\n".join(said)):
        reasons.append("its output reports trouble")
    if not reasons:
        return None
    return f"{name}: " + ", ".join(reasons) + "\n" + "".join(f"    | {line}\n" for line in said[-60:])


def framework_tests(node: str, folder: Path = FRAMEWORK) -> str | None:
    """Why the tests of the framework (or of a service, under web/) failed, or None when they passed."""
    name = folder.relative_to(ROOT).as_posix()
    tests = sorted((folder / "tests").glob("test_*.mjs"))
    if not tests:
        return f"{name}/tests has no test_*.mjs"
    done = subprocess.run([node, "--test", *map(str, tests)], capture_output=True, text=True, timeout=300)
    print(f"  {'ok  ' if done.returncode == 0 else 'FAIL'} {name}/tests ({len(tests)} files)")
    if done.returncode == 0:
        return None
    return f"{name} tests:\n" + "".join(f"    | {line}\n" for line in (done.stdout + done.stderr).strip().splitlines()[-80:])


def probe(browser: str, folder: Path, page: str = "index.html", name: str = "") -> str | None:
    """Why the page's walk of itself failed, or None when it printed PROBE OK."""
    name = name or folder.name
    with Served(folder) as served:
        command = [browser, "--headless=new", "--no-sandbox", "--disable-gpu", "--enable-logging=stderr", "--v=0",
                   f"--virtual-time-budget={BUDGET}", "--dump-dom", served.url + page + "?probe"]
        try:
            done = subprocess.run(command, capture_output=True, text=True, timeout=120)
        except subprocess.TimeoutExpired:
            return f"{name} probe: still running after 120s; stopped"
    said = console_lines(done.stderr)
    problem = verdict(f"{name} probe", done.returncode, said, "PROBE OK")
    print(f"  {'ok  ' if problem is None else 'FAIL'} probe{'' if page == 'index.html' else f' {name}/{page}'}")
    return problem


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Test the framework and probe sites.")
    parser.add_argument("sites", nargs="*")
    parser.add_argument("--chrome")
    parser.add_argument("--node")
    args = parser.parse_args(argv)
    failures = []
    try:
        node = args.node or shutil.which("node")
        if not node:
            raise SiteError("node not found: pass --node <path> or put node on the PATH")
        browser = find_browser(args.chrome)
        sites = find_sites(ROOT, args.sites)
        print("check: web/gd_chime")
        for folder in [FRAMEWORK, *(ROOT / "web" / s for s in SERVICES)]:
            problem = framework_tests(node, folder)
            if problem:
                failures.append(problem)
        # every primitive, in the framework's own page, walked in the browser; each service's page too
        for folder in [FRAMEWORK, *(ROOT / "web" / s for s in SERVICES)]:
            if (folder / "tests" / "ui" / "index.html").is_file():
                problem = probe(browser, folder, "tests/ui/index.html", folder.relative_to(ROOT).as_posix())
                if problem:
                    failures.append(problem)
        for site in sites:
            print(f"check: {site.name}")
            if not (site / "gd_chime").is_dir():
                raise SiteError(f"{site.name} has no gd_chime/: run tooling/install_site.py first")
            problem = probe(browser, site)
            if problem:
                failures.append(problem)
    except SiteError as e:
        print(f"check: error: {e}", file=sys.stderr)
        return 1
    for failure in failures:
        print(f"\nFAILED {failure}", file=sys.stderr)
    if not sites:
        print("check: no sites found under sites/")
        return 1
    print(f"check: {len(sites)} site(s), {'all passed' if not failures else f'{len(failures)} failure(s)'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
