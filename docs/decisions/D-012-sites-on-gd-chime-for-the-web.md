# D-012: Sites are web apps on gd-chime for the web, a JavaScript port

**Problem.** The factory makes Godot apps for Android. A web app - a page a
browser opens - was wanted, on gd-chime, and the factory should make one as
cheaply as it makes an app.

**Decision.** gd-chime is rewritten in JavaScript as `web/gd_chime/`: the
floor (bells, chimes, values, the door, the register, the driver, phrases
and the language) ported from the GDScript and its tests, and the
vocabulary built into the DOM. A site is a folder under `sites/` with a
`site.json`, made by `tooling/create_site.py`, given its copy of the
framework by `tooling/install_site.py`, walked by its probe in a headless
Chrome by `tooling/check_site.py`, and copied out by
`tooling/export_web.py` to `build/web/`, which CI publishes to GitHub Pages
from `main`.

**Why.** A described interface and bells that carry nothing are not
Godot's; they port. The first attempt, Godot's own Web export, ran
gd-chime unchanged but cost about 10 MB gzipped for a page that says hello,
and drew text into a canvas the browser cannot read, select or translate.
The port is about 100 KB, plain files with no build step, and draws real
DOM. The sites are checked as the apps are: a probe walks each one and
prints PROBE OK, and only a run that exited 0, said its line and reported
no trouble counts.

**Alternatives.** Godot's Web export (above). A JavaScript framework
(React, Svelte) beside gd-chime: a second UI foundation with other rules,
which the README forbids. Sites under `apps/`: the tools would have to
tell a Godot project from a page at every step, for nothing they share.

**Where it lives.** gd-chime is a dependency the factory must not fork
(README; D-001). The port is gd-chime's, kept here only until it moves
beside the addon in gd-chime's own folder and is pinned like the addon.
`tooling/install_site.py` alone reads its path.

**Reconsider if** a site needs what is not ported yet (its README lists
it): port that piece, don't work around it in the site. If the port and
the addon drift, the GDScript is the reference.
