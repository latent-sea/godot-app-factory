# Services

Shared capabilities the factory's apps install. Each folder here is one
service. An app names the ones it uses in its `factory.json`:

    "services": ["look"]

and `tooling/install.py` copies each into the app as
`addons/factory_<name>/` (gitignored), so a fix here reaches every app on
its next install. A service's `tests/test_*.gd` run inside every app that
installs it (`tooling/check_app.py`).

| Service | What it is | Needs |
| --- | --- | --- |
| [look](look/look.gd) | Appearance only: the Theme, gd-chime's dressed and sized for phones, at the text size it is handed (D-004, D-007) | nothing |
| [basics](basics/basics.gd) | Android's Back button, and where an app's data is saved (a probe always gets its own file) | nothing |
| [settings](settings/settings.gd) | The gear and Settings screen every app has: text size, haptics, reset app data, about (D-008) | look, basics |
| [shell](shell/opening.gd) | How an app runs as a Latensea app: the opening scene and the loading screen (D-009) | look |
| [testkit](testkit/walk.gd) | What a probe is made of: presses, taps, swipes, reading the screen, claims and the PROBE OK report; never exported | settings |
| [backend](backend/backend.gd) | The shared platform (D-010, D-011): signing in, the player's data, live channels; the session kept and refreshed | nothing |

A service says what it needs in its `service.json` (`{"needs": ["look"]}`).
`install.py` refuses an app that names a service without what it needs, and
a service's code may reach another service (`res://addons/factory_<name>/`)
only if it names it there - `tooling/tests/test_install.py` checks every one.

A service is made when a second app needs the same thing, never before.
(The backend came first: every app that keeps data online, and Lizarding,
will use one platform, and it was proven before any of them needed it. No
app installs it yet, so CI checks it in a freshly made app; its
`tests/online.gd` runs the same calls against a real platform, by hand.)

**Before a service grows, ask where the behaviour belongs** (D-009):
- Would an unrelated gd-chime application need it too? Then it may belong
  in gd-chime: note it in `docs/look-backlog.md` as a candidate, since
  changing gd-chime needs the owner's approval.
- Does only one app need it? Keep it in that app until a second one does.
- Does it change what happens - input, lifecycle, saving - rather than how
  things look? Then it is not the look's.
