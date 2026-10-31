---
name: luau-tooling
description: |
    Use when setting up or running the Luau/Roblox toolchain: rokit, Rojo or
    Azul sync and sourcemaps, wally/pesde packages, StyLua, selene, luau-lsp
    (editor + `luau-lsp analyze` in CI), Lune scripts, or darklua bundling
metadata:
    author: Fizzy (fork of Christopher Buss's skills)
    version: "2026.10.31"
    source:
        Hand-written, scripts at https://github.com/fizzyhex/luau-skills
---

> Checked against rokit 1.2.0, luau-lsp 1.70.1, StyLua 2.6.0, selene 0.32.0,
> Lune 0.11.1, darklua 0.19.0, wally 0.3.2, pesde 0.7.x, Rojo 7.7.x, Azul 2.x
> (2026-10-31).

The Roblox/Luau ecosystem uses small, single-purpose Rust CLIs, pinned per
project with **rokit**. A typical repo:

```text
rokit.toml          # pinned tool versions
default.project.json / sync/   # Rojo project file, or Azul's Studio mirror
sourcemap.json      # DataModel map for luau-lsp (generated; gitignore it)
wally.toml | pesde.toml        # packages
.luaurc             # languageMode, lints, require aliases
stylua.toml  selene.toml       # formatter / linter config
.lune/              # Lune automation scripts
```

**Before running anything:** read `rokit.toml` to see which tools the project
uses, run `rokit install`, and run tools from the project root. Rokit resolves
the nearest manifest, so a tool that isn't listed fails with "Failed to find
tool".

## Core

| Topic            | Description                                                         | Reference                                                  |
| ---------------- | ------------------------------------------------------------------- | ---------------------------------------------------------- |
| Rokit            | `rokit.toml`, `rokit add/install/update/trust`, global tools        | [core-rokit](references/core-rokit.md)                     |
| Sync & Sourcemap | Rojo project files, `rojo sourcemap`, Azul (Studio as source of truth) | [core-sync-sourcemap](references/core-sync-sourcemap.md) |
| Package Managers | wally.toml / pesde.toml, Packages folders, wally-package-types      | [core-package-managers](references/core-package-managers.md) |
| luau-lsp         | `luau-lsp analyze` flags, definitions, VS Code `luau-lsp.*` settings | [core-luau-lsp](references/core-luau-lsp.md)               |
| Lint & Format    | StyLua (`stylua.toml`, `--check`), selene (`std = "roblox"`)         | [core-lint-format](references/core-lint-format.md)         |

## Features

| Topic        | Description                                                  | Reference                                            |
| ------------ | ------------------------------------------------------------ | ---------------------------------------------------- |
| Lune Scripts | `lune run`, `@lune/fs/process/net/serde/roblox`, `lune setup` | [feature-lune-scripts](references/feature-lune-scripts.md) |
| darklua      | `darklua process`, bundling, `convert_require` for Roblox    | [feature-darklua](references/feature-darklua.md)     |

## Best Practices

| Topic | Description                                                       | Reference                                      |
| ----- | ----------------------------------------------------------------- | ---------------------------------------------- |
| CI    | GitHub Actions with setup-rokit: format, lint, type-check, build  | [best-practices-ci](references/best-practices-ci.md) |
