---
name: Jest Roblox Deviations
description: |
    Critical differences between Jest Roblox (Luau) and JavaScript Jest.
    Must-read before writing any Jest Roblox tests.
---

# Jest Roblox Deviations from JS Jest

Quick reference of every difference that matters when writing tests. Jest
Roblox mirrors the Jest 27/28 API, so JS Jest knowledge transfers, except
where listed here.

## Explicit Imports

Nothing is injected into the environment (unlike TestEZ or Jest Roblox v2).
Every global must be taken from `JestGlobals`, or Jest errors:

```luau
local JestGlobals = require(Packages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local test = JestGlobals.test
local expect = JestGlobals.expect
local jest = JestGlobals.jest
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach
local beforeAll = JestGlobals.beforeAll
local afterAll = JestGlobals.afterAll
```

Where `Packages` lives depends on how Jest is installed:

- Wally (`[dev-dependencies]` with `roblox/jest-globals`): the dev packages
  folder Wally creates, mapped by your Rojo project (the Jest docs write it as
  `Packages.JestGlobals`)
- Rotriever (`[dev_dependencies]`): `Packages.Dev.JestGlobals`

`JestGlobals` errors if required outside a running Jest test environment, so
only require it from test files and setup files.

Test files do **not** return anything (Jest 3.1.1+). Do not wrap the file in
`return function() ... end` as in TestEZ/Jest 2.

## Matchers Use Dot Calls

Matchers, modifiers and mock methods are plain fields, called with `.`:

```luau
expect(value).toBe(1)
expect(value).never.toBeNil()
mock.mockReturnValue(42)
```

## Negation: `.never` not `.not`

`not` is a reserved keyword in Luau. Use `.never` everywhere:

```luau
expect(value).never.toBe(0)
expect(array).never.toContain("x")
```

Negated asymmetric matchers live on `expect.never`, with aliases:

| `expect.never.*`                | Alias                        |
| ------------------------------- | ---------------------------- |
| `expect.never.arrayContaining`  | `expect.arrayNotContaining`  |
| `expect.never.objectContaining` | `expect.objectNotContaining` |
| `expect.never.stringContaining` | `expect.stringNotContaining` |
| `expect.never.stringMatching`   | `expect.stringNotMatching`   |

Inside custom matchers the negation flag is still named `self.isNot`.

## Truthiness

In Luau, only `false` and `nil` are falsy. `0`, `""`, and `{}` are **truthy**:

```luau
expect(0).toBeTruthy() -- passes (fails in JS)
expect("").toBeTruthy() -- passes (fails in JS)
expect(false).toBeFalsy()
expect(nil).toBeFalsy()
```

Assert exact booleans with `.toBe(true)` / `.toBe(false)` when it matters.

## Nil Checking

Prefer `.toBeNil()` and `.never.toBeNil()`. The JS names exist as aliases:

- `.toBeUndefined()` and `.toBeNull()` are identical to `.toBeNil()`
- `.toBeDefined()` is identical to `.never.toBeNil()`

There is no separate `undefined`; a table key holding `nil` does not exist.

## `jest.fn()` Returns Two Values

```luau
local mock, mockFn = jest.fn()
```

- `mock`: callable **table**; use it with `expect` and for `.mock*` methods
- `mockFn`: real **function** that forwards to `mock`; pass it to code that
  checks `type(x) == "function"` or `typeof(x) == "function"`

```luau
local mock, mockFn = jest.fn()
mockFn("hello")
expect(mock).toHaveBeenCalledWith("hello")
```

If the code under test accepts callable tables, only take the first value:
`local mock = jest.fn()`. The mock object's Luau type is `any`.

## `mockFn.new()`

Replaces JS `new mockFn()`:

```luau
local mock = jest.fn()
local instance = mock.new()
```

## `.each` Syntax

No tagged template literals. Pass a table of rows, or a heading string
followed by rows:

```luau
-- Array of arrays: row values become positional arguments
it.each({
	{ 1, 1, 2 },
	{ 1, 2, 3 },
})("add(%i, %i) = %i", function(a: number, b: number, expected: number)
	expect(a + b).toBe(expected)
end)

-- Heading string: each row becomes a table keyed by heading
it.each("a | b | expected", { 1, 1, 2 }, { 1, 2, 3 })(
	"returns $expected when $a is added to $b",
	function(row: { a: number, b: number, expected: number })
		expect(row.a + row.b).toBe(row.expected)
	end
)
```

