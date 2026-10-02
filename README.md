# Godot App Factory

A solo-developer platform for rapidly creating, developing, testing and deploying many independent applications from a shared Godot foundation.

This repository is not one application.

It is intended to become an **app factory**: shared application infrastructure, platform integrations, tooling and deployment automation that make each subsequent application significantly cheaper and faster to build.

Godot is the application runtime.

Android is the first major deployment target, but the architecture should preserve the cross-platform advantages of Godot wherever practical.

The web is the second: a *site* is an app exported for a browser (`tooling/create_site.py`, `tooling/export_web.py`), published to GitHub Pages from `main` (D-012).

---

## Existing UI foundation: gd-chime

This project already has an established general-purpose UI framework:

**gd-chime**

https://github.com/latent-sea/latent-productions/tree/main/Projects/Lizarding/product/gd-chime

`gd-chime` is an existing dependency of this project, not code to be recreated here.

It provides the UI/application-description layer, including its own:

- public API;
- application model;
- responsive layout system;
- themes and looks;
- controls and application components;
- state/update conventions;
- demos;
- automated tests and checks;
- architectural constitution.

Before making architectural decisions involving UI, agents should read:

- `gd-chime/README.md`
- `gd-chime/CONSTITUTION.md`

The factory should respect the architectural boundary defined there.

In particular:

> Applications depend on gd-chime. gd-chime must not depend on applications or on this factory.

The factory may provide higher-level services that applications use alongside gd-chime, but it must not turn gd-chime into an application-specific framework.

Do not copy or fork gd-chime functionality into this repository simply for convenience.

If genuinely general-purpose UI functionality is missing, it may belong upstream in gd-chime rather than here.

---

# Philosophy

## Solo-developer first

This system exists for one human developer.

Do not introduce enterprise processes, organizational abstractions, governance systems or conventional team-oriented ceremony unless they directly improve the productivity or reliability of a solo developer.

The system should remain understandable by one person returning to it months later.

---

## AI-native development

Development will frequently be performed by AI coding agents.

Multiple AI sessions may work on different parts of the repository concurrently.

The architecture should therefore favour:

- clear boundaries;
- small coherent systems;
- explicit interfaces;
- deterministic builds;
- strong automated tests;
- low-conflict repository structure;
- concise documentation;
- independent validation.

Avoid designs where every feature requires editing the same central files.

An AI session working on Android integration should not need to understand an unrelated application's business logic.

An AI session working on one service should ideally be able to build and test that service independently.

---

## The apps are the products

The factory is infrastructure.

Its purpose is to make actual applications easier to build, maintain and deploy.

Do not optimize for framework sophistication for its own sake.

Every abstraction should ultimately reduce the effort, repetition or risk involved in shipping applications.

---

## gd-chime owns UI

Do not create a competing general-purpose UI framework inside the factory.

gd-chime is the shared UI foundation.

The factory may provide application-level composition around it, but UI concepts that belong generally to applications should normally be implemented in gd-chime.

Maintain a strong distinction between:

### gd-chime

General-purpose application/UI concerns.

### app factory

Shared application services, platform integration, tooling, creation and deployment.

### individual apps

Actual product behaviour, content, assets and domain-specific logic.

---

## Reuse without rigidity

Applications may be substantially different from one another.

Some may be conventional utilities.

Some may be data-heavy applications.

Some may use device capabilities.

Some may be games.

Lizarding itself may eventually consume parts of the same application platform.

Applications may share:

- UI through gd-chime;
- configuration;
- persistence;
- networking;
- authentication;
- backend services;
- analytics;
- billing;
- notifications;
- logging;
- device integration;
- deployment tooling.

They should not be forced into identical application behaviour simply because they share infrastructure.

The platform should help applications rather than constrain them.

---

## Shared platform, not copied boilerplate

Shared behaviour should live in reusable components.

Applications should consume those components rather than receive copied versions of them.

A fix to authentication, persistence, Android integration or another shared service should be capable of benefiting existing applications without manually applying the same fix repeatedly.

Generated code should therefore be kept to a minimum.

---

## Configuration where appropriate, code where necessary

