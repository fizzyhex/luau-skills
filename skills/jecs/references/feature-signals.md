---
name: feature-signals
description: |
    Use when external systems need to observe component changes in jecs.
    Supports multiple listeners and disconnect. For component
    constructors/destructors, use hooks instead.
---

# Jecs Signals

Signals are **event subscriptions** for external observers. Unlike hooks (which
are constructors/destructors), signals support multiple listeners and can be
disconnected.

## Signal Types

| Signal    | Triggers When           | Callback                                     |
| --------- | ----------------------- | -------------------------------------------- |
| `added`   | Component added         | `(entity, id, value, oldArchetype) -> ()`    |
| `changed` | Component value changed | `(entity, id, value, oldArchetype) -> ()`    |
| `removed` | Component removed       | `(entity, id, delete: boolean?) -> ()`       |

Each subscription returns a `() -> ()` disconnect function.

## Basic Usage

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)

local world = jecs.world()
local Position = world:component() :: jecs.Id<Vector3>

-- Subscribe - returns disconnect function
local disconnect = world:added(Position, function(entity, id, value)
	print(`Position added to {entity}: {value}`)
end)

-- Later: unsubscribe
disconnect()
```

## Multiple Listeners

```luau
local Health = world:component() :: jecs.Id<number>

-- UI listener
local disconnectUI = world:changed(Health, function(entity, id, value)
	updateHealthBar(entity, value)
end)

-- Sound listener
local disconnectSFX = world:changed(Health, function(entity, id, value)
	playDamageSound()
end)

-- Remove individual listeners
disconnectUI()
```

Disconnecting the same listener twice errors.

## Signals for Pairs

Subscribing on a relationship fires for every pair with that relationship and
receives the full pair ID.

```luau
local Owns = world:component() :: jecs.Id<number>

-- Listen to any ownership changes
world:added(Owns, function(entity, id, value)
	local target = jecs.pair_second(world, id)
	print(`{entity} now owns {target}`)
end)
```

## Removed Signal

The `removed` signal receives a `delete` flag like hooks.

```luau
world:removed(Health, function(entity, id, delete)
	if delete then
		-- Entity being deleted
		return
	end

	-- Component removed normally
	cleanupHealthEffects(entity)
end)
```

## Signals vs Hooks

**Signals are event subscriptions.** External systems observe component changes.

**Hooks are constructors/destructors.** They define how a component itself
initializes and cleans up.

| Feature       | Signals                 | Hooks                             |
| ------------- | ----------------------- | --------------------------------- |
| Mental model  | Event subscription      | Constructor/Destructor            |
| Belongs to    | External observers      | The component itself              |
| Per component | Multiple                | One (intentional)                 |
| Disconnect    | Yes                     | No                                |
| Set via       | `world:added(comp, fn)` | `world:set(comp, jecs.OnAdd, fn)` |

**Use signals when:** "Other systems need to know about this component"

- UI updates when Health changes
- Networking replicates component state
- Audio plays sound on damage

**Use hooks when:** "This component always does X on add/remove"

- Model destroys its Instance on removal
- Transform syncs to a BasePart on change

Signals can do everything hooks do. Use signals by default. Use hooks when you
need the slight performance gain and know you'll only ever have one listener.
Signals occupy the component's hook slot: set any hook before the first
subscription, never after.

## Quick Reference

```luau
-- Subscribe
local disconnect1 = world:added(Component, fn)
local disconnect2 = world:changed(Component, fn)
local disconnect3 = world:removed(Component, fn)

-- Unsubscribe
disconnect1()
disconnect2()
disconnect3()
```

<!--
Source references:
- how_to/111_signals.luau
- src/jecs.luau (World.added, World.changed, World.removed)
- examples/networking/networking_send.luau
-->
