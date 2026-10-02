#!/usr/bin/env bash
# Adds a tenant to the platform, as root: add-tenant.sh <name> <port>
#
# - A login on the machine with no admin rights, home /srv/<name>, reached by
#   the SSH keys in /srv/<name>/.ssh/authorized_keys (bin/add-ssh-key).
# - A slot for its long-lived services: systemd user services that keep
#   running when nobody is logged in, all under one ceiling on processor and
#   memory that the tenant can't raise.
# - Its database role and schema (tenants/<name>.sql), with a password made
#   here and handed over in /srv/<name>/.platform/db.env, readable by the
#   tenant only.
# - Its port on 127.0.0.1, which Caddy serves as play.<domain> (for Lizarding).
# Safe to run again.

set -euo pipefail

name=${1:?tenant name}
port=${2:?port its service listens on}
PLATFORM_DIR=/srv/platform
FACTORY="$PLATFORM_DIR/factory/platform"
home="/srv/$name"

# The tenant's ceiling: 2 of the 4 cores and 2.5 GB of the 8 GB, for all its
# processes together. The platform's containers are capped at about 4.5 GB.
CPU_QUOTA=200%
MEMORY_MAX=2560M
TASKS_MAX=1024

echo "== tenant $name"
if ! id "$name" >/dev/null 2>&1; then
  useradd --create-home --home-dir "$home" --shell /bin/bash --user-group "$name"
fi
chmod 750 "$home"
install -d -m 700 -o "$name" -g "$name" "$home/.ssh"
touch "$home/.ssh/authorized_keys"
chown "$name:$name" "$home/.ssh/authorized_keys"
chmod 600 "$home/.ssh/authorized_keys"

# Its services run without a login, restarted by systemd, under its ceiling.
loginctl enable-linger "$name"
uid=$(id -u "$name")
systemctl start "user@$uid.service"
systemctl set-property "user-$uid.slice" CPUQuota="$CPU_QUOTA" MemoryMax="$MEMORY_MAX" TasksMax="$TASKS_MAX"
install -d -o "$name" -g "$name" "$home/.config" "$home/.config/systemd" "$home/.config/systemd/user"
if [ -f "$FACTORY/tenants/$name.service.example" ]; then
  install -m 0644 -o "$name" -g "$name" "$FACTORY/tenants/$name.service.example" "$home/.config/systemd/user/$name.service.example"
fi

# What the factory hands over sits in .platform: the tenant reads it, can't change it.
install -d -m 750 -o root -g "$name" "$home/.platform"

# Its database role, once: the password goes to the tenant and to nowhere else.
cd "$PLATFORM_DIR/supabase"
exists=$(docker compose exec -T db psql -qXAt -U supabase_admin -d postgres -c "select 1 from pg_roles where rolname = '$name'")
if [ "$exists" != "1" ]; then
  password=$(openssl rand -hex 24)
  docker compose exec -T db psql -qX -v ON_ERROR_STOP=1 -v tenant_password="$password" -U supabase_admin -d postgres < "$FACTORY/tenants/$name.sql"
  umask 027
  cat > "$home/.platform/db.env" <<EOF
# $name's database: its role, from this machine only. Made by the factory; keep it secret.
DATABASE_URL=postgresql://$name:$password@127.0.0.1:5432/postgres
PGHOST=127.0.0.1
PGPORT=5432
PGDATABASE=postgres
PGUSER=$name
PGPASSWORD=$password
EOF
  chown "root:$name" "$home/.platform/db.env"
  chmod 640 "$home/.platform/db.env"
fi

# What it needs to know about the platform, no secrets.
publishable=$(grep '^SUPABASE_PUBLISHABLE_KEY=' .env | cut -d= -f2-)
domain=$(grep '^PLATFORM_DOMAIN=' .env | cut -d= -f2-)
cat > "$home/.platform/platform.env" <<EOF
# The platform, as $name sees it. Made by the factory; nothing secret.
PLATFORM_URL=https://api.$domain
# The tokens' public keys (ES256), and who issues the tokens:
JWKS_URL=https://api.$domain/auth/v1/.well-known/jwks.json
JWKS_URL_LOCAL=http://127.0.0.1:8000/auth/v1/.well-known/jwks.json
TOKEN_ISSUER=https://api.$domain/auth/v1
TOKEN_AUDIENCE=authenticated
# The key clients send as apikey (public, safe in apps):
PUBLISHABLE_KEY=$publishable
# Your service listens here; players reach it as wss://play.$domain
LISTEN=127.0.0.1:$port
EOF
chmod 644 "$home/.platform/platform.env"
echo "== tenant $name ready: login $name, folder $home, port $port"
