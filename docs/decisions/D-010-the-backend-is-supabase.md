# D-010: The backend is Supabase, self-hosted in the end

**Problem.** The factory has no backend. Apps can only save to the phone.
The apps now planned need more, and what they need depends on the app:
- **Sign-in.** One Latensea player across every app. They can sign in with
  an emailed code, Google or Steam, and all three link to the same player.
  Steam is for Lizarding.
- **Private records**, backed up and on every device of that player.
- **Shared data** that many players see.
- **Live updates** pushed to the app, not polled for.
- **Server logic**, and webhooks in and out.
Lizarding will use the same platform and own its own code. Its Next Fest
campaign (Feb/March 2027) runs its simulation on its own machine.

**Decision.**
- **The platform core is Supabase:**
  - Postgres with row-level security, rules on each table saying who may
    read or write each row;
  - sign-in with emailed codes and Google;
  - a data API;
  - live updates;
  - server functions and database webhooks.
  Steam sign-in is added as a function that links to the same player.
- **Hosting.**
  - **Now:** the hosted free plan, for development.
  - **Later:** self-hosted on one Hetzner machine, within $25 a month, with
    Cloudflare's free plan in front. The self-host rehearsal happens before
    December, so the campaign doesn't run on it untried.
  - **Lizarding's campaign:** a separate dedicated-core machine, so the two
    are isolated.
- **Apps talk to it in plain GDScript.** The client is HTTP plus one
  WebSocket, with no plugin and no native code. It becomes a `backend`
  service, and each app's `factory.json` says what that app uses.
- **Build only what a named app needs.** Each capability arrives with the
  first app that needs it.

**Why.** Supabase does everything on the list, and the free plan costs
nothing while we build. It can be self-hosted with the same API, so apps
don't change when it moves. Privacy lives on the table: a row the rules
hide is never sent live, never readable, and the same rule covers every
app. The experiment ([experiments/backend](../../experiments/backend/))
showed plain GDScript is enough:
- **Emailed-code sign-in** worked on a local Supabase.
- **One player on two devices** received their own notes live, in 83–283 ms
  locally and 724 ms on a phone against the hosted project.
- **A stranger** neither received nor could read them.
- **Google sign-in** on a phone worked, through the phone's own account
  picker. The one native part is a small Android add-on (Credential Manager),
  which means apps using it are built with Godot's Gradle build.

**Alternatives.**
- **Firebase.** Its Godot clients are plugins, and it can't be self-hosted.
  Steam sign-in would still need custom code.
- **Cloudflare Workers alone.** It has no sign-in and no live database
  queries, so we'd write both.
- **Nakama or PocketBase.** They are good for games or small apps, with less
  of the list built in for the other.
- **Our own server.** Everything on the list would be ours to write and
  secure.

**Not yet proven.**
- **Emailed codes on the hosted plan** need an email sender and its DNS
  records.
- **Steam sign-in**, **deletion across apps**, and **load at Lizarding's
  scale** are all untested.

**Reconsider if**
- the self-host rehearsal takes more than the one machine or the budget
  allows;
- Lizarding's load test shows live updates can't keep up;
- an app needs something Postgres and functions can't express.
