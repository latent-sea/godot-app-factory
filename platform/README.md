# The shared platform

One machine (a Netcup VPS) runs the shared backend: self-hosted Supabase for the
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
| `bootstrap.sh` | The one command that starts `setup.sh` on a fresh machine |
| `cloud-init.yaml` | The same, for a provider with a box to paste it into when ordering |
| `setup.sh` | Sets up the machine, its firewall, Supabase, the platform's SQL, Lizarding, backups, and deploying |
| `bin/deploy` | Every five minutes: takes main once its checks pass, applies what changed, rolls back if the platform is unwell. Tested by `checks/test_deploy.sh` |
| `bin/apply-sql` | The platform's SQL, in order |
| `supabase/platform.yml` | The factory's changes to Supabase's own compose file: only Caddy reachable from outside, memory ceilings, Postgres sized for 8 GB |
| `supabase/Caddyfile` | The one open door, on 443: `api.<domain>` and `play.<play domain>`, answering only Cloudflare |
| `sql/queues.sql` | Tenants create and drop their own queues (Supabase Queues) through the platform |
| `sql/delete_player.sql` | Deleting a player everywhere: each tenant's `forget_player`, then the sign-in |
| `sql/steam.sql`, `functions/steam-signin/` | Steam sign-in: a Steam account is one player, made the first time or linked to the signed-in one. Its logic is `steam.ts`, tested by `node --test platform/functions/steam-signin/steam.test.ts` |
| `tenants/add-tenant.sh` | A tenant's login, folder, service slot and its ceiling, database role, and handover files |
| `tenants/lizarding.sql` | Lizarding's role and schema |
| `tenants/lizarding.service.example` | An example of Lizarding's service, for Lizarding to adapt |
| `bin/add-ssh-key` | Lets a tenant's key log in |
| `bin/backup-db` | The nightly dump of the whole database |
| `checks/lizarding_walls.sql` | Run as Lizarding to see its walls hold |

## Ordering the machine

On Netcup, order a **VPS 1000 G12.5**: 4 shared **x86** cores, 8 GB, 128 GB, in
Nuremberg. (x86 because Lizarding's program is built for x86-64. Hetzner's
equivalent was sold out and its next size up three times the price; see D-011.)

1. **System:** in Netcup's server panel, install **Ubuntu 24.04** with your own
   SSH public key, so root logs in with it.
2. **Start the setup:** log in as root and run

       curl -fsSL https://raw.githubusercontent.com/latent-sea/godot-app-factory/main/platform/bootstrap.sh | bash -s latent-sea.com

   (a second domain after the first puts Lizarding's players on `play.<it>`). It
   refuses to start unless a key can log in, since the setup turns passwords
   off. The setup carries on if you log out, takes about ten minutes, and logs
   to `/var/log/platform-setup.log`.

The setup builds its own firewall: in on TCP 22 and 443 only. Where a
provider takes a cloud-config file when ordering, `cloud-init.yaml` does the
same as step 2.

## By hand, after ordering

1. **DNS:** in Cloudflare, add `api` on the platform's domain and `play` on
   the play domain as A records (and AAAA for IPv6) pointing at the server,
   proxied (orange cloud).
2. **Encryption:** on each of the two domains in Cloudflare, under SSL/TLS, set
   the mode to **Full (strict)** and turn on **Authenticated Origin Pulls**.
3. **Origin certificates:** under SSL/TLS, Origin Server, create one for
   `*.<domain>` and `<domain>`. Save it on the server as
   `/srv/platform/secrets/tls/origin.pem` and its key as `origin.key`. When
   the play domain is another domain, create one for it the same way, saved
   as `play-origin.pem` and `play-origin.key` beside them (a certificate
   covers one domain). Then run `docker restart platform-caddy`.
4. **Lizarding's key:** `/srv/platform/factory/platform/bin/add-ssh-key lizarding "<their public key>"`.
5. **Steam sign-in, when the game is on Steam:** in `/srv/platform/supabase/.env` set
   `STEAM_WEB_API_KEY` (a publisher Web API key, from Steamworks), `STEAM_APP_ID`
   and, if the game uses another, `STEAM_IDENTITY` (default `latensea`); then
   `docker compose up -d functions`. Until then steam-signin answers that it isn't set up.

## Running it

- **The dashboard:** `ssh -L 8000:127.0.0.1:8000 root@<server>`, then open
  http://localhost:8000. Its user and password are `DASHBOARD_USERNAME` and
  `DASHBOARD_PASSWORD` in `/srv/platform/supabase/.env`.
- **Logs:** `cd /srv/platform/supabase && docker compose logs -f <service>`.
- **Updating Supabase:** change `SUPABASE_TAG` in `setup.sh` after reading
  Supabase's changelog. Copy the new release's `docker/` files over
  `/srv/platform/supabase`, keeping `.env`, `.supabase-version` and
  `volumes/db/data`; the factory's `platform.yml` carries every change to the
  compose file, so nothing in the copied files needs editing. Then run
  `docker compose pull && docker compose up -d`. Take a dump first.
- **Deploying changes:** merging to main is the whole of it. Every five minutes
  the machine fetches main and takes a new commit once every GitHub check on it
  has passed, applying only what changed under `platform/` (SQL, functions,
  compose changes, the Caddyfile, these scripts). If the platform doesn't answer
  afterwards it goes back to the commit it was on and refuses the new one. See
  what happened at `https://api.<domain>/platform/status`, or
  `journalctl -u platform-deploy`. The machine pulls; GitHub holds no key to it.
  - SQL only moves forward: every file is safe to run again and only adds or
    replaces, because going back to an earlier commit doesn't undo it.
  - A Caddyfile change restarts Caddy, so connected players reconnect.
  - Supabase's own version is never changed this way (next item).
- **Restoring:** on a fresh machine set up the same way, stop everything but
  the database, then run
  `gunzip -c db-<date>.sql.gz | docker compose exec -T db psql -U supabase_admin -d postgres`,
  copy back `/srv/lizarding` and `.env`, and start again.
- **Backups:** the nightly dump stays on the machine, in `/srv/backups`.
  Copies off the machine aren't set up yet; until they are, take a snapshot in
  Netcup's panel before anything risky.

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
- **Players connect:** to `wss://play.<play domain>` (`PLAY_URL` and `LISTEN` in
  `.platform/platform.env`) through Cloudflare. Your
  service listens on `127.0.0.1:8100`.
- **The database:** connect directly to `127.0.0.1:5432` as `lizarding`.
  - You may hold up to 20 connections.
  - Each statement is limited to 30 s, and a transaction left idle to 60 s.
- **Queues:** create them with `select platform.create_queue('lizarding_<name>')`
  and drop them with `select platform.drop_queue(...)`. Use them with pgmq's
  own functions (`pgmq.send`, `pgmq.read`, `pgmq.archive`, ...).
- **Deleting a player:** provide `lizarding.forget_player(player uuid)`, a
  `security definer` function your role owns (it then runs as you, never as the
  platform). Until you do, deleting any player fails, so write it first, even
  as a stub:
  `create function lizarding.forget_player(player uuid) returns void language sql security definer set search_path = lizarding as 'select';`
  `sql/delete_player.sql` says what it must do.
- **Backups:** the nightly dump covers your schema. Nothing yet copies
  `/srv/lizarding` off the machine, so keep what you can't lose in your
  repository or the database. Write files atomically (write a new file, then
  rename it), since a snapshot may land mid-write.
