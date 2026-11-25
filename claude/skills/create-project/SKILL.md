---
name: create-project
description: Scaffold a new multi-feature Django+DRF+React platform using PostHog's product-module architecture — facade/contracts isolation between features, self-registering backend routes and frontend scenes, fail-closed tenant scoping on every model, a serializer-to-TypeScript generated-types pipeline, and an email/password login spec. Use when starting a new project that needs to scale to many independent feature modules over time, when adding a new module to a project this skill already scaffolded, or when implementing email/password auth on top of it.
---

# Create project (PostHog-pattern scaffolder)

Scaffolds a monorepo where every feature is a self-contained, independently-testable
module — the same pattern PostHog uses for `products/`. The payoff: adding feature #40
never requires touching code for features #1-39, and CI can skip-test modules a change
didn't touch.

Read [references/architecture.md](references/architecture.md) first if you (or the user)
haven't seen this pattern before — it explains *why* each piece exists, not just what to
type. Skip straight to the workflow below if the rationale is already understood.

## Workflow

### 1. New project (once)

```bash
scripts/scaffold_project.sh <project_name>
```

Creates:
- `backend/config/settings/` — modular settings (one file per concern), including
  `web.py`'s `MODULES_APPS` — the hand-maintained module-registration list, mirroring
  PostHog's `PRODUCTS_APPS` (see [references/settings-architecture.md](references/settings-architecture.md))
- `backend/config/urls.py` — already wired to the route registry below
- `backend/core/scoping/` — fail-closed tenant-scoped model base class
- `backend/core/routing/` — module route auto-discovery
- `modules/` — empty, one subfolder per feature module
- `frontend/src/app/scenes.ts` — scene auto-discovery registry
- `docker-compose.yml` — Postgres + Redis skeleton (extend with your own queue/analytics store)
- `manage.py` — already points at `backend.config.settings`

Settings and URLs are wired and runnable as generated — `./manage.py check` should pass
once dependencies are installed. Extend `frontend/` into your bundler of choice; see
[references/frontend-conventions.md](references/frontend-conventions.md) for that wiring.

### 2. New feature module (every time)

```bash
scripts/scaffold_module.sh <module_name>   # snake_case, e.g. billing_alerts
```

Creates `modules/<module_name>/` with:
- `backend/facade/{api.py,contracts.py}` — the *only* files other modules may import
- `backend/presentation/{views.py,serializers.py}` — thin DRF layer
- `backend/models.py` — extends `TenantScopedModel`, tenant-isolated by default
- `backend/routes.py` — self-registers into the router, zero core edits
- `frontend/scenes/`, `frontend/logics/` — a Kea-pattern scene, self-registers via `frontend/index.ts`
- `module.yaml` — ownership/description metadata

Follow the printed "next steps" — first one is always adding the module's `AppConfig`
to `MODULES_APPS` in `backend/config/settings/web.py`. That line is the one piece of
module registration that can't be auto-discovered (Django needs `INSTALLED_APPS`
before any discovery loop can run — see
[references/settings-architecture.md](references/settings-architecture.md)); everything
after it (routes, migrations, types) follows automatically or via the printed commands.

### 3. Auth (email/password login)

Not scaffolded by a script — auth touches a real `User` model, password hashing, and
session config that need a human decision or two, not blind codegen. Read
[references/auth-email-password-spec.md](references/auth-email-password-spec.md): a
full spec (data model, auth backend config, API surface, rate limiting, CSRF, and how
login hooks into the org/tenant scoping this scaffold already sets up) ported from
PostHog's `posthog/api/authentication.py`. Implement against it directly rather than
re-deriving the pattern from scratch.

### 4. Keep every module honest

As the number of modules grows, enforce the boundary mechanically rather than by
convention alone — see the "Enforcing isolation" section in
[references/architecture.md](references/architecture.md):
- An import-linter or `tach`-style config that blocks `modules.X.backend.models` imports
  from any file outside `modules.X`
- CI treats `facade/contracts.py` + `facade/api.py` as the only "public" surface per
  module for test-impact analysis

## References

- [references/architecture.md](references/architecture.md) — why this shape (facade/contracts, tenant scoping, self-registration), and how to keep modules from coupling as the project grows
- [references/settings-architecture.md](references/settings-architecture.md) — why settings are split one-file-per-concern, and why `MODULES_APPS` (Django app registration) is a manual list while route registration isn't
- [references/backend-conventions.md](references/backend-conventions.md) — Django/DRF wiring: `INSTALLED_APPS`, OpenAPI generation, tenant-scope enforcement points
- [references/frontend-conventions.md](references/frontend-conventions.md) — React/Kea wiring: scene registry, generated API types, when to reach for a shared component library vs a module-local one
- [references/auth-email-password-spec.md](references/auth-email-password-spec.md) — email/password login spec: data model, auth backend config, API surface, rate limiting, CSRF, and the org/tenant-scoping integration point
