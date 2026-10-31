---
name: Asymmetric Matchers
description: |
    Flexible value matching with expect.anything(), expect.any(),
    expect.callable(), and asymmetric variants.
---

# Asymmetric Matchers

Asymmetric matchers can be used inside `toEqual`, `toHaveBeenCalledWith`,
`toMatchObject`, `toMatchSnapshot` property matchers, and other
deep-comparison matchers as placeholder values.

## Import

```luau
local expect = require(Packages.JestGlobals).expect
```

## `expect.anything()`

Matches anything except `nil`:

```luau
local mock = jest.fn()
mock("a")
expect(mock).toHaveBeenCalledWith(expect.anything())
```

## `expect.any(typename | prototype)`

Matches by `typeof()` name or by prototype class:

```luau
-- Type strings
expect({ id = 42 }).toEqual({ id = expect.any("number") })
expect({ name = "foo" }).toEqual({ name = expect.any("string") })

-- Prototype class (uses LuauPolyfill instanceof)
expect(instance).toEqual(expect.any(MyClass))
```

Supports Roblox types (`"DateTime"`, `"Vector3"`...), Luau types
(`"thread"`), `RegExp`, and LuauPolyfill types (`Error`, `Set`...).

## `expect.nothing()`

Matches only `nil`. Use to assert a key is absent:

```luau
expect({ foo = "bar" }).toMatchObject({
	foo = "bar",
	missing = expect.nothing(),
})
```

## `expect.callable()`

Matches anything that can be called: functions, callable tables (including
`jest.fn()` mocks) and callable userdata. Prefer it over
`expect.any("function")`:

```luau
expect(callback).toEqual(expect.callable())
```

## `expect.arrayContaining(array)`

Matches a received array that contains all elements of the expected array
(subset check; extra elements are allowed):

```luau
expect({ "a", "b", "c" }).toEqual(expect.arrayContaining({ "a", "c" }))
```

## `expect.objectContaining(table)`

Matches a received table that recursively contains all expected key-value
pairs:

```luau
expect({ x = 1, y = 2, z = 3 }).toEqual(expect.objectContaining({ x = 1, y = 2 }))
```

## `expect.stringContaining(string)`

Matches a string containing the exact expected substring:

```luau
expect("hello world").toEqual(expect.stringContaining("world"))
```

## `expect.stringMatching(pattern | regexp)`

Matches a string against a Luau string pattern or a `RegExp`:

```luau
local RegExp = require(Packages.RegExp)

expect("abc123").toEqual(expect.stringMatching("%d+"))
expect("abc123").toEqual(expect.stringMatching(RegExp("\\d+")))
```

## Negated Asymmetric Matchers

The containing/matching matchers have `.never` variants (also available as
`expect.arrayNotContaining`, `expect.objectNotContaining`,
`expect.stringNotContaining`, `expect.stringNotMatching`):

```luau
expect({ "a", "b" }).toEqual(expect.never.arrayContaining({ "c" }))
expect({ x = 1 }).toEqual(expect.never.objectContaining({ y = 2 }))
expect("hello").toEqual(expect.never.stringContaining("bye"))
expect("hello").toEqual(expect.never.stringMatching("^bye"))
```

## `.resolves` and `.rejects`

Unwrap a Promise (`roblox/promise`) before matching. The result is itself a
Promise, so **return** it from the test:

```luau
local Promise = require(Packages.Promise)

it("resolves to lemon", function()
	return expect(Promise.resolve("lemon")).resolves.toBe("lemon")
end)

it("rejects with octopus", function()
	return expect(Promise.reject(Error.new("octopus"))).rejects.toThrow("octopus")
end)
```

## Nesting Asymmetric Matchers

Matchers compose freely:

```luau
expect(data).toEqual({
	users = expect.arrayContaining({
		expect.objectContaining({
			name = expect.any("string"),
			email = expect.stringMatching("@"),
		}),
	}),
})
```

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/ExpectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Deviations.md
-->
