---
name: google-python-style
description: Write or review Python following Google Python Style Guide with Ruff. Use when writing Python, reviewing Python, scaffolding Python projects, or creating AGENTS.md for Python repos.
---

# Google Python Style

Distilled from **Google Python Style Guide** (`https://google.github.io/styleguide/pyguide.html`,
source: `https://github.com/google/styleguide/blob/gh-pages/pyguide.md`).
Full guide is normative on conflicts.
Formatter and linter: `ruff` (`ruff format` + `ruff check`). Google rules below still apply; Ruff enforces them where possible.

When asked to create an `AGENTS.md` for a Python project, save the guide below (minus project-specific notes) as `AGENTS.md` in the project root, then append a short repo-specific section (entry point, Python version, key conventions).

## 1. Language rules

### Lint — always run `ruff`
- Run `ruff check` and `ruff format --check` on all changed code; fix before committing.
- Suppress false positives inline with reason: `def do_PUT(self):  # noqa: N802 -- WSGI name`.
- Prefer file-level `per-file-ignores` in `pyproject.toml` over scattered `noqa` where the pattern repeats.
- For unused args, `del unused_arg  # Unused.` at top of function. `_` / `unused_` prefixes allowed but discouraged (break named-arg callers).

### Imports — modules/packages only
- `import x` for packages/modules. `from x import y` only where `x` is package prefix and `y` is module name.
- `from x import y as z` when: name clash, clash with public API param (e.g. `features`), inconveniently long, or too generic (`from storage.file_system import options as fs_options`).
- `import y as z` only for standard abbreviations (`import numpy as np`).
- No relative imports — use full package path even in same package (avoids double-import).
- Exempt from module-only rule: `typing`, `collections.abc`, `typing_extensions` symbols.
- Import full pathname: `from absl import flags` / `import absl.flags`, never bare `import jodie`. Don't assume binary dir is on `sys.path`.

### Packages, exceptions
- Every new import uses full package name.
- Use built-in exceptions where fitting (`ValueError` for precondition violations).
- Never use `assert` for logic/preconditions (removable without breakage). `assert` OK in pytest tests and as non-load-bearing sanity check with message.
- Libraries define `*Error` subclasses of existing exceptions; avoid repetition (`foo.FooError`).
- No bare `except:` / `except Exception:` unless re-raising or an isolation point that logs + suppresses (e.g. thread guard).
- Keep `try` bodies minimal; use `finally` for cleanup.

### State, nesting, comprehensions
- Avoid mutable global state. If unavoidable: module-level `_PRIVATE` name, access via public functions, comment the rationale. Public constants `ALL_CAPS_WITH_UNDERSCORES` are encouraged.
- Nested functions/classes only to close over a local (other than `self`/`cls`). Don't nest just to hide — use module-level `_private` so tests can reach it.
- Comprehensions: single `for` + optional `if` only. Multiple `for`s / filters → explicit loops. Optimize for readability.
- Use default iterators/operators: `for k in d`, `if x in lst`, `for line in f`, `for k, v in d.items()`. Never `d.keys()`, `f.readlines()`.

### Functions
- Generators: fine; document with `Yields:` not `Returns:`. Wrap resource-holding generators in a context manager (PEP-533).
- Lambdas: one-liners only (<60–80 chars). Prefer `operator.mul` over `lambda x, y: x*y`; prefer genexps over `map/filter+lambda`.
- Ternary `x if c else y`: each part must fit on one line; otherwise full `if`.
- Default args: never mutable (`[]`, `{}`, `time.time()`, `FLAGS.value`). Use `None` sentinel + `if b is None: b = []`. `()` tuple default OK (immutable).
- Properties via `@property` only for cheap, unsurprising computed access; never to just proxy an attribute (make it public instead). No subclass-critical logic in properties; no manual descriptors (power feature).
- Truthiness: `if foo:` / `if not seq:` preferred. Exceptions: `if foo is None:` for None checks; `if not x:` never `x == False`; integers: `if i % 10 == 0:` (not `if not i % 10:`); numpy: `if not arr.size`. Note `'0'` is truthy.
- Decorators: judicious, documented ("this is a decorator"), unit-tested, no I/O at import time. No `staticmethod` (use module function); `classmethod` only for named constructors / process-wide cache routines.
- Threading: don't rely on GIL-atomicity of builtins. Use `queue.Queue`, `threading.Condition` over raw locks.
- No power features: metaclasses, bytecode, dynamic inheritance, import hacks, `getattr` tricks, `__del__` cleanup, sys internals. Stdlib uses (`abc`, `dataclasses`, `enum`) are fine.
- `from __future__ import ...` encouraged where needed; don't remove until env is modern-only.
- Type-annotate all new/modified public APIs; type-check with pytype. If blocked, leave `TODO(bug-link)` comment.

