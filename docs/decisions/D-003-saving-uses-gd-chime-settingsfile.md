# D-003: Saving uses gd-chime's SettingsFile; no factory persistence yet

**Problem.** The Checklist keeps its items between runs. The plan said the
app would write its own JSON file and a shared service would be extracted
once a second app needed saving.

**Decision.** The app keeps its model with `GdChime.SettingsFile` and checks
what it reads with `GdChime.SaveShape`, both exported by gd-chime. There is
no persistence code in the app or the factory.

**Why.** gd-chime already writes atomically, at most once a frame, and moves
an unreadable file aside instead of failing. Writing our own would copy
gd-chime functionality, which the README rules out.

**Alternatives.** The app's own FileAccess store (the original plan); a
factory `services/persistence` now (no second user yet).

**Reconsider when** an app needs something SettingsFile is not for - large
data, queries, sync - which is when a factory service earns its place.
