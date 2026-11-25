#!/usr/bin/env bash
# scaffold_project.sh <project_name>
#
# Creates the root monorepo skeleton for a PostHog-pattern multi-module platform:
# fail-closed tenant scoping, self-registering module routes, self-registering
# frontend scenes. See ../references/architecture.md for the rationale.
set -euo pipefail

PROJECT_NAME="${1:?usage: scaffold_project.sh <project_name>}"

if [ -e "$PROJECT_NAME" ]; then
  echo "Error: $PROJECT_NAME already exists" >&2
  exit 1
fi

mkdir -p "$PROJECT_NAME"/backend/config/settings
mkdir -p "$PROJECT_NAME"/backend/core/scoping
mkdir -p "$PROJECT_NAME"/backend/core/routing
mkdir -p "$PROJECT_NAME"/modules
mkdir -p "$PROJECT_NAME"/frontend/src/app
mkdir -p "$PROJECT_NAME"/packages/ui
mkdir -p "$PROJECT_NAME"/docs

cd "$PROJECT_NAME"

touch backend/__init__.py backend/core/__init__.py backend/config/__init__.py
touch backend/core/scoping/__init__.py backend/core/routing/__init__.py
touch modules/.gitkeep

# --- manage.py ---

cat > manage.py <<'PY'
#!/usr/bin/env python
import os
import sys


def main() -> None:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "backend.config.settings")
    from django.core.management import execute_from_command_line

    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
PY
chmod +x manage.py

# --- backend/config/settings: modular settings, one file per concern ---
# Mirrors PostHog's posthog/settings/ — split by domain instead of one sprawling
# settings.py, merged into a single namespace by __init__.py. See
# ../references/settings-architecture.md for the full rationale.

cat > backend/config/settings/utils.py <<'PY'
from __future__ import annotations

import os
from collections.abc import Callable
from typing import Any


def get_from_env(key: str, default: Any = None, *, optional: bool = False, type_cast: Callable | None = None) -> Any:
    value = os.getenv(key)
    if value is None or value == "":
        if optional:
            return None
        if default is not None:
            return default
        raise RuntimeError(f'The environment variable "{key}" is required to run this project!')
    if type_cast is not None:
        return type_cast(value)
    return value


def get_list(text: str) -> list[str]:
    if not text:
        return []
    return [item.strip() for item in text.split(",")]


def str_to_bool(value: object) -> bool:
    if isinstance(value, bool):
        return value
    return str(value).lower() in ("y", "yes", "t", "true", "on", "1")
PY

cat > backend/config/settings/overrides.py <<'PY'
"""
Imported first by __init__.py, before any other settings module — mirrors PostHog's
posthog/settings/overrides.py. Sets env vars that other settings modules (starting
with base_variables.py) depend on reading correctly, e.g. forcing DEBUG/TEST on
under pytest even if the environment didn't set them.
"""

import os
import sys

runner = sys.argv[0] if sys.argv else ""
cmd = sys.argv[1] if len(sys.argv) > 1 else None

if cmd == "test" or runner.endswith("pytest"):
    os.environ.setdefault("DEBUG", "1")
    os.environ.setdefault("TEST", "1")
PY

cat > backend/config/settings/base_variables.py <<'PY'
"""
Env-derived flags every other settings module reads — computed once here so
DEBUG/TEST mean the same thing everywhere instead of each file re-deriving them
(and risking a slightly different answer). Mirrors PostHog's
posthog/settings/base_variables.py.
"""

import os
import sys

from .utils import get_from_env, str_to_bool

BASE_DIR: str = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DEBUG: bool = get_from_env("DEBUG", False, type_cast=str_to_bool)
TEST: bool = get_from_env(
    "TEST",
    "pytest" in (sys.argv[0] if sys.argv else ""),
    type_cast=str_to_bool,
)
SECRET_KEY: str = get_from_env("SECRET_KEY", "insecure-dev-key-change-me")
PY

cat > backend/config/settings/database.py <<'PY'
"""Database connection settings — separate from web.py so extending to a second
database (e.g. a module on its own DB, mirroring PostHog's PRODUCT_DB_WRITER_URLS)
touches only this file."""

import os

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.getenv("DATABASE_NAME", "postgres"),
        "USER": os.getenv("DATABASE_USER", "postgres"),
        "PASSWORD": os.getenv("DATABASE_PASSWORD", "postgres"),
        "HOST": os.getenv("DATABASE_HOST", "localhost"),
        "PORT": os.getenv("DATABASE_PORT", "5432"),
    }
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
PY

cat > backend/config/settings/web.py <<'PY'
"""
Web app settings: installed apps, middleware, routing.

MODULES_APPS is a hand-maintained list, one entry per feature module's AppConfig —
mirrors PostHog's posthog/settings/web.py PRODUCTS_APPS list. This is deliberately
NOT auto-discovered: Django needs INSTALLED_APPS fully populated at django.setup()
time, before any app-config loop can run, so there is no "loop over modules/ and
find AppConfigs" trick available here the way there is for route registration
(backend/core/routing/registry.py runs its discovery loop AFTER apps are ready).
Add one line here whenever scripts/scaffold_module.sh creates a new module.
"""

