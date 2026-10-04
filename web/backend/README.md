# The backend for sites

`backend.js` is the web twin of the Godot apps' backend service
(`services/backend/backend.gd`): signing in, a visitor's data and live
updates on the shared platform (D-010, D-011), with the same calls, answers
and rules, so a person is the same player in an app, a game and a site. Plain
JavaScript, one ES module, no dependencies.

A site asks for it in its `site.json`, and `tooling/install_site.py` copies
it in beside the site as `backend/` (gitignored):

```json
{ "title": "Shivonne Dubarry", "services": ["backend"] }
```

```js
import { Backend } from "./backend/backend.js";

const backend = new Backend("https://api.latent-sea.com", "sb_publishable_…");
await backend.restore();
if (!backend.isSignedIn()) await backend.signInAnonymously(turnstileAnswer);
const saved = await backend.insert("shivonne_dubarry_requests", { name: "…" });
backend.channel("requests").onChanges("shivonne_dubarry_requests").on("changed", show).join();
```

Every call answers a `Reply` (`ok`, `status`, `data`, `error`) and never
throws. The session lives in `localStorage`, or for the visit only where the
browser refuses storage, and is refreshed before it runs out. Sign-in: as a
guest, by a code emailed to the visitor, or with Google's "Sign in with
Google" button (`signInWithGoogleToken`); each takes Turnstile's answer
where the platform asks for one.

The publishable key is public and belongs in the page. What a visitor may
read or write is decided by the tables' row rules on the platform, never by
the page.

## Tests

- `tests/test_backend.mjs`: offline, under Node's test runner, with a
  stand-in platform, socket and clock. Run by `tooling/check_site.py`.
- `tests/ui/index.html`: the module in a real browser (storage, fetch).
  Walked by `tooling/check_site.py`.
- `tests/online.mjs`: the same walk as the Godot service's `online.gd`,
  against the live platform, by hand:

      BACKEND_URL=https://api.latent-sea.com BACKEND_KEY=sb_publishable_… node web/backend/tests/online.mjs
