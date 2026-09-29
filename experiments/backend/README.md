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
| `supa.gd` | The client, one per device. It handles sign-in by emailed code, anonymously or with a Google token, reading and writing a table, and live inserts. Live inserts use a WebSocket speaking Phoenix channels, the protocol Supabase Realtime uses. |
| `app.sql` | The one table, `notes`. Row-level security lets only the note's owner see it, and it is published for live updates. |
| `local/` | The test against a Supabase running on this machine. It signs in by emailed code, reading each code from a local mail catcher. |
| `phone/` | The same checks as an Android app ("Backend Test"), run against the hosted project. |
| `google/` | Google sign-in as an Android app ("Google Test"). A small Android add-on opens the phone's own account picker; Supabase turns Google's answer into a player. |

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

**Google sign-in, on a phone.** All four checks passed:
1. The account picker gave the app a Google token.
2. Supabase accepted the token as a player.
3. That player saved a note.
4. The player read the note back.

## Running it again

The client is shared, so first copy it into whichever project you run:
`cp supa.gd local/`, `phone/` or `google/`.

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

**Google.** Write `google/plugin_src/local.properties` with
`sdk.dir=<Android SDK>`, then run `google/build.sh`. It builds the add-on,
installs Godot's Android build template and exports `googletest.apk`. The
paths to Godot, Gradle and the SDK at its top are this machine's. Google's
side is set up in the Latensea Google Cloud project:
- an **Android client** for package `com.latentsea.supatest` and the SHA-1
  of `tooling/android/debug.keystore`;
- a **Web client**, whose ID is `GOOGLE_WEB_CLIENT_ID` in `google/main.gd`
  and in Supabase's Google provider, with its secret;
- while the project is in testing, your account on the **test users** list.

## What we learned on the way

- Supabase's default emails contain only a link. A code sign-in needs a
  template containing `{{ .Token }}`, for sign-up and for sign-in alike.
- On the hosted free plan, editing email templates requires your own email
  sender (custom SMTP). That is why the phone test signs in anonymously.
- Auth refuses a second code to the same address within its send interval.
- A live channel needs a moment after joining before changes arrive.
- Google sign-in needs an Android add-on, and an add-on needs Godot's
  Gradle build rather than the prebuilt one:
  - It stores the engine uncompressed unless the preset turns on
    `gradle_build/compress_native_libraries`.
  - Even compressed, a debug export is 31 MB against 26 MB for release.
- Google sees only the SHA-256 of the nonce, and Supabase gets the raw
  nonce and checks the two match. So a token can't be replayed.
- The Web client's ID goes to both the add-on and Supabase. The Android
  client is only registered (package plus signing key) and never
  appears in code.
- Maven Central sometimes answers 429 (too many requests). Google's mirror
  of it doesn't.
- Realtime only sends a change to someone whose row-level security lets
  them read it. The privacy rule is written once, on the table.
