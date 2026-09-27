# D-004: The apps' look is a factory service built on gd-chime's exported Themes

**Problem.** gd-chime's ready-made looks (material and the rest) live in its
demo folder, outside its public API, and its floor look is a placeholder.

**Decision.** The factory's look lives in `services/look` and every app
installs it (`"services": ["look"]`) as `addons/factory_look/`: a palette
through `GdChime.Themes`, then the factory's own styles, then phone sizing.
An app wears `FactoryLook.make()`, optionally with a palette of its own.
Nothing is copied from gd-chime's demos. It began as the Checklist's own
look and moved to the factory, as you asked, before the second app.

**Why.** Stays inside gd-chime's promise (only the facade), and the app
proves what a look needs before anything is made shared.

**Rules it carries** are in `docs/look-backlog.md`, starting with: a disabled
control just looks faded, with no reason shown.

**Reconsider if** an app needs a look the palette and styles can't reach, or
gd-chime starts shipping looks in its addon.
