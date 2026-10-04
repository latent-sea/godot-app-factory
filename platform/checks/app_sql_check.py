"""Holds every app's and site's tables to the platform's rules (platform/README.md, "Apps' tables").

    python3 platform/checks/app_sql_check.py [apps/<app>/backend.sql ...]

With no files, checks every apps/*/backend.sql and sites/*/backend.sql (a
site's tables follow the same rules, named for the site). Run by CI. For each
file:
- every table, view and function is the app's: public.<app>_<name>;
- tables are made with "create table if not exists", since the file runs on
  every deploy;
- every table has row-level security enabled;
- every table belongs to players (a column referencing auth.users with
  "on delete cascade", so deleting a player deletes their rows), unless its
  statement says "-- no player data";
- nothing is dropped but the app's own policies and triggers, and no role,
  schema or other app is touched.
Standard library only.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NAME = r'(?:"?public"?\.)?"?([A-Za-z_][A-Za-z0-9_]*)"?'
ON_TABLE = re.compile(rf'(?:create|drop) (?:policy|trigger)(?: if exists)? (?:"[^"]*"|\S+) on {NAME}|create (?:unique )?index(?: if not exists)?(?: \S+)? on {NAME}')


def statements(sql: str) -> list[str]:
    """The file's statements, dollar-quoted bodies kept whole."""
    out, current, quoted = [], [], False
    for line in sql.splitlines(keepends=True):
        current.append(line)
        if line.count("$$") % 2:
            quoted = not quoted
        if not quoted and re.search(r";\s*(--.*)?$", line.strip()):
            out.append("".join(current))
            current = []
    if "".join(current).strip():
        out.append("".join(current))
    return out


def check(path: Path) -> list[str]:
    app = path.parent.name
    prefix = f"{app}_"
    problems = []
    sql = path.read_text(encoding="utf-8")
    tables: dict[str, str] = {}
    secured: set[str] = set()

    for statement in statements(sql):
        code = re.sub(r"--[^\n]*", "", statement)
        flat = " ".join(code.split()).lower()
        if not flat:
            continue

        made = re.match(rf"create table (if not exists )?{NAME}", flat)
        if made:
            name = made.group(2)
            if not made.group(1):
                problems.append(f"{name}: use 'create table if not exists', as the file runs on every deploy")
            tables[name] = statement
        for kind, name in re.findall(rf"(?:create|alter|create or replace) (table|view|function|materialized view)(?: if not exists| if exists)? {NAME}", flat):
            if not name.startswith(prefix):
                problems.append(f"{kind} {name}: not {app}'s (names start {prefix})")
        for name in re.findall(rf"alter table(?: if exists)? {NAME} enable row level security", flat):
            secured.add(name)
        for policy_table, index_table in ON_TABLE.findall(flat):
            name = policy_table or index_table
            if not name.startswith(prefix):
                problems.append(f"'{flat[:60]}': {name} is not {app}'s table")
        if re.match(r"(drop|truncate) ", flat) and not re.match(r"drop (policy|trigger) if exists ", flat):
            problems.append(f"'{flat[:60]}': only policies and triggers may be dropped (with 'if exists')")
        if re.match(r"(create|alter|drop) (role|user|schema|extension|publication)", flat) or re.match(r"(alter|reassign) .* owner", flat):
            problems.append(f"'{flat[:60]}': roles, schemas, extensions and publications are the platform's")
        for schema in re.findall(r"\b(auth|storage|realtime|platform|pgmq|lizarding|extensions)\.([a-z_]+)", flat):
            if schema not in {("auth", "uid"), ("auth", "users"), ("auth", "jwt"), ("auth", "role")}:
                problems.append(f"{schema[0]}.{schema[1]}: the platform's, not {app}'s")

    for name, statement in tables.items():
        if name not in secured:
            problems.append(f"{name}: no 'alter table ... enable row level security'")
        if "-- no player data" not in statement:
            body = " ".join(statement.lower().split())
            if not re.search(r"references auth\.users\b[^,]*on delete cascade", body):
                problems.append(f"{name}: no column 'references auth.users ... on delete cascade' (or say '-- no player data')")
    return [f"{path.relative_to(ROOT)}: {problem}" for problem in problems]


def main(argv: list[str]) -> int:
    files = [Path(a).resolve() for a in argv] or sorted(ROOT.glob("apps/*/backend.sql")) + sorted(ROOT.glob("sites/*/backend.sql"))
    problems = [p for f in files for p in check(f)]
    for problem in problems:
        print("NOT TRUE:", problem)
    print(f"{len(files)} table file(s)" + ("" if problems else ": all hold the rules"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
