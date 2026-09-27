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
| Test helpers (frames, finding pressables, taps, a finger swipe, the report) | Copied from gd-chime's patterns, then repeated in the I Ching | The testkit service: a probe writes only its own claims |
| Android's Back button | Written into the I Ching by hand | The basics service; `create_app.py` wires it in |
| Where saved data lives, and the probe's own file | Repeated in both apps | The basics service |
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
- `ChimeApp` also has members named `Prompts` and `prompts` (gd-chime's own
  guidance prompts): don't use those names in an app.
- Every model must be in the tree: handed to a screen, or registered with
  `model()`. A model made but not registered leaks, and its actions only
  work by accident. A drawer takes no model, so register its model app-wide.
- Long words wrap only inside a row that lets them grow:
  `ui.row([ui.text(...).wraps().grow()])`. Otherwise one long line widens
  every screen in the same stack.
- gd-chime's NotificationTray reserves room for a 14-letter notice beside
  its buttons, which is wider than a phone at phone sizes. Say it in place
  instead (the I Ching's card says "Copied").
- To move from a model (say, after the sixth tap), dispatch
  `GdChime.Driver.GO` through the app's `commands`, as gd-chime's own Form does.
- gd-chime doesn't handle Android's Back button: the basics service does
  (`Basics.answer_back(self)`), with `config/quit_on_go_back=false`.
- A press inks every word on it in its own state's colour, so a quieter
  style (`QUIET`) inside a row or card does nothing. Say "matters less" with
  a smaller size instead (the Notes list does this).
- A screen's first focusable control takes the focus when it opens. If that
  is a field, a phone raises its keyboard: put a link before it (the Notes
  list's "New note" is in the title row for this reason).
- A pressable's style can be a bound value (`Bound` reading a type name),
  which is how a chosen tag chip changes look.
