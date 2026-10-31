---
name: Async Testing
description: |
    Testing asynchronous code with Promises and done callbacks in Jest Roblox.
---

# Async Testing

## Import

```luau
local JestGlobals = require(Packages.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local Promise = require(Packages.Promise) -- roblox/promise
```

Luau has no `async`/`await`. Jest Roblox waits for a test when it **returns**
a Promise or when the test function takes a `done` parameter.

## Promises

Return a Promise from the test function. Jest waits for it; a rejection fails
the test:

```luau
it("fetches peanut butter", function()
	return fetchData():andThen(function(data: string)
		expect(data).toBe("peanut butter")
	end)
end)
```

Tests can **only** return a `Promise` or `nil`. Forgetting the `return`
lets the test finish before the assertion runs.

### `.resolves` / `.rejects`

Unwrap Promises inline. **Return** the assertion, since it is a Promise too:

```luau
it("resolves to lemon", function()
	return expect(Promise.resolve("lemon")).resolves.toBe("lemon")
end)

it("rejects with octopus", function()
	return expect(Promise.reject(Error.new("octopus"))).rejects.toThrow("octopus")
end)
```

## `done` Callbacks

For callback-style APIs, declare a **second** parameter (the first is the test
context, usually `_`). Jest waits until `done()` is called, or fails with a
timeout:

```luau
it("the data is peanut butter", function(_, done)
	fetchData(function(err: string?, data: string?)
		if err then
			done(err)
			return
		end
		xpcall(function()
			expect(data).toBe("peanut butter")
			done()
		end, function(assertionError)
			done(assertionError)
		end)
	end)
end)
```

Wrap the assertions in `xpcall` and pass the error to `done`, otherwise a
failing `expect` only surfaces as an opaque timeout. Do not mix `done` with
returned Promises.

## Assertion Counts

Use `expect.assertions(n)` or `expect.hasAssertions()` to guarantee
callbacks actually ran:

```luau
it("calls both callbacks", function()
	expect.assertions(2)
	doAsync(function(data)
		expect(data).toBeTruthy()
	end, function(data)
		expect(data).toBeTruthy()
	end)
end)
```

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/TestingAsyncCode.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/ExpectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/GlobalAPI.md
-->
