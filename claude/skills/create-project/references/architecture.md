# Architecture rationale

Derived from PostHog's `products/` pattern (see `products/README.md` and
`products/architecture.md` in the PostHog monorepo). The problem it solves: a platform
with N features, built by however many people/agents, where feature N+1 should never
require reading or editing feature 1..N's code.

## The core idea: facade + contracts

Every module exposes exactly one importable surface: `backend/facade/api.py`. It's the
only file another module (or core) is allowed to import from this module. Everything
else — `models.py`, `logic.py`, `presentation/` — is private to the module.

`backend/facade/contracts.py` holds frozen dataclasses (DTOs). `facade/api.py` converts
ORM objects to DTOs before returning them — a caller from another module never sees a
Django model, an ORM queryset, or an internal exception type. This is what makes modules
independently testable: a downstream module's tests only need to know the DTO shape,
not the upstream module's implementation, so changing upstream internals doesn't force
re-running downstream tests.

```
modules/billing/
  backend/
    facade/
      api.py        # ONLY file other modules import: get_invoice(), charge_card()
      contracts.py  # frozen DTOs: InvoiceDTO, ChargeResultDTO
    models.py        # private — never imported outside modules.billing
    presentation/    # DRF views/serializers — thin, calls facade.api, not models
```

## Self-registration: adding a module never edits core

Two places would otherwise need a manual edit every time a module is added: the URL
router and the frontend scene list. Both are solved by discovery instead of registration:

- **Backend**: core loops `apps.get_app_configs()`, and for every app under `modules.*`
  calls `<module>.routes.register_routes(registry)` if the file exists. See
  `backend/core/routing/registry.py` in the scaffold.
- **Frontend**: `frontend/src/app/scenes.ts` uses a bundler glob
  (`import.meta.glob('/modules/*/frontend/index.ts', { eager: true })`) so any module
  with a `frontend/index.ts` that calls `registerScene(...)` is picked up automatically.

The `RouterRegistry` handle passed to modules only exposes a fixed set of parent routers
(`root`, `projects`, `organizations` in the scaffold). Modules can nest under those, but
can't create new top-level parents — this is what makes registration order not matter:
there's no ordering dependency between modules, only between each module and core.

## Tenant scoping: fail closed, not opt-in

`backend/core/scoping/models.py`'s `TenantScopedModel` filters every query to the
current tenant via a `ContextVar`, and raises `TenantScopeError` if no tenant context is
set — it does not silently return all tenants' rows. Set the context once per request
(middleware or a DRF viewset mixin) and once per background job (a decorator around the
Celery/RQ/whatever task entry point that takes `tenant_id` as its first argument).

This matters more as module count grows: with N modules each doing their own
`Model.objects.filter(tenant_id=request.tenant_id)`, it's a matter of time before one
call site forgets the filter. Baking it into the base model class makes "forgot to
scope" fail loudly (an exception) instead of silently (a cross-tenant data leak).

Give modules an explicit, differently-named escape hatch (`all_tenants` in the scaffold,
not `objects`) for the rare legitimate cross-tenant case (admin tooling, data migrations)
so it can't be reached by autocomplete accident.

**Gotcha this fail-closed design creates**: never call the scoped manager from a
class-level attribute Python evaluates at import time — most commonly a DRF viewset's
`queryset = Model.objects.all()`. That line runs during URL resolution/app loading,
before any request has entered tenant scope, so it raises `TenantScopeError`
immediately rather than when a request actually comes in. Override `get_queryset(self)`
instead — DRF calls it lazily, per-request, after the viewset's `initial()` has already
entered scope. The generated module template already does this; if you hand-write a
viewset later, this is the first thing to check when it 500s at boot with
`TenantScopeError`.

## Generated types: one source of truth

Don't hand-write TypeScript interfaces that mirror your DRF serializers — they will
drift. Point `drf-spectacular` at your viewsets to produce an OpenAPI spec, then generate
TypeScript client + types from that spec (`openapi-typescript`, `orval`, or similar) into
a `generated/` folder per module. Treat `generated/` as build output: never hand-edit it,
regenerate it as part of the same change that touches a serializer, and have CI fail if
committed generated files don't match a fresh regeneration.

## Enforcing isolation as the project scales

Convention alone erodes under deadline pressure. Once you have more than a handful of
modules, add a mechanical check:

- **Import linter** (Python: `import-linter`; the pattern is a "layers" or "independence"
  contract that forbids `modules.X.(?!facade)` being imported from outside `modules.X`).
- **Test-impact scoping**: if your CI can compute "which files changed", treat
  `facade/contracts.py` + `facade/api.py` as the only files that affect *other* modules'
  test runs — a change to `modules.billing.models` should only re-run `modules.billing`'s
  own tests, not every module that happens to import billing's facade.
- **Separate databases per module** (optional, higher-effort): if two modules never need
  to join across their tables in a single SQL query, giving them separate databases (with
  a DB router) makes the facade boundary physical, not just lint-enforced — one module's
  database problems can't take down another's.

## What NOT to copy from PostHog verbatim

- PostHog's scale (dozens of products, years of history) justifies infrastructure (a
  bespoke person-data gRPC service, Rust ingestion tier, multiple ClickHouse clusters)
  that a new project doesn't need on day one. Start with the facade/contracts + tenant
  scoping + self-registration pattern; add a dedicated service for a hot data path only
  once you actually have a hot-path scaling problem, not preemptively.
- Don't introduce Temporal/Celery-workflow infrastructure until you have a concrete
  multi-step, long-running job that needs it. A single `modules/<name>/backend/tasks.py`
  with plain Celery tasks is enough until proven otherwise.
