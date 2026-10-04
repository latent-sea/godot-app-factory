#!/usr/bin/env bash
# The platform's own table and every app's and site's (apps/<app>/backend.sql,
# sites/<site>/backend.sql) in a real, throwaway PostgreSQL with a stand-in
# for Supabase (supabase_stub.sql): each loads, loads again (every deploy runs
# them all), and keeps one player's rows from another. Run by CI; prints PASS
# test_sql.sh, or what failed.
#
#   bash platform/checks/test_sql.sh
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
bin=$(find /usr/lib/postgresql -mindepth 2 -maxdepth 2 -name bin 2>/dev/null | sort -V | tail -1)
[ -n "$bin" ] || { echo "no PostgreSQL found" >&2; exit 1; }
work=$(mktemp -d)
# PostgreSQL won't run as root
as_pg() { if [ "$(id -u)" = 0 ]; then runuser -u postgres -- "$@"; else "$@"; fi; }
[ "$(id -u)" = 0 ] && chown postgres "$work"
trap 'as_pg "$bin/pg_ctl" -D "$work/db" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$work"' EXIT

as_pg "$bin/initdb" -D "$work/db" -U supabase_admin -A trust >/dev/null
as_pg "$bin/pg_ctl" -D "$work/db" -o "-k $work -c listen_addresses='' -c wal_level=logical" -l "$work/log" -w start >/dev/null
sql() { PGOPTIONS='-c client_min_messages=warning' as_pg psql -h "$work" -U supabase_admin -d postgres -qXtA -v ON_ERROR_STOP=1 "$@"; }

sql < "$repo/platform/checks/supabase_stub.sql"
files=("$repo/platform/sql/checks.sql")
for app in "$repo"/apps/*/backend.sql "$repo"/sites/*/backend.sql; do [ -f "$app" ] && files+=("$app"); done
for round in first second; do
  for file in "${files[@]}"; do
    sql -1 < "$file" || { echo "NOT TRUE: ${file#"$repo"/} loads a $round time"; exit 1; }
  done
done

failed=0
claim() { if [ "$1" = "$2" ]; then :; else echo "NOT TRUE: $3 (got '$1')"; failed=1; fi; }
a=11111111-1111-1111-1111-111111111111
b=22222222-2222-2222-2222-222222222222
sql -c "insert into auth.users values ('$a'), ('$b')"
as() {  # player, statement
  sql -c "begin; set local role authenticated; set local request.jwt.claim.sub = '$1'; $2; commit;" 2>&1 | grep -v '^\(BEGIN\|SET\|COMMIT\)$' || true
}
as "$a" "insert into public.platform_check (body) values ('mine')" >/dev/null
claim "$(as "$a" "select count(*) from public.platform_check")" 1 "a player reads their own row"
claim "$(as "$b" "select count(*) from public.platform_check")" 0 "another player can't see it"
claim "$(as "$b" "insert into public.platform_check (owner, body) values ('$a', 'forged')" | grep -c 'row-level security')" 1 "nor write a row as them"
claim "$(sql -c "select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'platform_check'")" 1 "the table is published live"
sql -c "delete from auth.users where id = '$a'"
claim "$(sql -c "select count(*) from public.platform_check")" 0 "deleting the player deletes their rows"

[ "$failed" = 0 ] && echo "PASS test_sql.sh (${#files[@]} file(s))"
exit "$failed"
