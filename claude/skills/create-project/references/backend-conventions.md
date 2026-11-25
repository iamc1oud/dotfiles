# Backend wiring (Django + DRF)

## Dependencies

```
django
djangorestframework
psycopg2-binary          # or psycopg[binary] — Postgres driver for DATABASES ENGINE=postgresql
drf-spectacular          # OpenAPI schema generation
drf-spectacular[sidecar] # optional: bundled Swagger UI
django-filter             # DEFAULT_FILTER_BACKENDS, if you use it on viewsets
```

`RouterRegistry` uses plain DRF `DefaultRouter`s for `root`/`projects`/`organizations`,
not `drf-nested-routers` — see the docstring in `backend/core/routing/registry.py` for
why (its `NestedDefaultRouter` requires the parent router to already have a registered
resource matching the nesting prefix; a minimal scaffold with no core `Project` model
has nothing to register there, so that lookup fails at import time). `projects` and
`organizations` are instead mounted at an explicit path in `urls.py`
(`api/projects/<int:project_id>/`), and a module's viewset reads
`self.kwargs["project_id"]` directly.

## The router registry and `urls.py`

`scaffold_project.sh` already wires this — `backend/core/routing/registry.py`'s
`build_routers()` is called from the generated `backend/config/urls.py`. No further
edits to `urls.py` are needed when a module is added: `build_routers()` discovers
`modules.*.backend.routes.register_routes` automatically at first URL resolution.
See [settings-architecture.md](settings-architecture.md) for why this can be
automatic while Django app registration (below) can't.

## Wiring tenant scope into the request lifecycle

Set the tenant context once per request, in a DRF viewset mixin or middleware:

```python
# backend/core/scoping/mixin.py
from rest_framework.viewsets import GenericViewSet
from .context import tenant_scope


class TenantScopedViewSetMixin(GenericViewSet):
    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        self._tenant_scope_cm = tenant_scope(request.tenant_id)  # however you resolve tenant from request
        self._tenant_scope_cm.__enter__()

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        self._tenant_scope_cm.__exit__(None, None, None)
        return response
```

Have every module's `ModelViewSet` inherit `TenantScopedViewSetMixin` alongside DRF's own
base classes, or fold it into a project-wide base viewset that all modules already use.

For background jobs, wrap the task entry point:

```python
from backend.core.scoping.context import with_tenant_scope

@shared_task
@with_tenant_scope()
def process_something(tenant_id: int, other_arg: str) -> None:
    ...
```

## OpenAPI + generated TypeScript pipeline

`drf_spectacular` and `DEFAULT_SCHEMA_CLASS` are already set in the generated
`backend/config/settings/web.py`. Remaining steps:

1. Add a schema view: `path("api/schema/", SpectacularAPIView.as_view())` in
   `backend/config/urls.py`.
2. Generate the spec: `./manage.py spectacular --file openapi.json`.
3. Generate TypeScript from the spec into each module's `frontend/generated/` — pick one:
   - `openapi-typescript openapi.json -o frontend/generated/api.schemas.ts` (types only)
   - `orval` (types + a typed client + optionally Zod schemas) if you want request
     validation on the frontend too, not just types.
4. Script steps 2-3 together (`scripts/build_types.sh` or an npm script) and run it in
   CI to fail if committed generated files are stale.

Annotate every non-trivial viewset action with `@extend_schema(...)` — without it,
drf-spectacular emits an empty request/response schema for hand-validated actions, and
the generated TypeScript type will be wrong (typically `unknown` or missing entirely).

## Registering a module's Django app — `MODULES_APPS`

Each module's Django app lives at `modules.<name>.backend`, with an `AppConfig` in
`apps.py` (written by `scaffold_module.sh`). Add its dotted path to `MODULES_APPS` in
`backend/config/settings/web.py`:

```python
MODULES_APPS: list[str] = [
    "modules.billing.backend.apps.BillingConfig",
    "modules.notifications.backend.apps.NotificationsConfig",
]
```

This is the one line of manual wiring `scaffold_module.sh` can't do for you
automatically — Django needs `INSTALLED_APPS` fully populated at `django.setup()`
time, before any discovery loop could run, so unlike route registration this can't be
made automatic without a separate code-generation step. See
[settings-architecture.md](settings-architecture.md) for the full reasoning and how
PostHog's own `PRODUCTS_APPS` handles the same constraint. Everything downstream of
this one line (routes, migrations, admin) follows automatically.
