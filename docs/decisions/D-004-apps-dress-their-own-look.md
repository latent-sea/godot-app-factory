# D-004: Apps dress their own look through gd-chime's exported Themes, for now

**Problem.** gd-chime's ready-made looks (material and the rest) live in its
demo folder, outside its public API, and its floor look is a placeholder.

**Decision.** For milestone 1 the Checklist builds its look in its own code:
a palette through `GdChime.Themes`, then its own styles (page, title, tick
boxes, add field). Nothing is copied from gd-chime's demos.

**Why.** Stays inside gd-chime's promise (only the facade), and the app
proves what a look needs before anything is made shared.

**Next.** A canonical look for the factory's apps will live **in the
factory**, not in gd-chime. The Checklist's palette, styles and
`phone_look.gd` are its first material.

**Reconsider when** the second app is built: that is when the shared look
is extracted.
