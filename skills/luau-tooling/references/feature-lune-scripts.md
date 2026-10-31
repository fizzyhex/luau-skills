---
name: feature-lune-scripts
description: |
    Use when writing automation or build scripts in Luau with Lune (lune run,
    .lune/ folder, @lune/fs, process, net, serde, roblox, task, stdio)
---

# Lune Scripts

Lune is a standalone Luau runtime for scripting outside Roblox, such as builds,
codegen, asset processing and place-file manipulation. It runs typed Luau with
require-by-string and a small std library under `@lune/...`.

## Running

```sh
lune run build              # finds build.luau in ./, ./lune/, ./.lune/, ~/lune/, ~/.lune/
lune run .lune/build.luau arg1 arg2
lune list                   # scripts in lune/ or .lune/ (with their `-->` description comment)
echo 'print(1)' | lune run -
lune setup                  # write type definitions + update .luaurc aliases for luau-lsp
lune build script.luau      # standalone executable
lune repl
```

Run `lune setup` once per machine or Lune version, so that `require("@lune/fs")`
type-checks in the editor and in `luau-lsp analyze --platform=standard`.

## Example: build helper

```luau
--> Regenerates the sourcemap and type-fixes wally packages
--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local function run(program: string, args: { string })
	local result = process.exec(program, args, { stdio = "inherit" })
	if not result.ok then
		print(`{program} failed with code {result.code}`)
		process.exit(result.code)
	end
end

run("rojo", { "sourcemap", "default.project.json", "--output", "sourcemap.json" })
if fs.isDir("Packages") then
	run("wally-package-types", { "--sourcemap", "sourcemap.json", "Packages/" })
end

local manifest = serde.decode("toml", fs.readFile("wally.toml"))
print("built", manifest.package.name, "args:", table.concat(process.args, " "))
```

## Standard library

| Module          | Highlights                                                                         |
| --------------- | ---------------------------------------------------------------------------------- |
| `@lune/fs`      | `readFile`, `writeFile`, `readDir`, `writeDir`, `removeFile/Dir`, `isFile`, `isDir`, `metadata`, `move`, `copy` |
| `@lune/process` | `args`, `env`, `cwd`, `os`, `arch`, `exit(code)`, `exec(prog, args, opts)` → `{ ok, code, stdout, stderr }`, `create` (streaming child) |
| `@lune/net`     | `request(urlOrParams)` → `{ ok, statusCode, statusMessage, headers, body }`, `serve`, `socket`, `urlEncode/Decode` |
| `@lune/serde`   | `encode(format, value, pretty?)` / `decode(format, str)` for `json`/`yaml`/`toml`; `compress`/`decompress`; `hash`/`hmac` |
| `@lune/roblox`  | `deserializePlace/Model`, `serializePlace/Model`, `Instance`, Roblox datatypes, `getAuthCookie` |
| `@lune/task`    | `spawn`, `defer`, `delay`, `wait`, `cancel` (same as Roblox `task`)                |
| `@lune/stdio`   | `prompt`, `color`, `style`, `format`, `write`, `ewrite`, `readLine`, `readToEnd`   |
| `@lune/datetime`, `@lune/regex`, `@lune/luau` | Dates, real regex (unlike Lua patterns), `luau.compile/load` |

## Editing place files

```luau
--!strict
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("place.rbxl"))
local workspace = game:GetService("Workspace")
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") then
		-- Lune's Instance type is generic: IsA doesn't refine, so writes need a cast
		(d :: any).Anchored = true
	end
end
fs.writeFile("place.rbxl", roblox.serializePlace(game))
```

## Key points

- `net.request` doesn't throw on 4xx/5xx. Check `response.ok`.
- `process.exec` doesn't use a shell. Pass args as a list, and invoke a shell
  explicitly (`{ shell = true }` option or `sh -c`) if you need pipes or globs.
- Scripts are ordinary modules: `require("./util")` works relative to the
  script file, and `.luaurc` aliases apply.
- Lune's `Instance` typings are generic: `IsA` doesn't refine to the subclass,
  so property writes need `(inst :: any).Prop = value`.
- Lune globals don't include Roblox's `game`, `workspace` or `script`. You get
  them only from a deserialized place.

<!--
Source references:
- https://github.com/lune-org/lune
- https://lune-org.github.io/docs/getting-started/2-command-line-usage
- https://lune-org.github.io/docs/getting-started/3-editor-setup
- https://lune-org.github.io/docs/the-book/8-spawning-processes
- https://lune-org.github.io/docs/api-reference/process
- https://lune-org.github.io/docs/api-reference/net
- https://lune-org.github.io/docs/api-reference/serde
- https://lune-org.github.io/docs/roblox/2-examples
-->
