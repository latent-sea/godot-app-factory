# D-009: The factory assembles an app, and each service declares what it needs

**Problem.** An outside review of `main` at 4d1d4e6 found three things,
all confirmed:
- **The look had outgrown appearance.** It also held the opening scene,
  and the node that reinterprets touch (long press, a press's spring).
- **The look and Settings knew each other in a loop.** The look read the
  text size from Settings' own file, while Settings was built on the look.
- **The services said nothing about their dependencies.** `factory.json`
  listed them as peers, but Settings could not work without the look and
  basics, and nothing checked that. Separately, every APK carried the
  probe and the testkit.

**Decision.**
- **Declared needs.** Each service names what it needs in its
  `service.json`. `install.py` refuses an app that lacks one, and a test
  checks every service's code reaches only services it names. This is a
  check, not a package manager: nothing is resolved or installed for you.
- **The look is appearance only.** It is handed the text size
  (`FactoryLook.make(palette, text_size)`) and knows nothing of where it
  is kept. Settings keeps it, and the app's `look()` passes one to the
  other. So the app composes, and the look and Settings don't know each
  other.
- **A shell service.** It holds how an app runs as a Latensea app: the
  opening scene and loading screen, and `enliven.gd`. (Since then
  everything enliven.gd did has moved into gd-chime, as the rule below
  asks; see docs/look-backlog.md.)
- **Nothing only a test needs is exported.** An app loads its probe only
  when walked. The export preset leaves out `probe.gd` and the testkit,
  and `export_android.py` fails an APK that carries them.
- **A rule for where behaviour belongs** (services/README.md):
  - An unrelated gd-chime app would need it: it's a gd-chime candidate,
    and changing gd-chime needs the owner's approval.
  - One app needs it: it stays in that app.
  - It changes what happens rather than how things look: it isn't the look's.

**Why.** The factory should put an app together, not become a second
framework the app lives inside; gd-chime is the framework. Each reuse
makes the next cross-cutting behaviour more tempting to put in the
factory, and ownership should decide where things go, not convenience.

**Alternatives.**
- Split the look into many small services. A button would then take five
  places to understand.
- Resolve dependencies automatically. That's machinery the factory
  doesn't need yet.
- Leave it. Every round was adding to the tangle.

**Reconsider if** the fourth app, chosen to be unlike the first three,
fights the shell or Settings, or doesn't want the Latensea look.
Whatever it fights is the boundary to move.
