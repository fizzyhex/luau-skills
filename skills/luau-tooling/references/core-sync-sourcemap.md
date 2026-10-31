---
name: core-sync-sourcemap
description: |
    Use when syncing files with Roblox Studio via Rojo or Azul, writing a Rojo
    project file, or generating sourcemap.json so luau-lsp can type instance paths
---

# Sync Tools and Sourcemaps

Both tools map files to instances. `Foo.luau` becomes a ModuleScript,
`Foo.server.luau` a Script and `Foo.client.luau` a LocalScript, and
`Folder/init.luau` makes the folder itself a script.

## Rojo (filesystem is the source of truth)

```json
{
	"name": "my-game",
	"tree": {
		"$className": "DataModel",
		"ReplicatedStorage": {
			"Shared": { "$path": "src/shared" },
			"Packages": { "$path": "Packages" }
		},
		"ServerScriptService": {
			"Server": { "$path": "src/server" }
		},
		"StarterPlayer": {
			"StarterPlayerScripts": {
				"Client": { "$path": "src/client" }
			}
		}
	}
}
```

```sh
rojo serve                                   # live sync to the Studio plugin
rojo build -o game.rbxl                      # build a place file
rojo sourcemap default.project.json -o sourcemap.json            # one-shot
rojo sourcemap default.project.json -o sourcemap.json --watch    # keep updated
rojo sourcemap --include-non-scripts -o sourcemap.json           # include Parts, Folders...
```

Only what the project file maps is synced. Anything else in Studio (models,
the map) is invisible to Rojo, and to the sourcemap.

## Azul (Studio is the source of truth)

Azul mirrors the **entire** DataModel from Studio into the filesystem (for
example `./sync`) through a companion plugin. Edits on either side sync both
ways, and Azul writes a Rojo-compatible `sourcemap.json` automatically.

```sh
azul                 # start the sync daemon in the project folder; connect via the Studio plugin
azul build           # push local files into Studio (one-off)
azul push            # selectively push files (e.g. installed Packages) into Studio
azul pack            # serialize instance properties for hermetic build/push
```

- With Azul, treat Studio as authoritative. Don't hand-create instance
  structure on disk and expect Studio to adopt it unless you `build`/`push`.
- `azul push`, `build` and `pack` bind the same port as the live daemon, so
  **stop the daemon first**.
- Azul can import Rojo projects (`--rojo`, `--rojo-project <file>`).
- In luau-lsp, disable sourcemap autogeneration (Azul writes the file):

```json
{
	"luau-lsp.sourcemap.enabled": true,
	"luau-lsp.sourcemap.autogenerate": false,
	"luau-lsp.sourcemap.sourcemapFile": "sourcemap.json",
	"luau-lsp.sourcemap.includeNonScripts": true
}
```

## Sourcemap essentials

- luau-lsp reads `sourcemap.json` to resolve `script.Parent.X`,
  `game.ReplicatedStorage.Y` and instance `require`s into real types.
- Add `sourcemap.json` to `.gitignore` (unless your workflow commits it), and
  regenerate it in CI before `luau-lsp analyze --sourcemap`.
- Include non-scripts if code indexes Parts and Folders by dot access
  (`workspace.Kitchen.Stove`).

<!--
Source references:
- https://rojo.space/docs
- https://github.com/rojo-rbx/rojo/blob/master/src/cli/sourcemap.rs
- https://github.com/Ransomwave/azul
- https://github.com/JohnnyMorganz/luau-lsp#for-rojo-users-requires-v730
-->
