---
name: best-practices-performance
description: |
    Use when optimizing hot Luau code on Roblox: native codegen (@native,
    --!native), table preallocation, buffers, vector math, builtin fastcalls,
    method call costs, or GC pressure
---

# Performance

Luau is fast when code is idiomatic and well typed. Profile first (MicroProfiler
or Script Profiler in Studio), then apply these rules to the hot paths only.

## Native code generation

```luau
--!native
--!strict
-- Whole-script native compilation

local function lengthSquared(v: Vector3): number
	return v.X * v.X + v.Y * v.Y + v.Z * v.Z
end

return lengthSquared
```

```luau
--!strict
-- Or per function:
@native
local function sumSquares(list: { number }): number
	local total = 0
	for _, n in list do
		total += n * n
	end
	return total
end

return sumSquares
```

- Native codegen helps **compute-heavy** Luau (math, buffers, loops). It
  doesn't speed up engine API calls, yields, or code that mostly calls Roblox
  methods.
- **Type annotations matter.** Codegen specializes on annotated parameter
  types such as `number`, `vector`/`Vector3` and `buffer`. Leaving them
  unannotated (or typing them `any`) keeps the generic paths.
- `@native` doesn't cover nested functions. Mark each one.
- Native compilation costs memory and load time, so apply it selectively.
  Avoid `getfenv`/`setfenv`, which disable optimizations.

## Tables

```luau
--!strict
local N = 1000

-- Preallocate arrays with a known size
local squares = table.create(N)
for i = 1, N do
	squares[i] = i * i -- known index is faster than table.insert when filling sequentially
end

-- Build objects with a complete literal (uses table templates)
local function newParticle(x: number, y: number)
	return { x = x, y = y, vx = 0, vy = 0, life = 1 }
end

-- Reuse instead of reallocating in hot loops
local scratch: { number } = {}
local function collect(values: { number }): { number }
	table.clear(scratch) -- keeps capacity
	for _, v in values do
		if v > 0 then
			table.insert(scratch, v)
		end
	end
	return scratch
end

print(#squares, newParticle(0, 0), collect({ 1, -1 }))
```

- Iterate with `for k, v in t`, `pairs` or `ipairs`. They're equally fast and
  avoid per-iteration calls. `for i = 1, #t` is slightly slower.
- Use `table.create` for arrays only. It's counter-productive for
  dictionaries.
- Use `t.field` with constant keys and uniform object shapes. That keeps the
  inline caches working.
- `#t` is effectively O(1) because the length is cached.
- Avoid creating temporary tables, closures or strings inside per-frame loops.
  They cause GC assists.

## Methods and OOP

- Point `__index` directly at a **table** (`Class.__index = Class`). `__index`
  functions and deep inheritance chains defeat method-call caching.
- Call methods with `obj:Method()`. Caching methods in locals (`local f =
  obj.Method`) doesn't help in Luau.
- Read static constants from `Class.CONST`, not from `self.CONST`, which goes
  through the metatable.

## Builtins (fastcalls)

- Direct calls such as `math.floor(x)`, `bit32.band(a, b)`, `type(x)`,
  `typeof(x)`, `rawget` and `select("#", ...)` compile to fast paths. You
  don't need `local floor = math.floor`. Globals are resolved at load time.
- `string.byte(s, i)` is faster than `s:byte(i)`, because method calls don't
  fastcall.
- `select(i, ...)` is O(1) with the builtin path.
- New math helpers are builtin and fast: `math.lerp`, `math.map`,
  `math.clamp`, `math.round`, `math.sign`, `math.isnan`, `math.isinf`,
  `math.isfinite`.

## buffer: compact binary data

```luau
--!strict
-- Fixed-size, mutable byte array; ideal for networking/serialization and packed data
local buf = buffer.create(12)
buffer.writef32(buf, 0, 1.5)
buffer.writef32(buf, 4, -2)
buffer.writeu32(buf, 8, 42)

local x = buffer.readf32(buf, 0)
local id = buffer.readu32(buf, 8)
print(x, id, buffer.len(buf), buffer.tostring(buf):len())
```

- Offsets are **0-based** byte offsets, unlike tables. Out-of-range access
  errors.
- Buffers replicate through remotes and store in DataStores more compactly
  than tables of numbers.
- They have `readbits`/`writebits` for bit-packing, plus `copy`, `fill` and
  `fromstring`/`tostring`.

## Vector math

On Roblox, `Vector3` is the native `vector` value type: a 3-wide SIMD value
that isn't heap-allocated. Arithmetic on `Vector3` is cheap. The built-in
`vector` library (`vector.create`, `vector.dot`, `vector.magnitude`, ...) works
on the same type and is fastcall-optimized. Prefer `Vector3` math over three
separate number tables.

## Strings

- Build large strings with `table.concat(parts)` or a `buffer`. Repeated `..`
  in a loop is slow.
- String interpolation and `string.format` are both fine for one-off
  formatting.

<!--
Source references:
- https://luau.org/performance
- https://luau.org/attributes#native
- https://luau.org/library#buffer-library
- https://luau.org/library#vector-library
- https://luau.org/news/2025-12-19-luau-recap-runtime-2025
- https://create.roblox.com/docs/luau/native-code-gen
-->
