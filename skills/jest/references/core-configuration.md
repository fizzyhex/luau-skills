---
name: Configuration
description: Installing Jest Roblox, jest.config options, and the runCLI entrypoint.
---

# Configuration

## Installation

Add the packages as dev dependencies with Wally:

```toml title="wally.toml"
[dev-dependencies]
Jest = "roblox/jest@^3.20.0"
JestGlobals = "roblox/jest-globals@^3.20.0"
```

Optional companions: `roblox/jest-benchmark` (benchmarks),
`roblox/promise` (async tests), `roblox/regexp` (`RegExp` in matchers).
Tests run inside a Roblox environment: Studio, or Open Cloud Luau Execution.

## Config File

Each project root (a DataModel Instance) needs a ModuleScript named
`jest.config` (`jest.config.lua` or `jest.config.luau` on disk). Jest errors
if it is missing.

```luau title="src/jest.config.luau"
return {
	testMatch = { "**/*.spec" },
	verbose = true,
}
```

The module may also return a Promise that resolves to the config table.
Path-like options take Instances, not strings.

## `runCLI` Entrypoint

There is no `jest` command. A script calls `Jest.runCLI` and inspects the
result:

```luau title="spec.server.luau"
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wherever your Rojo project maps the Wally dev packages
local Jest = require(ReplicatedStorage.Packages.Jest)
local root = ReplicatedStorage.Project

local status, result = Jest.runCLI(root, {
	verbose = false,
	ci = false,
}, { root }):awaitStatus()

if status == "Rejected" then
	print(result)
	error(result)
end

if not result.results.success then
	error("Tests failed")
end
```

Arguments: `runCLI(rootDir: Instance, options, projects: { Instance })`.
`projects` are the Instances containing a `jest.config`. `runCLI` returns a
Promise; `:awaitStatus()` yields until it settles.

## Configuration Options

| Option                   | Type              | Default                                                  | Description                                        |
| ------------------------ | ----------------- | -------------------------------------------------------- | -------------------------------------------------- |
| `clearMocks`             | boolean           | `false`                                                  | Auto-clear mocks before each test                  |
| `displayName`            | string/table      | `nil`                                                    | Label (`{ name, color }`) for multi-project output |
| `projects`               | `{ Instance }`    | `nil`                                                    | Run several projects together                      |
| `rootDir`                | Instance          | config's parent                                          | Root directory for scanning                        |
| `roots`                  | `{ Instance }`    | `{ rootDir }`                                            | Directories to search for tests                    |
| `setupFiles`             | `{ ModuleScript }` | `{}`                                                    | Run before the test framework is installed         |
| `setupFilesAfterEnv`     | `{ ModuleScript }` | `{}`                                                    | Run after the framework is installed, per file     |
| `testMatch`              | `{ string }`      | `{ "**/__tests__/**/*", "**/?(*.)+(spec\|test)?(.lua\|.luau)" }` | Glob patterns for test files              |
| `testRegex`              | string/`{ string }` | `{}`                                                   | Regex patterns (mutually exclusive with testMatch) |
| `testPathIgnorePatterns` | `{ string }`      | `{}`                                                     | Regex patterns of paths to skip                    |
| `testTimeout`            | number            | `5000`                                                   | Default test timeout (ms)                          |
| `testFailureExitCode`    | number            | `1`                                                      | Exit code on failure                               |
| `slowTestThreshold`      | number            | `5`                                                      | Seconds before a test is reported as slow          |
| `stackDepth`             | number            | `0`                                                      | Max stack frames printed (`0` = all)               |
| `verbose`                | boolean           | `false`                                                  | Show individual test results                       |
| `reporters`              | table             | `nil`                                                    | See below                                          |
| `snapshotFormat`         | table             | `nil`                                                    | See below                                          |
| `snapshotSerializers`    | `{ ModuleScript }` | `{}`                                                    | Custom snapshot serializers                        |
| `mockDataModel`          | boolean           | `false`                                                  | Enable spying on `game` methods                    |
| `oldFunctionSpying`      | boolean           | `false`                                                  | `spyOn` replaces with mock table instead of function |

## Reporters

```luau
return {
	reporters = {
		"default",
		{ reporter = script.Parent.MyReporter, options = { key = "value" } },
	},
}
```

Built-in reporters: `"default"`, `"summary"`, `"github-actions"`. Specifying
any reporter replaces the default one unless `"default"` is listed.

A custom reporter ModuleScript returns a class with
`.new(globalConfig, reporterOptions, reporterContext)` and at least
`:onRunComplete(testContexts, results)`. It may implement `:getLastError()`
returning a LuauPolyfill `Error` to force a failing exit.

## Snapshot Options

```luau
return {
	snapshotFormat = {
		printInstanceDefaults = false, -- only print changed Instance properties
		printInstanceTags = true, -- include CollectionService tags
		useStyledProperties = false, -- read properties via GetStyled
		redactStackTracesInStrings = false,
	},
	snapshotSerializers = { script.Parent.mySerializer },
}
```

## Setup Files

`setupFilesAfterEnv` is where you register custom matchers, serializers, or
shared hooks. JestGlobals is available there:

```luau title="setupJest.luau"
local JestGlobals = require(Packages.JestGlobals)
local expect = JestGlobals.expect
local jest = JestGlobals.jest
local afterEach = JestGlobals.afterEach

expect.extend({
	toBeEven = function(_, received: number)
		return {
			pass = received % 2 == 0,
			message = function()
				return `expected {received} to be even`
			end,
		}
	end,
})

afterEach(function()
	jest.useRealTimers()
end)
```

```luau title="jest.config.luau"
return {
	setupFilesAfterEnv = { script.Parent.setupJest },
}
```

## Roblox-Specific Options

### `mockDataModel` (boolean)

Enables instance mocking, allowing `jest.spyOn(game, "GetService")`. Only
whitelisted instances (currently `game`) are supported. Mocked instances are
tables, not real Instances, so patterns like `x:IsDescendantOf(game)` break;
leave it off unless you need it.

### `oldFunctionSpying` (boolean)

Controls how `jest.spyOn()` overwrites methods:

- `true`: replaces the field with the mock object (old behaviour)
- `false`: replaces it with a forwarding function (new behaviour)

`spyOn` always returns the mock object either way.

## `runCLI` Options

| Option                   | Description                                         |
| ------------------------ | --------------------------------------------------- |
| `ci`                     | Fail on new snapshots instead of allowing writes    |
| `clearMocks`             | Auto-clear mocks                                    |
| `resetMocks`             | Auto-reset mocks                                    |
| `debug`                  | Print config debug info                             |
| `expand`                 | Show full diffs                                     |
| `json`                   | JSON output                                         |
| `listTests`              | List test files and exit                            |
| `noStackTrace`           | Omit stack traces                                   |
| `passWithNoTests`        | Pass when no tests are found                        |
| `reporters`              | Override reporters                                  |
| `showConfig`             | Print config and exit                               |
| `stackDepth`             | Limit printed stack frames                          |
| `updateSnapshot`         | Re-record failing snapshots                         |
| `testMatch`              | Override glob patterns (overrides config files)     |
| `testNamePattern`        | Filter by full test name regex                      |
| `testPathPattern`        | Filter by file path regex                           |
| `testPathIgnorePatterns` | Exclude file paths                                  |
| `testTimeout`            | Override timeout                                    |
| `verbose`                | Show individual results                             |

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/GettingStarted.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Configuration.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/CLI.md
-->