## 2. Style rules

- **Semicolons:** never; one statement per line.
- **Line length:** 80 max. Exceptions: long imports, URLs/paths/flags in comments, unsplittable string constants, `noqa` comments. Break via implicit paren/bracket/brace joining — never backslash continuations. Prefer breaking at highest syntactic level; docstring summary ≤80.
  ```python
  Yes: foo_bar(self, width, height, color='black', design=None, x='foo',
               emphasis=None, highlight=0)
  Yes: x = ('This will build a very long long '
            'long long long long long long string')
  No:  if width == 0 and height == 0 and \
           color == 'red' ...
  ```
- **Parentheses:** sparing. `if foo:` not `if (x):`; `return foo`, `return spam, beans` not `return (foo)`. `(foo,)` for 1-tuple is good.
- **Indentation:** 4 spaces, no tabs. Continuations align with opening delimiter or 4-space hanging indent, nothing after opening delimiter on first line of hanging indent.
- **Trailing commas:** required when closing `]`, `)`, `}` is on its own line (and for 1-tuples); signals Ruff format to explode one-per-line.
- **Blank lines:** 2 between top-level defs; 1 between methods and between class docstring and first method; none right after `def`; single blanks inside functions as judged.
- **Whitespace:** `spam(ham[1], {'eggs': 2}, [])`; `if x == 4:`, `x, y = y, x`; `dict['key']`, `spam(1)` — no space before `(/[/:;,`. No trailing whitespace. Single spaces around `=`/comparisons/booleans. No space around `=` for kwargs/defaults — except with annotations: `def f(x: int = 0)`. Never vertically align tokens across lines.
- **Shebang:** only on directly-executed entry points: `#!/usr/bin/env python3`.
- **Docstrings:** every module/class/function needs `"""` docstring. First line = summary ≤80 chars ending `.`/`?`/`!`, then blank line, then rest. Use `Args:`/`Returns:`/`Yields:`/`Raises:` sections. Test `test_*` methods and `TestCase` subclasses may omit docstrings.
  ```python
  """One-line summary, terminated by a period.

  Details, usage:
    foo = ClassFoo()
    bar = foo.function_bar()
  """
  def connect_to_next_port(self, minimum: int) -> int:
      """Connects to the next available port.

      Args:
        minimum: A port value greater or equal to 1024.

      Returns:
        The new minimum port.

      Raises:
        ConnectionError: If no available port is found.
      """
  ```
  Block/inline comments: `#` + space, full sentences, correct spelling/grammar. Use `# TODO(username): message (bug-id)` format.
- **Strings:** single or double consistently within file; prefer `'''` for multiline only when needed. Use f-strings / `%` / `.format` per file convention. Logging: `logging.info('msg %s', arg)` — no f-strings in logging calls. Error messages: no abbreviations, no trailing punctuation in exceptions unless user-facing sentence.
- **Resources:** always close files/sockets via `with` / context managers, even on error paths.
- **Imports formatting:** stdlib, third-party, first-party groups, alphabetical, one per line; `from` imports after plain `import`s within group. No wildcard `import *`.
- **Statements:** one per line; no `if x: return y` on one line. Guard clauses OK.
- **Accessors:** no trivial getters/setters — make the attribute public. Use `@property` only for cheap computed access.
- **Naming:**
  | Kind | Convention | Example |
  |---|---|---|
  | Packages/modules | `lower_snake` | `my_module` |
  | Functions/methods/args/locals | `lower_snake` | `my_function` |
  | Classes/exceptions | `CapWords` | `MyClass`, `MyError` |
  | Constants | `ALL_CAPS` | `MAX_COUNT` |
  | Globals (mutable, avoid) | `_PRIVATE` | `_CACHE` |
  Avoid: single `l/O/I`, generic `foo/bar` in real code, type-encoded names (`str_name`), and shadowing builtins.
  File names: `lower_snake.py`, test files `*_test.py`.
- **`main()`:** all executables end with:
  ```python
  def main(argv: Sequence[str] | None = None) -> None: ...
  if __name__ == '__main__':
      main()
  ```
  No top-level side-effect code besides imports/constants/flags.
- **Function length:** keep focused/small; extract helper if >~40 lines or deeply nested.
- **Type annotations:** annotate args + returns on all public functions; `X | None` for nullable (not `Optional` in new code unless 3.9 compat needed); type aliases in `CapWords`; `TypeVar`s prefixed `T`/`_T`; string types as `str` (bytes explicit); put typing-only imports under `if TYPE_CHECKING:` to avoid cycles; use `.pyi` stubs for third-party/C-extensions.
