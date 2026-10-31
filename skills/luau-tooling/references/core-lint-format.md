---
name: core-lint-format
description: |
    Use when formatting Luau with StyLua (stylua.toml, --check) or linting with
    selene (selene.toml, std = "roblox", inline allow comments)
---

# Formatting (StyLua) and Linting (selene)

## StyLua

```toml
# stylua.toml (or .stylua.toml) at the project root
syntax = "Luau"                  # avoid Lua 5.2 `::label::` vs Luau `::` cast ambiguity
column_width = 120
line_endings = "Unix"
indent_type = "Tabs"             # default
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
collapse_simple_statement = "Never"

[sort_requires]
enabled = true                   # sorts consecutive `local X = require(...)` / GetService blocks
```

```sh
stylua src/                       # format in place
stylua --check src/               # CI: exit 1 + diff if anything is unformatted
stylua --check --output-format=summary src/   # just list files
stylua --verify src/              # re-parse output to guard against bad formatting
stylua -g '**/*.luau' -g '!**/Packages/**' -- .  # glob filter (`--` ends the glob list)
```

- `-- stylua: ignore` skips the next statement. Use `-- stylua: ignore start`
  / `-- stylua: ignore end` for a block within a single scope.
- `.styluaignore` uses gitignore syntax. Files passed explicitly are still
  formatted unless you pass `--respect-ignores`.
- The config is found by searching upward from each file **to the current
  directory**. Run from the project root.
- **Run StyLua after editing Luau files.** Don't hand-format to match the
  style.
- StyLua 2.6.0 parses `const`, `f<<T>>()`, `read`/`write` and plain `@native`.
  It can't parse parameterized attributes (`@[deprecated { ... }]`), and
  neither can selene 0.32.0.

## selene

```toml
# selene.toml
std = "roblox"                   # Roblox globals + Luau; auto-generates/caches the std
exclude = ["Packages/*", "DevPackages/*"]

[lints]
unused_variable = "warn"         # "allow" | "warn" | "deny"
shadowing = "allow"
global_usage = "deny"

[config]
empty_if = { comments_count = true }
```

```sh
selene src/                       # lint
selene --display-style=quiet src/ # compact output
selene update-roblox-std          # refresh the cached Roblox std now
selene generate-roblox-std        # write roblox.yml into the cwd (for pinning)
```

- `std` values can be chained, e.g. `std = "roblox+testez"` or a custom
  `std = "roblox+mylib"` (`mylib.yml` in the project).
- `roblox-std-source = "pinned"` uses a local `roblox.yml` instead of the
  auto-updating cache, which suits offline or reproducible CI.
- Inline filters: `-- selene: allow(unused_variable)` applies to the next
  statement or block. `--# selene: allow(lint)` at the top of a file (before
  any code) applies to the whole file.
- selene complements luau-lsp. selene finds code-smell issues (shadowing,
  `almost_swapped`, `if_same_then_else`). luau-lsp finds type errors, and has
  its own linter configured through `.luaurc` `"lint"`.

<!--
Source references:
- https://github.com/JohnnyMorganz/StyLua#configuration
- https://kampfkarren.github.io/selene/roblox.html
- https://kampfkarren.github.io/selene/usage/configuration.html
- https://kampfkarren.github.io/selene/usage/filtering.html
- selene 0.32.0 / StyLua 2.6.0 `--help` output
-->
