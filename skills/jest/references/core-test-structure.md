---
name: Test Structure
description: |
    Writing and organizing tests with describe, test/it, hooks, factory
    functions, .each, .only, .skip, .todo and .failing.
---

# Test Structure

## A Test File

Test files are ModuleScripts matched by `testMatch` (by default
`*.spec`/`*.test` files and anything under `__tests__`). They do not return a
value. All globals must be explicitly required:

```luau title="src/__tests__/sum.spec.luau"
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local JestGlobals = require(Packages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local sum = require(script.Parent.Parent.sum)

describe("sum", function()
	it("adds 1 + 2 to equal 3", function()
		expect(sum(1, 2)).toBe(3)
	end)
end)
```

`test` and `it` are aliases. `fdescribe`/`fit` alias `.only`, and
`xdescribe`/`xit`/`xtest` alias `.skip`.

## `describe` and `test`

```luau
describe("math operations", function()
	it("adds numbers", function()
		expect(1 + 2).toBe(3)
	end)

	it("subtracts numbers", function()
		expect(5 - 3).toBe(2)
	end)
end)
```

## Test Setup: Prefer Factory Functions

Prefer factory functions over shared state mutated in `beforeEach`.

**Why:**

- Each test explicitly shows its setup; no hidden state from hooks
- Tests stay independent; no shared mutable upvalues between them
- Easy to customize per test without conditional hook logic
- Reads top to bottom without jumping to hook definitions

```luau
type PlayerData = {
	name: string,
	health: number,
	inventory: { string },
}

local function createPlayer(overrides: { name: string?, health: number? }?): PlayerData
	local options = overrides or {}
	return {
		name = options.name or "TestPlayer",
		health = options.health or 100,
		inventory = {},
	}
end

describe("player combat", function()
	it("reduces health on damage", function()
		local player = createPlayer({ health = 50 })

		expect(applyDamage(player, 10).health).toBe(40)
	end)

	it("does not go below zero", function()
		local player = createPlayer({ health = 5 })

		expect(applyDamage(player, 20).health).toBe(0)
	end)
end)
```

When several values need coordinated setup, return them together:

```luau
local function createBattle(): (PlayerData, PlayerData)
	local attacker = createPlayer({ name = "Attacker", health = 100 })
	local defender = createPlayer({ name = "Defender", health = 80 })
	return attacker, defender
end

it("applies damage to the defender", function()
	local attacker, defender = createBattle()

	expect(resolveCombat(attacker, defender).defender.health).toBeLessThan(80)
end)
```

## Hooks

Use hooks for setup that genuinely must happen around every test (restoring
mocks, resetting timers, cleaning up Instances):

```luau
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach
local beforeAll = JestGlobals.beforeAll
local afterAll = JestGlobals.afterAll

afterEach(function()
	jest.useRealTimers()
	jest.restoreAllMocks()
end)
```

Hooks declared inside a `describe` apply only to tests in that block. Order:
all `beforeAll`, then for each test the outer `beforeEach` before the inner
ones, the test, then the inner `afterEach` before the outer ones, and finally
`afterAll`. `describe` bodies all run first (collection), before any test.
Hooks may return a Promise to make Jest wait.

## `.only` and `.skip`

Focus or skip tests **within a single file** (other files still run):

```luau
it.only("runs this test", function()
	expect(true).toBe(true)
end)

it.skip("is explicitly skipped", function()
	expect(true).toBe(false)
end)
```

Works on `describe` too: `describe.only()`, `describe.skip()`.

## `.todo`

Placeholder for tests you plan to write:

```luau
it.todo("handles the edge case")
```

Shows in the summary output. Must **not** be given a callback.

## `.failing`

Mark a test expected to fail; it passes if it throws and fails if it does
not:

```luau
it.failing("is a known bug", function()
	expect(5).toBe(6)
end)
```

Supports `.only.failing` and `.skip.failing`.

## `.each`: Data-Driven Tests

### Array of arrays (positional args)

```luau
it.each({
	{ 1, 1, 2 },
	{ 1, 2, 3 },
	{ 2, 1, 3 },
})("add(%i, %i) = %i", function(a: number, b: number, expected: number)
	expect(a + b).toBe(expected)
end)
```

A flat array of primitives is wrapped per row: `{ 1, 2, 3 }` becomes
`{ { 1 }, { 2 }, { 3 } }`.

### Array of keyed tables

```luau
type Case = { a: number, b: number, expected: number }

it.each({
	{ a = 1, b = 1, expected = 2 },
	{ a = 1, b = 2, expected = 3 },
})("computes $a + $b = $expected", function(case: Case)
	expect(case.a + case.b).toBe(case.expected)
end)
```

### Heading string

Luau has no tagged templates. Instead, pass the headings separated by `|`,
then one table per row:

```luau
it.each("a | b | expected", { 1, 1, 2 }, { 1, 2, 3 }, { 2, 1, 3 })(
	"returns $expected when $a is added to $b",
	function(case: Case)
		expect(case.a + case.b).toBe(case.expected)
	end
)
```

Titles support printf-style placeholders (`%s`, `%i`, `%d`, `%p`...) for
positional rows and `$key` for keyed rows. `.each` works on `it`/`test`,
`.only`, `.skip`, `describe`, `describe.only`, and `describe.skip`.

## Timeout

Tests and hooks accept a final `timeout` parameter in milliseconds:

```luau
it("is a slow operation", function()
	-- long running test
end, 10000)
```

The default timeout is 5000 ms. Configure globally via `testTimeout` in
`jest.config.luau` or `runCLI` options.

## Retries

`jest.retryTimes(n, options?)` (Jest Roblox 3.17+) reruns failing tests. Call
it at the top level of the file or inside a `describe`:

```luau
jest.retryTimes(3, { logErrorsBeforeRetry = true })
```

Options: `logErrorsBeforeRetry`, `waitBeforeRetry` (ms), `retryImmediately`.

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/GettingStarted.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/GlobalAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/SetupAndTeardown.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/JestObjectAPI.md
-->