MODULES_APPS: list[str] = [
    # "modules.billing_alerts.backend.apps.BillingAlertsConfig",
]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.postgres",
    "rest_framework",
    "drf_spectacular",
    "django_filters",
    *MODULES_APPS,
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

REST_FRAMEWORK = {
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

ROOT_URLCONF = "backend.config.urls"
PY

cat > backend/config/settings/__init__.py <<'PY'
# isort: skip_file
#
# Modular settings — one file per concern instead of one sprawling settings.py,
# merged here into a single namespace. Mirrors PostHog's posthog/settings/__init__.py.
# A settings change's blast radius stays scoped to the file that owns that concern;
# adding a new concern (e.g. a message queue, a third-party integration) means adding
# one new file here and one import line below — the same "one manual edit" tradeoff
# class as MODULES_APPS in web.py.

# Imported first: may set env vars that every module below depends on reading
# correctly (see overrides.py's docstring).
from .overrides import *  # noqa: F401,F403

from .utils import *  # noqa: F401,F403
from .base_variables import *  # noqa: F401,F403
from .database import *  # noqa: F401,F403
from .web import *  # noqa: F401,F403
PY

cat > backend/config/urls.py <<'PY'
from django.contrib import admin
from django.urls import include, path

from backend.core.routing.registry import build_routers

routers = build_routers()

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include(routers.root.urls)),
    path("api/projects/<int:project_id>/", include(routers.projects.urls)),
    path("api/organizations/<int:organization_id>/", include(routers.organizations.urls)),
]
PY

# --- backend/core/scoping: fail-closed tenant scoping ---

cat > backend/core/scoping/context.py <<'PY'
from __future__ import annotations

from contextlib import contextmanager
from contextvars import ContextVar

_current_tenant_id: ContextVar[int | None] = ContextVar("current_tenant_id", default=None)


class TenantScopeError(Exception):
    """Raised when a tenant-scoped query runs with no tenant context set."""


@contextmanager
def tenant_scope(tenant_id: int):
    token = _current_tenant_id.set(tenant_id)
    try:
        yield
    finally:
        _current_tenant_id.reset(token)


def get_current_tenant_id() -> int:
    tenant_id = _current_tenant_id.get()
    if tenant_id is None:
        raise TenantScopeError("No tenant context set — wrap the call in `with tenant_scope(tenant_id):`")
    return tenant_id


def with_tenant_scope():
    """Decorator for task entry points (Celery/RQ/etc) whose first arg is tenant_id."""

    def decorator(fn):
        def wrapper(tenant_id, *args, **kwargs):
            with tenant_scope(tenant_id):
                return fn(tenant_id, *args, **kwargs)

        return wrapper

    return decorator
PY

cat > backend/core/scoping/models.py <<'PY'
from django.db import models

from .context import get_current_tenant_id


class TenantScopedManager(models.Manager):
    """Default manager — every query auto-filtered to the current tenant context.
    Fail-closed: raises TenantScopeError rather than silently returning all tenants' rows.

    Gotcha: never reference this manager in a class-level attribute that Python
    evaluates at import time — e.g. a DRF viewset's `queryset = Model.objects.all()`.
    That runs before any request has entered tenant scope, so it raises immediately at
    import/URL-resolution time. Use `get_queryset(self)` instead; DRF calls it lazily,
    per-request, after scope is already entered (see the generated viewset template).
    """

    def get_queryset(self):
        return super().get_queryset().filter(tenant_id=get_current_tenant_id())


class UnscopedManager(models.Manager):
    """Escape hatch for genuine cross-tenant access (admin tooling, migrations).
    Named loudly on purpose — should never be reached by autocomplete accident.
    """


class TenantScopedModel(models.Model):
    tenant_id = models.BigIntegerField(db_index=True)

    objects = TenantScopedManager()
    all_tenants = UnscopedManager()

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        if not self.tenant_id:
            self.tenant_id = get_current_tenant_id()
        super().save(*args, **kwargs)
PY

cat > backend/core/scoping/mixin.py <<'PY'
from .context import tenant_scope


class TenantScopedViewSetMixin:
    """Mix into every module's ModelViewSet. Resolve request.tenant_id however your
    auth/middleware layer determines the current tenant (subdomain, header, session)."""

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        self._tenant_scope_cm = tenant_scope(request.tenant_id)
        self._tenant_scope_cm.__enter__()

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        self._tenant_scope_cm.__exit__(None, None, None)
        return response
PY

# --- backend/core/routing: module route auto-discovery ---

