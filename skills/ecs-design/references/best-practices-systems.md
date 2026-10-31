---
name: best-practices-systems
description:
    Use when designing jecs systems, deciding system scope, or structuring game
    logic in Roblox.
---

# System Design Best Practices

## Systems Are for Reusable Behavior

Systems handle **generalizable behavior patterns** that apply across many entity
types. One-off logic belongs in helper functions.

```luau
-- GOOD: Reusable system - works for players, NPCs, projectiles, etc.
local function movementSystem(dt: number)
	for entityId, transform, velocity in world:query(Transform, Velocity) do
		world:set(entityId, Transform, transform + velocity * dt)
	end
end

-- GOOD: Helper function for one-off spawning logic
local function spawnPlayerCharacter(player: Player, ownerEntity: jecs.Entity): jecs.Entity
	local entityId = world:entity()
	world:set(entityId, Transform, getSpawnCFrame(player))
	world:set(entityId, Model, createCharacterModel())
	world:add(entityId, pair(OwnedBy, ownerEntity))
	return entityId
end
```

```luau
-- BAD: God system with mixed concerns
local function physicsSystem()
	-- Applies gravity
	-- Updates positions
	-- Checks collisions
	-- Resolves collisions
	-- 500 lines of mixed concerns
end

-- BAD: System for one-off behavior that won't be reused
local function spawnPlayerCharacterSystem()
	-- Only ever spawns player characters
	-- Better as a helper function
end
```

**When to make a system vs helper function:**

| Make a System When...                   | Use a Helper Function When...           |
| --------------------------------------- | --------------------------------------- |
| Behavior applies to many entity types   | Logic is specific to one situation      |
| You'll query and process batches        | You know exactly which entity to act on |
| The logic runs every frame or regularly | It's called once (spawning, setup)      |
| You want it in the scheduler pipeline   | Order doesn't matter                    |

**Benefits of well-designed systems:**

- Reusable across entity types (players, NPCs, projectiles)
- Easy to disable for testing
- Easy to reorder in the pipeline
- Fewer systems with good component design (20-100 is typical)

## Query Once, Process Many

Systems process batches, not individuals:

```luau
-- BAD: Single-entity thinking
-- Called individually for each damage event
local function applyDamage(entity: jecs.Entity, amount: number)
	local health = assert(world:get(entity, Health))
	world:set(entity, Health, health - amount)
end

-- GOOD: Batch processing
local function damageSystem()
	for entityId, health, damage in world:query(Health, PendingDamage) do
		world:set(entityId, Health, health - damage.amount)
		world:remove(entityId, PendingDamage)
	end
end
```

## Avoid Work

The fastest code is code that doesn't run:

### Use query filters

```luau
-- BAD: Query all, filter in code
for entityId, transform in world:query(Transform) do
	if world:has(entityId, CanMove) and not world:has(entityId, Frozen) then
		-- move
	end
end

-- GOOD: Filter in query
for entityId, transform in world:query(Transform):with(CanMove):without(Frozen) do
	-- move
end
```

### Use change detection

Track changes using a `Previous` pair component:

```luau
local Previous = jecs.Rest

-- BAD: Update every frame even if unchanged
for entityId, transform, model in world:query(Transform, Model) do
	model:PivotTo(transform) -- Expensive even if transform didn't change
end

-- GOOD: Only process changed entities using Previous pair
for entityId, transform, previousTransform, model in world:query(Transform, pair(Previous, Transform), Model) do
	if transform ~= previousTransform then
		model:PivotTo(transform)
		world:set(entityId, pair(Previous, Transform), transform)
	end
end

-- Initialize Previous when entity is added (separate system)
for entityId, transform in world:query(Transform):without(pair(Previous, Transform)) do
	world:set(entityId, pair(Previous, Transform), transform)
end
```

### Use spatial partitioning

```luau
-- BAD: Check every entity pair
for entityId1, position1 in world:query(Position) do
	for entityId2, position2 in world:query(Position) do
		if (position1 - position2).Magnitude < range then
			-- O(n²) comparisons
		end
	end
end

-- GOOD: Use world cells or spatial hash
for entityId1, position1 in world:query(Position) do
	local cell1 = world:target(entityId1, InCell)
	if not cell1 then
		continue
	end
	for entityId2, position2 in world:query(Position):with(pair(InCell, cell1)) do
		-- Only check entities in same/adjacent cells
	end
end
```

## System Ordering

Systems run in a defined order. Think about dependencies:

```text
Input → Physics → Collision → Damage → Death → Cleanup → Render
```

Common phase pattern:

| Phase      | Purpose              | Example Systems                 |
| ---------- | -------------------- | ------------------------------- |
| Input      | Read player/AI input | InputSystem, AIDecisionSystem   |
| PreUpdate  | Prepare frame        | ResetFlagsSystem, SpawnSystem   |
| Update     | Main game logic      | MovementSystem, CombatSystem    |
| PostUpdate | React to changes     | DamageSystem, DeathSystem       |
| PreRender  | Prepare visuals      | AnimationSystem, TransformSync  |
| Render     | Draw                 | RenderSystem                    |
| Cleanup    | End of frame         | DespawnSystem, EventClearSystem |

## Data Flow

Systems communicate through components, not function calls. Events work best as
**separate entities** that reference their targets:

