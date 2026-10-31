---
name: best-practices-components
description:
    Use when deciding component granularity, whether to split or combine data,
    or designing component structures for jecs.
---

# Component Design Best Practices

## The Fundamental Question

For every piece of data, ask:

> "Is there a system that needs A but not B?"

If **yes** → separate components. If **no** → same component.

## Atomic Components

"Atomic" means indivisible for your use case, not smallest possible.

### Transform is atomic

```luau
-- WRONG: Over-split
local PositionX = world:component() :: jecs.Id<number>
local PositionY = world:component() :: jecs.Id<number>
local Rotation = world:component() :: jecs.Id<Vector3>

-- RIGHT: Transform is one concept
local Transform = world:component() :: jecs.Id<CFrame>
```

No system needs position without rotation. They form one semantic unit.

### Character data is NOT atomic

```luau
-- WRONG: Under-split
type Character = {
	name: string,
	health: number,
	transform: CFrame,
	velocity: Vector3,
}

-- RIGHT: Split by access pattern
local Transform = world:component() :: jecs.Id<CFrame>
local Velocity = world:component() :: jecs.Id<Vector3>
local Health = world:component() :: jecs.Id<number>
local DisplayName = world:component() :: jecs.Id<string>
```

Movement system needs transform/velocity. Health system needs health. UI system
needs display name. Different access patterns = different components.

## Semantic Grouping

Group data that represents one concept:

```luau
-- Health split: not all damageable entities need MaxHealth
local Health = world:component() :: jecs.Id<number> -- Current HP, required for damage
local MaxHealth = world:component() :: jecs.Id<number> -- Optional: for regen, UI, etc.

-- or: Max is a tag, so the pair carries Health's type (number)
local Max = world:entity()
local MaxHealthPair = jecs.pair(Max, Health)
world:set(entity, MaxHealthPair, 100)

-- Transform as one concept
local Transform = world:component() :: jecs.Id<CFrame>

-- Damage event as one concept
type DamageEventData = {
	amount: number,
	source: jecs.Entity,
	type: DamageType,
}
local DamageEvent = world:component() :: jecs.Id<DamageEventData>
```

## Change Rate Separation

Separate data that changes at different rates:

```luau
-- Changes every frame
local Transform = world:component() :: jecs.Id<CFrame>
local Velocity = world:component() :: jecs.Id<Vector3>

-- Changes occasionally
local Health = world:component() :: jecs.Id<number>
local Mana = world:component() :: jecs.Id<number>

-- Changes rarely/never
local MaxHealth = world:component() :: jecs.Id<number> -- Set at spawn
local DisplayName = world:component() :: jecs.Id<string> -- Never changes
local Team = world:component() :: jecs.Id<TeamId> -- Rarely changes
```

Why? Separating by change rate often aligns with access patterns—systems
processing movement don't need display names. This improves query specificity.

## Optional vs Required Data

Not all entities need all data. Use component presence to indicate capability:

```luau
-- Only entities that can move have velocity
local Velocity = world:component() :: jecs.Id<Vector3>

-- Only entities that can be damaged have health
local Health = world:component() :: jecs.Id<number>

-- Only entities that are rendered have a model
local Model = world:component() :: jecs.Id<Instance>
```

Query automatically filters:

```luau
-- Only processes entities that CAN move
for entityId, transform, velocity in world:query(Transform, Velocity) do
	-- ...
end
```

## Tags vs Data Components

**Tags:** Components with no data, presence indicates state/category.

```luau
-- Tags for classification (jecs.tag() or world:entity(); world:component()
-- always creates a data component)
local IsPlayer = jecs.tag()
local IsEnemy = jecs.tag()
local IsProjectile = jecs.tag()

-- Usage
world:add(entity, IsPlayer)
world:query(Health):with(IsEnemy) -- All enemies with health
```

**Key insight: Tags themselves cost nothing. The archetype transition does.**

Adding/removing any component (tag or not) triggers an archetype transition:

- Jecs iterates through all existing components
- Each component reference gets reassigned to the new archetype
- Bookkeeping updates entity indices and keeps arrays packed

This is pointer shuffling, not deep copying, but the loop overhead adds up at
scale.

**For most entities:** Tag transitions are negligible.

**For hot paths (thousands/frame):** Consider whether you need the transition.

```luau
-- FINE: Infrequent state changes
local IsStunned = jecs.tag()
world:add(entity, IsStunned)

-- CONSIDER: High-frequency state changes in performance-critical code
local CombatState = world:component() :: jecs.Id<{ stunned: boolean }>
world:set(entity, CombatState, { stunned = true }) -- In-place, no transition
```

**Rule of thumb:** Profile before optimizing transitions.

**When to prefer data over tags:** When entities have many components AND state
changes frequently during gameplay. Also when you have many mutually exclusive
states (idle/walking/running/jumping) - use a single data component.

## Complex Data in Components

Components can hold complex data. Don't over-flatten:

```luau
-- Fine: Arrays when they're accessed as a unit
local Waypoints = world:component() :: jecs.Id<{ Vector3 }>
local Abilities = world:component() :: jecs.Id<{ AbilityId }>

-- Fine: Nested structures when they're one concept
local Stats = world:component() :: jecs.Id<{
	dexterity: number,
	intelligence: number,
	strength: number,
}>
```

