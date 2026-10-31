---
name: Module Mocking
description: |
    Mocking modules with jest.mock(), jest.unmock(), jest.requireActual(),
    jest.resetModules() and jest.isolateModules().
---

# Module Mocking

## Import

```luau
local JestGlobals = require(Packages.JestGlobals)
local expect = JestGlobals.expect
local jest = JestGlobals.jest
local beforeEach = JestGlobals.beforeEach
local it = JestGlobals.it
```

Jest Roblox intercepts `require` inside test files (and the modules they
load). Modules are identified by `ModuleScript` or by a
[require-by-string](https://create.roblox.com/docs/reference/engine/globals/LuaGlobals/require)
path.

## `jest.mock(module, factory)`

Replace a module with the factory's return value whenever it is required. The
factory is **required** (there is no automocking or `__mocks__` folder):

```luau
local MyModule = script.Parent.Parent.MyModule

beforeEach(function()
	jest.resetModules()
	jest.mock(MyModule, function()
		return {
			getValue = jest.fn(function()
				return 42
			end),
			helper = jest.fn(function()
				return "mocked"
			end),
		}
	end)
end)

it("uses the mocked module", function()
	local myModule = require(MyModule) :: any

	expect(myModule.getValue()).toBe(42)
	expect(myModule.helper()).toBe("mocked")
end)
```

Require the module **after** calling `jest.mock` (inside the test or after
the mock call), since already-required modules are cached. Mocks are scoped
to the file that calls `jest.mock`; other test files get the real module.

The type checker still sees the real module's type, so cast when the mock's
shape differs.

## `jest.unmock(module)`

Stop mocking, so `require` returns the real module:

```luau
it("is not mocked", function()
	jest.unmock(MyModule)
	local real = require(MyModule)
	expect(real).toEqual({})
end)
```

## `jest.requireActual(module)`

Get the real module even while it is mocked, e.g. for a partial mock:

```luau
local Utils = script.Parent.Parent.Utils

jest.mock(Utils, function()
	local actual = jest.requireActual(Utils)
	return {
		mockedFunc = jest.fn(),
		realFunc = actual.realFunc,
	}
end)
```

## `jest.resetModules()`

Clear the module registry. Subsequent `require` calls return fresh copies:

```luau
local sum1 = require(script.Parent.Parent.sum)
jest.resetModules()
local sum2 = require(script.Parent.Parent.sum)

expect(sum1).never.toBe(sum2) -- separate instances of the module
```

Calling it in `beforeEach` isolates module-level state between tests.

## `jest.isolateModules(fn)`

Create a sandboxed module registry for modules required inside the callback:

```luau
local isolated
jest.isolateModules(function()
	isolated = require(script.Parent.Parent.MyModule)
end)

local normal = require(script.Parent.Parent.MyModule)

expect(isolated).never.toBe(normal) -- different instances
```

## Chaining

`jest.mock`, `jest.unmock` and `jest.resetModules` return the `jest` object:

```luau
jest.mock(ModuleA, function()
	return {}
end).mock(ModuleB, function()
	return {}
end)
```

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/JestObjectAPI.md
-->
