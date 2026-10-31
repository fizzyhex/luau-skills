---
name: Global Mocks
description: |
    Mocking global Luau functions like print() and math.random() using
    jest.globalEnv, and spying on game methods with mockDataModel.
---

# Global Mocks

## Import

```luau
local JestGlobals = require(Packages.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest
```

## Mocking Global Functions

`jest.globalEnv` is the function environment of the current test. Spy on it
like any table to mock globals such as `print()`:

```luau
it("captures print output", function()
	local mockPrint = jest.spyOn(jest.globalEnv, "print")
	mockPrint.mockImplementation(function() end)

	print("hello")

	expect(mockPrint).toHaveBeenCalledWith("hello")
end)
```

This also affects modules required by the test, e.g. a module that calls
`print` internally.

## Mocking Library Functions

Index into `jest.globalEnv` to reach libraries like `math`:

```luau
it("mocks math.random", function()
	local mockRandom = jest.spyOn(jest.globalEnv.math, "random")
	mockRandom.mockImplementationOnce(function(_min: number?, _max: number?)
		return 5
	end)

	expect(math.random(1, 6)).toBe(5)
end)
```

## Accessing Original Implementations

The original (unmocked) functions remain available through `jest.globalEnv`:

```luau
local mockRandom = jest.spyOn(jest.globalEnv.math, "random")
mockRandom.mockReturnValue(5)

local mocked = math.random() -- 5
local unmocked = jest.globalEnv.math.random() -- real random number
```

## Instance Methods

With `mockDataModel = true` in `jest.config`, whitelisted instances
(currently only `game`) can be spied. The first argument to the
implementation is the instance (`self`):

```luau
local mockServices = {
	LogService = {},
}

local mock = jest.spyOn(game, "GetService")
mock.mockImplementation(function(_self, service: string)
	return mockServices[service]
end)

expect(game:GetService("LogService")).toEqual(mockServices.LogService)
```

## Limitations

Only **whitelisted** globals can be mocked. These are **not** supported:

- `require()`: use `jest.mock()` instead
- Task scheduling (`task.delay`, etc.): use `jest.useFakeTimers()` instead
- `game` and other Instances through `jest.globalEnv`: use
  `jest.spyOn(game, ...)` with `mockDataModel` instead

Attempting to mock a non-whitelisted global produces an error:

```text
Jest does not yet support mocking the require global.
```

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/GlobalMocks.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/JestObjectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Configuration.md
-->
