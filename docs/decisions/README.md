# Decisions

One short record per decision that shapes the factory: the problem, the
decision, why, the alternatives, and what would make us reconsider.
Ordinary implementation details don't get one.

| | Decision |
| --- | --- |
| [D-001](D-001-gd-chime-from-a-pinned-public-mirror.md) | gd-chime comes from a pinned commit of a public mirror |
| [D-002](D-002-one-godot-project-per-app.md) | One Godot project per app |
| [D-003](D-003-saving-uses-gd-chime-settingsfile.md) | Saving uses gd-chime's SettingsFile; no factory persistence yet |
| [D-004](D-004-apps-dress-their-own-look.md) | The apps' look is a factory service built on gd-chime's exported Themes |
| [D-005](D-005-debug-apks-and-a-shared-debug-key.md) | Milestone 1 ships debug APKs signed by a shared debug key in the repo |
| [D-006](D-006-tooling-is-python-standard-library.md) | Factory tooling is Python 3, standard library only |
| [D-007](D-007-phone-sizing-in-the-look.md) | Phone sizing is done in the look, not in gd-chime |
| [D-008](D-008-every-app-has-settings.md) | Every app has the same Settings, and text size is one of them |
| [D-009](D-009-the-factory-assembles-services-declare-needs.md) | The factory assembles an app; each service declares what it needs, the look is appearance only, a shell service runs the app |
| [D-010](D-010-the-backend-is-supabase.md) | The backend is Supabase, on the hosted free plan now and self-hosted later; apps use plain GDScript |
| [D-011](D-011-one-machine-lizarding-a-tenant.md) | One machine (a Netcup VPS) carries the platform; the factory owns it and Lizarding is a tenant |
| [D-012](D-012-sites-on-gd-chime-for-the-web.md) | Sites are web apps on gd-chime for the web, a JavaScript port; published to GitHub Pages |
| [D-013](D-013-apps-tables-in-the-repo.md) | Each app's tables are a file in its folder, applied by the platform itself; names start with the app's |
