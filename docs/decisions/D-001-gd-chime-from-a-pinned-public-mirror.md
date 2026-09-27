# D-001: gd-chime comes from a pinned commit of a public mirror

**Problem.** gd-chime is written inside the private monorepo
`latent-productions`. The factory's CI and cloud sessions need it without
credentials, at a known version, from a clean checkout.

**Decision.** An Action in `latent-productions` publishes the gd-chime folder
to the public `latent-sea/gd-chime` as snapshot commits: each sync is one
commit holding the folder as it is, so no monorepo history or messages
become public. `dependencies.json` pins one mirror commit;
`tooling/install.py` copies only `addons/gd_chime/` from it into each app's
gitignored `addons/`.

**Why.** No secrets to manage, reproducible builds, deliberate upgrades (move
the pin, CI runs), and apps receive exactly gd-chime's public addon.

**Alternatives.** A git submodule of the whole monorepo (private, and drags
everything in). Moving gd-chime out of the monorepo (cleanest, but changes
how gd-chime is developed). A deploy key (a secret to rotate).

**Reconsider if** gd-chime moves to its own repository, or starts publishing
tagged releases.
