# Services

Shared capabilities the factory's apps install. Each folder here is one
service. An app names the ones it uses in its `factory.json`:

    "services": ["look"]

and `tooling/install.py` copies each into the app as
`addons/factory_<name>/` (gitignored), so a fix here reaches every app on
its next install. A service's `tests/test_*.gd` run inside every app that
installs it (`tooling/check_app.py`).

| Service | What it is |
| --- | --- |
| [look](look/look.gd) | The apps' Theme: gd-chime's, dressed and sized for phones (D-004, D-007) |
| [basics](basics/basics.gd) | Android's Back button, and where an app's data is saved (a probe always gets its own file) |
| [settings](settings/settings.gd) | The gear and Settings screen every app has: text size, haptics, reset app data, about (D-008) |
| [testkit](testkit/walk.gd) | What a probe is made of: presses, taps, swipes, reading the screen, claims and the PROBE OK report |

A service is made when a second app needs the same thing, never before.
