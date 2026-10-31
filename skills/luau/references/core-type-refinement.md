---
name: core-type-refinement
description: |
    Use when narrowing optional, union, or unknown values in Luau with
    if-checks, type(), typeof(), :IsA(), assert, or tagged unions
---

# Type Refinement

The checker narrows the type of a local or property inside a branch when you
test it with:

1. Truthiness: `if x then` (removes `nil`/`false`), `if not x then`.
2. Type guards: `type(x) == "number"` (Luau primitives) or `typeof(x) ==
   "Vector3"` (primitives **plus** Roblox data types).
3. Equality: `x == "hello"` narrows to the singleton `"hello"`.
4. `instance:IsA("ClassName")` for Roblox instances.
5. `assert(cond)`, which refines the rest of the scope.

You can combine them with `and`, `or` and `not`. `~=` inverts a refinement.

## Patterns

```luau
--!strict
-- Early return narrows the rest of the function
local function getName(model: Model?): string
	if not model then
		return "none"
	end
	return model.Name -- model: Model
end

-- unknown -> concrete via type()
local function parse(data: unknown): { name: string, score: number }?
	if type(data) ~= "table" then
		return nil
	end
	local t = data :: { [unknown]: unknown }
	local name, score = t.name, t.score
	if type(name) == "string" and type(score) == "number" then
		return { name = name, score = score }
	end
	return nil
end

-- typeof() also knows Roblox datatypes
local function magnitude(v: unknown): number
	if typeof(v) == "Vector3" then
		return v.Magnitude
	end
	return 0
end

-- assert refines everything after it
local x: string | number = 1
assert(type(x) == "number", "expected number")
local doubled: number = x * 2

-- Optional properties refine too
local cfg: { timeout: number? } = {}
if cfg.timeout then
	local t: number = cfg.timeout
	print(t)
end

print(getName, parse, magnitude, doubled)
```

## Tagged (discriminated) unions

```luau
--!strict
type Shape =
	| { kind: "circle", radius: number }
	| { kind: "rect", w: number, h: number }

local function area(s: Shape): number
	if s.kind == "circle" then
		return math.pi * s.radius ^ 2
	else
		return s.w * s.h -- narrowed to the rect member
	end
end

-- Exhaustiveness check: s is `never` once every tag is handled
local function describe(s: Shape): string
	if s.kind == "circle" then
		return "circle"
	elseif s.kind == "rect" then
		return "rect"
	else
		local _exhaustive: never = s
		return _exhaustive
	end
end

print(area, describe)
```

A leading `|` (or `&`) is allowed in multi-line type definitions.

## Roblox instances: `:IsA`

```luau
--!strict
local function getText(inst: Instance): string
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		return inst.Text
	end
	return ""
end

local function anchorAll(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true -- d: BasePart
		end
	end
end

print(getText, anchorAll)
```

- `IsA` follows inheritance: `IsA("BasePart")` matches Part, MeshPart and so on.
  Compare `ClassName` when you need an exact class, but that doesn't refine the
  type.
- `type(inst)` is `"userdata"` and `typeof(inst)` is `"Instance"`. Neither tells
  you the class.

## What doesn't refine

- `type(x) == "table"` refines `unknown` only to the opaque `table` type, which
  can't be indexed (`Type 'table' does not have key 'name'`). Cast it with
  `x :: { [unknown]: unknown }` as in `parse` above, then check each field.
- Storing a check in a variable (`local ok = type(x) == "string"; if ok then`)
  doesn't narrow `x`. Test inline.
- Refinements apply to locals and property paths. They don't apply to function
  call results (`if f() then f().x end`), so assign to a local first.

<!--
Source references:
- https://luau.org/types/type-refinements
- https://luau.org/types/unions-and-intersections#tagged-unions
- https://luau.org/types/roblox-types
- https://rfcs.luau.org/syntax-leading-bar-and-ampersand.html
-->
