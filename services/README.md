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

A service is made when a second app needs the same thing, never before.
