---
name: feature-pairs
description: |
    Use when creating entity relationships, parent-child hierarchies, or
    querying pairs in jecs
---

# Jecs Pairs and Relationships

Pairs encode entity-to-entity relationships: `(Relationship, Target)`.

## Creating Pairs

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local pair = jecs.pair

local world = jecs.world()
local Likes = world:entity()

local alice = world:entity()
local bob = world:entity()

-- Add relationship
world:add(bob, pair(Likes, alice)) -- bob likes alice

-- Check relationship
world:has(bob, pair(Likes, alice)) -- true
world:has(bob, pair(Likes, jecs.Wildcard)) -- true (likes anyone)
```

## Pairs with Data

First element determines data type (or the second, if the first is a tag).

```luau
type OwnershipData = {
	since: string,
}

local Owns = world:component() :: jecs.Id<OwnershipData>
local car = world:entity()

world:set(bob, pair(Owns, car), { since = "2024-01-01" })

local data = assert(world:get(bob, pair(Owns, car)), "Ownership data should be defined")
print(data.since) -- "2024-01-01"
```

## Built-in Relationships

### ChildOf (Parent-Child Hierarchy)

```luau
local ChildOf = jecs.ChildOf

local parent = world:entity()
local child = world:entity()

world:add(child, pair(ChildOf, parent))

-- Get parent
world:parent(child) -- returns parent
world:target(child, ChildOf) -- same thing

-- Iterate children
for childEntityId in world:children(parent) do
	print(childEntityId)
end

-- Or via query
for childEntityId in world:query(pair(ChildOf, parent)) do
	print(childEntityId)
end
```

**Note:** ChildOf is exclusive (one parent only) and cascades deletion. Use
ChildOf for **ownership/lifecycle** (deletion, serialization), not necessarily
for operational links. For direct access in systems, also store entity members.
See `ecs-design` skill for when to use both together.

### Exclusive Relationships

Only one target allowed per relationship type.

```luau
local item = world:entity()
local player1 = world:entity()
local player2 = world:entity()

local BelongsTo = world:entity()
world:add(BelongsTo, jecs.Exclusive)

world:add(item, pair(BelongsTo, player1))
world:add(item, pair(BelongsTo, player2))
-- Now item belongs to player2 only (replaced)
```

## Querying Relationships

### Specific Target

```luau
-- All entities that like alice
for entityId in world:query(pair(Likes, alice)) do
	print(entityId)
end
```

### Wildcard Target

```luau
-- All entities that like someone
for entityId in world:query(pair(Likes, jecs.Wildcard)) do
	local target = world:target(entityId, Likes)
	print(`{entityId} likes {target}`)
end
```

### Wildcard Relationship

```luau
-- All relationships with alice as target
for entityId in world:query(pair(jecs.Wildcard, alice)) do
	print(`{entityId} has relationship with alice`)
end
```

### Multiple Targets

Entity can have multiple targets for same relationship. `world:target` indices
are 0-based.

```luau
world:add(bob, pair(Likes, alice))
world:add(bob, pair(Likes, charlie))

-- Iterate all targets
local nth = 0
local target = world:target(bob, Likes, nth)
while target do
	print(`bob likes {target}`)
	nth += 1
	target = world:target(bob, Likes, nth)
end

-- Or use the targets iterator
for liked in world:targets(bob, Likes) do
	print(`bob likes {liked}`)
end
```

## Pair Introspection

```luau
local likesPair = pair(Likes, alice)

-- Check if ID is a pair
jecs.IS_PAIR(likesPair) -- true

-- Extract parts (resolves alive entities)
jecs.pair_first(world, likesPair) -- Likes
jecs.pair_second(world, likesPair) -- alice

-- Raw extraction (no world needed)
jecs.ECS_PAIR_FIRST(likesPair) -- raw ID
jecs.ECS_PAIR_SECOND(likesPair) -- raw ID
```

## Combining with Components

```luau
local Transform = world:component() :: jecs.Id<CFrame>
local Health = world:component() :: jecs.Id<number>

-- Query children with Transform and Health
for entity, transform, health in world:query(Transform, Health, pair(ChildOf, parent)) do
	print(`Child {entity}: pos={transform}, health={health}`)
end
```

## Use Cases

| Pattern     | Example                  |
| ----------- | ------------------------ |
| Hierarchy   | `pair(ChildOf, parent)`  |
| Ownership   | `pair(OwnedBy, player)`  |
| Targeting   | `pair(Targets, enemy)`   |
| Tagging     | `pair(InZone, zone)`     |
| Graph edges | `pair(ConnectsTo, node)` |

## Multi-Position Pattern

Use pairs for multiple values of same type.

```luau
local Begin = world:entity()
local End = world:entity()

world:set(entity, pair(Begin, Transform), CFrame.new(0, 0, 0))
world:set(entity, pair(End, Transform), CFrame.new(10, 20, 30))
```

<!--
Source references:
- how_to/013_pairs.luau
- how_to/041_entity_relationships.luau
- how_to/042_target.luau
- how_to/043_wildcards.luau
- examples/queries/wildcards.luau
- examples/entities/hierarchy.luau
-->