```luau
-- GOOD: Event as separate entity (preferred pattern)
-- Helper function creates event entity
local function dealDamage(source: jecs.Entity, target: jecs.Entity, amount: number): jecs.Entity
	local entityId = world:entity()
	world:set(entityId, Hit, { amount = amount, source = source, target = target })
	return entityId
end

-- CombatSystem creates hit events
dealDamage(attacker, victim, 50)

-- DamageSystem processes all hits (runs later)
for entityId, hit in world:query(Hit) do
	local health = world:get(hit.target, Health)
	if health then
		world:set(hit.target, Health, health - hit.amount)
	end
end

-- Benefits: Other systems can intercept/modify/log hits independently
```

```luau
-- OKAY: Event as component on target (simpler but less flexible)
world:set(target, PendingDamage, { amount = 50, source = attacker })

-- BAD: Direct function call
DamageSystem.applyDamage(target, 50) -- Tight coupling
```

## Stateless Systems

Systems should not store state. Use components:

```luau
-- BAD: State in system (upvalue)
local lastFrameTime = 0
local function movementSystem()
	local now = os.clock()
	local dt = now - lastFrameTime
	lastFrameTime = now
	-- ...
end

-- GOOD: State in component/world (singleton)
local FrameData = world:component() :: jecs.Id<{ dt: number, time: number }>
-- Set by a timing system, read by others:
-- world:set(FrameData, FrameData, { dt = dt, time = now })
```

## No Yielding in Systems

Systems must never yield. The scheduler runs systems synchronously in sequence -
yielding blocks all subsequent systems.

```luau
-- BAD: Yields in system - blocks everything!
local function pathfindingSystem()
	for entityId, target in world:query(Target) do
		PathfindingService:CreatePath():ComputeAsync(start, goal) -- YIELDS!
	end
end

-- GOOD: Spawn thread for async work
local function pathfindingSystem()
	for entityId, target in world:query(Target):without(ComputingPath) do
		world:add(entityId, ComputingPath)
		task.spawn(function()
			local path = PathfindingService:CreatePath()
			path:ComputeAsync(start, goal)
			if not world:contains(entityId) then
				return -- entity was deleted while we yielded
			end
			world:set(entityId, Path, path)
			world:remove(entityId, ComputingPath)
		end)
	end
end
```

Common yielding APIs to watch for: `task.wait()`, DataStore calls, and any
Roblox method ending in `Async`.

## Iterator Invalidation

Structural changes (adding/removing components, deleting entities) during
iteration can cause issues. Mark entities for later processing instead:

```luau
-- WARNING: May invalidate iterator
for entityId, health in world:query(Health) do
	if health <= 0 then
		world:delete(entityId) -- Structural change during iteration!
	end
end

-- SAFER: Mark for deletion, process in cleanup system
for entityId, health in world:query(Health):without(Destroy) do
	if health <= 0 then
		world:add(entityId, Destroy)
	end
end

-- Cleanup system runs at end of frame
for entityId in world:query(Destroy) do
	world:delete(entityId)
end
```

## Common System Patterns

### Event processing

```luau
-- Events as entities with limited lifetime
type HitData = {
	amount: number,
	source: jecs.Entity,
	target: jecs.Entity,
}
local Hit = world:component() :: jecs.Id<HitData>
local Destroy = jecs.tag()

-- Helper function to create event
local function dealDamage(source: jecs.Entity, target: jecs.Entity, amount: number): jecs.Entity
	local entityId = world:entity()
	world:set(entityId, Hit, { amount = amount, source = source, target = target })
	return entityId
end

-- Process events in system
for entityId, hit in world:query(Hit):without(Destroy) do
	local health = world:get(hit.target, Health)
	if health then
		world:set(hit.target, Health, health - hit.amount)
	end

	world:add(entityId, Destroy)
end

-- Cleanup system runs at end of frame
for entityId in world:query(Destroy) do
	world:delete(entityId)
end
```

## Query Caching

**Critical rule:** Never call `:cached()` inside a system. Create cached queries
at module scope.

```luau
-- WRONG: Creates new cache every frame!
local function movementSystem(dt: number)
	for entityId, transform, velocity in world:query(Transform, Velocity):cached() do
		-- New cache created every call
	end
end

-- RIGHT: Cache created once at module load
local moveQuery = world:query(Transform, Velocity):cached()

local function movementSystem(dt: number)
	for entityId, transform, velocity in moveQuery do
		-- Reuses existing cache
	end
end
```

Cached queries track matching archetypes. Creating them inside systems means
rebuilding this tracking every frame, defeating the purpose.

## Checklist

Before finalizing a system:

- [ ] Is this behavior **reusable** across entity types? (If not, use a helper
      function)
- [ ] Does it use query filters instead of code filters?
- [ ] Is the query cached **at module scope** (for frequent queries)?
- [ ] Does the system **avoid yielding**?
- [ ] Does it **avoid structural changes** during iteration? (Use marker
      components)
- [ ] Is all state in components, not the system?
- [ ] Are events handled via component entities?

<!--
Source references:
- https://github.com/SanderMertens/flecs/blob/master/docs/DesignWithFlecs.md#systems
- https://github.com/SanderMertens/ecs-faq#system
-->
