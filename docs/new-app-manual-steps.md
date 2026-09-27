# Making a new app: what is still done by hand

What it took to make the Checklist, after the factory's tools existed, and
what step 8 automated. A new app is now:

    python tooling/create_app.py <name> [--title "Its Title"]
    python tooling/install.py <name>
    python tooling/check_app.py <name>

and it builds its APK in CI with no hand edits (CI checks a freshly
created app on every run).

## Repeats for every app

| Step | For the Checklist | Now |
| --- | --- | --- |
| `apps/<name>/` with `factory.json` (name, package id, services) | By hand | `create_app.py` |
| `project.godot`: gd-chime's settings, plugin, Mobile renderer, ETC2/ASTC, orientation, icon | Copied from gd-chime and edited | `create_app.py` |
| No Godot splash, splash in the look's ground colour | By hand, after seeing Godot's logo on the phone | `create_app.py` |
| `main.tscn` rooted in a `SubViewportContainer` | By hand, after a failed run | `create_app.py` |
| `export_presets.cfg` for Android | By hand | `create_app.py` |
| A starter test and probe that pass | Written by hand | `create_app.py` |
| A look | In the app | The factory's look service (`services/look`) |
| An icon | Drawn by hand | A placeholder from `create_app.py`; **still by hand** |
| Test helpers (frames, finding pressables, a finger swipe) | Copied from gd-chime's patterns | **Still by hand**: a candidate service once a second real app repeats them |
| Picked up by CI, gd-chime installed, debug APK, QR link | Automatic | Automatic |

## Once, for the factory

- The gd-chime mirror, its deploy key and secret (done).
- The debug keystore (done, D-005).
- Godot's Android SDK path: `export_android.py` sets it in the editor
  settings, because Godot ignores `ANDROID_HOME`.

## Things learned that the next app shouldn't have to learn

- A `ChimeApp` scene root is a `SubViewportContainer`.
- `ChimeApp` already has a member named `Look`: preload the factory's look
  as `FactoryLook`.
- A GDScript error in a test means Godot never quits: `check_app.py` stops it
  after 2 minutes and reports it.
- A field needs gd-chime's `Field` style (`GdChime.Fields.FIELD`), and the
  look must dress it, or it draws as the engine's grey default.
- gd-chime's status marks mean health (well, fault, still), not ticks.
- gd-chime reports refused saves and unreadable files as errors on
  purpose, so a test that triggers one fails `check_app.py`'s clean-output
  rule. Those cases are gd-chime's to test.
- gd-chime sizes are for a monitor; phones need the look enlarged (D-007).
- A row template is called once with no item, so every read allows for null.