cat > backend/core/routing/registry.py <<'PY'
"""
Module route registry — mirrors PostHog's posthog/api/routing.py + rest_router.py.

Each module exposes modules.<name>.backend.routes.register_routes(registry).
Core builds the router once and calls every module's register_routes() —
adding a module never requires editing this file.

Three flat DefaultRouters, not a nested-router library: `projects`/`organizations`
are mounted at a manually specified URL prefix in urls.py (`api/projects/<project_id>/`)
rather than derived from a parent-registered resource. drf-nested-routers'
NestedDefaultRouter looks up its URL prefix from an already-registered viewset on the
parent router — since core registers no "projects" viewset on `root` (there may be no
core Project model at all), that lookup fails at import time. A flat router mounted at
an explicit path sidesteps the dependency and the failure mode entirely; a module's
viewset reads `self.kwargs["project_id"]` the same way it would with a nested router.
"""

from django.apps import apps
from rest_framework.routers import DefaultRouter


class RouterRegistry:
    """Handle passed to modules. Modules may only nest onto these parents —
    never define new top-level parents — so registration order never matters."""

    def __init__(self):
        self.root = DefaultRouter()
        self.projects = DefaultRouter()
        self.organizations = DefaultRouter()


def build_routers() -> RouterRegistry:
    registry = RouterRegistry()

    for app_config in apps.get_app_configs():
        if not app_config.name.startswith("modules."):
            continue
        try:
            routes_module = __import__(f"{app_config.name}.routes", fromlist=["register_routes"])
        except ModuleNotFoundError:
            continue
        routes_module.register_routes(registry)

    return registry
PY

# --- frontend: scene auto-discovery ---

cat > frontend/src/app/sceneRegistry.ts <<'TS'
import type { ComponentType } from 'react'

export interface SceneConfig {
    name: string
    path: string
    component: ComponentType
}

const registry = new Map<string, SceneConfig>()

export function registerScene(key: string, config: SceneConfig): void {
    if (registry.has(key)) {
        throw new Error(`Scene "${key}" already registered`)
    }
    registry.set(key, config)
}

export function getScenes(): SceneConfig[] {
    return Array.from(registry.values())
}
TS

cat > frontend/src/app/scenes.ts <<'TS'
// registerScene/getScenes live in sceneRegistry.ts, not here — this file eagerly
// glob-imports every module's frontend/index.ts below, and those files call
// registerScene. If registerScene lived in this file, that's a circular import:
// Vite's import.meta.glob transform hoists its synthesized imports to the very top
// of the compiled output (ahead of anything else, regardless of source order), so
// every module's index.ts would run — and call registerScene — before this file's
// own `const registry = new Map()` had executed, a TDZ crash ("Cannot access
// 'registry' before initialization"). Modules import registerScene straight from
// sceneRegistry.ts to avoid the cycle entirely; this re-export is just a
// convenience for App.tsx, which isn't part of that cycle.
export { getScenes, registerScene } from './sceneRegistry'
export type { SceneConfig } from './sceneRegistry'

// Auto-discover every module's frontend entry point — a module becomes routable
// just by existing under modules/*/frontend/index.ts, no edit needed here.
// Swap this glob for your bundler's equivalent if you're not on Vite (see
// references/frontend-conventions.md).
import.meta.glob('/modules/*/frontend/index.ts', { eager: true })
TS

cat > frontend/src/app/App.tsx <<'TSX'
import { Route, Routes } from 'react-router-dom'
import { getScenes } from './scenes'

export function App(): JSX.Element {
    return (
        <Routes>
            {getScenes().map(({ path, component: Component }) => (
                <Route key={path} path={path} element={<Component />} />
            ))}
        </Routes>
    )
}
TSX

# --- docker-compose skeleton ---

cat > docker-compose.yml <<'YML'
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
  redis:
    image: redis:7
    ports:
      - "6379:6379"
YML

cat > README.md <<MD
# $PROJECT_NAME

Scaffolded with the \`create-project\` skill (PostHog product-module pattern).
See \`docs/architecture.md\` for the module isolation contract before adding a module —
run \`scripts/scaffold_module.sh <name>\` to add one.
MD

echo ""
echo "Project scaffolded at ./$PROJECT_NAME"
echo "Next steps:"
echo "  1. pip install django djangorestframework psycopg2-binary drf-spectacular django-filter"
echo "  2. ./manage.py check   # settings + urls are already wired (backend/config/settings/, backend/config/urls.py)"
echo "  3. Bootstrap Vite at the MONOREPO ROOT, not inside frontend/ — scenes.ts's"
echo "     import.meta.glob('/modules/*/frontend/index.ts') resolves that leading"
echo "     slash relative to Vite's root, and modules/ is a sibling of frontend/, not"
echo "     nested inside it. So: package.json, vite.config.ts, index.html, tsconfig.json"
echo "     all live at repo root; index.html's <script> points at /frontend/src/main.tsx."
echo "     A plain 'npm create vite@latest frontend' scaffolds frontend/ as its own"
echo "     Vite root and the glob will silently match nothing."
echo "  4. Read references/architecture.md + references/settings-architecture.md"
echo "  5. Run scripts/scaffold_module.sh <name> for your first module"
