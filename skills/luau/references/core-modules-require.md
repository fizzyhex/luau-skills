---
name: core-modules-require
description: |
    Use when writing Luau modules, exporting types, using require-by-string
    paths (./, ../, @self, @game, .luaurc aliases), or fixing require cycles
---

# Modules and require

A module is a file (or a Roblox `ModuleScript`) that returns **exactly one
value**, usually a table. The first `require` runs it, and every later
`require` returns the cached value. On Roblox, server and client each run the
module separately.

## Exporting types

```luau
-- Inventory/Item.luau
export type Item = {
	id: string,
	count: number,
}

local Item = {}

function Item.new(id: string): Item
	return { id = id, count = 1 }
end

return Item
```

```luau
-- consumer
local Item = require("./Item")

local apple: Item.Item = Item.new("apple") -- types are accessed via the require local
print(apple)
```

- `export type` works only at the top level of the module. You can also export
  generic aliases: `export type Result<T> = ...`.
- Types come only from `export type`. The checker treats the returned table's
  shape as the value's type, and you can't add fields to it from outside
  (`Module.NewField = x` is an error).
- The `require` argument must be resolvable statically, either a string literal
  or an instance path. Otherwise the result is `any`.

## Require-by-string paths

| Prefix      | Filesystem (Luau CLI, Lune, luau-lsp)          | Roblox                                   |
| ----------- | ---------------------------------------------- | ---------------------------------------- |
| `./x`       | Sibling of this file (siblings of the folder for `init.luau`) | Child of `script.Parent`  |
| `../x`      | One level up                                   | Child of `script.Parent.Parent`          |
| `@self/x`   | Child of this module (for `init.luau`: inside its folder) | Child of `script`             |
| `@game/...` | n/a                                            | Starts at `game`, e.g. `@game/ReplicatedStorage/Shared` |
| `@alias/x`  | Alias from `.luaurc`/`.config.luau`            | Not configurable in Studio. Tooling (darklua/Azul) may rewrite it |

- Unprefixed paths like `require("utils")` are **errors**. Always start with
  `./`, `../` or `@`.
- Don't write extensions: `require("./utils")` finds `utils.luau`, `utils.lua`
  or `utils/init.luau`. Having two candidates at once is an error.
- `init.luau` **is** its folder. Inside `Foo/init.luau`, `./Bar` is a sibling
  of `Foo`, and `@self/Bar` is `Foo/Bar.luau`. This matches Rojo's `init`
  mapping.
- On Roblox, string requires don't wait for instances to exist. On the client,
  use `require(Parent:WaitForChild("Module"))` if the module might not have
  replicated yet.

```luau
-- Shared/Inventory/init.luau
local Item = require("@self/Item") -- Shared/Inventory/Item.luau
local Util = require("./Util") -- Shared/Util.luau (sibling of the Inventory folder)

export type Item = Item.Item -- re-export a type

return { Item = Item, Util = Util }
```

## Instance requires (classic Roblox)

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Signal"))
local Sibling = require(script.Parent.Sibling) -- needs a sourcemap for types in external editors
```

Instance paths only type-check in an external editor if luau-lsp has a Rojo
sourcemap (see luau-tooling). Without one, the result is `any`.

## `.luaurc` aliases and config

`.luaurc` is JSON with comments and trailing commas allowed. Settings are
inherited from parent directories, and the closest file wins:

```json
{
	"languageMode": "strict",
	"lint": { "*": true, "LocalUnused": false },
	"lintErrors": false,
	"typeErrors": true,
	"globals": ["expect"],
	"aliases": {
		"Shared": "./src/shared",
		"Packages": "./Packages"
	}
}
```

```luau
local Promise = require("@Packages/Promise")
local Config = require("@Shared/Config")
```

- Alias names are case-insensitive and match `[A-Za-z0-9.\-_]`. You use them
  only at the start of a path. A relative alias target is resolved from the
  `.luaurc` that defines it. `@self` is reserved.
- `.config.luau` is a newer Luau-syntax alternative: `return { luau = {
  languagemode = "strict", aliases = { ... } } }`.

## Cyclic requires

The checker can't type-check a require cycle, and the runtime errors on one.
Break it by:

1. Moving shared types into a types-only module that both sides require.
2. Passing the dependency in (injection) instead of requiring it.
3. Calling `require` lazily inside a function body, so it runs after both
   modules have loaded.
4. As a last resort, `local B = require("./B") :: any`, which loses all types.

<!--
Source references:
- https://luau.org/types/considerations
- https://luau.org/syntax#type-annotations
- https://rfcs.luau.org/new-require-by-string-semantics.html
- https://rfcs.luau.org/amended-require-resolution.html
- https://rfcs.luau.org/abstract-module-paths-and-init-dot-luau.html
- https://rfcs.luau.org/require-by-string-aliases.html
- https://rfcs.luau.org/config-luaurc.html
- https://rfcs.luau.org/config-luauconfig.html
- https://create.roblox.com/docs/reference/engine/globals/LuaGlobals#require
-->
