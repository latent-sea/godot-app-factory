# Making a new app: what is still done by hand

What it took to make the Checklist, after the factory's tools existed. Each
line says who did it and whether it would repeat for the next app. The
repeating lines are what step 8 of the plan automates.

## Repeats for every app

| Step | How it was done | Automate as |
| --- | --- | --- |
| Create `apps/<name>/` with `factory.json` (name, package id) | By hand | `create_app.py <name>` |
| `project.godot`: gd-chime's three settings, the plugin, the Mobile renderer, ETC2/ASTC textures, orientation, icon | Copied from gd-chime's `checks/installed/project.godot` and edited | Generated from `factory.json` |
| No Godot splash: `boot_splash/show_image=false` and the splash colour set to the app's ground | By hand, after seeing Godot's logo on the phone | Generated from the look's ground colour |
| `main.tscn` whose root is the app script, typed `SubViewportContainer` (a `ChimeApp` is one; `Control` fails) | By hand, after a failed run | Generated |
| `export_presets.cfg`: Android, arm64, package id and name, version, `tests/*` left out of the export | By hand | Generated from `factory.json` |
| An icon | Drawn by hand as `icon.svg` | Later: from one image |
| A look: palette, page margins, title, field, phone sizing | In the app (`checklist.gd`, `phone_look.gd`) | The factory's canonical look (D-004, D-007) |
| A probe that walks the screen, and `tests/test_*.gd` | Written by hand; helpers (frames, finding pressables, a finger swipe) copied from gd-chime's patterns | Shared test helpers in the factory |
| Being picked up by CI | Automatic: CI finds `apps/*/factory.json` | Done |
| gd-chime at the pinned version | Automatic: `tooling/install.py` | Done |
| Debug APK | Automatic: CI, `tooling/export_android.py` | Done |

## Once, for the factory

- The gd-chime mirror, its deploy key and secret (done).
- The debug keystore (done, D-005).
- Godot's Android SDK path: `export_android.py` sets it in the editor
  settings, because Godot ignores `ANDROID_HOME`.

## Things learned that the next app shouldn't have to learn

- A `ChimeApp` scene root is a `SubViewportContainer`.
- A field needs gd-chime's `Field` style (`GdChime.Fields.FIELD`), and the
  look must dress it, or it draws as the engine's grey default.
- gd-chime's status marks mean health (well, fault, still), not ticks.
- gd-chime reports refused saves and unreadable files as errors on
  purpose, so a test that triggers one fails `check_app.py`'s clean-output
  rule. Those cases are gd-chime's to test.
- gd-chime sizes are for a monitor; phones need the look enlarged (D-007).
- A row template is called once with no item, so every read allows for null.
