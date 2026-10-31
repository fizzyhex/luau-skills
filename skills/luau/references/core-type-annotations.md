---
name: core-type-annotations
description: |
    Use when annotating Luau variables, functions, or type aliases, choosing
    between any/unknown/never, or casting with ::
---

# Type Annotations

## Type modes

Put the mode comment on the **first line** of the file:

| Directive      | Behavior                                                             |
| -------------- | -------------------------------------------------------------------- |
| `--!strict`    | Full inference. Unknown types are errors. **Use this.**              |
| `--!nonstrict` | Default if there's no directive or `.luaurc`. Unknowns become `any`  |
| `--!nocheck`   | No type checking at all                                              |

`--!native` (performance) and `--!optimize 2` are separate directives, not type
modes.

## Annotation syntax

```luau
--!strict
local age: number = 25
local names: { string } = { "Alice", "Bob" } -- array shorthand for { [number]: string }
local maybe: string? = nil -- `T?` is `T | nil`

-- Parameters and return types
local function greet(name: string, times: number?): string
	return string.rep(`Hello {name} `, times or 1)
end

-- Multiple returns: parenthesize. No returns: `()`
local function divmod(a: number, b: number): (number, number)
	return a // b, a % b
end

-- Function TYPES use `->`, and parameter names are optional documentation
type Callback = (errorCode: number, message: string) -> ()
type Predicate<T> = (T) -> boolean

-- Variadics: `...: T` in definitions, `...T` in types
local function sum(...: number): number
	local total = 0
	for _, n in { ... } do
		total += n
	end
	return total
end
type Sum = (...number) -> number

-- Singleton (literal) types: strings and booleans only, not numbers
type Direction = "up" | "down" | "left" | "right"
local dir: Direction = "up"

-- Type aliases are file-local unless exported
export type Point = { x: number, y: number }

-- typeof(expr) gives the type of an expression without evaluating it
local defaults = { volume = 0.5, muted = false }
type Settings = typeof(defaults)

print(age, names, maybe, greet("a"), divmod(7, 2), sum(1, 2), dir)
local _cb: Callback? = nil
local _p: Predicate<number>? = nil
local _s: Sum = sum
local _set: Settings = defaults
```

Common mistakes:

- `function(x): number, string` is wrong. Write `: (number, string)`.
- `(string, number)?` is a **syntax error** because type packs can't be
  optional. Return `(string?, number?)` or an optional table instead.
- There's no `number[]` and no `Array<T>` (unless you alias it). Use `{ T }`.
- Number literal types (`type One = 1`) don't exist.
- `void`, `undefined`, `null` and `object` don't exist. Use `()`, `nil` and
  `{ [any]: any }`/`{}`.
- Lowercase `table` and `function` aren't usable as annotation types. Use
  `{ [K]: V }` and `(...any) -> ...any`.

## any vs unknown vs never

```luau
--!strict
local a: any = 5
local s1: string = a -- allowed: `any` opts out of checking (unsafe)

local u: unknown = 5
-- local s2: string = u -- error: unknown must be refined first
if type(u) == "number" then
	local n: number = u -- ok after refinement
	print(n)
end

-- never: the empty type, e.g. after exhaustive refinement
print(s1)
```

Use `unknown` for untrusted input (RemoteEvent args, decoded JSON, DataStore
values). Use `any` only for interop or to break require cycles.

## Casts with `::`

```luau
--!strict
local names = {} :: { string } -- give an empty literal a precise type
table.insert(names, "Ana")

local raw: unknown = "hello"
local len = (raw :: string):len() -- parenthesize before method calls

local n = 1
local anything = n :: any -- casting to/from `any` is always allowed
-- local b = n :: boolean -- error: unrelated types can't be cast

print(len, anything)
```

- A cast only compiles if one side is a subtype of the other (or `any`). Casting
  through `any` (`x :: any :: T`) is an escape hatch. It's a code smell, so
  refine instead when you can.
- A cast on a multi-value expression keeps only the **first** value:
  `(f() :: number)`.
- A cast is an assertion to the checker. It doesn't check anything at runtime.

## Unions and intersections

```luau
--!strict
type Id = string | number

type Named = { name: string }
type Aged = { age: number }
type Person = Named & Aged -- table intersection = all fields

-- Intersections of function types model overloads
type Stringify = ((number) -> string) & ((boolean) -> string)

local p: Person = { name = "Kai", age = 3 }
local id: Id = 42
print(p, id)
```

- Before you use a union value as a specific member, refine it (see
  core-type-refinement).
- A union of two or more function types can't be called.
- `string & number` is uninhabitable (`never`).

<!--
Source references:
- https://luau.org/types
- https://luau.org/types/basic-types
- https://luau.org/types/unions-and-intersections
- https://luau.org/syntax#type-annotations
-->
