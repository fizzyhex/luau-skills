---
name: core-classes
description: |
    Use when writing a typed class/object in Luau with metatables, typing self,
    exporting a class type, or adding inheritance
---

# Typed Metatable Classes

Luau has no `class` keyword. Classes are tables with a metatable whose
`__index` points at a method table. To type them:

1. Declare the instance **data** type.
2. Derive the class type from the data and the metatable.
3. Annotate `self` explicitly on every method.

## Recommended pattern (new solver)

```luau
--!strict
local Account = {}
Account.__index = Account

type AccountData = {
	name: string,
	balance: number,
}

export type Account = setmetatable<AccountData, typeof(Account)>

function Account.new(name: string, balance: number): Account
	local self = {
		name = name,
		balance = balance,
	}
	return setmetatable(self, Account)
end

-- Define with `.` and an explicit `self` and call with `:` as usual
function Account.deposit(self: Account, credit: number)
	self.balance += credit
end

function Account.getBalance(self: Account): number
	return self.balance
end

local acc = Account.new("Hina", 500)
acc:deposit(20)
print(acc:getBalance())

return Account
```

## Portable pattern (old and new solver)

`setmetatable<...>` is a type function that only the new solver has. Under the
old solver, use `typeof(setmetatable(...))` instead:

```luau
--!strict
local Timer = {}
Timer.__index = Timer

type TimerData = { elapsed: number, running: boolean }
export type Timer = typeof(setmetatable({} :: TimerData, Timer))

function Timer.new(): Timer
	return setmetatable({ elapsed = 0, running = false }, Timer)
end

function Timer.tick(self: Timer, dt: number)
	if self.running then
		self.elapsed += dt
	end
end

return Timer
```

## Why not `function Class:method()`?

```luau
--!strict
local Counter = {}
Counter.__index = Counter
type Counter = setmetatable<{ count: number }, typeof(Counter)>

function Counter.new(): Counter
	return setmetatable({ count = 0 }, Counter)
end

-- With `:`, self is inferred independently per method (here as
-- `{ read count: unknown }`), so this line is a type error:
function Counter:increment()
	self.count += 1 -- TypeError: Property count ... is read-only
end
```

`self` types aren't shared across methods yet (a "shared self" design is
planned). The annotation on `self` is **required** in strict mode. You can't
annotate the implicit `self` of a `:` definition, so use `.` with
`self: Class`. Calls still use `obj:method()`.

## Inheritance

```luau
--!strict
local Base = {}
Base.__index = Base
type BaseData = { id: string }
export type Base = setmetatable<BaseData, typeof(Base)>

function Base.new(id: string): Base
	return setmetatable({ id = id }, Base)
end

-- Methods meant to be inherited take a STRUCTURAL self, not `Base`:
-- metatable types are invariant, so a `Derived` is not accepted as `Base`.
function Base.describe(self: { read id: string }): string
	return `Base {self.id}`
end

local Derived = setmetatable({}, { __index = Base })
Derived.__index = Derived
type DerivedData = BaseData & { level: number }
export type Derived = setmetatable<DerivedData, typeof(Derived)>

function Derived.new(id: string, level: number): Derived
	return setmetatable({ id = id, level = level }, Derived)
end

function Derived.levelUp(self: Derived)
	self.level += 1
end

local d = Derived.new("x", 1)
d:levelUp()
print(d:describe()) -- resolved through Derived -> Base
```

If `Base.describe` took `self: Base`, then `d:describe()` would fail with
`Expected this to be exactly 'Base', but got 'Derived'`. Inheritance chains
are also slower, because every miss walks another `__index`. Prefer
**composition**, or keep hierarchies one level deep.

## Key points

- Keep `__index = Class` pointing at a **table**, never a function. That's the
  fast path for method calls.
- Put static fields and constants on `Class`, not on instances. Read them as
  `Class.CONSTANT`.
- Create every field in the constructor literal. Don't add fields later,
  because the checker seals the type and the VM optimizes uniform shapes.
- Export both the module table (`return Account`) and the type (`export type
  Account`). Callers write `Account.Account` as the type (see
  core-modules-require).
- For private fields, use a naming convention (`_field`). Luau has no access
  modifiers.

<!--
Source references:
- https://luau.org/types/object-oriented-programs
- https://rfcs.luau.org/metatable-type-functions.html
- https://luau.org/performance#fast-method-calls
-->
