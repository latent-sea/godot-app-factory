# D-006: Factory tooling is Python 3, standard library only

**Problem.** Install, check and export must run the same on Windows, in CI
and in cloud sessions.

**Decision.** Tools in `tooling/` are Python 3 scripts using only the
standard library, plus git and Godot.

**Why.** Python is on every CI runner and cloud session and a one-time
install on Windows; no pip dependencies to break.

**Alternatives.** GDScript tools run by headless Godot (no Python needed, but
awkward for files, git and processes); shell scripts (not on Windows).

**Reconsider if** a tool needs a library the standard library lacks.
