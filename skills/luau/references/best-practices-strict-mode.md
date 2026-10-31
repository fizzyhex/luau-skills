---
name: best-practices-strict-mode
description: |
    Use when setting up or fixing Luau strict mode, interpreting common type
    errors, choosing between the old and new type solver, or removing `any`
---

# Strict Mode Best Practices

## Turn it on everywhere

- Put `--!strict` on line 1 of every file, **or** set `"languageMode":
  "strict"` in the root `.luaurc`. A per-file directive overrides `.luaurc`.
- Leave `--!nonstrict` and `--!nocheck` for vendored or generated code.
- Treat type errors as build failures in CI with `luau-lsp analyze` (see
  luau-tooling).

## Old vs new type solver

Roblox and luau-lsp have both solvers. The new one (Roblox "New Luau Type
Solver", luau-lsp `luau-lsp.fflags.enableNewSolver`, CLI
`--flag:LuauSolverV2=true`) adds:

- `read`/`write` property modifiers and read-only `table.freeze` results
- Type functions: `keyof`, `index`, `setmetatable<>`, user-defined `type
  function`
- Stricter checks, e.g. iterating a record type without an indexer is an error

If a project has to type-check under both, avoid those features. Use the
`typeof(setmetatable({} :: Data, Class))` class pattern, and check which solver
the project's tooling enables before you reach for type functions.

## Prefer precise types over `any`

| Instead of                         | Write                                                   |
| ---------------------------------- | ------------------------------------------------------- |
| `local t = {}` then fill           | `local t: { [string]: Item } = {}` or `{} :: { Item }`  |
| `data: any` from network/storage   | `data: unknown`, then refine                            |
| `x :: any :: T`                    | Fix the source type, or refine with `type`/`IsA`        |
| Untyped function params            | Annotate params and returns on every exported function  |
| `table` / `{}` as a param type     | A specific shape `{ id: string }` or `{ [K]: V }`       |
| `function Class:method()`          | `function Class.method(self: Class)`                    |

Annotate **module boundaries**: exported functions, constructors and public
fields. Let inference handle locals.

## Common errors and fixes

| Error (abridged)                                                | Cause and fix                                                                     |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `Value of type 'Instance?' could be nil`                         | `FindFirstChild`/`Parent`/`Character` is optional. Guard with `if not x then return end` |
| `Key 'Anchored' not found in external type 'Instance'`           | Not refined to the subclass. Use `if x:IsA("Part") then`                          |
| `Key 'Thing' not found in external type 'Workspace'`             | Dot access to a child with no sourcemap. Use `WaitForChild` and `IsA`, or set up a sourcemap |
| `Expected this to be 'string', but got 'unknown'`               | Refine `unknown` with `type()`/`typeof()` first                                   |
| `Type 'table' does not have key 'x'`                             | `type(v) == "table"` gives an opaque table. Cast to `{ [unknown]: unknown }` and check fields |
| `Property x of table '...' is read-only`                         | Writing a frozen or `read` field, **or** an unannotated `self` in a `:` method     |
| `Cannot iterate over a table without indexer`                    | A record table in a loop. Annotate it as `{ [K]: V }`                              |
| `Cannot add property 'y' to table '...'`                         | The table is sealed. Add the field to its type or to the constructor literal      |
| `Expected this to be exactly 'Base', but got 'Derived'`          | Metatable types are invariant. Use a structural `self` for inherited methods      |
| `Unknown type 'keyof'` / `read keyword is illegal here`           | The new solver isn't enabled                                                       |
| `Recursive type being used with different parameters`           | Self-reference inside an alias must reuse the same generics                       |
| `Unknown require` / `any` from require                           | Non-literal path or missing sourcemap. Use string requires or Rojo/Azul sourcemaps |

## Suppressing, sparingly

```luau
--!strict
local legacy = require("./legacy") :: any -- isolates an untyped module
local value = legacy.compute() :: unknown -- re-enter typed code via unknown
if type(value) == "number" then
	print(value + 1)
end
```

- Linter warnings can be turned off per file with `--!nolint LocalUnused`, or
  project-wide in `.luaurc` `"lint"`.
- Prefix intentionally unused locals with `_`. That's what the linter's own
  hint suggests.
- There's no `@ts-ignore` style comment for type errors. Fix the error, or
  narrow it down with a cast.

## Key points

- Types are erased at runtime. Annotations never validate data, so you have to
  validate untrusted input yourself.
- Inference is per function. Exported functions with no annotations get
  generic or `any` parameters that accept wrong input.
- When the checker complains, don't silence it. Model the real states (optional
  fields, tagged unions) instead.

<!--
Source references:
- https://luau.org/types
- https://luau.org/lint
- https://rfcs.luau.org/config-luaurc.html
- https://rfcs.luau.org/syntax-property-access-modifiers.html
- https://rfcs.luau.org/user-defined-type-functions.html
-->
