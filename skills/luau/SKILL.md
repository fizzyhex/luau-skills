---
name: luau
description: |
    Use when writing or reviewing typed Luau for Roblox (or Lune), especially
    strict-mode type annotations, generics, refinements, metatable classes,
    require-by-string modules, type functions, or Roblox Instance typing
metadata:
    author: Fizzy (fork of Christopher Buss's skills)
    version: "2026.10.31"
    source:
        Generated from https://github.com/luau-lang/site and
        https://github.com/luau-lang/rfcs, scripts at
        https://github.com/fizzyhex/luau-skills
---

> Based on the luau.org docs and Luau RFCs as of 2026-10-31. Snippets checked
> with luau-lsp 1.70.1 (new type solver) against the Roblox definitions.

Luau is Roblox's gradually typed, sandboxed dialect of Lua 5.1. It has
`continue`, compound assignment, `if`-expressions, string interpolation,
`const`, generalized iteration, structural types and a native code generator.
It does **not** have `goto`, integers, bitwise operators or tail calls.

**Defaults for agents:**

- Start every file with `--!strict` (or set `"languageMode": "strict"` in
  `.luaurc`). Nonstrict mode quietly infers `any`.
- Use `unknown` at trust boundaries (remotes, DataStores, JSON) and refine. Use
  `any` only to break cycles or for interop.
- Write methods as `function Class.method(self: Class, ...)`. A `:` definition
  does not get the class type for `self`.
- `FindFirstChild` returns `Instance?`. Refine with `:IsA()` before you touch
  class members.
- Features marked **(new solver)** need Luau's new type solver: Roblox's new
  solver, or `luau-lsp.fflags.enableNewSolver` /
  `--flag:LuauSolverV2=true`.

## Core References

| Topic                | Description                                                                | Reference                                                          |
| -------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Syntax vs Lua 5.1    | continue, `+=`, if-expr, interpolation, `const`, `//`, attributes, gotchas | [core-syntax-differences](references/core-syntax-differences.md)   |
| Type Annotations     | Modes, annotation syntax, function types, `::` casts, any/unknown/never    | [core-type-annotations](references/core-type-annotations.md)       |
| Type Refinement      | Truthiness, `type`/`typeof`, equality, `:IsA`, `assert`, tagged unions     | [core-type-refinement](references/core-type-refinement.md)         |
| Table Types          | Sealed/unsealed, indexers, arrays, `read`/`write` properties, freeze       | [core-table-types](references/core-table-types.md)                 |
| Classes              | Typed metatable OOP: `setmetatable<>`, `typeof(setmetatable(...))`, self   | [core-classes](references/core-classes.md)                         |
| Modules & Require    | require-by-string, `@self`, `.luaurc` aliases, `export type`, cycles       | [core-modules-require](references/core-modules-require.md)         |

## Features

| Topic          | Description                                                                 | Reference                                                    |
| -------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------ |
| Generics       | Generic functions/aliases, defaults, type packs, `f<<T>>()` instantiation   | [feature-generics](references/feature-generics.md)           |
| Type Functions | `keyof`, `index`, `rawget`, `setmetatable<>`, user-defined `type function`  | [feature-type-functions](references/feature-type-functions.md) |
| Roblox Types   | Instance classes, FindFirstChild/WaitForChild, services, remotes, attributes | [feature-roblox-types](references/feature-roblox-types.md)   |

## Best Practices

| Topic       | Description                                                                 | Reference                                                              |
| ----------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Strict Mode | Setting up strict mode, avoiding `any`, common type errors and their fixes  | [best-practices-strict-mode](references/best-practices-strict-mode.md) |
| Performance | `@native`/`--!native`, `table.create`, `buffer`, `vector`, fastcalls, OOP   | [best-practices-performance](references/best-practices-performance.md) |
