#!/usr/bin/env bash
# Starts setup.sh on a fresh Ubuntu 24.04 machine, for a provider with no
# box to paste cloud-init.yaml into (Netcup). Logged in as root, with your SSH
# key already able to log in:
#
#   curl -fsSL https://raw.githubusercontent.com/latent-sea/godot-app-factory/main/platform/bootstrap.sh | bash -s latent-sea.com
#
# A second domain, after the first, is where Lizarding's players connect
# (play.<it>); without one, play.<the first>. The setup carries on if you log
# out; it takes about ten minutes. Safe to run again.
set -euo pipefail
domain=${1:?give the domain of the platform, as in: bash -s latent-sea.com}
play=${2:-$domain}
name='^[a-z0-9-]+(\.[a-z0-9-]+)+$'
[[ "$domain" =~ $name && "$play" =~ $name ]] || { echo "Not a domain: $domain $play" >&2; exit 1; }
[ "$(id -u)" = 0 ] || { echo "Run this as root." >&2; exit 1; }

# The setup turns password logins off, so a key must already let you in.
if ! grep -qE '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-)' /root/.ssh/authorized_keys 2>/dev/null; then
  echo "No SSH key in /root/.ssh/authorized_keys: add yours first, or you'd be locked out." >&2
  exit 1
fi

install -d -m 700 /srv/platform
printf 'DOMAIN=%s\nPLAY_DOMAIN=%s\n' "$domain" "$play" > /srv/platform/platform.env
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q git curl
[ -d /srv/platform/factory ] || git clone -q --depth 1 https://github.com/latent-sea/godot-app-factory /srv/platform/factory

# as its own service, so logging out doesn't stop it
systemctl reset-failed platform-setup 2>/dev/null || true
systemd-run --unit=platform-setup --collect bash -c 'bash /srv/platform/factory/platform/setup.sh > /var/log/platform-setup.log 2>&1'
echo "Setting up the platform for $domain; about ten minutes."
echo "Watch it with:  tail -f /var/log/platform-setup.log"
