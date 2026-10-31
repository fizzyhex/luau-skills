---
name: feature-hooks
description: |
    Use when defining component constructors/destructors with OnAdd, OnChange,
    OnRemove hooks in jecs. For external observers, use signals instead.
---

# Jecs Component Hooks

Hooks are **constructors and destructors** for components. They define how a
component initializes and cleans up. One hook per type per component, by design.

## Hook Types

| Hook       | Triggers When                       | Signature                            |
| ---------- | ----------------------------------- | ------------------------------------ |
| `OnAdd`    | Component added with value          | `(entity, id, data) -> ()`           |
| `OnChange` | Existing component value changes    | `(entity, id, data) -> ()`           |
| `OnRemove` | Component removed or entity deleted | `(entity, id, delete: boolean?) -> ()` |

### The `id` Parameter

The `id` parameter is the full component ID that triggered the hook:

- **Regular components:** Same as the component you registered on
- **Pairs/relationships:** The full pair (e.g., `pair(ChildOf, parent)`)

For pairs, use `jecs.pair_second(world, id)` to extract the target entity. See
[Hooks for Pairs](#hooks-for-pairs) for examples.

## Setting Up Hooks

Hooks are set as data on the component entity. Define them **before** the
component is first used, or existing archetypes will not invoke them.

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)

local world = jecs.world()
local Transform = world:component() :: jecs.Id<CFrame>

world:set(Transform, jecs.OnAdd, function(entity: jecs.Entity, id, data)
	print(`Transform added to {entity}`)
end)

world:set(Transform, jecs.OnChange, function(entity: jecs.Entity, id, data)
	print(`Transform changed on {entity} to {data}`)
end)

world:set(Transform, jecs.OnRemove, function(entity: jecs.Entity, id, delete)
	if delete then
		return -- Entity being deleted, skip cleanup
	end

	print(`Transform removed from {entity}`)
end)
```

The hook IDs are typed with a generic callback, so leave `id`/`data`
unannotated and let the solver infer them.

## OnAdd

Fires after value is set. Receives the component ID and value.

```luau
local Health = world:component() :: jecs.Id<number>

world:set(Health, jecs.OnAdd, function(entity, id, value)
	-- Initialize related state
	print(`{entity} now has {value} health`)
end)

-- Triggers hook
world:set(entity, Health, 100)
```

## OnChange

Fires when existing component value is updated (not on initial add).

```luau
world:set(Health, jecs.OnChange, function(entity, id, value)
	print(`Health changed to {value}`)
end)

world:set(entity, Health, 100) -- OnAdd (not OnChange)
world:set(entity, Health, 50) -- OnChange fires
```

**Prefer `world:changed()` instead.** OnChange doesn't fit the
constructor/destructor model - observing mutations is typically an external
concern. Signals (`world:changed`) are built on the same hook slot but allow
multiple listeners and disconnect. A hook set *before* the first signal
subscription is kept as one of the listeners; setting the hook *after*
subscribing replaces the signal dispatcher and silently breaks the signals.

## OnRemove

Fires when component is removed OR entity is deleted. It runs before the value
is removed, so `world:get(entity, Component)` still works inside it.

```luau
local Dead = jecs.tag()

world:set(Health, jecs.OnRemove, function(entity, id, delete)
	if delete then
		-- Entity is being deleted - minimal cleanup only
		return
	end

	-- Normal removal - full cleanup
	world:remove(entity, Dead)
end)
```

**The `delete` flag:**

- `true`: Entity being deleted (all components removed)
- `nil`: Single component removed normally

## Structural Changes in Hooks

You CAN call `world:add`, `world:remove`, `world:set` in hooks with caveats:

```luau
world:set(Health, jecs.OnRemove, function(entity, id, delete)
	if delete then
		return -- IMPORTANT: Skip during deletion
	end

	-- Safe to make changes
	world:remove(entity, HealthBar)
end)
```

**DEBUG mode** (`jecs.world(true)`) throws an error if you make structural
changes when `delete` is true.

## Hook Order with ChildOf

When parent deleted, children's OnRemove hooks fire first (if no cycles).

```luau
-- Setup hierarchy
world:add(child, jecs.pair(jecs.ChildOf, parent))

-- When parent deleted:
-- 1. Child's OnRemove hooks fire
-- 2. Parent's OnRemove hooks fire
world:delete(parent)
```

## Hooks for Pairs

Hooks on relationship receive the full pair ID.

```luau
local OwnedBy = world:entity()

world:set(OwnedBy, jecs.OnAdd, function(entity, id, _)
	local owner = jecs.pair_second(world, id)
	print(`{entity} now owned by {owner}`)
end)
```

## Common Patterns

**Resource cleanup:**

```luau
local Model = world:component() :: jecs.Id<Instance>

world:set(Model, jecs.OnRemove, function(entity, id, delete)
	local model = world:get(entity, Model)
	if model then
		model:Destroy()
	end
end)
```

**Syncing state:**

```luau
local Position = world:component() :: jecs.Id<Vector3>
local Part = world:component() :: jecs.Id<BasePart>

world:set(Position, jecs.OnChange, function(entity, id, position)
	local part = world:get(entity, Part)
	if part then
		part.CFrame = CFrame.new(position)
	end
end)
```

## Hooks vs Signals

**Hooks are constructors/destructors.** They define how a component initializes
and cleans up. One per component, by design.

**Signals are event subscriptions.** External systems observe component changes.
Multiple listeners, can disconnect.

| Feature       | Hooks                  | Signals            |
| ------------- | ---------------------- | ------------------ |
| Mental model  | Constructor/Destructor | Event subscription |
| Belongs to    | The component itself   | External observers |
| Per component | One (intentional)      | Multiple           |
| Disconnect    | No                     | Yes                |

**Use hooks when:** "This component always does X on add/remove"

- Model destroys its Instance on removal
- Transform syncs to a BasePart on change

**Use signals when:** "Other systems need to know about this component"

- UI updates when Health changes
- Networking replicates component state
- Audio plays sound on damage

Signals can do everything hooks do. Hooks are an optimization for the
single-listener, never-disconnect case.

See [feature-signals](feature-signals.md) for signal-based listeners.

<!--
Source references:
- how_to/110_hooks.luau
- examples/hooks/cleanup.luau
-->
