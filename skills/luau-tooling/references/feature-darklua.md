---
name: feature-darklua
description: |
    Use when transforming Luau with darklua: bundling a module tree into one
    file, converting require-by-string/.luaurc aliases into Roblox instance
    requires, or stripping/minifying code for a build
---

# darklua

darklua rewrites Lua/Luau using an ordered list of **rules**. It's used to:

- make `@alias` string requires work on Roblox, which can't read `.luaurc`
  aliases, by converting them to instance paths;
- bundle a module graph into a single file (for Lune tools, plugins, or a
  standalone release);
- strip comments or debug code, inject build-time globals, or minify.

## Commands

```sh
darklua process src/ out/                    # apply rules from .darklua.json(5) in the cwd
darklua process src/ out/ -c build.darklua.json
darklua process entry.luau bundled.luau      # bundles when `bundle` is configured
darklua minify src/ out/
darklua convert data.json data.luau          # json/json5/yaml/toml -> Lua table module
```

The config file is `.darklua.json` or `.darklua.json5`, picked up from the
directory you run in. Rules run in order, and the order matters.

## Roblox: convert string requires to instance requires

```json5
// .darklua.json5
{
  generator: "retain_lines", // default; keeps line numbers for stack traces
  rules: [
    {
      rule: "convert_require",
      current: {
        name: "path",
        sources: { "@Packages": "./Packages", "@Shared": "./src/shared" },
      },
      target: {
        name: "roblox",
        rojo_sourcemap: "./sourcemap.json",
        indexing_style: "wait_for_child", // or "find_first_child" (default) | "property"
      },
    },
  ],
}
```

Typical flow: generate the sourcemap from the **source** tree, run `darklua
process src/ dist/`, then sync or build from `dist/` (a second Rojo project
pointing at `dist`).

## Bundling

```json5
{
  bundle: {
    require_mode: "luau", // follows Luau module-path rules (.luaurc aliases, @self)
    excludes: ["@lune/**"], // keep runtime-provided modules as real requires
  },
}
```

- The `path` require mode resolves like filesystem paths with
  `module_folder_name: "init"` and custom `sources`. The `luau` mode follows
  the official Luau resolution (`@self`, `init.luau` semantics, `.luaurc`
  aliases via `use_luau_configuration`).
- Modules **must not have side effects at require time**, because bundling may
  reorder them.
- Data files (`.json`, `.yaml`, `.toml`, `.txt`) can be required and are
  inlined as Lua values.

## Other useful rules

`remove_comments`, `remove_spaces`, `remove_types` (output for Lua 5.1
consumers), `inject_global_value` (build flags, e.g. `__DEV__`),
`compute_expression`, `remove_unused_if_branch`, `remove_assertions`,
`remove_debug_profiling`, `remove_attribute`. See https://darklua.com/docs/rules.

<!--
Source references:
- https://github.com/seaofvoices/darklua
- https://darklua.com/docs/getting-started
- https://darklua.com/docs/config
- https://darklua.com/docs/bundle
- https://darklua.com/docs/luau-require-mode
- https://darklua.com/docs/roblox-require-mode
- https://darklua.com/rules/convert_require
-->
