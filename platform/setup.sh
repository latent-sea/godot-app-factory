#!/usr/bin/env bash
# Sets up the shared platform on a fresh Ubuntu 24.04 machine, as root. Run
# once by cloud-init.yaml at first boot; safe to run again.
#
# - The machine: SSH by key only, automatic security updates and reboots,
#   Docker from Docker's own repository.
# - Supabase, self-hosted from its own docker/ folder at a pinned release, with
#   the factory's changes (supabase/platform.yml) and its own fresh secrets.
# - The platform's SQL and functions: tenants' queues, deleting a player
#   everywhere, and Steam sign-in.
# - Lizarding, the first tenant (tenants/add-tenant.sh).
# - A nightly dump of the whole database.
#
# Secrets are made here and stay on the machine, readable by root only, in
# /srv/platform/secrets and /srv/platform/supabase/.env.

set -euo pipefail
# never stop to ask: not apt, not needrestart
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a

PLATFORM_DIR=/srv/platform
FACTORY="$PLATFORM_DIR/factory/platform"
SUPABASE_TAG=self-hosted/v0.8.2
# shellcheck source=/dev/null
source "$PLATFORM_DIR/platform.env"
: "${DOMAIN:?set DOMAIN in /srv/platform/platform.env}"

say() { echo "== $*"; }

# --- the machine ------------------------------------------------------------

say "SSH by key only"
cat > /etc/ssh/sshd_config.d/10-platform.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
# Ubuntu 24.04 starts SSH on demand, so it may not be running to reload
systemctl try-reload-or-restart ssh

say "automatic security updates, rebooting at 04:30 when one needs it"
apt-get install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/52platform <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:30";
EOF

say "Docker, from Docker's repository"
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
apt-get install -y git jq openssl postgresql-client python3-venv

# --- Supabase ---------------------------------------------------------------

# The platform's folder and the backups are root's alone: no tenant can read them.
mkdir -p "$PLATFORM_DIR/secrets/tls" /srv/backups
chmod 700 "$PLATFORM_DIR" "$PLATFORM_DIR/secrets" /srv/backups

if [ ! -d "$PLATFORM_DIR/supabase" ]; then
  say "Supabase's self-host files at $SUPABASE_TAG"
  tmp=$(mktemp -d)
  git clone -q --depth 1 --filter=blob:none --sparse --branch "$SUPABASE_TAG" https://github.com/supabase/supabase "$tmp"
  git -C "$tmp" sparse-checkout set docker
  cp -r "$tmp/docker" "$PLATFORM_DIR/supabase"
  rm -rf "$tmp"
  echo "$SUPABASE_TAG" > "$PLATFORM_DIR/supabase/.supabase-version"

  say "fresh secrets and signing keys"
  cd "$PLATFORM_DIR/supabase"
  cp .env.example .env
  chmod 600 .env
  sh utils/generate-keys.sh --update-env >/dev/null
  # an EC P-256 signing key: tokens are ES256, and their public keys are published
  sh utils/add-new-auth-keys.sh --update-env >/dev/null

  set_env() { sed -i "s|^$1=.*|$1=$2|" .env; grep -q "^$1=" .env || echo "$1=$2" >> .env; }
  set_env SUPABASE_PUBLIC_URL "https://api.$DOMAIN"
  set_env API_EXTERNAL_URL "https://api.$DOMAIN"
  set_env SITE_URL "https://api.$DOMAIN"
  set_env ENABLE_ANONYMOUS_USERS true
  set_env PLATFORM_DOMAIN "$DOMAIN"
  set_env PLATFORM_DIR "$PLATFORM_DIR"
  # Supabase's file first, the factory's changes after it
  set_env COMPOSE_FILE "docker-compose.yml:$FACTORY/supabase/platform.yml"
fi

cd "$PLATFORM_DIR/supabase"
say "starting the platform"
docker compose up -d
until docker compose exec -T db pg_isready -U postgres -h localhost >/dev/null 2>&1; do sleep 2; done
until curl -fs -o /dev/null http://127.0.0.1:8000/auth/v1/health -H "apikey: $(grep '^SUPABASE_PUBLISHABLE_KEY=' .env | cut -d= -f2-)"; do sleep 2; done

say "the platform's SQL"
admin_sql() { docker compose exec -T db psql -qX -v ON_ERROR_STOP=1 -U supabase_admin -d postgres; }
admin_sql < "$FACTORY/sql/queues.sql"
admin_sql < "$FACTORY/sql/delete_player.sql"
admin_sql < "$FACTORY/sql/steam.sql"

say "the platform's functions"
# each beside Supabase's own main and hello, where the functions container finds them
cp -r "$FACTORY/functions/." "$PLATFORM_DIR/supabase/volumes/functions/"
docker compose restart functions

# --- tenants ----------------------------------------------------------------

bash "$FACTORY/tenants/add-tenant.sh" lizarding 8100

# --- backups ----------------------------------------------------------------

say "nightly database dump at 03:30"
install -m 0755 "$FACTORY/bin/backup-db" /usr/local/sbin/platform-backup-db
install -m 0644 "$FACTORY/systemd/platform-backup.service" "$FACTORY/systemd/platform-backup.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now platform-backup.timer

say "Cloudflare's public certificate for Authenticated Origin Pulls"
curl -fsSL https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem -o "$PLATFORM_DIR/secrets/tls/cloudflare-origin-pull-ca.pem"

say "done. Still to do by hand: Cloudflare's origin certificate in $PLATFORM_DIR/secrets/tls (see README)"
