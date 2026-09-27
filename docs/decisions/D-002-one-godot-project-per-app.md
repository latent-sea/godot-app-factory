# D-002: One Godot project per app

**Problem.** Apps need their own package id, icon, export settings and
version, and several AI sessions may work on different apps at once.

**Decision.** Each app is a complete Godot project at `apps/<name>/`, marked
by a `factory.json`. Tooling and CI find apps by that file; there is no
central list to edit.

**Why.** Independent export identity, no shared files between apps, and an
app opens in the editor on its own.

**Alternatives.** One Godot project holding every app as scenes: less disk,
but export presets and settings collide and every session touches it.

**Reconsider if** apps need to share scenes or resources at runtime.