Configuration is appropriate for things such as:

- application identity;
- package/bundle identity;
- branding;
- enabled capabilities;
- API environments;
- permissions;
- build metadata;
- platform settings.

Do not turn unique application behaviour into configuration merely to make the factory appear generic.

If something is genuine business logic, it should normally remain code.

---

## Prefer explicit systems over magic

Convenience is useful.

Invisible behaviour is expensive.

Prefer architecture that can be understood by reading the repository.

Avoid unnecessary:

- hidden registration;
- reflection-like behaviour;
- generated glue;
- global magic;
- implicit coupling.

Automation should make the system easier to understand, not harder.

---

## Modular over centralized

Avoid giant shared modules containing unrelated functionality.

Prefer coherent capabilities with narrow responsibilities.

Potential examples include:

```text
services/
    persistence/
    networking/
    auth/
    notifications/
    analytics/
    billing/

platform/
    android/
```

These names are illustrative rather than prescriptive.

Avoid giant registries or god objects every application must modify.

---

## Respect dependency direction

Lower-level shared infrastructure must not become dependent on individual applications.

The intended general direction is:

```text
individual applications
        ↓
shared app services
        ↓
platform integrations

individual applications
        ↓
gd-chime
```

gd-chime remains independently installable and must not acquire dependencies on this factory.

Application-specific concepts must not leak downward into shared infrastructure.

---

## Prove abstractions through applications

Do not build shared abstractions because something might someday be reusable.

Prefer:

1. build real application behaviour;
2. encounter genuine repetition;
3. understand what is actually common;
4. extract the useful common capability.

Real applications should drive the evolution of the factory.

---

## Build for change

External services and platform APIs will change.

Reasonable boundaries should exist around volatile concerns such as:

- backend implementation;
- authentication providers;
- analytics;
- billing;
- notifications;
- cloud storage;
- crash reporting;
- Android-native APIs.

Do not construct elaborate abstraction layers merely to make every dependency theoretically replaceable.

---

## Automate repetition

Repeated mechanical work should progressively disappear.

The factory should eventually automate as much as practical of:

- creating a new application;
- dependency setup;
- configuration;
- Android export configuration;
- package naming;
- icons and metadata;
- builds;
- testing;
- signing;
- versioning;
- release preparation;
- Play Store deployment.

Automation is valuable when it removes work.

Automation that creates another system requiring constant maintenance is not automatically an improvement.

---

## Tests protect leverage

Shared code has a large blast radius.

A defect in common infrastructure may affect many applications.

Shared capabilities should therefore have strong automated tests.

Where possible, platform services should be independently testable from the applications using them.

A clean checkout should be capable of reproducing builds without undocumented local state.

---

## Never solve a hypothetical problem at the expense of a current one

Leave sensible migration paths for future requirements.

Do not build infrastructure merely because it might become necessary after dozens of applications exist.

Use the simplest architecture that meets actual requirements while leaving obvious routes for evolution.

---

# Success criterion

The primary measure of this project is:

> **The next application should be cheaper to build than the previous one.**

By the fifth application, common application plumbing should require dramatically less work than it did for the first.

A new application should increasingly consist of:

```text
application identity
configuration
branding/look
assets
domain model
application-specific behaviour
```

rather than repeated infrastructure.

---

# Technology direction

Unless investigation identifies a strong reason otherwise:

- Godot 4.x is the application runtime.
- GDScript is the default application language where appropriate.
- gd-chime is the shared UI/application-description framework.
- GitHub hosts source control.
- GitHub Actions provides CI/CD where useful.
- Android is the initial mobile deployment target.
- The web is the second target: a site is an app with a Web export preset, served as static files from GitHub Pages.

Native Android code should be introduced when Godot alone cannot reasonably provide required platform functionality.

---

# Android integration

Android-specific capabilities should sit behind clearly defined interfaces rather than leak throughout application code.

Likely examples include:

- Google Play Billing;
- notifications;
- camera access;
- file/document APIs;
- sharing;
- permissions;
- biometric authentication;
- deep links;
- Play services;
- native platform intents.

