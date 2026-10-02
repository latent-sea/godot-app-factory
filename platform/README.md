# The shared platform

One Hetzner machine runs the shared backend: self-hosted Supabase for the
factory's apps, and Lizarding's game server as a tenant beside it. The factory
owns the machine and the platform; Lizarding owns its own parts. Decided in
[D-011](../docs/decisions/D-011-one-machine-lizarding-a-tenant.md).

| Who | Owns |
| --- | --- |
| Factory | The machine (system, updates, firewall, logins), Cloudflare, DNS and certificates, Supabase and Postgres, sign-in and the token's keys, backups, and the limits on each tenant |
| Lizarding | Its game server (build, deploy, logs, restarts), everything in the `lizarding` schema, its files under `/srv/lizarding`, checking tokens and seating players, its load testing, and its part of deleting a player |

Neither side edits the other's part.

## What's here

| | |
| --- | --- |
| `cloud-init.yaml` | Pasted into Hetzner when ordering the machine; runs `setup.sh` at first boot |
| `setup.sh` | Sets up the machine, Supabase, the platform's SQL, Lizarding, and backups |
| `supabase/platform.yml` | The factory's changes to Supabase's own compose file: only Caddy reachable from outside, memory ceilings, Postgres sized for 8 GB |
| `supabase/Caddyfile` | The one open door, on 443: `api.<domain>` and `play.<domain>`, answering only Cloudflare |
| `sql/queues.sql` | Tenants create and drop their own queues (Supabase Queues) through the platform |
| `sql/delete_player.sql` | Deleting a player everywhere: each tenant's `forget_player`, then the sign-in |
| `tenants/add-tenant.sh` | A tenant's login, folder, service slot and its ceiling, database role, and handover files |
| `tenants/lizarding.sql` | Lizarding's role and schema |
| `tenants/lizarding.service.example` | An example of Lizarding's service, for Lizarding to adapt |
| `bin/add-ssh-key` | Lets a tenant's key log in |
| `bin/backup-db` | The nightly dump of the whole database |
| `checks/lizarding_walls.sql` | Run as Lizarding to see its walls hold |

## Ordering the machine

On Hetzner Cloud, create a server with:

- **Location:** Nuremberg or Falkenstein (Germany).
- **Image:** Ubuntu 24.04.
- **Type:** Shared vCPU, **x86** (AMD or Intel, not Arm), 4 vCPU and 8 GB.
  Lizarding's program is built for x86-64, so an Arm machine can't run it.
- **Networking:** public IPv4 and IPv6.
- **SSH key:** your own public key. Root logs in with it; passwords are off.
- **Firewall:** a new one allowing inbound TCP 22 (SSH) and TCP 443 only.
- **Backups:** on. Hetzner keeps 7 daily copies of the whole disk off the machine.
- **Cloud config:** all of `cloud-init.yaml`, with `DOMAIN=` set to your domain.

Setup takes about ten minutes after the server starts. Its log is at
`/var/log/platform-setup.log`.

## By hand, after ordering

1. **DNS:** in Cloudflare, add `api` and `play` as A records (and AAAA for
   IPv6) pointing at the server, proxied (orange cloud).
2. **Encryption:** under SSL/TLS, set the mode to **Full (strict)** and turn on
   **Authenticated Origin Pulls**.
3. **Origin certificate:** under SSL/TLS, Origin Server, create one for
   `*.<domain>` and `<domain>`. Save it on the server as
   `/srv/platform/secrets/tls/origin.pem` and its key as `origin.key`, then
   run `docker restart platform-caddy`.
4. **Lizarding's key:** `/srv/platform/factory/platform/bin/add-ssh-key lizarding "<their public key>"`.

## Running it

- **The dashboard:** `ssh -L 8000:127.0.0.1:8000 root@<server>`, then open
  http://localhost:8000. Its user and password are `DASHBOARD_USERNAME` and
  `DASHBOARD_PASSWORD` in `/srv/platform/supabase/.env`.
- **Logs:** `cd /srv/platform/supabase && docker compose logs -f <service>`.
- **Updating Supabase:** change `SUPABASE_TAG` in `setup.sh` after reading
  Supabase's changelog. Copy the new release's `docker/` files over
  `/srv/platform/supabase`, keeping `.env` and `volumes/db/data`. Then run
  `docker compose pull && docker compose up -d`. Take a dump first.
- **Restoring:** on a fresh machine set up the same way, stop everything but
  the database, then run
  `gunzip -c db-<date>.sql.gz | docker compose exec -T db psql -U supabase_admin -d postgres`,
  copy back `/srv/lizarding` and `.env`, and start again. Hetzner's backups
  restore the whole disk in one step instead.

## For Lizarding

- **Log in:** `ssh lizarding@<server>`. Your folder is `/srv/lizarding`.
- **Handover files:** in `~/.platform`:
  - `db.env`: your database role, password and address. Secret.
  - `platform.env`: the platform's address, the tokens' public keys and issuer, and your port.
- **Your service:** a systemd user service.
  `~/.config/systemd/user/lizarding.service.example` shows the shape.
  - It keeps running after you log out.
  - It restarts if it stops.
  - It shares one ceiling with all your processes: 2 cores and 2.5 GB.
- **Players connect:** to `wss://play.<domain>` through Cloudflare. Your
  service listens on `127.0.0.1:8100`.
- **The database:** connect directly to `127.0.0.1:5432` as `lizarding`.
  - You may hold up to 20 connections.
  - Each statement is limited to 30 s, and a transaction left idle to 60 s.
- **Queues:** create them with `select platform.create_queue('lizarding_<name>')`
  and drop them with `select platform.drop_queue(...)`. Use them with pgmq's
  own functions (`pgmq.send`, `pgmq.read`, `pgmq.archive`, ...).
- **Deleting a player:** provide `lizarding.forget_player(player uuid)`. Until
  you do, deleting any player fails, so write it first, even as a stub.
  `sql/delete_player.sql` says what it must do.
- **Backups:** the nightly dump covers your schema. Hetzner's daily disk backup
  covers `/srv/lizarding`. Write files you can't lose atomically (write a new
  file, then rename it), since a disk copy may land mid-write.
