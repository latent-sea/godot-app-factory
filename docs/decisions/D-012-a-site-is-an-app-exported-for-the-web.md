# D-012: A site is an app exported for the web, and the web is served from GitHub Pages

**Problem.** The apps are built on gd-chime and exported for Android. A
web app - a page a browser opens, with no install - was wanted, built on
the same foundation, made by the factory as cheaply as an app.

**Decision.** A site is an app: `apps/<name>/` with a `factory.json`, the
same services, tests and probe, made by `tooling/create_site.py` from the
app template with `tooling/templates/site/` laid over it. What makes it a
site is its `export_presets.cfg`, which has a Web preset instead of an
Android one; each exporter reads the presets and takes the apps with one
for its platform (`godot.exporting`). `tooling/export_web.py` exports a
site to `build/web/<name>/`, and CI publishes `build/web/` to GitHub Pages
from `main`, at `https://latent-sea.github.io/godot-app-factory/<name>/`,
with a front page naming every site.

**Why.** Godot exports to the web, so gd-chime runs in a browser as it is:
the site template is the app template with four files changed, and
install, check and CI needed nothing new to take a site. One kind of thing
under `apps/`, found by `factory.json`, keeps D-002. The export is
single-threaded (`variant/thread_support=false`) so any static host serves
it with no cross-origin isolation headers, which GitHub Pages cannot set;
the price is that no app code runs on a thread, which none of the factory's
does. Pages is free for a public repository and needs no server of ours.

**Alternatives.** A `sites/` folder beside `apps/`: a second kind for every
tool to know, for a difference of one preset. A web UI framework beside
gd-chime: a second UI foundation, which the README forbids. Serving sites
from the platform machine (D-011): a Caddy route and a deploy step, for
static files GitHub already serves.

**Reconsider if** a site needs threads (a worker, GDExtension), when the
host must send the isolation headers; or a site needs a backend route of
its own, when the platform machine is the host.
