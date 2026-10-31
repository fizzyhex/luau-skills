# Sentinel hooks configuration

The sentinel hooks lint, format and type-check Luau code as Claude edits it.
They are strict typed Luau running on [Lune](https://lune-org.github.io/docs),
and drive three tools from the target project's toolchain:

| Step       | Tool                  | What it does                                                         |
| ---------- | --------------------- | -------------------------------------------------------------------- |
| Format     | StyLua                | Rewrites the edited file in place (the auto-fix).                    |
| Lint       | selene                | Reports diagnostics; `error`-severity lines are surfaced to Claude.  |
| Type check | `luau-lsp analyze`    | Type-checks the edited file and every module that requires it.      |

## Requirements

- `lune` must be runnable from the project directory, because the hooks are
  started as `lune run "${CLAUDE_PLUGIN_ROOT}/hooks/<hook>.luau"`. Either add
  it to the project's `rokit.toml` or install it globally
  (`rokit add --global lune-org/lune`).
- `stylua`, `selene` and `luau-lsp` are resolved from the project directory
  (so Rokit, Aftman or Foreman shims pick up the project's own versions).
- StyLua only runs when a `stylua.toml` or `.stylua.toml` is found between the
  edited file's directory and the project root; selene only runs when a
  `selene.toml` is found the same way. Each tool runs from its config's
  directory, so selene's std files and `.styluaignore` resolve as usual.

Every step degrades gracefully: a missing tool, a missing config, missing
Roblox definitions or a failed `require-graph` skips that step (noted in the
debug log only). The hooks never block the agent because of their own failure;
an internal error is printed to stderr with exit code 1, which Claude Code
treats as non-blocking.

## Settings

Project-local settings live in the YAML frontmatter of
`.claude/sentinel.local.md` (relative to `CLAUDE_PROJECT_DIR`, falling back to
the working directory). Any markdown body is ignored.

```yaml
---
lint-cadence: tiered
max-lint-errors: 20
---
```

If the file is absent, every setting falls back to its default. Unknown keys
are ignored.

| Setting              | Frontmatter key          | Type                                  | Default    | Description |
| -------------------- | ------------------------ | ------------------------------------- | ---------- | ----------- |
| `lint`               | `lint`                   | `boolean`                             | `true`     | Master switch for the lint hooks. When `false`, every lint hook (`PostToolUse`, `PostToolBatch`, `Stop`, `SubagentStop`, `TaskCompleted`) exits immediately. |
| `typecheck`          | `typecheck`              | `boolean`                             | `true`     | Master switch for the typecheck hooks (`PostToolUse` and `Stop`). |
| `stylua`             | `stylua`                 | `boolean`                             | `true`     | Format edited files with StyLua. Formatting failures (usually syntax errors) are surfaced as `error[stylua]` lint issues. |
| `selene`             | `selene`                 | `boolean`                             | `true`     | Lint edited files with selene. |
| `debug`              | `debug`                  | `boolean`                             | `false`    | The `Stop` hooks attach a trace to their output; every other hook appends its trace to `.claude/state/debug.log`. |
| `maxLintAttempts`    | `max-lint-attempts`      | `number`                              | `1`        | Per-file ceiling on consecutive surfaces. At the ceiling the lint hook adds a "fix loop appears stuck" notice and the typecheck hook a CRITICAL "stop editing this file" notice, and the `Stop` hooks stop blocking on that file. The counter resets when the file comes back clean. |
| `maxLintErrors`      | `max-lint-errors`        | `number`                              | `10`       | Maximum number of lint error lines per surface. Overflow is summarised as `+ N more issues — run selene . to see all`. |
| `lintCadence`        | `lint-cadence`           | `"strict" \| "tiered" \| "stop-only"` | `"strict"` | When lint errors are surfaced. See [Cadence modes](#cadence-modes). |
| `lintAutoFixOnBatch` | `lint-auto-fix-on-batch` | `boolean`                             | `true`     | Only used by the `tiered` and `stop-only` cadences. When `true`, `PostToolBatch` silently formats every file edited in the batch with StyLua. |
| `typecheckArgs`      | `typecheck-args`         | comma-separated strings               | `[]`       | Replaces the automatic `luau-lsp analyze` flags (platform, definitions, sourcemap, base `.luaurc`). The hook runs `luau-lsp analyze <args> <files>`, so include every flag you need. |
| `lintGuardAllow`     | `lint-guard-allow`       | comma-separated globs                 | `[]`       | Project-relative globs exempted from the lint guard. See [Lint guard](#lint-guard). |

### Notes on parsing

- Values are read as strings; quotes around them are stripped. Booleans use the
  literal text `true` / `false`. CRLF line endings are accepted.
- `lint`, `typecheck`, `stylua` and `selene` default to enabled; only the
  literal `false` disables them. `debug` defaults to disabled; only the literal
  `true` enables it.
- `typecheck-args` and `lint-guard-allow` are comma-separated; whitespace
  around each entry is trimmed and empty entries are dropped.
- `lint-guard-allow` globs support `*`, `?`, `[...]`, `{a,b}` and `**`, are
  matched against the `/`-separated project-relative path, and compare
  case-insensitively on Windows.
- `lint-cadence` falls back to `strict` for unrecognised values.
- `max-lint-attempts` and `max-lint-errors` fall back to their defaults for
  non-numeric values.

## Type checking

`luau-lsp analyze` runs from the project root on the edited file plus its
transitive dependents. Dependents come from `luau-lsp require-graph`, which
understands require-by-string, `.luaurc` aliases and (with a sourcemap) Roblox
`require(script.Parent...)` paths. The graph covers git-visible Luau files
(tracked and untracked, honouring `.gitignore`, so submodules and installed
`Packages/` are skipped), or the whole project directory outside git.

Unless `typecheck-args` is set, the hook adds:

- `--platform=roblox` or `--platform=standard`. The platform comes from
  `luau-lsp.platform.type` in `.vscode/settings.json` when set; otherwise it
  is `roblox` when the project root has a `sourcemap.json` or any
  `*.project.json`, and `standard` otherwise.
- For Roblox projects, `--definitions=<path>`. `luau-lsp analyze` never
  downloads definitions itself, so the hooks download luau-lsp's published
  `globalTypes.d.luau` from
  `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau`
  and cache it at `.claude/state/luau-lsp/globalTypes.d.luau`. `SessionStart`
  warms the cache; it is refreshed when older than seven days, and a stale copy
  is used if the refresh fails. With no copy at all the type check is skipped.
  To pin your own definitions, place a file at that path (it is refreshed once
  it is a week old) or use `typecheck-args`.
- `--sourcemap=<root>/sourcemap.json` when that file exists. Keep it current
  with `rojo sourcemap --watch` or your sync tool.
- `--base-luaurc=<root>/.luaurc` when that file exists. Nested `.luaurc` files
  are still picked up by luau-lsp as usual.

Only diagnostics whose kind ends in `Error` (`TypeError`, `SyntaxError`, ...)
are surfaced. Lint warnings such as `LocalUnused` are left to selene. Up to five
errors are shown for the edited file and five for other files.

## Lint guard

A `PreToolUse` hook blocks `Edit` and `Write` on files named `selene.toml`,
`stylua.toml`, `.stylua.toml`, `.styluaignore` or `sentinel.local.md`. Claude is
told to report the offending rule to the user instead of editing the config.
The settings file is protected too, so Claude cannot grant itself a carve-out.

`.luaurc` is deliberately not protected: adding aliases is a routine edit.

`lint-guard-allow` is the only escape hatch. Patterns match the file's
project-relative path, so a monorepo can open one config while the rest stay
protected:

```yaml
---
lint-guard-allow: packages/app/selene.toml
---
```

With that setting, `packages/app/selene.toml` is editable while
`packages/lib/selene.toml` and the root config remain blocked. Globs work too:
`tools/**/stylua.toml` exempts every StyLua config under `tools/`. Files outside
the project directory are never exempt.

## Cadence modes

`lintCadence` controls when lint diagnostics reach Claude.

### `strict` (default)

- `PostToolUse` formats the edited file with StyLua, lints it with selene and
  surfaces any remaining errors immediately.
- `PostToolBatch`, `SubagentStop` and `TaskCompleted` do nothing.
- `Stop` re-lints the edited files and blocks once if errors remain.

Best for short tasks where per-edit feedback is useful.

### `tiered`

- `PostToolUse` records the edited file but does not format, lint or surface
  anything.
- `PostToolBatch` silently formats the edited files (see `lintAutoFixOnBatch`).
- `SubagentStop` and `TaskCompleted` re-lint the edited files at these
  checkpoints and surface remaining errors.
- `Stop` re-lints the edited files and surfaces remaining errors.

Best for long sessions where per-edit lint output bloats context.

### `stop-only`

- `PostToolUse` records the edited file but does not lint.
- `PostToolBatch` silently formats if `lintAutoFixOnBatch` is `true`.
- `SubagentStop` and `TaskCompleted` do nothing.
- `Stop` re-lints the edited files.

Best when you only want end-of-task feedback.

### Stop behaviour

The lint `Stop` hook blocks at most once per batch of edits: after a block it
records the attempt, and the next stop with errors still present lets Claude
finish with an informational "may be pre-existing" note. The typecheck `Stop`
hook allows up to three blocks. Both reset their counters once the files are
clean.

Linting is per file, so unlike type checking the lint `Stop` hook re-checks
the edited files only, never their dependents.

### Typecheck cadence

The typecheck hooks ignore `lintCadence`. `PostToolUse` always type-checks the
edited file and its dependents (when `typecheck` is enabled), and `Stop`
re-checks every edited file plus its dependents.

## State

Hooks keep their state in `<project>/.claude/state/`, which should be
gitignored:

| File                               | Contents                                                        |
| ---------------------------------- | --------------------------------------------------------------- |
| `edited-files.json`                | Edited files per `<session_id>:<agent_id or main>` bucket.       |
| `lint-attempts.json`               | Per-session, per-file surface counters.                          |
| `stop-attempts.json`               | Lint `Stop` block counters per bucket.                           |
| `typecheck-stop-attempts.json`     | Typecheck `Stop` block counters per bucket.                      |
| `sessions/<session_id>`            | Live-session registry (the `claude` process ID).                 |
| `claude-pid`                       | Cached `claude` process ID.                                      |
| `luau-lsp/globalTypes.d.luau`      | Cached Roblox type definitions.                                  |
| `debug.log`                        | Debug traces (only with `debug: true`).                          |

`SessionStart` registers the session and drops state belonging to sessions
whose `claude` process is gone. If the process cannot be found, the session is
recorded as `unknown` and kept for seven days.

## Examples

### Default: no config file needed

Strict cadence, StyLua and selene on, type checking on. Equivalent to an empty
frontmatter or no `.claude/sentinel.local.md` at all.

### Tiered cadence for long sessions

```yaml
---
lint-cadence: tiered
max-lint-errors: 20
---
```

### Type checking only

```yaml
---
lint: false
---
```

### Format with StyLua but skip selene

```yaml
---
selene: false
---
```

### Custom luau-lsp flags

```yaml
---
typecheck-args: --platform=roblox, --definitions=types/globalTypes.d.luau, --sourcemap=sourcemap.json
---
```

The automatic flags are replaced, so list every flag you need. Paths are
relative to the project root.

### Debug a misbehaving hook

```yaml
---
debug: true
---
```

The `Stop` hooks attach traces of the files they considered and the stop
decision; other hooks write theirs to `.claude/state/debug.log`.
