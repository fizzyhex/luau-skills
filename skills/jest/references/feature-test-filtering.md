---
name: Test Filtering
description: |
    Filtering which tests run by file path, name pattern, and glob matching.
---

# Test Filtering

## In-File Filtering: `.only` and `.skip`

Controls which tests run **within a single file**; other files still run:

```luau
describe.only("focused suite", function()
	it("runs", function()
		expect(true).toBe(true)
	end)

	it.skip("is skipped", function()
		expect(true).toBe(false)
	end)

	describe.skip("skipped block", function()
		it.only("still does not run", function()
			expect(true).toBe(false)
		end)
	end)
end)

describe("a now skipped suite", function()
	it("is skipped because of describe.only above", function()
		expect(true).toBe(false)
	end)
end)
```

`.skip` inside `.only` still skips, and `.only` inside `.skip` still skips
(skip wins).

## Filter by File Path

Path filters match the test's filesystem path when Jest can resolve
DataModel paths to files; otherwise they match the DataModel path, which can
be unintuitive.

### `testMatch` (glob patterns)

In `jest.config`:

```luau
return {
	testMatch = { "**/*.spec" },
}
```

Default: `{ "**/__tests__/**/*", "**/?(*.)+(spec|test)?(.lua|.luau)" }`.
Patterns apply in order, so put negations (`"!**/__fixtures__/**"`) **after**
the positive patterns. Passing `testMatch` to `runCLI` overrides every config
file.

### `testRegex` (regex patterns)

Mutually exclusive with `testMatch`. Matched against the absolute path:

```luau
return {
	testRegex = { "foo\\.lua$" },
}
```

### `testPathPattern` (runCLI)

Only run files whose path matches a regex:

```luau
Jest.runCLI(root, {
	testPathPattern = "components",
}, { root }):awaitStatus()
```

### `testPathIgnorePatterns` (runCLI/config)

Exclude files matching any of the patterns:

```luau
Jest.runCLI(root, {
	testPathIgnorePatterns = { "legacy", "__fixtures__" },
}, { root }):awaitStatus()
```

## Filter by Test Name

### `testNamePattern`

Match against the full test name (all parent `describe` names plus the test
name, space-separated):

```luau
Jest.runCLI(root, {
	testNamePattern = "auth",
}, { root }):awaitStatus()
```

Given:

```luau
describe("block A", function()
	it.todo("test one")
	it.todo("test two")
end)

describe("block B", function()
	it.todo("test three")
end)

it.todo("test one two three")
```

- `"block A"` matches "test one" and "test two"
- `"block A test one"` matches only "test one"
- `"test one"` matches "test one" and "test one two three"
- `"block B test one"` matches nothing

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/TestFiltering.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/CLI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Configuration.md
-->
