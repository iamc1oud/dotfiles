#!/usr/bin/env bash
# scaffold_module.sh <module_name>
#
# Creates a new isolated feature module: backend (facade/contracts/presentation)
# + frontend (scene/logic), self-registering into the project scaffolded by
# scaffold_project.sh. Run from the project root.
set -euo pipefail

name="${1:?usage: scaffold_module.sh <module_name> (snake_case, e.g. billing_alerts)}"

if [ ! -d modules ]; then
  echo "Error: ./modules not found — run this from a project scaffolded by scaffold_project.sh" >&2
  exit 1
fi

if [ -e "modules/$name" ]; then
  echo "Error: modules/$name already exists" >&2
  exit 1
fi

# PascalCase for class names, e.g. billing_alerts -> BillingAlerts
Name="$(python3 -c "print(''.join(w.capitalize() for w in '$name'.split('_')))")"

base="modules/$name"
mkdir -p "$base"/backend/facade
mkdir -p "$base"/backend/presentation
mkdir -p "$base"/backend/migrations
mkdir -p "$base"/backend/tests
mkdir -p "$base"/frontend/scenes
mkdir -p "$base"/frontend/logics

touch "$base"/backend/__init__.py
touch "$base"/backend/facade/__init__.py
touch "$base"/backend/presentation/__init__.py
touch "$base"/backend/migrations/__init__.py
touch "$base"/backend/tests/__init__.py

cat > "$base/backend/apps.py" <<'PY'
from django.apps import AppConfig


class {{Name}}Config(AppConfig):
    name = "modules.{{name}}.backend"
    label = "{{name}}"
PY

cat > "$base/backend/models.py" <<'PY'
from django.db import models

from backend.core.scoping.models import TenantScopedModel


class {{Name}}(TenantScopedModel):
    name = models.CharField(max_length=200)

    class Meta:
        app_label = "{{name}}"
PY

cat > "$base/backend/facade/contracts.py" <<'PY'
from dataclasses import dataclass


@dataclass(frozen=True)
class {{Name}}DTO:
    """Frozen DTO — the only object this module returns across its facade boundary.
    Other modules import this, never modules.{{name}}.backend.models directly."""

    id: str
    name: str
PY

cat > "$base/backend/facade/api.py" <<'PY'
from __future__ import annotations

from modules.{{name}}.backend.facade.contracts import {{Name}}DTO
from modules.{{name}}.backend.models import {{Name}}


def get_{{name}}(id: str) -> {{Name}}DTO | None:
    """Public entry point for other modules — never import .models directly outside this module."""
    instance = {{Name}}.objects.filter(id=id).first()
    if instance is None:
        return None
    return {{Name}}DTO(id=str(instance.id), name=instance.name)
PY

cat > "$base/backend/presentation/serializers.py" <<'PY'
from rest_framework import serializers


class {{Name}}Serializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    name = serializers.CharField()
PY

cat > "$base/backend/presentation/views.py" <<'PY'
from drf_spectacular.utils import extend_schema
from rest_framework import viewsets

from backend.core.scoping.mixin import TenantScopedViewSetMixin
from modules.{{name}}.backend.models import {{Name}}
from modules.{{name}}.backend.presentation.serializers import {{Name}}Serializer


class {{Name}}ViewSet(TenantScopedViewSetMixin, viewsets.ModelViewSet):
    serializer_class = {{Name}}Serializer

    def get_queryset(self):
        # Not a class-level `queryset = {{Name}}.objects.all()`: that attribute is
        # evaluated once at import time, before any request has set tenant scope, and
        # the fail-closed TenantScopedManager raises immediately. get_queryset() defers
        # the query until DRF calls it per-request, after initial() has entered scope.
        return {{Name}}.objects.all()

    @extend_schema(summary="List {{name}}")
    def list(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)
PY

cat > "$base/backend/routes.py" <<'PY'
from backend.core.routing.registry import RouterRegistry
from modules.{{name}}.backend.presentation.views import {{Name}}ViewSet


def register_routes(registry: RouterRegistry) -> None:
    registry.projects.register(r"{{name}}", {{Name}}ViewSet, basename="project_{{name}}")
PY

cat > "$base/frontend/logics/{{name}}SceneLogic.ts" <<'TS'
import { actions, kea, listeners, path, reducers, selectors } from 'kea'

export const {{name}}SceneLogic = kea([
    path(['modules', '{{name}}', 'frontend', 'logics', '{{name}}SceneLogic']),
    actions({
        setSelected: (id: string | null) => ({ id }),
    }),
    reducers({
        selected: [
            null as string | null,
            {
                setSelected: (_: string | null, { id }: { id: string | null }) => id,
            },
        ],
    }),
    selectors({
        hasSelection: [(s: any) => [s.selected], (selected: string | null) => selected !== null],
    }),
    listeners(() => ({
        setSelected: () => {
            // side effects: analytics, routing, etc.
        },
    })),
])
TS

cat > "$base/frontend/scenes/{{Name}}Scene.tsx" <<'TSX'
import { useActions, useValues } from 'kea'

import { {{name}}SceneLogic } from '../logics/{{name}}SceneLogic'

export function {{Name}}Scene(): JSX.Element {
    const { selected, hasSelection } = useValues({{name}}SceneLogic)
    const { setSelected } = useActions({{name}}SceneLogic)

    return (
        <div>
            <h1>{{Name}}</h1>
            <p>{hasSelection ? `Selected: ${selected}` : 'Nothing selected'}</p>
            <button onClick={() => setSelected(hasSelection ? null : 'example')}>
                {hasSelection ? 'Clear selection' : 'Select example'}
            </button>
        </div>
    )
}
TSX

cat > "$base/frontend/index.ts" <<'TS'
import { registerScene } from '../../../frontend/src/app/sceneRegistry'

import { {{Name}}Scene } from './scenes/{{Name}}Scene'

registerScene('{{name}}', {
    name: '{{Name}}',
    path: '/{{name}}',
    component: {{Name}}Scene,
})
TS

cat > "$base/module.yaml" <<'YAML'
name: {{name}}
owner: <team-or-you>
description: <one-line description of what this module does>
YAML

# Substitute placeholders across every generated file's contents
grep -rl '{{name}}\|{{Name}}' "$base" | while read -r f; do
  sed -i '' "s/{{name}}/$name/g; s/{{Name}}/$Name/g" "$f"
done

# Substitute placeholders in filenames themselves (e.g. {{Name}}Scene.tsx -> BillingAlertsScene.tsx)
find "$base" -depth -name '*{{name}}*' -o -name '*{{Name}}*' | while read -r f; do
  newname="$(dirname "$f")/$(basename "$f" | sed "s/{{name}}/$name/g; s/{{Name}}/$Name/g")"
  mv "$f" "$newname"
done

echo ""
echo "Module scaffolded at $base"
echo "Next steps:"
echo "  1. Add \"modules.$name.backend.apps.${Name}Config\" to MODULES_APPS in backend/config/settings/web.py"
echo "  2. ./manage.py makemigrations $name && ./manage.py migrate"
echo "  3. Regenerate OpenAPI + TypeScript types (see references/backend-conventions.md)"
echo "  4. Run kea-typegen so ${name}SceneLogic.ts gets its generated type import"
