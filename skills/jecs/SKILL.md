---
name: jecs
description:
    Use when building ECS-based games in Roblox with Luau using jecs for
    entities, components, queries, and relationships
metadata:
    author: Fizzy (fork of Christopher Buss's skills)
    version: "2026.10.31"
    source:
        Generated from https://github.com/Ukendio/jecs, maintained at
        https://github.com/fizzyhex/luau-skills
---

> Based on jecs v0.11.0, generated 2026-10-31

High-performance Entity Component System for Luau. Features entity
relationships, archetype storage, 800k entities at 60fps.

Examples are strict typed Luau. Unless shown otherwise they assume:

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)

local world = jecs.world()
```

Component IDs carry their data type through a cast:
`local Health = world:component() :: jecs.Id<number>`. World methods use `:`
(`world:set(...)`); module functions use `.` (`jecs.pair(...)`).

## Core References

| Topic            | Description                                            | Reference                                  |
| ---------------- | ------------------------------------------------------ | ------------------------------------------ |
| World & Entities | World creation, entities, components, tags, singletons | [core-basics](references/core-basics.md)   |
| Queries          | Query system, filters (with/without), caching          | [core-queries](references/core-queries.md) |

## Features

| Topic                 | Description                                            | Reference                                                      |
| --------------------- | ------------------------------------------------------ | -------------------------------------------------------------- |
| Pairs & Relationships | Entity pairs, ChildOf, wildcards, relationship queries | [feature-pairs](references/feature-pairs.md)                   |
| Component Hooks       | OnAdd, OnChange, OnRemove lifecycle hooks              | [feature-hooks](references/feature-hooks.md)                   |
| Signals               | Multiple listeners with added/changed/removed signals  | [feature-signals](references/feature-signals.md)               |
| Cleanup Traits        | OnDelete, OnDeleteTarget, cascade deletion policies    | [feature-cleanup-traits](references/feature-cleanup-traits.md) |

## Best Practices

| Topic           | Description                                       | Reference                                                                      |
| --------------- | ------------------------------------------------- | ------------------------------------------------------------------------------ |
| Archetypes      | Archetype storage, transitions, fragmentation     | [best-practices-archetypes](references/best-practices-archetypes.md)           |
| Change Tracking | Delta detection, dirty flags, networking patterns | [best-practices-change-tracking](references/best-practices-change-tracking.md) |

## Advanced

| Topic        | Description                                  | Reference                                  |
| ------------ | -------------------------------------------- | ------------------------------------------ |
| Advanced API | Preregistration, bulk ops, exported types    | [advanced-api](references/advanced-api.md) |
