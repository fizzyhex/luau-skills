---
name: feature-generics
description: |
    Use when writing generic Luau functions or type aliases, variadic generic
    type packs (T...), default type parameters, or explicit f<<T>>() instantiation
---

# Generics and Type Packs

## Generic functions and aliases

```luau
--!strict
local function map<T, U>(list: { T }, fn: (T) -> U): { U }
	local out = table.create(#list)
	for i, v in list do
		out[i] = fn(v)
	end
	return out
end

local strs: { string } = map({ 1, 2, 3 }, tostring)

type Pair<T> = { first: T, second: T }
type PairOf<T = string> = Pair<T> -- defaults are allowed on ALIASES only

local p: PairOf = { first = "a", second = "b" }
print(strs, p)
```

- **No constraints or bounds.** `<T: Instance>` and `<T extends X>` are syntax
  errors. Take the concrete supertype (`inst: Instance`) instead, or a
  structural type like `{ read name: string }`.
- **No defaults on function generics.** `function f<T = string>()` is invalid.
- Generics are inferred at each call. Write `<T>` when inference falls short
  or when you want the signature documented.
- Inside the body, `T` is opaque. You can't call `T` methods or test
  `typeof(x) == T`.

## Explicit instantiation: `f<<T>>(...)`

```luau
--!strict
local function emptyList<T>(): { T }
	return {}
end

local nums = emptyList<<number>>() -- { number }; T can't be inferred from arguments

local function swap<A, B>(a: A, b: B): (B, A)
	return b, a
end
local s, n = swap<<number, string>>(1, "hello")
print(nums, s, n)
```

## Type packs (variadic generics)

`T...` is a generic **pack**, meaning zero or more types that can differ.
`...T` is a variadic of one repeated type.

```luau
--!strict
-- Forward arbitrary arguments/returns with full typing
local function try<A..., R...>(fn: (A...) -> R..., ...: A...): (boolean, R...)
	return pcall(fn, ...)
end
local ok, doubled = try(function(x: number): number
	return x * 2
end, 21)

-- A typed signal
export type Signal<T...> = {
	connect: (self: Signal<T...>, callback: (T...) -> ()) -> () -> (),
	fire: (self: Signal<T...>, T...) -> (),
}

-- Instantiating packs
type OnDamage = Signal<number, string> -- trailing types form the pack
type OnReady = Signal<> -- empty pack
type Fn<Args..., Rets...> = (Args...) -> Rets...
type Explicit = Fn<(number, string), ...boolean> -- parenthesize all but the last pack

print(ok, doubled)
local _d: OnDamage? = nil
local _r: OnReady? = nil
local _e: Explicit? = nil
```

- A function's return type is a pack. `() -> ()` returns nothing, and `() ->
  ...number` returns any number of numbers.
- Packs can't be optional (`(A, B)?` is a syntax error) and can't be stored in
  tables. Use `table.pack(...)`, which is `{ [number]: T, n: number }`, to
  capture values.

## Self-referential generics

```luau
--!strict
type Tree<T> = { value: T, children: { Tree<T> } }
local leaf: Tree<number> = { value = 1, children = {} }
print(leaf)
```

A recursive alias must use the **same** parameters when it refers to itself.
Inside `Tree<T>`, writing `Tree<{ T }>` is rejected.

<!--
Source references:
- https://luau.org/types/generics
- https://luau.org/types/basic-types#type-packs
- https://rfcs.luau.org/explicit-type-parameter-instantiation.html
- https://rfcs.luau.org/syntax-default-type-alias-type-parameters.html
- https://rfcs.luau.org/recursive-type-restriction.html
-->
