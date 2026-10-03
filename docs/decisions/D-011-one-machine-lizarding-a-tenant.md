# D-011: One machine carries the platform, with Lizarding as a tenant

Ian decided this on 2 Oct 2026. It replaces the separate campaign machine and
the December date in D-010's hosting plan.

**Update, 3 Oct 2026: the machine is a Netcup VPS.** When it came to ordering,
Hetzner's cheap shared range had been sold out everywhere since September,
and after two price rises its next x86 size (CPX32) was €35.49 a month. After
comparing the main European providers, Ian chose Netcup's VPS 1000 G12.5:
4 shared x86 cores, 8 GB, 128 GB, about €14 a month (€12 on a 12-month term),
before VAT. Nothing else here changes. What did:
- The setup starts from one command (`platform/bootstrap.sh`), as Netcup has
  no cloud-config box, and builds its own firewall.
- Hetzner's daily off-machine disk backups don't come across, so copies of
  the nightly dump off the machine are still to be arranged.
- Netcup's shared cores have a fair-use limit on long stretches at 100%,
  which the platform doesn't approach; dedicated cores (its RS range) are the
  step up when Lizarding needs them.

**Problem.** D-010 chose Supabase, self-hosted later on Hetzner, with a
separate machine for Lizarding's campaign. Lizarding is ready to build now, the
budget doesn't run to dedicated cores, and it wasn't settled who owns what on
a shared machine.

**Decision.**
- **One machine.** One Hetzner machine, 4 shared x86 cores and 8 GB of memory
  (about €11 a month before backups and VAT), carries both the platform and
  Lizarding's game server. It is resized upward when the numbers call for it.
  Ian rents it and holds the account, the payment and the secrets.
- **The factory owns the machine and the platform.**
  - The machine: the system, updates, firewall and logins.
  - Cloudflare, DNS and certificates.
  - Supabase and Postgres.
  - Sign-in and the token's keys.
  - Backups.
  - The limits on each tenant.
- **Lizarding is a tenant.** Lizarding owns:
  - its game server;
  - everything in the `lizarding` schema;
  - its files in `/srv/lizarding`;
  - checking tokens and seating players;
  - its own load testing;
  - its part of deleting a player.

  Neither side edits the other's part.
- **The set-up is code**, in `platform/`. It was rehearsed before the machine
  existed. A first-boot file Ian pastes when ordering does the rest.

**How the walls are built.**
- **Database role.** Lizarding's role owns its schema and nothing else. It
  holds at most 20 connections, and statements and idle transactions are
  limited in time.
- **Queues.** pgmq keeps every queue in its own schema, so a tenant creates
  its queues through `platform.create_queue`, named after itself, and only it
  is granted them.
- **Machine.** Lizarding's processes share one ceiling it can't raise: 2 cores
  and 2.5 GB. The platform's containers are capped at 4.5 GB in total.
- **Network.** Only Caddy is reachable from outside, on 443, and it answers
  only Cloudflare (Authenticated Origin Pulls). Everything else listens on
  127.0.0.1.
- **Tokens.** Tokens are ES256. Their public keys are published, so Lizarding
  checks tokens without holding any platform secret.

**Rehearsed** on Supabase's self-host release v0.8.2:
- **Lizarding's role:** it can use its own schema and queues. It's refused the
  sign-in data, the apps' tables, the public schema, another tenant's queues,
  creating roles, and taking another role's identity. Its 21st connection is
  refused.
- **Tokens:** a player's token verifies against the published public key
  alone. Tampered tokens are refused by the data API, live updates and a
  key-only check.
- **Deleting a player:** it runs Lizarding's `forget_player`, then removes the
  sign-in. Only the platform's service role may call it.
- **Caddy:** only Cloudflare's client certificate gets in. The dashboard isn't
  reachable from outside. A WebSocket reaches the game server's port.
- **Memory:** the platform uses about 1 GB at rest.

**Alternatives.**
- **A second machine for Lizarding.** Out of budget for now. It returns when
  Lizarding's load says so; the tenant's walls make moving it out a copy, not
  a redesign.
- **A direct port for game connections.** That would expose the machine's
  address and bypass Cloudflare's protection for the platform too.
- **Lizarding in its own Supabase project.** That would split players across
  two sign-ins.

**Reconsider if**
- Lizarding's service or the database outgrows its ceiling in load tests;
- Cloudflare's WebSocket handling hurts play (it can drop idle or long
  connections, so clients must keep connections alive and reconnect);
- a second tenant arrives that needs walls this doesn't give.
