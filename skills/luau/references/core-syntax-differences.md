---
name: core-syntax-differences
description: |
    Use when unsure whether a Lua 5.x/other-language feature exists in Luau, or
    when writing loops, string formatting, conditionals or constants
---

# Luau Syntax vs Lua 5.1

Luau is Lua 5.1 plus extensions. Some later-Lua features exist, and many
features from other languages don't.

## Extensions that exist

```luau
--!strict
local scores: { [string]: number } = { alice = 10, bob = 0, carol = 7 }

-- Generalized iteration: no pairs/ipairs needed (and equally fast)
for name, score in scores do
	if score == 0 then
		continue -- `continue` exists; must be the last statement in its block
	end
	-- String interpolation with backticks; any expression inside {}
	print(`{name} scored {score}`)
end

-- Compound assignment (statements, not expressions): += -= *= /= //= %= ^= ..=
local total = 0
total += 5
local s = "a"
s ..= "b"

-- Floor division
local half = 7 // 2 -- 3

-- if-then-else EXPRESSION (else is mandatory, no `end`)
local label = if total > 5 then "big" elseif total > 0 then "small" else "zero"

-- const binding: cannot be reassigned (the value is still mutable)
const MAX_ITEMS = 10
const config = table.freeze({ debug = false }) -- freeze to make contents immutable

-- Number literals
local mask = 0b1010_1010
local big = 1_000_000
local hex = 0xFF

print(half, label, MAX_ITEMS, config, mask, big, hex)
```

### Attributes

```luau
@native -- compile this function with native codegen
local function dot(ax: number, ay: number, bx: number, by: number): number
	return ax * bx + ay * by
end

@[deprecated { use = "newApi()", reason = "faster" }]
local function oldApi() end

print(dot(1, 2, 3, 4), oldApi)
```

Only built-in attributes exist: `@native`, `@deprecated` (plus internal ones).
Users can't define their own. `@native` does not apply to nested functions.

Tooling caveat: StyLua 2.6.0 and selene 0.32.0 can't parse the parameterized
`@[...]` form, though they handle plain `@native`/`@deprecated`. Use plain
`@deprecated` in projects that run them.

### Custom iteration with `__iter`

```luau
local Bag = {}
Bag.__index = Bag
Bag.__iter = function(self: { items: { string } })
	return next, self.items
end

local bag = setmetatable({ items = { "egg", "rice" } }, Bag)
for i, item in bag do
	print(i, item)
end
```

`__pairs`/`__ipairs` are **not** supported. Use `__iter`.

## Things that do NOT exist

| Feature                       | Use instead                                                    |
| ----------------------------- | -------------------------------------------------------------- |
| `goto` / labels               | `continue`, `break`, early `return`                            |
| Integer type, `math.tointeger`| Numbers are doubles (exact integers up to 2^53)                |
| `&` `\|` `~` `<<` `>>` ops    | `bit32.band/bor/bxor/lshift/rshift/arshift` (32-bit)           |
| `<const>` / `<close>`         | `const x = ...`; there's no to-be-closed equivalent            |
| `__gc` finalizers             | Explicit `:Destroy()` / cleanup functions                      |
| Tail-call elimination         | Loops for deep recursion (stack depth ~20000 Luau calls)       |
| `__pairs` / `__ipairs`        | `__iter`                                                       |
| `io`, `loadfile`, `dofile`    | Host APIs (Roblox services, Lune `@lune/fs`)                   |
| `string.dump`, bytecode load  | Not available (sandboxing)                                     |
| User-defined overloads        | Intersection-typed values, or one function with union params   |
| Ternary `a ? b : c`           | `if a then b else c`                                           |
| `!=`, `!`, `&&`, `\|\|`       | `~=`, `not`, `and`, `or`                                       |
| `x++`                         | `x += 1`                                                       |
| `print(x += 1)`               | Compound assignment is a statement                             |

## Gotchas that still apply from Lua

```luau
--!strict
local list = { "a", "b", "c" }
print(list[0]) --> nil (arrays are 1-based)
print(list[1]) --> a

-- `#` is only meaningful for arrays without holes. On a dictionary it's 0,
-- and with nil holes the result is any valid "border" (unspecified).
local dict: { [string]: number } = { a = 1, b = 2 }
local count = 0
for _ in dict do
	count += 1
end

-- `a and b or c` breaks when b is falsy; use an if-expression
local flag = false
local wrong = true and flag or "fallback" --> "fallback" (!)
local right = if true then flag else "fallback" --> false

-- Only nil and false are falsy: 0 and "" are truthy
if 0 then
	print("0 is truthy")
end

print(count, wrong, right)
```

- Inequality is `~=`; string concatenation is `..`.
- `string.format`, `string.find` etc. use **Lua patterns**, not regex. `.`, `%d`
  and `%a` are pattern classes, and `%` is the escape character.
- `print"hi"` works, but a backtick string must be parenthesized:
  `` print(`hi`) ``.
- `{{` inside an interpolated string is a parse error. Escape braces with `\{`.
- Interpolated strings can't be used as types (`` type T = `x` `` is invalid).
- In `repeat ... until cond`, `continue` can't skip a local that `cond` uses.
- Table literals assign in program order. Closures may be cached and reused,
  which changes function identity but not behavior.

<!--
Source references:
- https://luau.org/syntax
- https://luau.org/compatibility
- https://luau.org/attributes
- https://rfcs.luau.org/const-keyword.html
- https://rfcs.luau.org/generalized-iteration.html
-->
