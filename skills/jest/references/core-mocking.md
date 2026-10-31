---
name: Mock Functions
description: |
    Creating mocks with jest.fn(), jest.spyOn(), inspecting calls/returns, and
    configuring mock behavior.
---

# Mock Functions

## Import

```luau
local JestGlobals = require(Packages.JestGlobals)
local expect = JestGlobals.expect
local jest = JestGlobals.jest
```

## Creating Mocks

### `jest.fn(implementation?)`

Returns **two values** (Luau deviation):

```luau
local mock, mockFn = jest.fn()
```

- `mock`: callable table, use for assertions and `.mock*` configuration
- `mockFn`: real function that forwards to `mock`; pass it to code requiring
  `typeof(x) == "function"`

If the code accepts callable tables, you only need the first:

```luau
local mock = jest.fn()
```

With an implementation:

```luau
local double = jest.fn(function(x: number): number
	return x * 2
end)

expect(double(5)).toBe(10)
```

`jest.fn(impl)` is shorthand for `jest.fn().mockImplementation(impl)`. The
mock object is typed `any`, so configuration methods and `.mock` fields are
not type-checked; the forwarding function keeps the implementation's
signature.

### `jest.spyOn(object, methodName)`

Creates a mock that tracks calls to `object[methodName]`. **Calls the original
by default**:

```luau
local video = {
	play = function(): boolean
		return true
	end,
}

it("plays video", function()
	local spy = jest.spyOn(video, "play")

	expect(video.play()).toBe(true)
	expect(spy).toHaveBeenCalled()

	spy.mockRestore() -- put the original back
end)
```

Override the implementation:

```luau
jest.spyOn(video, "play").mockImplementation(function()
	return false
end)
```

By default the spied field is replaced with a forwarding **function**; set
`oldFunctionSpying = true` in config to replace it with the mock table
instead. The three-argument `spyOn(object, name, accessType)` form is not
supported. To spy on `game` methods, see
[feature-global-mocks](feature-global-mocks.md#instance-methods).

Call `jest.restoreAllMocks()` (e.g. in `afterEach`) to restore every spy.
It only affects mocks created with `jest.spyOn`.

## The `.mock` Property

Every mock tracks call data (all arrays are 1-indexed):

```luau
local mock = jest.fn()
mock("a", "b")
mock("c")

print(mock.mock.calls) -- { { "a", "b" }, { "c" } }
print(mock.mock.results) -- { { type = "return", value = nil }, ... }
print(mock.mock.lastCall) -- { "c" }
print(mock.mock.instances) -- objects created through mock.new()
```

`results[i].type` is `"return"`, `"throw"`, or `"incomplete"`.
`mockClear`/`mockReset` replace the whole `.mock` table, so do not cache it
in a local.

## Configuring Return Values

```luau
local mock = jest.fn()

-- Fixed return value
mock.mockReturnValue(42)
mock() -- 42

-- Values in sequence, then the default
mock.mockReturnValue("default").mockReturnValueOnce("first").mockReturnValueOnce("second")

mock() -- "first"
mock() -- "second"
mock() -- "default"
```

## Configuring Implementations

```luau
local mock = jest.fn(function(x: number): number
	return x + 1
end).mockImplementationOnce(function()
	return 99
end)

mock(1) -- 99 (one-time implementation)
mock(1) -- 2 (back to the default)
```

Favour `mockReturnValue` over `mockImplementation` where possible.

## Mock Names

Improve failure messages:

```luau
local fetchUser = jest.fn().mockName("fetchUser")
expect(fetchUser).toHaveBeenCalledWith("user-1")
-- expect(fetchUser).toHaveBeenCalledWith(...)
```

`mock.getMockName()` returns the name.

## Resetting Mocks

| Method                   | Clears calls/results | Removes implementation | Restores original (spies) |
| ------------------------ | -------------------- | ---------------------- | ------------------------- |
| `mock.mockClear()`       | Yes                  | No                     | No                        |
| `mock.mockReset()`       | Yes                  | Yes                    | No                        |
| `mock.mockRestore()`     | Yes                  | Yes                    | Yes                       |
| `jest.clearAllMocks()`   | All mocks            | No                     | No                        |
| `jest.resetAllMocks()`   | All mocks            | Yes                    | No                        |
| `jest.restoreAllMocks()` | All spies            | Yes                    | Yes                       |

Auto-clear or auto-reset before each test via config:

```luau title="jest.config.luau"
return {
	clearMocks = true, -- or resetMocks = true (runCLI option)
}
```

## Constructor Mocking

Use `mock.new()` instead of JS `new mockFn()`:

```luau
local MockClass = jest.fn()
local instance = MockClass.new()

expect(MockClass).toHaveBeenCalledTimes(1)
```

## `.mockReturnThis()`

Makes the mock return the mock object itself on every call:

```luau
local mock = jest.fn().mockReturnThis()

expect(mock()).toBe(mock)
```

## Asserting Mock Calls

```luau
local mock = jest.fn()
mock("a")
mock("b")

expect(mock).toHaveBeenCalledTimes(2)
expect(mock).toHaveBeenCalledWith("a")
expect(mock).toHaveBeenLastCalledWith("b")
expect(mock).toHaveBeenNthCalledWith(1, "a")
```

Or inspect `.mock` directly:

```luau
expect(mock.mock.calls).toHaveLength(2)
expect(mock.mock.calls[1][1]).toBe("a")
```

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/MockFunctionAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/MockFunctions.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/JestObjectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Configuration.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Deviations.md
-->
