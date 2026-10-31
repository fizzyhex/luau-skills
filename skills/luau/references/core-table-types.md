---
name: core-table-types
description: |
    Use when typing Luau tables: arrays, dictionaries, records, optional fields,
    read-only/write-only properties, frozen tables, or sealed vs unsealed errors
---

# Table Types

```luau
--!strict
type Array = { string } -- same as { [number]: string }
type Dict = { [string]: number } -- indexer
type Record = { name: string, hp: number, tag: string? } -- properties
type Mixed = { [number]: string, n: number } -- properties + indexer
```

## Sealed vs unsealed

- **Unsealed**: a table literal with no annotation, in the scope that created
  it. Adding fields extends its type.
- **Sealed**: an annotated table, or one that has left its scope (for example
  returned from a function). Adding unknown fields is an error.

```luau
--!strict
local t = { x = 1 }
t.y = 2 -- ok: unsealed, type is now { x: number, y: number }

local p: { x: number } = { x = 1 }
-- p.y = 2 -- error: sealed

-- Width subtyping: a sealed table with MORE fields fits a type with fewer
type Point2D = { x: number, y: number }
type Point1D = { x: number }
local q: Point1D = { x = 5, y = 1 } :: Point2D
print(t, p, q)
```

When you build an object field by field, declare its type up front:

```luau
--!strict
type Stats = { hp: number, speed: number }
local stats: Stats = { hp = 100, speed = 16 } -- prefer a complete literal
```

## Indexers don't add `nil`

```luau
--!strict
local prices: { [string]: number } = { apple = 1 }
local p = prices.banana -- typed `number`, but is nil at runtime!

-- Make the absence explicit when it matters:
local safe: number? = prices["banana"]
if safe then
	print(safe + 1)
end
print(p)
```

Array reads like `list[i]` are typed `T`, not `T?`, too. Guard indices
yourself.

## Iterating records (new solver)

```luau
--!strict
-- `for k, v in { a = 1, b = 2 }` on a record type errors in the new solver:
-- "Cannot iterate over a table without indexer". Type it as a dictionary:
local scores: { [string]: number } = { alice = 10, bob = 3 }
for name, score in scores do
	print(name, score)
end
```

## read / write properties (new solver)

```luau
--!strict
type ReadOnlyPoint = { read x: number, read y: number }
type Sink = { write value: string }
type ReadOnlyList<T> = { read T } -- read-only array/indexer
type ReadOnlyMap<K, V> = { read [K]: V }

local origin: ReadOnlyPoint = { x = 0, y = 0 }
-- origin.x = 1 -- error: Property x of table 'ReadOnlyPoint' is read-only

-- read/write are contextual keywords and still valid property names
type Reader = { read: () -> number }

print(origin)
local _l: ReadOnlyList<number> = { 1 }
local _m: ReadOnlyMap<string, number> = {}
local _s: Sink? = nil
local _r: Reader? = nil
```

Use `read` for API surfaces that callers mustn't mutate. A `{ read x: T }`
parameter also accepts **subtypes** of `T`, because read-only properties are
covariant.

## Frozen tables

```luau
--!strict
local Colors = table.freeze({ Red = 1, Blue = 2 })
-- Colors.Red = 3 -- type error (new solver): property is read-only; runtime error too
type Color = keyof<typeof(Colors)> -- "Blue" | "Red"
local c: Color = "Red"
print(c, table.isfrozen(Colors))
```

`table.freeze` is shallow and returns the same table. Freezing a table that's
already frozen errors. Frozen properties are `read`, so dynamic indexing
`Colors[key]` with a `keyof` union fails to type-check. Index with literal
keys, or keep the table unfrozen if you need dynamic lookups. Frozen tables make good
enum-like constants. `table.clone` returns an unfrozen, shallow copy.

## Useful table library functions

| Function                       | Notes                                                      |
| ------------------------------ | ---------------------------------------------------------- |
| `table.create(n, v?)`          | Preallocates the array part; fills with `v` if given       |
| `table.find(t, v, init?)`      | Linear search in an array, returns an index or `nil`       |
| `table.clear(t)`               | Empties the table but keeps its capacity (reuse buffers)   |
| `table.clone(t)`               | Shallow copy (metatable kept, not frozen)                  |
| `table.freeze(t)` / `isfrozen` | Shallow, irreversible                                      |
| `table.move(a, f, t, d, tt?)`  | Bulk copy of array ranges                                  |
| `table.insert/remove/sort`     | Array only, and tuned for arrays                           |
| `table.concat(t, sep?)`        | Fast string building                                       |

`table.getn`, `table.foreach` and `table.foreachi` are deprecated.

<!--
Source references:
- https://luau.org/types/tables
- https://rfcs.luau.org/syntax-property-access-modifiers.html
- https://rfcs.luau.org/property-readonly.html
- https://rfcs.luau.org/function-table-freeze.html
- https://luau.org/library#table-library
-->
