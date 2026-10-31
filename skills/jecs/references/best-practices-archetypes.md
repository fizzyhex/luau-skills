---
name: best-practices-archetypes
description: |
    Use when understanding archetype storage, entity transitions, or dealing
    with fragmentation in jecs
---

# Jecs Archetypes

Archetypes are the core storage unit. Understanding them helps optimize
performance.

## What is an Archetype?

An archetype represents a unique combination of components. All entities with
exactly the same component set belong to the same archetype.

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)

local world = jecs.world()

local Position = world:component() :: jecs.Id<Vector3>
local Velocity = world:component() :: jecs.Id<Vector3>
local Mass = world:component() :: jecs.Id<number>

local e1 = world:entity()
world:set(e1, Position, Vector3.zero) -- creates archetype [Position]
world:set(e1, Velocity, Vector3.zero) -- moves to archetype [Position, Velocity]

local e2 = world:entity()
world:set(e2, Position, Vector3.zero) -- archetype [Position] exists
world:set(e2, Velocity, Vector3.zero) -- archetype [Position, Velocity] exists
world:set(e2, Mass, 100) -- creates archetype [Position, Velocity, Mass]

-- e1 in [Position, Velocity]
-- e2 in [Position, Velocity, Mass]
```

## Archetype Transitions

When adding/removing components, entities move between archetypes:

1. Remove entity from old archetype's entity list
2. Copy component data to new archetype's columns
3. Add entity to new archetype's entity list
4. Update entity record (archetype pointer, row index)

**This is why add/remove is more expensive than set.** Setting values doesn't
change archetypes.

## Archetype Graph

Archetypes form a cached graph:

```text
ROOT_ARCHETYPE
    └── +Position → [Position]
                        └── +Velocity → [Position, Velocity]
                                            └── +Mass → [Position, Velocity, Mass]
```

Edges are cached bidirectionally. Adding a component follows an edge; if no edge
exists, a new archetype is created.

## Fragmentation

Fragmentation occurs when entities spread across many archetypes, especially
with relationships.

```luau
local pair = jecs.pair
local Likes = world:entity()

world:add(e1, pair(Likes, alice)) -- archetype [pair(Likes, alice)]
world:add(e2, pair(Likes, bob)) -- archetype [pair(Likes, bob)]
world:add(e3, pair(Likes, charlie)) -- archetype [pair(Likes, charlie)]
-- 3 different archetypes!
```

**Impact:**

- More archetypes = more archetype creation overhead
- Queries must iterate more archetypes
- Wildcard indices add registration overhead (each relationship pair registers
  with `pair(R, T)`, `pair(R, Wildcard)`, and `pair(Wildcard, T)` indices)

## When Fragmentation Matters

Fragmentation from relationships is often acceptable. Relationships provide
auto-cleanup on target deletion and queryable graph semantics. Only optimize if
profiling shows a bottleneck.

**Alternative when you don't need relationship semantics:**

```luau
-- Relationship approach: One archetype per target, but auto-cleanup on delete
world:add(entity, pair(Likes, uniqueTarget))

-- Data approach: Shared archetype, but manual cleanup required
local LikesSomeone = jecs.tag()
local LikesTarget = world:component() :: jecs.Id<jecs.Entity>
world:add(entity, LikesSomeone)
world:set(entity, LikesTarget, targetEntity) -- Store target as component data
```

**Batch component operations:**

```luau
-- BAD: Multiple archetype transitions
world:set(entity, Position, Vector3.zero)
world:set(entity, Velocity, Vector3.zero)
world:set(entity, Mass, 100)

-- BETTER: Single transition
jecs.bulk_insert(world, entity, { Position, Velocity, Mass }, { Vector3.zero, Vector3.zero, 100 })

-- Batch removal
jecs.bulk_remove(world, entity, { Velocity, Mass })
```

## Archetype Lifecycle

**Empty archetypes persist** for recycling. They don't slow down queries
(`query:archetypes()` skips empty archetypes automatically).

**Archetypes are invalidated** (auto-deleted) when one of their component IDs
can no longer be used (e.g., relationship target entity is deleted).

**Manual cleanup** removes empty archetypes to free memory:

```luau
world:cleanup()
```

**When to call `cleanup()`:**

- Every ~15 seconds during gameplay, OR
- When archetype count exceeds ~100
- After mass entity deletion (especially with relationships)

## Performance Guidelines

| Operation                  | Cost     | Notes                            |
| -------------------------- | -------- | -------------------------------- |
| `set` (existing component) | Low      | Same archetype                   |
| `add`/`remove`             | Medium   | Archetype transition             |
| New archetype creation     | High     | Graph update, query cache update |
| Query iteration            | Very low | Especially cached                |

**Rules of thumb:**

1. Minimize component add/remove during gameplay
2. Prefer `set` over `add`+`set`
3. Cache frequently-used queries
4. Use `jecs.bulk_insert`/`jecs.bulk_remove` for batched operations
5. Call `world:cleanup()` periodically or after mass deletions

<!--
Source references:
- how_to/030_archetypes.luau
- how_to/040_fragmentation.luau
-->
