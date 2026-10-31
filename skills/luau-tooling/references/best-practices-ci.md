---
name: best-practices-ci
description: |
    Use when setting up GitHub Actions (or other CI) for a Luau/Roblox project:
    installing tools with setup-rokit, then format check, lint, type-check, build
---

# CI for Luau / Roblox Projects

Run the same pinned tools as local development (from `rokit.toml`), in this
order: **install, format check, lint, type check, build**.

## GitHub Actions

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tools from rokit.toml
        uses: CompeyDev/setup-rokit@v0.2.1
        # with:
        #   cache: true          # off by default; benchmark before enabling
        #   path: .              # dir containing rokit.toml

      - name: Install packages
        run: |
          wally install
          rojo sourcemap default.project.json --output sourcemap.json
          wally-package-types --sourcemap sourcemap.json Packages/

      - name: Format
        run: stylua --check src/

      - name: Lint
        run: selene src/

      - name: Fetch Roblox definitions
        run: |
          curl -sSL -o globalTypes.d.luau \
            https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

      - name: Type check
        run: |
          luau-lsp analyze \
            --definitions=@roblox=globalTypes.d.luau \
            --sourcemap=sourcemap.json \
            --ignore="**/Packages/**" \
            --flag:LuauSolverV2=true \
            src/

      - name: Build place
        run: rojo build default.project.json --output game.rbxl
```

## Adapting it

- **pesde projects:** replace the package step with `pesde install`. The
  scripts package handles sourcemaps and sync config.
- **Azul projects (Studio is the source of truth):** CI can't talk to Studio.
  Check the mirrored `./sync` tree using the `sourcemap.json` committed by
  Azul, or skip `--sourcemap` and accept looser DataModel typing. Don't run
  `rojo build` unless a project file exists.
- **Lune tools/libraries:** run `lune setup`, then `luau-lsp analyze
  --platform=standard`, and run tests with `lune run test`.
- **Solver choice:** pass `--flag:LuauSolverV2=true` only if the project
  targets the new solver (matches `luau-lsp.fflags.enableNewSolver` in
  `.vscode/settings.json`). Or point `--settings .vscode/settings.json` at the
  shared editor settings so CI and editor agree.
- **Rate limits:** setup-rokit passes `github.token` by default. If installs
  still hit limits, enable `cache: true` or use `rokit authenticate`.

## Key points

- Tools in CI come from `rokit.toml` only. Never `cargo install` or download
  binaries ad hoc.
- `stylua --check`, `selene` and `luau-lsp analyze` all exit non-zero on
  problems, so no extra parsing is needed.
- Pin the definitions file (commit it, or download a specific commit's raw
  URL) if you need reproducible type-check results. The `main` URL changes
  with every Roblox API update.
- Run the same commands locally before pushing. A `.lune/check.luau` script
  that calls them through `process.exec` keeps local runs and CI in sync.

<!--
Source references:
- https://github.com/CompeyDev/setup-rokit
- https://github.com/rojo-rbx/rokit
- https://github.com/JohnnyMorganz/luau-lsp
- https://github.com/JohnnyMorganz/StyLua#--check-checking-files-for-formatting
- https://kampfkarren.github.io/selene/
-->
