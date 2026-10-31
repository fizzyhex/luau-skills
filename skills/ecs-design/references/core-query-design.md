---
name: core-query-design
description:
    Use when designing queries that span multiple entities, need relationship
    traversal, or answer "interesting questions" about game state.
---

# Query Design for Complex Questions

Queries answer questions. Simple questions involve one entity. Interesting
questions involve multiple entities connected by relationships.

## Decomposing Questions into Constraints

Every query is a list of constraints that progressively narrows results:

**Question:** "Which vendors in this city sell healing potions?"

| Constraint             | Remaining Entities |
| ---------------------- | ------------------ |
| Is a vendor            | [all vendors]      |
| In same city as player | [vendors in city]  |
| Sells healing potions  | [answer]           |

Each constraint eliminates entities quickly—this is why ECS queries are
efficient.

## When You Need Multiple Entities

If your question involves phrases like "that belongs to," "in the same X as," or
"related to," you need to join data across entities:

```luau
-- "Find allies at war with someone"
-- Entities: my faction, ally faction, their enemy
for id, faction in world:query(Faction):with(pair(AlliedWith, allyId)) do
	-- Now check: does allyId have AtWar relationship?
	if world:has(allyId, pair(AtWar, jecs.Wildcard)) then
		-- This ally is at war
	end
end
```

## Forward vs Reverse Lookups

| Access Pattern    | Solution                          | Example                    |
| ----------------- | --------------------------------- | -------------------------- |
| Child → Parent    | Entity member or `world:target()` | Get item's owner           |
| Parent → Children | Relationship query                | Get all items in inventory |
| Unknown depth     | Manual traversal or observers     | Find inherited Style       |

```luau
-- Forward: child knows parent
local parent = world:target(child, jecs.ChildOf)

-- Reverse: find all children of parent
for id in world:query(Transform):with(pair(jecs.ChildOf, parentId)) do
	-- Each child entity
end
```

## Hierarchy Traversal

For inherited properties (Style, Transform), traverse upward until found:

```luau
local Style = world:component() :: jecs.Id<StyleData>

local function getInheritedStyle(entity: jecs.Entity): StyleData?
	local current: jecs.Entity? = entity

	while current do
		local style = world:get(current, Style)
		if style then
			return style
		end

		current = world:parent(current)
	end

	return nil
end
```

<!--
Source references:
- https://ajmmertens.medium.com/why-it-is-time-to-start-thinking-of-games-as-databases-e7971da33ac3
-->
