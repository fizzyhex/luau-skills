---
name: core-luau-lsp
description: |
    Use when type-checking Luau from the command line with `luau-lsp analyze`,
    providing Roblox definitions or sourcemaps, enabling the new type solver,
    or configuring the VS Code luau-lsp extension
---

# luau-lsp

The Luau language server, also usable as a standalone checker (`luau-lsp
analyze`). Project-wide Luau settings (mode, lints, aliases) live in
`.luaurc`. Editor-specific settings use the `luau-lsp.*` namespace.

## CLI: `luau-lsp analyze`

```sh
luau-lsp analyze [options] <files or directories...>
```

| Flag                                | Purpose                                                                    |
| ----------------------------------- | -------------------------------------------------------------------------- |
| `--platform roblox\|standard`       | Defaults to `roblox`. Use `standard` for Lune/pure Luau (silences the defs warning) |
| `--definitions=@roblox=<path>`      | Load a definitions file (alias `--defs`). Repeatable. **analyze never downloads definitions** |
| `--sourcemap <path>`                | Rojo-style sourcemap for DataModel/instance-require resolution             |
| `--base-luaurc <path>`              | Default `.luaurc` applied beneath the project's own                         |
| `--settings <path>`                 | Reuse LSP settings JSON (e.g. `.vscode/settings.json`, for fflags and aliases) |
| `--flag:<Name>=<value>`             | Set a Luau FFlag, e.g. `--flag:LuauSolverV2=true` for the new solver       |
| `--no-flags-enabled`                | Don't enable all FFlags by default                                         |
| `--no-strict-dm-types`              | Make DataModel lookups looser (strict by default in analyze)                |
| `--ignore <glob>`                   | Suppress diagnostics for matching files (e.g. `"**/Packages/**"`). Repeatable |
| `--formatter default\|plain\|gnu`   | Output format                                                              |
| `--annotate`                        | Print the source with inferred types                                       |

The exit code is non-zero when there are errors, so it works as a CI gate.

### Typical Roblox invocation

```sh
# 1. Fetch Roblox API definitions (analyze won't do it for you)
curl -sSL -o globalTypes.d.luau \
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

# 2. Produce a sourcemap (Rojo; Azul writes one automatically)
rojo sourcemap default.project.json --output sourcemap.json

# 3. Analyze
luau-lsp analyze \
  --definitions=@roblox=globalTypes.d.luau \
  --sourcemap=sourcemap.json \
  --ignore="**/Packages/**" \
  --flag:LuauSolverV2=true \
  src/
```

For Lune or plain Luau: `luau-lsp analyze --platform=standard src/` (run
`lune setup` first so the `@lune/...` aliases resolve).

Other subcommands: `luau-lsp lsp` (start the server) and `luau-lsp
require-graph`.

## VS Code extension settings

```json
{
	"luau-lsp.platform.type": "roblox",
	"luau-lsp.fflags.enableNewSolver": true,
	"luau-lsp.sourcemap.enabled": true,
	"luau-lsp.sourcemap.autogenerate": true,
	"luau-lsp.sourcemap.rojoProjectFile": "default.project.json",
	"luau-lsp.sourcemap.sourcemapFile": "sourcemap.json",
	"luau-lsp.sourcemap.includeNonScripts": true,
	"luau-lsp.diagnostics.strictDatamodelTypes": false,
	"luau-lsp.types.definitionFiles": {},
	"luau-lsp.ignoreGlobs": ["**/_Index/**"],
	"luau-lsp.completion.imports.enabled": true,
	"luau-lsp.studioPlugin.enabled": false
}
```

| Setting                                   | Notes                                                                 |
| ----------------------------------------- | --------------------------------------------------------------------- |
| `platform.type`                           | `roblox` (default; auto-downloads Roblox defs) or `standard`          |
| `fflags.enableNewSolver`                  | Off by default. Turn it on to use `read`/`write`, `keyof`, `type function` |
| `sourcemap.autogenerate`                  | Runs `rojo sourcemap --watch` for you. Set `false` for Azul or a custom generator |
| `sourcemap.generatorCommand`              | A custom sourcemap command for non-Rojo setups                        |
| `diagnostics.strictDatamodelTypes`        | Off by default: DataModel types are `any` in diagnostics (hover is still typed) |
| `types.definitionFiles`                   | Extra `.d.luau` definitions (`{ "@name": "path" }`)                   |
| `studioPlugin.enabled`                    | Companion Studio plugin for instances outside the file tree (replaces the deprecated `plugin.enabled`) |
| `server.baseLuaurc`                       | Same as `--base-luaurc`                                               |
| `require.fileAliases` / `directoryAliases`| **Deprecated**. Use `.luaurc` `aliases` instead                        |
| `types.roblox`                            | **Deprecated**. Use `platform.type`                                    |

## Key points

- If the editor shows types but CI doesn't (or the reverse), compare solver
  flags, definitions, sourcemap and `strictDatamodelTypes`. analyze defaults
  to **strict** DataModel types, while the extension defaults to loose.
- `Key 'X' not found in external type 'Workspace'` in CI almost always means
  there's no `--sourcemap`, or the sourcemap was generated without
  `--include-non-scripts`.
- Neovim and other editors use the same server (`luau-lsp lsp`) with the same
  settings keys.

<!--
Source references:
- https://github.com/JohnnyMorganz/luau-lsp
- https://github.com/JohnnyMorganz/luau-lsp/blob/main/editors/code/package.json
- luau-lsp 1.70.1 `analyze --help` output
-->
