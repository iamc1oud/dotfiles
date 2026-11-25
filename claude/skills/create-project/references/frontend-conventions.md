# Frontend wiring (React + Kea)

## Dependencies

```
react
react-router-dom
kea               # state management — business logic lives here, not in components
kea-typegen       # generates *LogicType.ts from each *Logic.ts (run in a watch script)
```

## Scene auto-discovery

`scaffold_project.sh` writes `frontend/src/app/sceneRegistry.ts` (the `registerScene()`/
`getScenes()` functions and the registry `Map`) and `frontend/src/app/scenes.ts` (a
Vite `import.meta.glob` call that eagerly imports every `modules/*/frontend/index.ts`,
plus a convenience re-export of `sceneRegistry.ts`'s exports for `App.tsx`). Each
module's `index.ts` (written by `scaffold_module.sh`) calls `registerScene(key, config)`
at module-load time — so a module becomes routable purely by existing, no edit to
`scenes.ts` required.

**Why two files, not one:** modules import `registerScene` back from the app shell,
and `scenes.ts` glob-imports those same modules — a circular import. Vite's
`import.meta.glob` transform hoists its synthesized imports to the very top of the
compiled output, ahead of anything else regardless of source order, so if the registry
(`const registry = new Map()`) lived in `scenes.ts` itself, every module's `index.ts`
would run — and call `registerScene`, reading `registry` — before that line had
executed. That's a TDZ crash (`Cannot access 'registry' before initialization`) that
only shows up at runtime in the browser, never in `tsc`. Keep the registry in the leaf
file (`sceneRegistry.ts`, no imports of its own) and have both modules and `scenes.ts`
import from there — never have a module import `registerScene` from `scenes.ts`.

**Vite root must be the monorepo root, not `frontend/`:** the glob's leading slash
(`/modules/*/frontend/index.ts`) resolves relative to Vite's configured root. Since
`modules/` is a sibling of `frontend/`, not nested inside it, `package.json`,
`vite.config.ts`, `index.html`, and `tsconfig.json` all belong at the repo root, with
`index.html`'s entry script pointing at `/frontend/src/main.tsx`. Scaffolding via a
plain `npm create vite@latest frontend` instead gives `frontend/` its own Vite root,
and the glob will silently match zero modules.

If you're not on Vite, swap the glob for your bundler's equivalent:
- Webpack: `require.context('../../modules', true, /frontend\/index\.ts$/)`
- Next.js: an explicit barrel file listing each module (Next doesn't support glob
  imports at build time the same way) — the one case where you do hand-maintain a
  registration list.

## Wiring the router

```tsx
// frontend/src/app/App.tsx
import { Routes, Route } from 'react-router-dom'
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
```

## Kea logic conventions

- All business logic — state, derived values, side effects — lives in a `*SceneLogic.ts`
  file. Components call `useValues`/`useActions` against the logic; they hold no local
  state of their own beyond pure UI concerns (an input's uncommitted draft value, etc).
- Run `kea-typegen watch` during development — it generates a `<name>SceneLogicType.ts`
  next to each logic file with typed action/reducer/selector signatures. Import that
  type into the `kea<...>([...])` call once generated; the scaffold's template omits it
  until the generator has run once.
- Cross-module dependencies in the frontend go through the same facade discipline as the
  backend: if scene A needs data scene B's logic already fetched, import B's logic and
  its selectors — never reach into B's component internals or duplicate B's API calls.

## Generated API types

Each module's `frontend/generated/` (written by the OpenAPI pipeline — see
`backend-conventions.md`) holds the TypeScript types and/or client for that module's own
endpoints. Import from there, not from hand-written interfaces:

```ts
import type { InvoiceApi } from '../generated/api.schemas'
```

Never hand-edit files under `generated/` — they're build output, regenerated whenever
the backend serializer changes. If a generated type is wrong, the fix is in the Django
serializer (add `help_text`, fix a field type), not in the generated file.

## Shared components: module-local vs shared library

Start with a single shared component library (`packages/ui/` or similar) that every
module imports from — buttons, tables, modals, form inputs. Don't let a module reach
into another module's component internals; if two modules need the same non-trivial
component, promote it to the shared library rather than copy-pasting or cross-importing.
Only reach for a second design system (as PostHog did with quill alongside its older
Lemon components) when you have a concrete, deliberate reason to run two in parallel
(e.g. mid-migration) — otherwise it fragments the UI and every developer has to learn
two ways to build the same kind of control.
