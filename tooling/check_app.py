"""Check apps: import each project, run its tests, and run its probe.

    python tooling/check_app.py            every app under apps/
    python tooling/check_app.py checklist  just the named apps
    options: --godot <path>

Run tooling/install.py first.

A test is a script apps/<app>/tests/test_*.gd that extends SceneTree. It
prints "PASS <its file name>" once every claim held, and quits 0. The tests
of each factory service the app uses (addons/factory_*/tests/) run too, in
the app, so a service is checked in every app that wears it. The probe
is gd-chime's own walk of the app's screens, run as `-- --probe` on the main
scene, which prints "PROBE OK".

A run counts as passing only when three things agree: the process exited 0,
it printed its pass line, and nothing in its output looks like an error. Any
one of them can be true while the check did not really run.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import godot
from install import InstallError, find_apps

ROOT = godot.ROOT
# Output that means something went wrong even when the process exits 0.
TROUBLE = re.compile(r"^(SCRIPT ERROR|ERROR|Parse Error|NOT TRUE|FAIL)\b|^\s+at: ", re.MULTILINE)


def verdict(name: str, done, pass_line: str) -> str | None:
    """Why this run does not count as passing, or None when it does."""
    output = done.stdout + done.stderr
    reasons = []
    if done.returncode != 0:
        reasons.append(f"exited {done.returncode}")
    if pass_line not in done.stdout.splitlines():
        reasons.append(f"never printed '{pass_line}'")
    trouble = TROUBLE.search(output)
    if trouble:
        reasons.append("its output reports trouble")
    if not reasons:
        return None
    return f"{name}: " + ", ".join(reasons) + "\n" + _indent(output)


def _indent(text: str) -> str:
    return "".join(f"    | {line}\n" for line in text.strip().splitlines()[-60:])


def check(godot_bin: str, app: Path) -> list[str]:
    """Every failure in this app, each with its output."""
    godot.import_project(godot_bin, app)
    failures = []
    tests = sorted((app / "tests").glob("test_*.gd"))
    service_tests = sorted((app / "addons").glob("factory_*/tests/test_*.gd"))
    for test in tests + service_tests:
        where = test.relative_to(app).as_posix()
        done = godot.run(godot_bin, app, "--script", f"res://{where}", timeout=120)
        problem = verdict(f"{app.name}/{where}", done, f"PASS {test.name}")
        print(f"  {'ok  ' if problem is None else 'FAIL'} {where}")
        if problem:
            failures.append(problem)
    done = godot.run(godot_bin, app, "--", "--probe", timeout=120)
    problem = verdict(f"{app.name} probe", done, "PROBE OK")
    print(f"  {'ok  ' if problem is None else 'FAIL'} probe")
    if problem:
        failures.append(problem)
    if not tests:
        failures.append(f"{app.name}: has no tests/test_*.gd")
    return failures


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Import, test and probe apps.")
    parser.add_argument("apps", nargs="*")
    parser.add_argument("--godot")
    args = parser.parse_args(argv)
    try:
        godot_bin = godot.find(args.godot)
        apps = find_apps(ROOT, args.apps)
        failures = []
        for app in apps:
            print(f"check: {app.name}")
            failures += check(godot_bin, app)
    except (godot.ToolError, InstallError) as e:
        print(f"check: error: {e}", file=sys.stderr)
        return 1
    for failure in failures:
        print(f"\nFAILED {failure}", file=sys.stderr)
    if not apps:
        print("check: no apps found under apps/")
        return 1
    print(f"check: {len(apps)} app(s), {'all passed' if not failures else f'{len(failures)} failure(s)'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
