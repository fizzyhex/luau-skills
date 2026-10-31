---
name: advanced-api
description: |
    Use when preregistering components, bulk operations, or advanced type
    patterns in jecs
---

# Jecs Advanced API

Preregistration, bulk operations, and exported Luau types.

## Preregistering Components

Register components before world creation for stable IDs.

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)

-- Preregister (before world)
local Transform = jecs.component() :: jecs.Id<CFrame>
local Velocity = jecs.component() :: jecs.Id<Vector3>
local Dead = jecs.tag()

-- Add metadata before world
jecs.meta(Transform, jecs.Name, "Transform")
jecs.meta(Velocity, jecs.Name, "Velocity")

-- Components registered when world created
local world = jecs.world()
```

**Benefits:**

- Stable component IDs across sessions
- Metadata available immediately
- Cleaner module structure (a shared `components` ModuleScript that every
  system requires)

## Bulk Operations

Insert or remove multiple components in a single archetype transition.

### bulk_insert

```luau
local Transform = world:component() :: jecs.Id<CFrame>
local Velocity = world:component() :: jecs.Id<Vector3>
local Mass = world:component() :: jecs.Id<number>
local Dead = world:entity()

local entityId = world:entity()

-- Insert multiple components at once (ids and values are parallel arrays)
jecs.bulk_insert(
	world,
	entityId,
	{ Transform, Velocity, Mass, Dead },
	{ CFrame.identity, Vector3.new(1, 0, 0), 100, nil }
)
```

Tags use `nil` as the placeholder value. Values are not type-checked against
their components (`values` is `{ any }`).

### bulk_remove

```luau
-- Remove multiple components at once
jecs.bulk_remove(world, entityId, { Transform, Velocity, Mass })
```

**Performance:** Single archetype transition vs multiple.

## Entity Records

Access internal entity storage info.

```luau
local entityRecord: jecs.Record = jecs.record(world, entityId)
-- entityRecord.archetype - current archetype
-- entityRecord.row - position in archetype
-- entityRecord.dense - position in dense array
```

## Component Records

Access component storage metadata.

```luau
local compRecord: jecs.ComponentRecord? = jecs.component_record(world, Transform)
-- compRecord.records - { [archetypeId]: column index }
-- compRecord.counts - { [archetypeId]: entity count }
-- compRecord.size - total entities with this component
```

## Luau Types

### Core Types

```luau
type World = jecs.World -- World instance
type Entity<T = nil> = jecs.Entity<T> -- Entity ID (T = data type when used as a component)
type Id<T = any> = jecs.Id<T> -- Component or pair ID carrying data type T
type Pair<First, Second> = jecs.Pair<First, Second> -- Relationship pair
type Query<T...> = jecs.Query<T...> -- Uncached query
type CachedQuery<T...> = jecs.Cached_Query<T...> -- Cached query
type Archetype = jecs.Archetype -- Archetype storage
type Record = jecs.Record -- Entity record
type ComponentRecord = jecs.ComponentRecord -- Component metadata
```

There is no separate `Tag` type: a tag is an `jecs.Entity<nil>` (what
`jecs.tag()` and `world:entity()` return).

### Type Inference

The data type travels in the ID's phantom `__T` field. Declare it once with a
`::` cast and the solver infers it everywhere else.

```luau
local Health = world:component() :: jecs.Id<number>

-- Pair data type: the first element's type, unless the first is a tag,
-- in which case the second element's type is used
local Owns = world:component() :: jecs.Id<{ amount: number }>
local car = world:entity()
world:set(e, jecs.pair(Owns, car), { amount = 1 }) -- { amount: number }

local Begin = world:entity() -- tag
world:set(e, jecs.pair(Begin, Transform), CFrame.identity) -- CFrame (from Transform)
```

### Query Typing

```luau
-- Query values are inferred from the component IDs
for entity, transform, velocity in world:query(Transform, Velocity) do
	-- entity: jecs.Entity
	-- transform: CFrame
	-- velocity: Vector3
end

-- Multiple get returns a tuple of optionals
local transform, velocity = world:get(entityId, Transform, Velocity)
-- transform: CFrame?
-- velocity: Vector3?
```

Typed queries and `get` overloads cover up to 8 query terms and 4 `get`
components.

## Debug Mode

Enable runtime checks:

```luau
local world = jecs.world(true) -- DEBUG mode

-- Throws on:
-- - Structural changes in OnRemove during deletion
-- - Invalid entity references
-- - Component ID misuse
```

## is_tag Helper

Check if an ID is a tag (no data):

```luau
local world = jecs.world()
local Dead = world:entity()
local Health = world:component() :: jecs.Id<number>

jecs.is_tag(world, Dead) -- true
jecs.is_tag(world, Health) -- false (world:component() is never a tag)
```

Useful for serialization and networking logic.

## Quick Reference

| Function                              | Purpose                     |
| ------------------------------------- | --------------------------- |
| `jecs.component() :: jecs.Id<T>`      | Preregister typed component |
| `jecs.tag()`                          | Preregister tag             |
| `jecs.meta(e, id, value)`             | Set metadata before world   |
| `jecs.bulk_insert(w, e, ids, values)` | Insert multiple components  |
| `jecs.bulk_remove(w, e, ids)`         | Remove multiple components  |
| `jecs.record(w, e)`                   | Get entity record           |
| `jecs.component_record(w, id)`        | Get component record        |
| `jecs.is_tag(w, id)`                  | Check if tag                |

<!--
Source references:
- how_to/011_preregistering_components.luau
- src/jecs.luau (exported types)
-->
