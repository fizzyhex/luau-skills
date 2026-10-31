---
name: Matchers
description: |
    All built-in matchers for asserting values, types, equality, errors, and
    mock calls.
---

# Matchers

## Import

```luau
local expect = require(Packages.JestGlobals).expect
```

Matchers are called with a dot: `expect(received).matcher(expected)`.

## Negation

Use `.never` (not `.not`, which is a reserved keyword in Luau):

```luau
expect(value).never.toBe(0)
```

## Value Matchers

| Matcher                    | Checks                                                                     |
| -------------------------- | -------------------------------------------------------------------------- |
| `.toBe(value)`             | Identity via LuauPolyfill `Object.is` (like `==`). Primitives, references. |
| `.toEqual(value)`          | Recursive deep equality. Use for tables.                                   |
| `.toStrictEqual(value)`    | Deep equality + metatable type check.                                      |
| `.toBeNil()`               | Value is `nil` (aliases: `.toBeUndefined()`, `.toBeNull()`).               |
| `.toBeDefined()`           | Value is not `nil` (same as `.never.toBeNil()`).                           |
| `.toBeTruthy()`            | Not `false` or `nil`. **`0` and `""` are truthy in Luau.**                 |
| `.toBeFalsy()`             | Only `false` or `nil`. **`0` is NOT falsy.**                               |
| `.toBeNan()`               | Value is NaN (`0 / 0`).                                                    |
| `.toBeInstanceOf(class)`   | Metatable inheritance via LuauPolyfill `instanceof`.                       |

```luau
expect({ a = 1 }).toEqual({ a = 1 }) -- deep equal
expect({ a = 1 }).never.toBe({ a = 1 }) -- different references
expect(0).toBeTruthy() -- passes (Luau deviation)
```

`.toBe` reports a deep diff on failure; for large tables compare identity
directly: `expect(received == expected).toBe(true)`.

## Number Matchers

| Matcher                      | Comparison                              |
| ---------------------------- | --------------------------------------- |
| `.toBeGreaterThan(n)`        | `>`                                     |
| `.toBeGreaterThanOrEqual(n)` | `>=`                                    |
| `.toBeLessThan(n)`           | `<`                                     |
| `.toBeLessThanOrEqual(n)`    | `<=`                                    |
| `.toBeCloseTo(n, digits?)`   | Approximate equality (default 2 digits) |

```luau
expect(0.1 + 0.2).toBeCloseTo(0.3, 5)
```

## String Matchers

| Matcher                 | Checks                                |
| ----------------------- | ------------------------------------- |
| `.toMatch(pattern)`     | Luau string pattern or `RegExp`       |
| `.toContain(substring)` | Exact substring (plain, not a pattern) |

```luau
expect("hello world").toMatch("^hello")
expect("score: 42").toMatch("%d+")
expect("hello world").toContain("world")
```

For JS-style regular expressions add the `roblox/regexp` package:

```luau
local RegExp = require(Packages.RegExp)

expect("grapefruit").toMatch(RegExp("grapefruit|orange"))
```

## Table/Array Matchers

| Matcher                            | Checks                                              |
| ---------------------------------- | --------------------------------------------------- |
| `.toContain(item)`                 | Array contains item (identity)                      |
| `.toContainEqual(item)`            | Array contains item (deep equality)                 |
| `.toHaveLength(n)`                 | `#` length (arrays/strings), or a `length` field    |
| `.toHaveProperty(keyPath, value?)` | Nested property exists (dot string or array of keys) |
| `.toMatchObject(subset)`           | Table contains all properties in subset             |

```luau
expect({ "a", "b", "c" }).toContain("b")
expect({ { x = 1 } }).toContainEqual({ x = 1 })
expect({ a = { b = 2 } }).toHaveProperty("a.b", 2)
expect({ list = { "x", "y" } }).toHaveProperty({ "list", 1 }, "x")
```

Use the array form of `keyPath` when a key itself contains a dot. Passing an
array to `toMatchObject` requires the received array to have exactly as many
elements, each matched as a subset.

## Error Matchers

Wrap the throwing code in a function, otherwise the error propagates before
`expect` can catch it. `.toThrowError` is an alias of `.toThrow`.

```luau
expect(function()
	error("boom")
end).toThrow("boom") -- substring match

expect(function()
	error("boom")
end).toThrow(RegExp("^boom$")) -- RegExp match
```

LuauPolyfill `Error` objects and classes are supported:

```luau
local LuauPolyfill = require(Packages.LuauPolyfill)
local Error = LuauPolyfill.Error
local extends = LuauPolyfill.extends

local DisgustingFlavorError = extends(Error, "DisgustingFlavorError", function(self, message)
	self.message = message
	self.name = "DisgustingFlavorError"
end)

local function drinkOctopus()
	error(DisgustingFlavorError("yuck, octopus flavor"))
end

expect(drinkOctopus).toThrow("yuck") -- message substring
expect(drinkOctopus).toThrow(Error("yuck, octopus flavor")) -- exact message
expect(drinkOctopus).toThrow(DisgustingFlavorError) -- instance of class
```

## Mock Matchers

| Matcher                                | Alias                     | Checks                              |
| -------------------------------------- | ------------------------- | ----------------------------------- |
| `.toHaveBeenCalled()`                  | `.toBeCalled()`           | Called at least once                |
| `.toHaveBeenCalledTimes(n)`            | `.toBeCalledTimes(n)`     | Exact call count                    |
| `.toHaveBeenCalledWith(...)`           | `.toBeCalledWith(...)`    | Any call had these args             |
| `.toHaveBeenLastCalledWith(...)`       | `.lastCalledWith(...)`    | Last call had these args            |
| `.toHaveBeenNthCalledWith(n, ...)`     | `.nthCalledWith(n, ...)`  | Nth call (1-indexed) had these args |
| `.toHaveReturned()`                    | `.toReturn()`             | Returned (did not throw) at least once |
| `.toHaveReturnedTimes(n)`              | `.toReturnTimes(n)`       | Returned successfully n times       |
| `.toHaveReturnedWith(value)`           | `.toReturnWith(value)`    | Some call returned value            |
| `.toHaveLastReturnedWith(value)`       | `.lastReturnedWith(value)` | Last call returned value           |
| `.toHaveNthReturnedWith(n, value)`     | `.nthReturnedWith(n, value)` | Nth call returned value          |

```luau
local mock = jest.fn()
mock("a")
mock("b")

expect(mock).toHaveBeenCalledTimes(2)
expect(mock).toHaveBeenNthCalledWith(1, "a")
expect(mock).toHaveBeenLastCalledWith("b")
```

## Roblox-Specific Matchers

### `.toMatchInstance(table)`

Match a Roblox Instance (and named children) against expected properties.
Without a `ClassName` key, any class matches:

```luau
expect(scrollingFrame).toMatchInstance({
	Name = "Example List",
	Position = UDim2.new(0.5, 0, 0.5, 0),
	["List Layout"] = {
		ClassName = "UIListLayout",
	},
})
```

### `.toBeInstanceOf(prototype)`

```luau
local Animal = {}
Animal.__index = Animal

function Animal.new()
	return setmetatable({}, Animal)
end

expect(Animal.new()).toBeInstanceOf(Animal)
```

## Assertion Counts

```luau
it("runs both callbacks", function()
	expect.assertions(2) -- exactly 2 assertions must run
	-- or: expect.hasAssertions() -- at least 1
	doAsync(function(data)
		expect(data).toBeTruthy()
	end, function(data)
		expect(data).toBeTruthy()
	end)
end)
```

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/ExpectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/UsingMatchers.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Deviations.md
-->
