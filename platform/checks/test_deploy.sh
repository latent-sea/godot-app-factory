#!/usr/bin/env bash
# claims are strings evaluated later, naming variables set between them
# shellcheck disable=SC2016,SC2034
# bin/deploy against a stand-in machine: a local repository plays GitHub,
# and docker, curl, systemctl and sleep are stand-ins that log what they're
# asked. Run by CI; prints PASS test_deploy.sh, or every claim that failed.
#
#   bash platform/checks/test_deploy.sh
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0
claim() { if eval "$1"; then :; else echo "NOT TRUE: $2"; failed=1; fi; }

# GitHub: the factory's platform folder, committed
origin="$work/origin"
mkdir -p "$origin"
git -C "$origin" init -q -b main
cp -r "$here" "$origin/platform"
git -C "$origin" -c user.name=t -c user.email=t@t add -A
git -C "$origin" -c user.name=t -c user.email=t@t commit -q -m first
commit() { git -C "$origin" -c user.name=t -c user.email=t@t add -A && git -C "$origin" -c user.name=t -c user.email=t@t commit -q -m "$1" && git -C "$origin" rev-parse HEAD; }

# The machine, as setup.sh leaves it
srv="$work/srv"
mkdir -p "$srv/supabase/volumes/functions" "$srv/status" "$work/bin" "$work/sbin" "$work/units"
git clone -q --depth 1 "file://$origin" "$srv/factory"
echo "SUPABASE_PUBLISHABLE_KEY=sb_publishable_test" > "$srv/supabase/.env"
sed -n 's/^SUPABASE_TAG=//p' "$here/setup.sh" > "$srv/supabase/.supabase-version"

# Stand-ins. GitHub's verdict on a commit is $work/checks.json; the platform
# answers unless the commit carries platform/BROKEN.
cat > "$work/bin/docker" <<EOF
#!/usr/bin/env bash
echo "docker \$*" >> "$work/log"
case "\$*" in
  *inspect*) echo true ;;
  *exec*) cat > /dev/null ;;
esac
EOF
cat > "$work/bin/curl" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *check-runs*) cat "$work/checks.json" ;;
  *auth/v1/health*) [ ! -f "$srv/factory/platform/BROKEN" ] ;;
  *functions/v1*) if [ -f "$srv/factory/platform/BROKEN" ]; then echo 502; else echo 400; fi ;;
  *) exit 1 ;;
esac
EOF
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "%s/log"\n' "$work" > "$work/bin/systemctl"
printf '#!/usr/bin/env bash\n' > "$work/bin/sleep"
chmod +x "$work"/bin/*

checks() {  # every run's conclusion, or "running"
  local runs=()
  for c in "$@"; do
    if [ "$c" = running ]; then runs+=('{"status":"in_progress","conclusion":null}')
    else runs+=("{\"status\":\"completed\",\"conclusion\":\"$c\"}"); fi
  done
  (IFS=,; echo "{\"check_runs\":[${runs[*]}]}") > "$work/checks.json"
}
deploy() {
  : > "$work/log"
  PATH="$work/bin:$PATH" PLATFORM_DIR="$srv" CHECKS_URL=https://checks.test BIN_DIR="$work/sbin" \
    UNIT_DIR="$work/units" LOCK="$work/lock" bash "$srv/factory/platform/bin/deploy" > "$work/out" 2>&1
}
running() { git -C "$srv/factory" rev-parse HEAD; }
result() { jq -r .result "$srv/status/status.json"; }
logged() { grep -q -- "$1" "$work/log"; }

# Nothing new: nothing done
first=$(running)
checks success
deploy
claim '[ "$(running)" = "$first" ] && [ ! -s "$work/log" ]' "with nothing new, nothing is done"

# A change outside the platform's folder: taken, nothing applied
echo notes > "$origin/README.md"
outside=$(commit "outside")
deploy
claim '[ "$(running)" = "$outside" ] && [ ! -s "$work/log" ] && [ "$(result)" = deployed ]' "a change outside platform/ is taken with nothing applied"

# A function changed, its checks still running: wait
mkdir -p "$origin/platform/functions/hello-test"
echo 'export {}' > "$origin/platform/functions/hello-test/index.ts"
func=$(commit "function")
checks success running
deploy
claim '[ "$(running)" = "$outside" ]' "a commit whose checks are still running waits"

# ... then passed: copied, functions restarted, recorded
checks success skipped
deploy
claim '[ "$(running)" = "$func" ] && [ -f "$srv/supabase/volumes/functions/hello-test/index.ts" ]' "once its checks pass, the function is copied in"
claim 'logged "compose restart functions" && ! logged "restart platform-caddy" && ! logged "psql"' "only the functions are restarted"
claim '[ "$(result)" = deployed ] && [ "$(jq -r .running "$srv/status/status.json")" = "$func" ]' "the status says it was deployed"

# SQL changed, a check failed: refused, and not looked at again
echo "-- a change" >> "$origin/platform/sql/steam.sql"
sql=$(commit "sql")
checks success failure
deploy
claim '[ "$(running)" = "$func" ] && [ "$(result)" = refused ] && ! logged psql' "a commit with a failed check is refused, nothing applied"
checks success
deploy
claim '[ "$(running)" = "$func" ] && [ ! -s "$work/log" ]' "a refused commit isn't tried again, even if its checks change"

# A newer commit after a refused one: the SQL is applied
echo "-- another" >> "$origin/platform/sql/steam.sql"
sql2=$(commit "sql again")
deploy
claim '[ "$(running)" = "$sql2" ] && logged "exec -T db psql"' "a newer commit is taken and its SQL applied"

# A Caddyfile change that leaves the platform unwell: rolled back
echo "# a change" >> "$origin/platform/supabase/Caddyfile"
touch "$origin/platform/BROKEN"
broken=$(commit "breaks")
deploy || true
claim '[ "$(running)" = "$sql2" ] && [ "$(result)" = rolled-back ] && [ "$(cat "$srv/deploy-refused")" = "$broken" ]' "a commit that leaves the platform unwell is rolled back and refused"
claim '[ "$(grep -c "restart platform-caddy" "$work/log")" = 2 ]' "Caddy restarted for it, and again for the rollback"

# The scripts themselves changed: installed beside and renamed over
rm "$origin/platform/BROKEN"
echo "# touched" >> "$origin/platform/bin/deploy"
scripts=$(commit "scripts")
deploy
claim '[ "$(running)" = "$scripts" ] && grep -q "# touched" "$work/sbin/platform-deploy" && [ -x "$work/sbin/platform-apply-sql" ]' "changed scripts are installed"
claim '[ -f "$work/units/platform-deploy.timer" ] && logged "systemctl daemon-reload"' "and the timers, with systemd told"

if [ "$failed" = 0 ]; then echo "PASS test_deploy.sh"; else echo "--- last run:"; cat "$work/out"; exit 1; fi
