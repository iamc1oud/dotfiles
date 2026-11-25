# Modular settings

Derived from PostHog's `posthog/settings/` (30+ files) and `posthog/settings/web.py`'s
`PRODUCTS_APPS` list. Two related but distinct problems, solved differently:

## Problem 1: one sprawling `settings.py` becomes unreviewable

Split by **concern**, not by module — `database.py`, `web.py` (apps/middleware/routing),
`integrations.py`, `email.py`, etc. A settings change's blast radius stays scoped to the
file that owns that concern, and each concern's env vars, defaults, and the comments
explaining *why* a default is what it is live together, instead of interleaved with
every other concern in one file.

`backend/config/settings/__init__.py` merges every file into one namespace:

```python
# isort: skip_file
from .overrides import *        # imported first — see below
from .utils import *
from .base_variables import *
from .database import *
from .web import *
```

`# isort: skip_file` matters — these imports must run in this order (each later file
can depend on names the earlier ones defined), and isort would otherwise alphabetize
them and break that.

Adding a new concern (a message queue, a third-party integration) costs one new file
plus one import line in `__init__.py` — small, explicit, and easy to review; not
"nothing to touch," but this concern doesn't need to be zero-edit the way module route
registration does, because it happens once per *concern*, not once per *module*.

### `overrides.py` — imported first, on purpose

PostHog's `posthog/settings/overrides.py` is imported before anything else specifically
because it *mutates environment variables* (forcing `DEBUG=1`/`TEST=1` under pytest)
that every other settings module reads via `get_from_env`. Anything that needs to run
before other settings modules can trust their own env reads goes here — nowhere else.

### `base_variables.py` — compute derived flags once

`DEBUG`, `TEST`, and similar flags get computed **once**, in one file, and every other
settings module imports them from there rather than re-deriving them. PostHog's real
version (`posthog/settings/base_variables.py`) is worth reading for the pattern even
though your project's specific flags will differ: `BASE_DIR`, `DEBUG`, `TEST`, plus
project-specific ones like `CLOUD_DEPLOYMENT` or `IS_INTERACTIVE_SHELL`. Getting this
wrong (recomputing `TEST` slightly differently in two files) is a real bug class —
one file silently disagreeing with another about "are we in a test run" causes
hard-to-reproduce CI-only failures.

### `get_from_env` — one helper, not ad hoc `os.getenv` everywhere

```python
def get_from_env(key, default=None, *, optional=False, type_cast=None):
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
```

Fails loudly (raises) on a genuinely required env var with no default, rather than
booting with `None` and failing later somewhere unrelated. Every settings file uses
this instead of raw `os.getenv(...) or default` so "required vs optional vs
type-cast" is one consistent shape across the whole settings tree.

### Environment-conditional values live next to the setting, not in a branch far away

PostHog's `posthog/settings/object_storage.py` branches `OBJECT_STORAGE_ENDPOINT`
on `TEST or DEBUG` right where the setting is defined, with a comment explaining
*why* dev/test needs a different default (`objectstorage:19000`, a docker-compose
service name) than prod (empty — reached via IAM role, not a keyed endpoint). Put
this kind of environment-specific branching in the settings file for that concern,
with the reasoning in a comment — don't push it into a separate "environments/"
config layer that forces a reader to jump files to see why a value differs by env.

### Optional/conditional apps — the `ee.py` pattern

PostHog conditionally appends an enterprise app if it's importable:

```python
try:
    from ee.apps import EnterpriseConfig
except ImportError:
    pass
else:
    INSTALLED_APPS.append("ee.apps.EnterpriseConfig")
```

Use this shape for any optional tier of your own platform (a paid-only app, a
dev-only tool like `django_extensions`) — the base settings tree works standalone,
and the optional piece layers on top only when present, rather than every deployment
needing to know whether to import it.

## Problem 2: registering a module's Django app is a required manual edit

This is the piece [architecture.md](architecture.md) and route auto-discovery don't
solve, and can't: `INSTALLED_APPS` must be fully populated at `django.setup()` time —
before models, migrations, or any app-config loop can run — so there is no "scan
`modules/` and find `AppConfig`s" trick available the way there is for routes (which
register in a loop that runs *after* `django.setup()`, on first URL resolution — see
`backend/core/routing/registry.py` and its docstring on why the two use different
timing).

PostHog handles this with an explicit, hand-maintained list —
`posthog/settings/web.py`'s `PRODUCTS_APPS` — rather than pretending it's automatic:

```python
# TODO: Automatically generate these like we do for the frontend
PRODUCTS_APPS = [
    "products.feature_flags.backend.apps.FeatureFlagsConfig",
    "products.experiments.backend.apps.ExperimentsConfig",
    ...
]
INSTALLED_APPS = [..., *PRODUCTS_APPS, ...]
```

The scaffold mirrors this exactly as `MODULES_APPS` in
`backend/config/settings/web.py`. `scripts/scaffold_module.sh` prints the line to add
as its first "next step" — it's the one piece of module registration that genuinely
can't be automated away, so make it a one-line, hard-to-miss addition rather than a
silent requirement.

If your project later needs true auto-generation (PostHog's own TODO), the mechanism
would be a build step that globs `modules/*/backend/apps.py` and writes
`MODULES_APPS` as generated output — not a runtime discovery loop, since the
ordering constraint (`INSTALLED_APPS` before `django.setup()` finishes) doesn't go
away just because the list is generated instead of hand-written.
