---
name: core-basics
description: |
    Use when creating worlds, entities, components, tags, or singletons in jecs
---

# Jecs Core Basics

World, entities, components, tags, and singletons in jecs ECS.

## World Creation

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)

local world: jecs.World = jecs.world()
```

## Entities

Entities are unique IDs (48-bit: 24-bit index + 24-bit generation).

```luau
-- Create entity
local entityId: jecs.Entity = world:entity()

-- Create at specific ID (bypasses the entity range)
world:entity(42)

-- Check existence
world:contains(entityId) -- true if alive with correct generation
world:exists(entityId) -- true if ID exists (ignores generation)

-- Delete entity (removes all components, triggers cleanup)
world:delete(entityId)

-- Entity ID introspection
local index = jecs.ECS_ID(entityId)
local generation = jecs.ECS_GENERATION(entityId)
```

**Generation:** When entities are recycled, generation increments. Stale
references fail `contains()` check.

## Components

Components are typed data attached to entities. IDs occupy range 1-256.

```luau
-- Create typed component: the cast fixes the data type
local Transform = world:component() :: jecs.Id<CFrame>
local Health = world:component() :: jecs.Id<number>

-- Set component data (value type is checked against the component)
world:set(entityId, Transform, CFrame.new(10, 20, 30))
world:set(entityId, Health, 100)

-- Get component data (returns T?)
local transform: CFrame? = world:get(entityId, Transform)
local health = assert(world:get(entityId, Health), "Entity must have health")

-- Get up to 4 components at once
local t, h = world:get(entityId, Transform, Health)

-- Check component presence (up to 4)
world:has(entityId, Transform)
world:has(entityId, Transform, Health)

-- Remove component
world:remove(entityId, Transform)

-- Clear all components (keeps entity)
world:clear(entityId)
```

**Mental Model:**

- Components = columns
- Entities = rows
- `set`/`get`/`remove` = cell operations

## Tags

Tags are components with no data (zero storage cost).

```luau
-- Create tag (preregistered; declare before creating the world)
local Dead = jecs.tag()

-- Or use a regular entity as a tag
local Enemy = world:entity()

-- Add tag (not set!)
world:add(entityId, Dead)
world:add(entityId, Enemy)

-- Check/remove same as components
world:has(entityId, Dead)
world:remove(entityId, Dead)
```

**Key Difference:** `world:add()` for tags, `world:set()` for data components.
`world:component()` always creates a data component (it has the
`jecs.Component` trait), so use `jecs.tag()` or `world:entity()` for tags.

## Singletons

Use component ID as both key and entity for global resources.

```luau
local TimeOfDay = world:component() :: jecs.Id<number>

-- Set singleton
world:set(TimeOfDay, TimeOfDay, 12.5)

-- Get singleton
local time = assert(world:get(TimeOfDay, TimeOfDay), "Singleton must have value")
-- time is 12.5
```

## Entity Ranges

Reserve ID ranges for client/server separation.

```luau
-- Restrict entity creation to range [1000, 5000]
world:range(1000, 5000)

-- Open-ended range (5000+)
world:range(5000)
```

## Component Metadata

Components are entities - set metadata using standard APIs.

```luau
world:set(Transform, jecs.Name, "Transform")
print(world:has(Transform, jecs.Component)) -- true
```

## Quick Reference

| Operation        | Method                                 |
| ---------------- | -------------------------------------- |
| Create world     | `jecs.world()`                         |
| Create entity    | `world:entity()`                       |
| Create component | `world:component() :: jecs.Id<T>`      |
| Create tag       | `jecs.tag()`                           |
| Set data         | `world:set(e, comp, value)`            |
| Add tag          | `world:add(e, tag)`                    |
| Get data         | `world:get(e, comp...)`                |
| Has component    | `world:has(e, comp...)`                |
| Remove           | `world:remove(e, comp)`                |
| Delete entity    | `world:delete(e)`                      |
| Clear entity     | `world:clear(e)`                       |

<!--
Source references:
- how_to/001_hello_world.luau
- how_to/002_entities.luau
- how_to/003_components.luau
- how_to/004_tags.luau
- how_to/005_entity_singletons.luau
- how_to/010_how_components_works.luau
-->
