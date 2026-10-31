---
name: core-queries
description: |
    Use when querying entities by components, filtering, or caching queries in
    jecs
---

# Jecs Queries

Query, filter, and iterate entities with specific component combinations.

## Basic Query

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)

local world = jecs.world()

local Transform = world:component() :: jecs.Id<CFrame>
local Velocity = world:component() :: jecs.Id<Vector3>

-- Iterate entities with both components (values are typed CFrame, Vector3)
for entityId, transform, velocity in world:query(Transform, Velocity) do
	world:set(entityId, Transform, transform + velocity)
end
```

Query returns entities that have **all** specified components. Queries are
iterable directly; `query:iter()` returns the same iterator explicitly.

## Query Filters

Refine queries with `:with()` and `:without()`.

```luau
-- Create tags
local Walking = jecs.tag()
local Flying = jecs.tag()

-- query() returns values - use for components you need to read
for entityId, transform, velocity in world:query(Transform, Velocity) do
	world:set(entityId, Transform, transform + velocity)
end

-- with() filters only - use for tags or components you don't need to read
for entityId, transform, velocity in world:query(Transform, Velocity):with(Walking):without(Flying) do
	-- Walking required but not returned - only transform and velocity available
	world:set(entityId, Transform, transform + velocity)
end
```

- `query(A, B)`: Returns values of A and B
- `with(...)`: Must have these components (filter only, no values returned)
- `without(...)`: Must NOT have these components

## Cached Queries

Cache for repeated iteration (systems). Faster iteration, slightly slower
creation.

```luau
-- Create once (module scope), reuse every frame
local movementQuery = world:query(Transform, Velocity):cached()

-- Fast iteration
for entityId, transform, velocity in movementQuery do
	world:set(entityId, Transform, transform + velocity)
end
```

**When to cache:**

- Frame-by-frame systems: **Cache**
- Ad-hoc/one-time queries: **Don't cache**
- Dynamic runtime conditions: **Don't cache**

A cached query keeps itself up to date as archetypes are created and deleted.
Call `cachedQuery:fini()` to dispose of one you no longer need.

## Query Methods

```luau
local someEntity = world:entity()

local query = world:query(Transform, Velocity)

-- Iterate
for entityId, transform, velocity in query do
	world:set(entityId, Transform, transform + velocity)
end

query:has(someEntity) -- false

world:set(someEntity, Transform, CFrame.new(0, 0, 0))
world:set(someEntity, Velocity, Vector3.new(1, 0, 0))

-- Check entity membership
query:has(someEntity) -- true

-- Get archetypes directly (advanced)
local archetypes: { jecs.Archetype } = query:archetypes()
```

## Direct Archetype Access

Maximum performance for hot paths - eliminates iterator function call
overhead, which is roughly 60-80% of iteration cost.

```luau
local cached = world:query(Transform, Velocity):cached()

for _, archetype in cached:archetypes() do
	local entities = archetype.entities
	local transforms = archetype.columns_map[Transform]
	local velocities = archetype.columns_map[Velocity]

	-- Iterate backwards so structural changes to the current row are safe
	for row = #entities, 1, -1 do
		transforms[row] = transforms[row] + velocities[row]
	end
end
```

Columns are untyped (`{ any }`); annotate locals if you want typed access, e.g.
`local transforms = archetype.columns_map[Transform] :: { CFrame }`.

## Entity Lookup

Find entities with specific tag/component.

```luau
-- All entities with a component
for entityId in world:each(Transform) do
	print(entityId)
end

-- All children of parent (ChildOf shortcut)
for child in world:children(parent) do
	print(child)
end
```

## Wildcard Queries

Query relationships with any target.

```luau
local pair = jecs.pair

local Likes = world:entity()

-- All entities that like something
for entityId in world:query(pair(Likes, jecs.Wildcard)) do
	local target = world:target(entityId, Likes)
	print(`{entityId} likes {target}`)
end
```

See [feature-pairs](feature-pairs.md) for relationship details.

## Query Tradeoffs

| Type             | Creation | Iteration | Best For          |
| ---------------- | -------- | --------- | ----------------- |
| Uncached         | Fast     | Normal    | Ad-hoc queries    |
| Cached           | Slow     | Fast      | Per-frame systems |
| Archetype access | -        | Fastest   | Hot paths         |

## Common Patterns

**System pattern:**

```luau
local Transform = jecs.component() :: jecs.Id<CFrame>
local Velocity = jecs.component() :: jecs.Id<Vector3>
local Mass = jecs.component() :: jecs.Id<number>

local function physicsSystem(world: jecs.World): (deltaTime: number) -> ()
	-- Runs only once to create the cached query
	local physicsQuery = world:query(Transform, Velocity, Mass):cached()

	return function(deltaTime: number)
		-- Runs every frame
		for entity, transform, velocity, mass in physicsQuery do
			-- Update physics
		end
	end
end
```

**Find first matching entity:**

```luau
local Target = jecs.tag()
local Active = jecs.tag()

local function findFirstTarget(): jecs.Entity?
	for entity in world:query(Target):with(Active) do
		return entity
	end

	return nil
end
```

<!--
Source references:
- how_to/020_queries.luau
- how_to/021_query_operators.luau
- how_to/022_query_caching.luau
-->
