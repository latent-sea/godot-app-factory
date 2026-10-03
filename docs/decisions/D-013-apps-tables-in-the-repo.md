# D-013: Each app's tables are a file in its folder, applied by the platform

Decided on 3 Oct 2026, when Ian asked for app tables after the platform went
live.

**Problem.** Apps keep data on one shared platform. Their tables have to get
there without anyone logging in, can't collide with each other's, and must
keep each player's rows from every other player.

**Decision.**
- An app's tables are `apps/<app>/backend.sql`, reviewed and merged like
  any other change. The machine applies every app's file after the
  platform's own SQL whenever any of them changes (`platform/bin/deploy`).
- Apps share the `public` schema, the one the platform serves; every name
  starts with the app's (`notes_...`).
- Every table has row-level security, and a column that deletes a player's
  rows when the player is deleted.
- The files only move forward: each is safe to run again, and removing
  something is done by hand.
- `platform/checks/app_sql_check.py` holds the rules and
  `platform/checks/test_sql.sh` loads the files into a real PostgreSQL and
  checks the walls, both in CI.

**Why.** It keeps one way of changing the platform (merge to main), and
lets the checks catch a missing rule before it reaches players.

**Alternatives.** A schema per app keeps names apart without prefixes, but
the platform serves only the schemas it is told about, so each new app
would mean changing and restarting it; prefixes need nothing. A migration
tool (numbered files, a record of which ran) handles removals and data
changes, but is more machinery than a few small apps need yet.

**Reconsider if** an app needs to change or remove data in place, or apps
grow enough that a schema each is worth the platform change.