These may be implemented using Godot Android plugins, Java/Kotlin integration, or another appropriate mechanism.

Applications should ideally consume a stable Godot-facing service rather than directly knowing Android implementation details.

Where practical, non-Android implementations or graceful unsupported-platform behaviour should remain possible.

---

# Shared backend

Applications are expected to share backend infrastructure.

The backend architecture has not yet been selected.

The factory should establish a clean application-facing boundary for backend communication without prematurely committing every application to a particular server implementation.

Likely common concerns include:

- authentication;
- API requests;
- user identity;
- remote configuration;
- application data;
- subscriptions/entitlements;
- cloud persistence.

Backend implementation choices should be driven by real application requirements.

---

# Relationship with Lizarding

The existence of this factory should also make it possible for Lizarding and future games to reuse appropriate shared infrastructure.

That does **not** mean the factory should become game-specific.

Likewise, Lizarding should not dictate abstractions that ordinary applications do not need.

Shared capabilities should move downward only when they are genuinely general.

gd-chime already demonstrates this principle: it was created in the context of Lizarding but is independently usable by general applications.

The same standard should apply to new shared infrastructure.

---

# Repository direction

A likely structure may emerge along the lines of:

```text
apps/
    app_one/
    app_two/

services/
    networking/
    persistence/
    auth/
    analytics/
    billing/

platform/
    android/

tooling/
    create_app/
    build/
    release/

docs/
    architecture/
```

gd-chime should remain an external/shared dependency rather than being silently copied into this structure.

The actual repository structure should emerge from implementation rather than being forced to match this example.

---

# Consuming gd-chime

The exact dependency mechanism should be selected deliberately.

Possible approaches include:

- Git submodule;
- scripted dependency installation;
- versioned release/download;
- another reproducible dependency mechanism.

Requirements are more important than mechanism.

The solution should:

1. keep gd-chime independently maintained;
2. avoid copied divergent versions;
3. allow applications to pin a known-good version;
4. allow upgrades to be deliberate;
5. work from a clean checkout;
6. work in CI;
7. allow AI cloud sessions to obtain dependencies without access to the developer's local machine.

Do not casually vendor an arbitrary snapshot of gd-chime into each application.

---

# Architectural decisions

Significant architectural choices should be recorded concisely.

Decision records should explain:

- the problem;
- the decision;
- reasoning;
- realistic alternatives;
- what would cause reconsideration.

Do not create documentation bureaucracy for ordinary implementation details.

---

# Working with AI coding sessions

AI agents working in this repository should:

1. read this README before making architectural changes;
2. inspect relevant existing code before designing replacements;
3. read gd-chime's README and Constitution before changing anything involving its boundary;
4. respect gd-chime's public API rather than reaching into its internals;
5. keep work focused;
6. avoid unrelated refactoring;
7. build and test changes;
8. prefer extending established patterns over creating parallel systems;
9. simplify abstractions that prove harmful;
10. leave the repository easier for the next session to understand.

When multiple AI sessions operate concurrently, work should normally be separated through branches or worktrees and scoped to distinct concerns.

---

# Immediate objective

The first milestone is to establish the minimum viable **application factory**, not to implement every possible shared capability.

The first development effort should:

1. study gd-chime and understand its intended public boundary;
2. establish a reproducible mechanism for consuming gd-chime;
3. create the basic factory/project structure;
4. create one or more common application-service patterns only where immediately useful;
5. establish an Android export/build path;
6. produce a small real application using gd-chime and the factory;
7. build that application for Android;
8. identify what application creation still requires manually;
9. automate the highest-value repeated parts;
10. use the resulting experience to determine the next shared capability.

Do not recreate gd-chime as part of this milestone.

Do not attempt to build auth, billing, analytics, notifications and every other future service at once.

First prove the full path:

```text
idea
  ↓
new app
  ↓
gd-chime UI
  ↓
shared factory capabilities
  ↓
Android build
  ↓
installable application
```

---

# Guiding question

When making a design decision, ask:

> Does this make it easier for one developer, assisted by AI, to repeatedly create and maintain distinct applications without duplicating infrastructure?

If not, the complexity probably does not belong here.
