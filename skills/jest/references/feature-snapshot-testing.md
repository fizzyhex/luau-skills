---
name: Snapshot Testing
description: Capturing and comparing snapshots for regression testing.
---

# Snapshot Testing

## Import

```luau
local JestGlobals = require(Packages.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
```

## Basic Usage

```luau
it("table", function()
	expect({
		a = 1,
		b = "test",
		c = { "array", "of", "strings" },
	}).toMatchSnapshot()
end)
```

Snapshots are stored as Luau modules in `__snapshots__/<test file>.snap.lua`:

```luau
exports[ [=[table 1]=] ] = [=[
Table {
  "a": 1,
  "b": "test",
  "c": Table {
    "array",
    "of",
    "strings",
  },
}
]=]
```

**Unlike upstream Jest, a new snapshot is not written on the first run.** The
test fails until you rerun with `updateSnapshot` in an environment that can
write to the filesystem. Snapshot testing is not supported on `rocale-cli`.

## Updating Snapshots

Pass `updateSnapshot = true` to `runCLI` to write new snapshots and re-record
failing ones:

```luau
Jest.runCLI(root, {
	updateSnapshot = true,
	testPathPattern = "MyComponent",
}, { root }):awaitStatus()
```

Combine with `testPathPattern` or `testNamePattern` to limit which snapshots
get rewritten. Writing requires a runner with filesystem access (the Jest
docs use Roblox's `roblox-cli` with `--fs.readwrite`); plain Studio runs
cannot write snapshot files.

On CI, set `ci = true` so missing snapshots fail instead of being written.

## Property Matchers

For generated or non-deterministic values, pass asymmetric matchers. They are
checked first, then saved as type placeholders (e.g. `Any<number>`):

```luau
it("matches with dynamic fields", function()
	local user = {
		id = math.floor(math.random() * 20),
		name = "John Smith",
		createdAt = DateTime.now(),
	}

	expect(user).toMatchSnapshot({
		id = expect.any("number"),
		name = expect.any("string"),
		createdAt = expect.any("DateTime"),
	})
end)
```

Non-matcher values in the table are checked exactly and saved as-is.

## Error Snapshots

```luau
it("captures the error message", function()
	expect(function()
		error(Error("something broke"))
	end).toThrowErrorMatchingSnapshot()
end)
```

Plain string errors work, but LuauPolyfill `Error` objects give cleaner
snapshots.

## Snapshot Hints

Add a hint string to distinguish multiple snapshots in one test:

```luau
it("captures multiple snapshots", function()
	expect(stateA).toMatchSnapshot("before update")
	expect(stateB).toMatchSnapshot("after update")
end)
```

With property matchers the hint is the second argument:
`toMatchSnapshot(propertyMatchers, hint)`.

## Custom Serializers

A serializer is a table with `test` and `serialize`:

```luau title="customSerializer.luau"
local function serialize(val, config, indentation, depth, refs, printer)
	return "Pretty foo: " .. printer(val.foo, config, indentation, depth, refs, printer)
end

local function test(val: unknown): boolean
	return typeof(val) == "table" and (val :: any).foo ~= nil
end

return {
	serialize = serialize,
	test = test,
}
```

Register it per file:

```luau
expect.addSnapshotSerializer(require(script.Parent.customSerializer))
```

Or for all tests in config:

```luau title="jest.config.luau"
return {
	snapshotSerializers = { script.Parent.customSerializer },
}
```

## Roblox Instance Snapshots

Instances serialize with their properties. Configure formatting in
`jest.config`:

```luau
return {
	snapshotFormat = {
		printInstanceDefaults = false, -- omit properties left at default values
		printInstanceTags = true, -- show CollectionService tags
	},
}
```

## Custom Snapshot Matchers

Build matchers that delegate to snapshot testing:

```luau
local JestSnapshot = require(Packages.JestSnapshot)
local toMatchSnapshot = JestSnapshot.toMatchSnapshot

expect.extend({
	toMatchTrimmedSnapshot = function(self, received: string, length: number)
		return toMatchSnapshot(self, string.sub(received, 1, length), "toMatchTrimmedSnapshot")
	end,
})
```

## Best Practices

- Commit snapshot files alongside tests and review their diffs in PRs
- Keep snapshots small and focused
- Use property matchers or mocks for non-deterministic fields
- Use descriptive test names (they become snapshot keys)
- On CI, use `ci = true` to prevent writing new snapshots

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/SnapshotTesting.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/ExpectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Configuration.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/CLI.md
-->
