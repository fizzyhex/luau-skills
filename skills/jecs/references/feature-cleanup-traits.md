---
name: feature-cleanup-traits
description: |
    Use when configuring automatic cleanup behavior for component/entity
    deletion in jecs
---

# Jecs Cleanup Traits

Cleanup traits define what happens when components or relationship targets are
deleted.

## Cleanup Actions

| Action   | Effect                                           |
| -------- | ------------------------------------------------ |
| `Remove` | Remove the component from all entities (default) |
| `Delete` | Delete all entities that have the component      |

## Cleanup Conditions

| Condition        | Triggers When                       |
| ---------------- | ----------------------------------- |
| `OnDelete`       | The component/tag itself is deleted |
| `OnDeleteTarget` | A relationship target is deleted    |

## Configuration

Apply traits as `(Condition, Action)` pairs on components:

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local pair = jecs.pair

local world = jecs.world()

-- (OnDelete, Remove) - Default behavior
local Tag = world:entity()
world:add(Tag, pair(jecs.OnDelete, jecs.Remove))

-- (OnDelete, Delete) - Cascade deletion
local Critical = world:entity()
world:add(Critical, pair(jecs.OnDelete, jecs.Delete))
```

## OnDelete Behaviors

### OnDelete + Remove (Default)

When component deleted, remove it from all entities.

```luau
local Buff = world:entity()
world:add(Buff, pair(jecs.OnDelete, jecs.Remove))

local entityId = world:entity()
world:add(entityId, Buff)

world:delete(Buff)
world:has(entityId, Buff) -- false (removed)
world:contains(entityId) -- true (still exists)
```

### OnDelete + Delete

When component deleted, delete all entities that have it.

```luau
local Temporary = world:entity()
world:add(Temporary, pair(jecs.OnDelete, jecs.Delete))

local entityId = world:entity()
world:add(entityId, Temporary)

world:delete(Temporary)
world:contains(entityId) -- false (deleted)
```

## OnDeleteTarget Behaviors

For relationships - trigger when target entity is deleted.

### OnDeleteTarget + Remove

Remove relationship when target deleted.

```luau
local OwnedBy = world:entity()
world:add(OwnedBy, pair(jecs.OnDeleteTarget, jecs.Remove))

local loot = world:entity()
local player = world:entity()
world:add(loot, pair(OwnedBy, player))

world:delete(player)
world:has(loot, pair(OwnedBy, player)) -- false
world:contains(loot) -- true (loot still exists)
```

### OnDeleteTarget + Delete (Hierarchy)

Delete entities when their relationship target is deleted.

```luau
-- ChildOf has this built-in
local CustomChildOf = world:entity()
world:add(CustomChildOf, pair(jecs.OnDeleteTarget, jecs.Delete))

local parent = world:entity()
local child = world:entity()
world:add(child, pair(CustomChildOf, parent))

world:delete(parent)
world:contains(child) -- false (cascaded)
```

**Note:** `jecs.ChildOf` has this trait built-in.

## Built-in Cleanup Traits

| Component      | Cleanup Trait              |
| -------------- | -------------------------- |
| `jecs.ChildOf` | `(OnDeleteTarget, Delete)` |

`ChildOf` also has the `Exclusive` trait (one parent only) - see
[feature-pairs](feature-pairs.md#exclusive-relationships).

## Common Patterns

**Faction membership:**

```luau
local MemberOf = world:entity()
world:add(MemberOf, pair(jecs.OnDeleteTarget, jecs.Remove))
-- Deleting faction removes membership, keeps entities
```

**Scene hierarchy:**

```luau
local InScene = world:entity()
world:add(InScene, pair(jecs.OnDeleteTarget, jecs.Delete))
-- Deleting scene deletes all entities in it
```

**Equipment slots:**

```luau
local EquippedBy = world:entity()
world:add(EquippedBy, pair(jecs.OnDeleteTarget, jecs.Remove))
-- Player deletion removes equipment reference, keeps items
```

## Performance Note

Relationships increase archetype count. Each `pair(Relation, target)` creates
new archetypes. Cleanup traits help manage this but consider fragmentation for
heavy relationship use.

See [best-practices-archetypes](best-practices-archetypes.md) for fragmentation
details.

<!--
Source references:
- how_to/100_cleanup_traits.luau
-->