**When to externalize:**

- Items that need individual queries → separate entities with relationships
- Data shared across entities → separate entity, reference by ID

### Handle Pattern

Store references to external systems rather than duplicating data:

```luau
-- Handles to Roblox-managed resources
local Model = world:component() :: jecs.Id<Model>
local Animation = world:component() :: jecs.Id<AnimationTrack>

-- Handles to external systems
local NavAgentId = world:component() :: jecs.Id<number> -- Pathfinding system
local PhysicsBodyId = world:component() :: jecs.Id<number> -- Physics simulation
```

For transform hierarchies specifically, Roblox's Instance hierarchy already
handles parent-child relationships efficiently. Store a Model handle and let
Roblox manage the spatial hierarchy rather than reimplementing it in ECS.

## Entity Members vs Relationships

Storing entity IDs in components (called "entity members") is a key pattern:

```luau
-- Entity members - store entity reference as component data
local Target = world:component() :: jecs.Id<jecs.Entity>
local Parent = world:component() :: jecs.Id<jecs.Entity>
local LastAttacker = world:component() :: jecs.Id<jecs.Entity>

-- Usage
world:set(attacker, Target, enemy) -- No fragmentation
local target = world:get(attacker, Target)
```

**Entity members** — Use when:

- Forward lookup only ("who does X target?")
- Many unique targets (avoids fragmentation)
- Link changes frequently
- No auto-cleanup needed

**Relationships** — Use when:

- Need reverse lookup ("who targets X?")
- Want grouping by target
- Want auto-cleanup on target deletion
- Few unique targets

```luau
-- Entity member: attacker → target (forward only)
local AttackTarget = world:component() :: jecs.Id<jecs.Entity>
world:set(attacker, AttackTarget, enemy)

-- Relationship: query all children of a parent (reverse lookup)
world:add(child, pair(jecs.ChildOf, parent))
for id in world:query(Transform):with(pair(jecs.ChildOf, parent)) do
	-- All children of this parent
end
```

### Using Both Together

These patterns aren't mutually exclusive. For composed entities (a car with
hull, motor, wheels), use **both**:

```luau
-- ChildOf for lifecycle: deletion cascades, serialization
world:add(hull, pair(jecs.ChildOf, car))
world:add(motor, pair(jecs.ChildOf, car))
world:add(wheel1, pair(jecs.ChildOf, car))

-- Entity members for operational access: direct lookup in systems
type CarPartsData = {
	hull: jecs.Entity,
	motor: jecs.Entity,
	wheels: { jecs.Entity }, -- always 4
}
local CarParts = world:component() :: jecs.Id<CarPartsData>
world:set(car, CarParts, {
	hull = hull,
	motor = motor,
	wheels = { wheel1, wheel2, wheel3, wheel4 },
})
```

ChildOf gives you generic operations (delete car → children deleted). Entity
members give you direct access without queries.

**Replication note:** Entity members require extra work to replicate - you must
track which component fields contain entity IDs and remap them. Relationships
are easier to detect via `jecs.IS_PAIR`.

## Common Mistakes

### Mistake: God component

```luau
-- BAD: Everything in one component
type Everything = {
	buffs: { Buff },
	equipment: Equipment,
	health: number,
	inventory: { Item },
	mana: number,
	transform: CFrame,
	velocity: Vector3,
	-- ... 20 more fields
}
```

**Fix:** Split by access pattern and change rate.

### Mistake: Primitive explosion

```luau
-- BAD: Every field is a component
local HealthCurrent = world:component() :: jecs.Id<number>
local HealthMax = world:component() :: jecs.Id<number>
local HealthRegeneration = world:component() :: jecs.Id<number>
local ManaPool = world:component() :: jecs.Id<number>
local ManaMax = world:component() :: jecs.Id<number>
-- 50+ components for one entity type
```

**Fix:** Group semantically related data.

### Mistake: Inheritance thinking

```luau
-- BAD: Trying to model inheritance (metatables / __index chains)
local BaseCharacter = {}
BaseCharacter.__index = BaseCharacter

local Enemy = setmetatable({}, BaseCharacter) -- adds aiState
local Player = setmetatable({}, BaseCharacter) -- adds inventory
```

**Fix:** Composition. All characters have Transform. Players also have
Inventory. Enemies also have AIState. No inheritance needed.

### Mistake: Enums as separate components

```luau
-- BAD: One component per state
local StateIdle = jecs.tag()
local StateWalking = jecs.tag()
local StateRunning = jecs.tag()
local StateJumping = jecs.tag()
```

**Fix:** One component with enum value.

```luau
type State = "idle" | "jumping" | "running" | "walking"
local CharacterState = world:component() :: jecs.Id<State>
```

## Checklist

Before finalizing a component:

- [ ] Can any system use only part of this data? → Split
- [ ] Does this data always change together? → Keep together
- [ ] Is this data optional for some entities? → Separate component
- [ ] Do I need reverse lookup for this entity reference? → Relationship
- [ ] Am I splitting just because it's "more atomic"? → Stop

<!--
Source references:
- https://github.com/SanderMertens/flecs/blob/master/docs/DesignWithFlecs.md#components
- https://github.com/SanderMertens/ecs-faq#how-do-i-design-for-ecs
-->
