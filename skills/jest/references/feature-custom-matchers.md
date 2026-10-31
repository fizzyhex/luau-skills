---
name: Custom Matchers
description: Extending Jest Roblox with custom matchers via expect.extend().
---

# Custom Matchers

## Import

```luau
local JestGlobals = require(Packages.JestGlobals)
local expect = JestGlobals.expect
```

## `expect.extend(matchers)`

Each matcher is a function whose **first parameter is `self`** (the matcher
context), followed by the received value and the matcher's arguments. Use
`_` when the context is unused.

```luau
expect.extend({
	toBeWithinRange = function(self, received: number, floor: number, ceiling: number)
		local pass = received >= floor and received <= ceiling
		local range = self.utils.printExpected(`{floor} - {ceiling}`)
		local value = self.utils.printReceived(received)
		return {
			pass = pass,
			message = function()
				if pass then
					return `expected {value} not to be within range {range}`
				end
				return `expected {value} to be within range {range}`
			end,
		}
	end,
})
```

## Type Checking Extended Matchers

`JestGlobals.expect` only knows the built-in matchers, so calling a custom
matcher on it is a type error under `--!strict`. `JestGlobals.expectExtended`
is the same `expect` typed to accept any extra matcher; use it in files that
call custom matchers:

```luau
local expect = JestGlobals.expectExtended

expect(100).toBeWithinRange(90, 110)
```

For precise types, cast with the exported `ExpectExtended` type:

```luau
type RangeMatchers = {
	toBeWithinRange: (floor: number, ceiling: number) -> (),
}

local expect = JestGlobals.expect :: JestGlobals.ExpectExtended<RangeMatchers>
```

## Matcher Context (`self`)

| Property            | Description                                       |
| ------------------- | ------------------------------------------------- |
| `self.isNot`        | `true` if called through `.never`                 |
| `self.promise`      | Set when called through `.resolves` / `.rejects`  |
| `self.equals(a, b)` | Recursive deep-equality check                     |
| `self.utils`        | Formatting helpers from `jest-matcher-utils`      |

The flag is `isNot` even though the user-facing modifier is `.never`.

### Formatting with `self.utils`

`matcherHint`, `printExpected` and `printReceived` produce standard Jest
output:

```luau
expect.extend({
	toBeFoo = function(self, received: string)
		local options = { isNot = self.isNot, promise = self.promise }
		local pass = received == "foo"
		return {
			pass = pass,
			message = function()
				return self.utils.matcherHint("toBeFoo", nil, nil, options)
					.. "\n\n"
					.. `Expected: {if pass then "never " else ""}{self.utils.printExpected("foo")}\n`
					.. `Received: {self.utils.printReceived(received)}`
			end,
		}
	end,
})
```

## Return Value

Matchers must return `{ pass: boolean, message: () -> string }`:

- `pass`: whether the value matched
- `message`: function returning the failure text
    - When `pass = true`: message for the `.never` failure case
    - When `pass = false`: message for the normal failure case

## Using Custom Matchers

```luau
it("is in range", function()
	expect(100).toBeWithinRange(90, 110)
	expect(101).never.toBeWithinRange(0, 100)
end)
```

## As Asymmetric Matchers

Custom matchers are also available on `expect` and `expect.never`:

```luau
expect({ apples = 6, bananas = 3 }).toEqual({
	apples = expect.toBeWithinRange(1, 10),
	bananas = expect.never.toBeWithinRange(11, 20),
})
```

## Custom Snapshot Matchers

Delegate to `JestSnapshot.toMatchSnapshot`, passing `self` through:

```luau
local JestSnapshot = require(Packages.JestSnapshot)
local toMatchSnapshot = JestSnapshot.toMatchSnapshot

expect.extend({
	toMatchTrimmedSnapshot = function(self, received: string, length: number)
		return toMatchSnapshot(self, string.sub(received, 1, length), "toMatchTrimmedSnapshot")
	end,
})
```

## Global Registration

Register in a `setupFilesAfterEnv` module so every test file gets the
matchers:

```luau title="setupJest.luau"
local JestGlobals = require(Packages.JestGlobals)
local expect = JestGlobals.expect

expect.extend({
	toBeWithinRange = function(self, received: number, floor: number, ceiling: number)
		-- ...
	end,
})
```

```luau title="jest.config.luau"
return {
	setupFilesAfterEnv = { script.Parent.setupJest },
}
```

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/ExpectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Deviations.md
- https://github.com/Roblox/jest-roblox/blob/main/src/jest-globals/src/index.lua
-->
