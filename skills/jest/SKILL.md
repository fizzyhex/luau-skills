---
name: jest
description: |
    Write tests, mock functions, assert values, and configure test suites for
    Roblox Luau code using Jest Roblox, a Luau port whose API diverges from
    JS Jest in subtle, non-obvious ways that LLM training data does not cover.
    Use whenever encountering Jest in Luau code: editing .spec.luau/.spec.lua
    test files, calling jest.fn/jest.mock/jest.spyOn, using
    describe/it/expect, writing jest.config.luau or a runCLI entrypoint, or
    debugging Jest tests.
metadata:
    author: Fizzy (fork of Christopher Buss's skills)
    version: "2026.10.31"
    source:
        Generated from https://github.com/Roblox/jest-roblox, maintained at
        https://github.com/fizzyhex/luau-skills
---

> Based on Jest Roblox v3.20.x, generated 2026-10-31.

Jest Roblox is a Luau port of Jest for the Roblox platform. It closely follows
the upstream Jest API but has critical deviations due to Luau language
constraints.

**Critical deviations from JS Jest:**

- Matchers are called with a dot: `expect(x).toBe(y)`, not `expect(x):toBe(y)`
- `.never` instead of `.not` (`not` is a reserved keyword)
- `jest.fn()` returns **two values**: mock object + forwarding function
- `0`, `""`, `{}` are **truthy** in Luau (only `false` and `nil` are falsy)
- Nothing is global: `describe`, `it`, `expect`, `jest`, hooks, etc. must be
  explicitly taken from `JestGlobals`
- `.each` uses tables (or a `"a | b"` heading string), not tagged templates
- Custom matchers take `self` (the matcher context) as their first parameter
- Every test project needs a `jest.config.lua`/`.luau`, and tests are started
  from a script that calls `Jest.runCLI`

Examples are strict typed Luau and assume this prelude unless shown otherwise
(the `Packages` path depends on your package manager; see
[core-deviations](references/core-deviations.md#explicit-imports)):

```luau
--!strict
local JestGlobals = require(Packages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect
local jest = JestGlobals.jest
```

Read [core-deviations](references/core-deviations.md) first when working with
this codebase.

## Core References

| Topic               | Description                                              | Reference                                                          |
| ------------------- | -------------------------------------------------------- | ------------------------------------------------------------------ |
| Deviations          | All Luau/Roblox differences from JS Jest                 | [core-deviations](references/core-deviations.md)                   |
| Test Structure      | describe, test/it, hooks, .each, .only/.skip             | [core-test-structure](references/core-test-structure.md)           |
| Matchers            | toBe, toEqual, toContain, toThrow, mock matchers         | [core-matchers](references/core-matchers.md)                       |
| Asymmetric Matchers | expect.anything/any/nothing/callable, .resolves/.rejects | [core-asymmetric-matchers](references/core-asymmetric-matchers.md) |
| Mocking             | jest.fn(), spyOn, mock.calls, return values              | [core-mocking](references/core-mocking.md)                         |
| Configuration       | jest.config.lua, runCLI, reporters, options              | [core-configuration](references/core-configuration.md)             |

## Features

### Testing Patterns

| Topic            | Description                                     | Reference                                                          |
| ---------------- | ----------------------------------------------- | ------------------------------------------------------------------ |
| Async Testing    | Promises, done callbacks, .resolves/.rejects    | [feature-async-testing](references/feature-async-testing.md)       |
| Custom Matchers  | expect.extend(), self parameter, self.isNot     | [feature-custom-matchers](references/feature-custom-matchers.md)   |
| Snapshot Testing | toMatchSnapshot, property matchers, serializers | [feature-snapshot-testing](references/feature-snapshot-testing.md) |
| Test Filtering   | testMatch, testPathPattern, testNamePattern     | [feature-test-filtering](references/feature-test-filtering.md)     |

### Mocking

| Topic          | Description                                   | Reference                                                      |
| -------------- | --------------------------------------------- | -------------------------------------------------------------- |
| Timer Mocks    | useFakeTimers, Roblox timers, engineFrameTime | [feature-timer-mocks](references/feature-timer-mocks.md)       |
| Global Mocks   | jest.globalEnv, spyOn globals, library mocks  | [feature-global-mocks](references/feature-global-mocks.md)     |
| Module Mocking | jest.mock(), isolateModules, resetModules     | [feature-module-mocking](references/feature-module-mocking.md) |

### Advanced

| Topic        | Description                                      | Reference                                                    |
| ------------ | ------------------------------------------------ | ------------------------------------------------------------ |
| Benchmarking | benchmark(), Reporter, Profiler, CustomReporters | [advanced-benchmarking](references/advanced-benchmarking.md) |
