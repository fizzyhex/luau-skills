---
name: best-practices-change-tracking
description: |
    Use when implementing change detection, dirty tracking, or delta updates in
    jecs
---

# Jecs Change Tracking

Patterns for detecting added, changed, and removed components.

## Previous Value Pattern

Store previous values as relationship pairs to detect changes.

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local pair = jecs.pair

local world = jecs.world()
local Position = world:component() :: jecs.Id<Vector3>
local Previous = jecs.Rest -- Built-in entity for "previous" pattern

-- Cached queries for each state
local added = world:query(Position):without(pair(Previous, Position)):cached()

local changed = world:query(Position, pair(Previous, Position)):cached()

local removed = world:query(pair(Previous, Position)):without(Position):cached()
```

`jecs.Rest` is a tag, so `pair(Previous, Position)` carries `Position`'s data
type (`Vector3`).

## Processing Changes

```luau
-- Process newly added
for entity, position in added do
	print(`Added {entity}: {position}`)
	world:set(entity, pair(Previous, Position), position)
end

-- Process changed (compare values)
for entity, current, previous in changed do
	if current ~= previous then
		-- or deep compare for tables
		print(`Changed {entity}: {previous} -> {current}`)
		world:set(entity, pair(Previous, Position), current)
	end
end

-- Process removed
for entity in removed:iter() do
	print(`Removed from {entity}`)
	world:remove(entity, pair(Previous, Position))
end
```

## Signal-Based Tracking

Use signals for immediate notification. See
[feature-signals](./feature-signals.md) for full signal API details.

```luau
type ChangeRecord<T> = {
	added: { [jecs.Entity]: T },
	changed: { [jecs.Entity]: T },
	removed: { [jecs.Entity]: true },
}

local function trackComponent<T>(component: jecs.Id<T>): ChangeRecord<T>
	local record: ChangeRecord<T> = {
		added = {},
		changed = {},
		removed = {},
	}

	world:added(component, function(entity, _, value)
		record.added[entity] = value
	end)

	world:changed(component, function(entity, _, value)
		record.changed[entity] = value
	end)

	world:removed(component, function(entity)
		record.removed[entity] = true
	end)

	return record
end

-- Usage
local positionChanges = trackComponent(Position)

-- After frame, process and clear
local function flushChanges()
	for entity, value in positionChanges.added do
		-- Handle added
	end

	table.clear(positionChanges.added)
	table.clear(positionChanges.changed)
	table.clear(positionChanges.removed)
end
```

## Networking Delta Sync

Combine signals with batched sending:

```luau
local Networked = jecs.tag()
local REMOVED = "jecs.Remove" -- sentinel for removed components

local storages: { [jecs.Entity]: { [jecs.Entity]: any } } = {}

-- Setup tracking for all networked components
for component in world:each(Networked) do
	local storage: { [jecs.Entity]: any } = {}
	storages[component] = storage

	world:added(component, function(entity, _, value)
		storage[entity] = if value == nil then true else value -- tags have no value
	end)

	world:changed(component, function(entity, _, value)
		storage[entity] = value
	end)

	world:removed(component, function(entity)
		storage[entity] = REMOVED
	end)
end

-- Send delta each frame
local function sendDelta()
	local delta: { [string]: { [jecs.Entity]: any } } = {}

	for component, storage in storages do
		if next(storage) ~= nil then
			delta[tostring(component)] = table.clone(storage)
			table.clear(storage)
		end
	end

	if next(delta) ~= nil then
		remotes.replication:FireAllClients(delta)
	end
end
```

## Dirty Flag Pattern

Simple boolean tracking:

```luau
local Dirty = jecs.tag()
local Position = world:component() :: jecs.Id<Vector3>

-- Mark dirty on change
world:changed(Position, function(entity)
	world:add(entity, Dirty)
end)

-- Process dirty entities
local dirtyQuery = world:query(Position):with(Dirty):cached()

local function processDirty()
	for entity, position in dirtyQuery do
		syncToNetwork(entity, position)
		world:remove(entity, Dirty)
	end
end
```

## Comparison Methods

| Method         | Pros                          | Cons                          |
| -------------- | ----------------------------- | ----------------------------- |
| Previous pairs | Query-based, batch processing | Extra storage, manual sync    |
| Signals        | Immediate, no polling         | Memory for callbacks          |
| Dirty flag     | Simple, query-friendly        | Boolean only, no old value    |
| Hooks          | Single handler, fast          | Can't have multiple listeners |

## When to Use Each Method

- **Previous pairs** work well when changes are frequent. The diffing cost is
  spread across batch processing and you get access to old values.
- **Signals** (`world:changed`) are better when changes are infrequent and
  diffing becomes your bottleneck. They fire immediately on change.

## Best Practices

1. **Use Previous pairs** for frame-by-frame systems needing old values
2. **Use Signals** for multiple subscribers or immediate reaction
3. **Use Dirty flags** for simple "needs update" tracking
4. **Batch changes** - don't process every signal immediately
5. **Clear tracking state** at end of frame to prevent accumulation

<!--
Source references:
- examples/queries/changetracking.luau
- examples/networking/networking_send.luau
-->
