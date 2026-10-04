# Sites

Web apps on gd-chime for the web (`web/gd_chime/`, D-012). Each folder here
holding a `site.json` is one site:

| File | What it is |
| --- | --- |
| `index.html` | the page |
| `site.js` | the app: a `ChimeApp` - its actions, its screens, its models |
| `probe.js` | the site walked as a person would, opened with `?probe` |
| `site.json` | its title |
| `gd_chime/` | its copy of the framework, from `tooling/install_site.py` (gitignored) |
| `backend.sql` | its tables on the platform, applied by the server when merged to main (`platform/README.md`, "Apps' tables") |
| `backend/` | its copy of the platform's client (`web/backend/`), when `site.json` names `"services": ["backend"]` (gitignored) |

    python tooling/create_site.py <name>     # a new one, saying hello
    python tooling/install_site.py           # every site's gd_chime/
    python tooling/check_site.py             # the framework's tests, then every probe
    python tooling/export_web.py             # build/web/, as a host serves it

CI publishes `build/web/` to GitHub Pages from `main`.
