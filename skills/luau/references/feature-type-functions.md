---
name: feature-type-functions
description: |
    Use when deriving Luau types from other types: keyof, index, rawget,
    setmetatable/getmetatable type functions, or writing a user-defined
    `type function` with the types library (new type solver)
---

# Type Functions (new solver)

Type functions run **at analysis time** and compute types from types. They're
only available under the new type solver. The old solver reports
`Unknown type 'keyof'`.

## Built-in type functions

| Function                     | Result                                                          |
| ---------------------------- | --------------------------------------------------------------- |
| `keyof<T>`                   | Union of T's property names as string singletons (respects `__index`) |
| `rawkeyof<T>`                | Same, but ignores the metatable                                 |
| `index<T, K>`                | Type of property `K` in `T` (K may be a union or `keyof<T>`)    |
| `rawget<T, K>`               | Same as `index`, but ignores `__index`                          |
| `setmetatable<T, MT>`        | T with metatable MT (the class pattern)                         |
| `getmetatable<T>`            | The metatable type of T (honors `__metatable`)                  |

Operator type functions like `add<A, B>`, `concat<A, B>`, `len<T>` and
`unm<T>` also exist. They show up in error messages and hovers when the solver
can't reduce an operator yet.

```luau
--!strict
type Person = { name: string, age: number, alive: boolean }

type PersonKey = keyof<Person> -- "age" | "alive" | "name"
type Age = index<Person, "age"> -- number
type PersonValue = index<Person, keyof<Person>> -- number | string | boolean

-- Derive key unions from runtime tables to avoid duplicating lists
local Sounds = {
	cat = "meow",
	dog = "woof",
}
type Animal = keyof<typeof(Sounds)> -- "cat" | "dog"

local function speak(a: Animal): string
	return Sounds[a] -- ok: indexing with a union of its keys
end

local k: PersonKey = "name"
local a: Age = 3
print(speak("cat"), k, a)
```

Pitfall: dynamic indexing **does not** work on a `table.freeze(...)` literal.
`Frozen[a]` errors with `Cannot add indexer to table '{ read cat: string, ...
}'`. Freezing makes the properties read-only. Keep the table unfrozen for the
type, or index with literal keys.

## User-defined type functions

```luau
--!strict
type function Partial(ty)
	if not ty:is("table") then
		error("Partial expects a table type")
	end
	local out = types.newtable()
	for key, prop in ty:properties() do
		if prop.read then
			out:setproperty(key, types.optional(prop.read))
		end
	end
	return out
end

type Person = { name: string, age: number }
type PersonPatch = Partial<Person> -- { name: string?, age: number? }

local patch: PersonPatch = { age = 31 }
print(patch)
```

Rules:

- Declare one with `type function Name(params)` at the top level. Use it like
  a generic alias: `Name<Args>`. You can export it with `export type function`.
- The parameters and return value are **type** values (the `type` userdata),
  not runtime values. Call `error(...)` to report a type error at the use site.
- The function's environment is limited to the `types` library, `assert`,
  `error`, `print`, `next`, `ipairs`, `pairs`, `select`, `unpack`,
  `get/setmetatable`, `raw*`, `tonumber`, `tostring`, `type`, `typeof`,
  `math`, `table`, `string`, `bit32`, `utf8` and `buffer`. There's no
  `require`, no Roblox APIs, and no access to runtime locals.
- A type function runs every time the checker evaluates it, so keep it pure
  and cheap. `print` inside one shows up as a diagnostic at the use site,
  which helps with debugging.

### `types` library cheat sheet

| API                                                          | Purpose                                    |
| ------------------------------------------------------------ | ------------------------------------------ |
| `types.number/string/boolean/any/unknown/never/thread/buffer`| Primitive type values                      |
| `types.singleton(v)`                                         | `"lit"` / `true` / `nil` singleton          |
| `types.unionof(a, b, ...)` / `types.intersectionof(...)`     | Combine types                              |
| `types.optional(t)` / `types.negationof(t)`                  | `t?` / `~t`                                |
| `types.newtable(props?, indexer?, metatable?)`               | Build a table type                         |
| `types.newfunction({head, tail}, {head, tail}?, generics?)`  | Build a function type                      |
| `types.copy(t)`, `types.generic(name?, ispack?)`             | Copy, or create a generic                  |
| `t.tag`, `t:is("table")`                                     | Inspect the kind (`"table"`, `"union"`, `"extern"` for Roblox classes, ...) |
| `t:issubtypeof(other)`                                       | Subtyping check                            |
| `tbl:properties()`                                           | `{ [keyType]: { read: type?, write: type? } }` |
| `tbl:setproperty / setreadproperty / setwriteproperty`       | Mutate a table type                        |
| `tbl:indexer()`, `tbl:setindexer(k, v)`, `tbl:metatable()`   | Indexers and metatables                    |
| `union:components()`, `singleton:value()`                    | Decompose types                            |
| `fn:parameters()`, `fn:returns()`, `fn:generics()`           | Inspect function types                     |

Property keys in `properties()` are **singleton types**, not strings. Use
`key:value()` to get the Lua string.

<!--
Source references:
- https://luau.org/types/type-functions
- https://luau.org/types-library
- https://rfcs.luau.org/keyof-type-operator.html
- https://rfcs.luau.org/index-type-operator.html
- https://rfcs.luau.org/rawget-type-operator.html
- https://rfcs.luau.org/metatable-type-functions.html
- https://rfcs.luau.org/user-defined-type-functions.html
- https://rfcs.luau.org/udtf-is-extern.html
-->
