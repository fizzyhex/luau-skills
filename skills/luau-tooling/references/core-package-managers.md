---
name: core-package-managers
description: |
    Use when adding or installing Luau/Roblox dependencies with wally (wally.toml)
    or pesde (pesde.toml), requiring installed packages, or fixing missing
    package types with wally-package-types
---

# Package Managers: wally and pesde

Check which one the project uses (`wally.toml` or `pesde.toml`). Don't mix
them in one project unless pesde's wally-dependency support is already set up.

## wally

```toml
# wally.toml
[package]
name = "fizzy/yomfood"        # scope/name, lowercase, dashes allowed
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"              # "shared" or "server"
private = true

[dependencies]                 # -> Packages/
Promise = "evaera/promise@4.0.0"

[server-dependencies]          # -> ServerPackages/
ProfileStore = "lm-loleris/profilestore@1.0.3"

[dev-dependencies]             # -> DevPackages/
Jest = "jsdotlua/jest@3.10.0"
```

```sh
wally install                 # resolve, write wally.lock, populate Packages/
wally update [scope/name]     # update within semver ranges
wally search <query>
wally init / publish / login
```

- Versions use Cargo semantics: `"x/y@1.2.0"` means `^1.2.0`.
- The key on the left is the **alias**, and it becomes the folder/module name.
  You require it as `require(ReplicatedStorage.Packages.Promise)`, or
  `require("@game/ReplicatedStorage/Packages/Promise")` on Roblox.
- Wally has no CLI `add`. Edit `wally.toml` and run `wally install`.
- Commit `wally.lock`, and gitignore `Packages/`, `ServerPackages/` and
  `DevPackages/`.
- Map the package folders in your Rojo project file. With Azul, use
  `azul push` to get them into Studio.

### wally-package-types (fix missing types)

Wally's generated thunks (`Packages/Promise.lua`) re-export the value but **not
the exported types**, so `Promise.Promise` is an unknown type. Fix it after
every install:

```sh
wally install
rojo sourcemap default.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
# repeat for ServerPackages/ and DevPackages/ if used
```

## pesde

A newer Luau package manager. It supports `luau`, `lune`, `roblox` and
`roblox_server` targets, and can also install wally and git dependencies.

```toml
# pesde.toml
name = "fizzy/yomfood"        # lowercase letters, numbers, underscores
version = "0.1.0"

[target]
environment = "roblox"        # luau | lune | roblox | roblox_server
lib = "src/init.luau"

[indices]
default = "https://github.com/pesde-pkg/index"

[wally_indices]
default = "https://github.com/UpliftGames/wally-index"

[place]                        # where packages live in the DataModel (Roblox)
shared = "game.ReplicatedStorage.Packages"
server = "game.ServerScriptService.Packages"

[dependencies]
hello = { name = "pesde/hello", version = "^1.0.0" }
promise = { wally = "evaera/promise", version = "^4.0.0" }
lib = { repo = "acme/lib", rev = "v1.0.0" }

[dev_dependencies]
```

```sh
pesde init                    # interactive; pick target + scripts package (e.g. pesde/scripts_rojo)
pesde add pesde/hello         # registry dependency
pesde add wally#evaera/promise
pesde add gh#acme/package#main
pesde add --dev acme/foo
pesde install                 # writes pesde.lock, installs to *_packages/
pesde update / outdated / remove <alias>
pesde run <script>            # runs [scripts] entries via Lune
pesde x <pkg>                 # run a binary package without adding it
```

- Packages are installed to `roblox_packages/` (Roblox targets),
  `luau_packages/` or `lune_packages/`.
- Roblox projects need a sync-config generator script (`pesde init` sets one
  up through a scripts package such as `pesde/scripts_rojo`). Wally deps also
  need a `sourcemap_generator` script to get proper types.
- Commit `pesde.toml` and `pesde.lock`, and gitignore `*_packages/`.

<!--
Source references:
- https://github.com/UpliftGames/wally
- https://github.com/JohnnyMorganz/wally-package-types
- https://docs.pesde.dev/quickstart
- https://docs.pesde.dev/guides/dependencies
- https://docs.pesde.dev/guides/roblox
- https://docs.pesde.dev/reference/manifest
-->