A table of keyed tables (`{ { a = 1, b = 1, expected = 2 } }`) is also
accepted; the callback receives each keyed table.

## `expect.any(typename | prototype)`

Luau has no constructors for primitives. Pass a `typeof()` name string:

```luau
expect.any("number")
expect.any("string")
expect.any("boolean")
expect.any("table")
expect.any("DateTime") -- Roblox types work too
```

Or pass a prototype (class) table; it is checked with LuauPolyfill's
`instanceof`.

## `expect.nothing()`

Matches only `nil`. Use inside `toMatchObject`/`toEqual` to assert a key is
absent:

```luau
expect({ foo = "bar" }).toMatchObject({
	foo = "bar",
	baz = expect.nothing(),
})
```

## `expect.callable()`

Luau-only. Matches anything that can be called (functions, callable tables,
callable userdata). Prefer it over `expect.any("function")`, which rejects
callable tables such as `jest.fn()` mocks.

## `.toMatch()` and `expect.stringMatching()`

Take a [Luau string pattern](https://create.roblox.com/docs/luau/strings#patterns)
(`"%d+"`, not `"\\d+"`) or a `RegExp` from the `roblox/regexp` package.

## `.toHaveLength()`

Uses the `#` operator, so it is only meaningful for strings and non-sparse
arrays (returns 0 for dictionaries). If the table has a `length` field, that
is used instead. It cannot check a function's argument count.

## `.toStrictEqual()`

`toEqual` plus a type check based on metatable inheritance. It does **not**
check array sparseness or `undefined` properties like JS Jest.

## `.toBeInstanceOf(prototype)`

Uses LuauPolyfill's `instanceof` on metatable-based classes. Give the class a
`__tostring` metamethod for nicer failure output.

## `.toThrow(error?)`

Also accepts LuauPolyfill `Error` objects (message equality) and `Error`
classes (instance check). Strings are substring matches; `RegExp` values are
pattern matches.

## `.toMatchInstance(table)`

Jest Roblox-only matcher that checks a Roblox `Instance` (and its children,
by name) against a table of expected properties.

## Custom Matchers

The first parameter is always `self` (the matcher context); use `_` if
unused. Context fields: `self.isNot`, `self.equals(a, b)`, `self.utils`,
`self.promise`.

```luau
expect.extend({
	toBeEven = function(self, received: number)
		local pass = received % 2 == 0
		return {
			pass = pass,
			message = function()
				local hint = if self.isNot then "not to be even" else "to be even"
				return `expected {received} {hint}`
			end,
		}
	end,
})
```

## Async Tests

Tests can only return a `Promise` (from `roblox/promise`) or `nil`. There is
no `async`/`await`; chain with `:andThen()` and **return** the promise. A
`done` callback is the **second** parameter of the test function (the first is
the test context).

## Fake Timers

`jest.useFakeTimers()` fakes Luau/Roblox timers: `delay`, `tick`, `time`,
`DateTime`, `task.delay`, `task.wait`, `task.cancel`, `os.time`, `os.clock`.
Timer-advancing APIs take **milliseconds** even though `task.delay` takes
seconds.

Roblox-only: `jest.setEngineFrameTime(ms)` processes timers per frame like
the engine scheduler.

## Global and Instance Mocks

Globals are spied through `jest.globalEnv`
(`jest.spyOn(jest.globalEnv, "print")`). Instance methods (only `game` is
whitelisted) can be spied when the `mockDataModel` config option is on.
`require` cannot be mocked as a global; use `jest.mock()`.

## Module Mocking

`jest.mock(module, factory)` takes a `ModuleScript` (or a require-by-string
path), and the factory is **required**. There is no automock and no
`__mocks__` directory.

## Snapshots

Snapshots are stored as Luau files (`__snapshots__/<test>.snap.lua`). Unlike
upstream, new snapshots are **not** written on the first run: the test fails
until you rerun with `updateSnapshot` in an environment with filesystem write
access.

## Configuration

- The config file is `jest.config.lua`/`.luau` returning a table (or a
  Promise resolving to one); one is **required** per project
- Paths are Instances, not filesystem strings: `projects`, `roots`, `rootDir`,
  `setupFiles`, `setupFilesAfterEnv`, `snapshotSerializers` all take
  Instances/ModuleScripts
- There is no `jest` command; tests are started from a script calling
  `Jest.runCLI(rootDir, options, projects):awaitStatus()`
- `.only`/`.skip` only affect the file they are in

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Deviations.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/ExpectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/JestObjectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/UpgradingToJest3.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/SnapshotTesting.md
-->
