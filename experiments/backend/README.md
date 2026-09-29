# Backend experiment (September 2026)

A throwaway test of whether a Godot app can talk to Supabase in plain
GDScript, with no plugin. Supabase provides the database, sign-in and live
updates. It passed, and [D-010](../../docs/decisions/D-010-the-backend-is-supabase.md)
records what it showed.

This folder is not part of the factory. Nothing here is installed into an
app, and CI doesn't look at it. It stays as the starting point for the real
`backend` service.

| | |
| --- | --- |
| `supa.gd` | The client, one per device. It handles an emailed sign-in code or an anonymous sign-in, reading and writing a table, and live inserts. Live inserts use a WebSocket speaking Phoenix channels, the protocol Supabase Realtime uses. |
| `app.sql` | The one table, `notes`. Row-level security lets only the note's owner see it, and it is published for live updates. |
| `local/` | The test against a Supabase running on this machine. It signs in by emailed code, reading each code from a local mail catcher. |
| `phone/` | The same checks as an Android app ("Backend Test"), run against the hosted project. |

## What was checked

1. One player signs in on two devices, and a stranger signs in too.
2. Device B writes a note, and device A receives it live.
3. The stranger neither receives the note live nor can read it.
4. Someone signed out can't read it either (local only).
5. Device A can read it back.

To confirm the checks can fail, the read policy was opened to everyone. The
stranger's checks then failed.

## Results

| Where | Sign-in | Live update after a write |
| --- | --- | --- |
| Local Supabase, this machine | Emailed six-digit code | 83–283 ms |
| Hosted free project, from the server | Anonymous | 876 ms |
| Hosted free project, from a phone | Anonymous | 724 ms |

All checks passed everywhere.

## Running it again

The client is shared, so first copy it into whichever project you run:
`cp supa.gd local/` or `cp supa.gd phone/`.

**Local.**
1. Copy the database's first-start scripts into `local/db/` from
   `supabase/supabase` at commit 177ef0c, folder `docker/volumes/db`. The
   files are `realtime.sql`, `webhooks.sql`, `roles.sql`, `jwt.sql`,
   `_supabase.sql` and `pooler.sql`.
2. Write `local/.env` with `POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`,
   `REALTIME_DB_ENC_KEY` and `SECRET_KEY_BASE`. `ANON_KEY` is a JWT with the
   role `anon`, signed with `JWT_SECRET`.
3. Add `127.0.0.1 realtime-dev.supabase-realtime` to `/etc/hosts`.
   Realtime reads its tenant from the host name.
4. In `local/`, start three things:
   - the mail catcher: `python3 mailcatch.py` (needs `aiosmtpd`);
   - the email template server: `python3 -m http.server 8081 -d templates`;
   - Supabase: `docker compose up -d`.
5. Still in `local/`, run
   `SPIKE_ENV=.env godot --headless --path . --script spike.gd`.
   `hosted.gd` runs the same way against the hosted project.

**Phone.** Open `phone/` in Godot 4.6 and export for Android. The internet
permission is already on.

## What we learned on the way

- Supabase's default emails contain only a link. A code sign-in needs a
  template containing `{{ .Token }}`, for sign-up and for sign-in alike.
- On the hosted free plan, editing email templates requires your own email
  sender (custom SMTP). That is why the phone test signs in anonymously.
- Auth refuses a second code to the same address within its send interval.
- A live channel needs a moment after joining before changes arrive.
- Realtime only sends a change to someone whose row-level security lets
  them read it. The privacy rule is written once, on the table.
