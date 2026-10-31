---
name: Benchmarking
description: |
    Performance testing with JestBenchmark, profiling, and custom reporters.
---

# Benchmarking

Roblox-only feature for gating performance in CI and capturing perf metrics.

## Setup

Add the package as a dev dependency:

```toml title="wally.toml"
[dev-dependencies]
JestBenchmark = "roblox/jest-benchmark@^3.20.0"
```

```luau
local JestBenchmark = require(Packages.JestBenchmark)
local benchmark = JestBenchmark.benchmark
local CustomReporters = JestBenchmark.CustomReporters
local MetricLogger = JestBenchmark.MetricLogger
local initializeReporter = JestBenchmark.Reporter.initializeReporter
local initializeProfiler = JestBenchmark.Profiler.initializeProfiler
```

## `benchmark(name, fn, timeout?)`

Wrapper around `test` with automatic FPS and section-time profiling:

```luau
describe("home page benchmarks", function()
	benchmark("first render performance", function(Profiler, reporters)
		render(React.createElement(HomePage))
		local element = screen.getByText("Continue")

		expect(element).toBeDefined()
	end)
end)
```

Supports `benchmark.only` and `benchmark.skip`.

The callback receives:

- `Profiler`: controls reporter start/stop
- `reporters`: table of named custom reporters

## Reporters

A `Reporter` collects values during a benchmark and reduces them with a
collector function.

### Creating a Reporter

```luau
local function average(numbers: { number }): number
	if #numbers == 0 then
		return 0
	end

	local sum = 0
	for _, value in numbers do
		sum += value
	end

	return sum / #numbers
end

local averageReporter = initializeReporter("average", average)
```

### Reporter API

```luau
averageReporter.start("section1")
averageReporter.report(10)
averageReporter.report(20)
averageReporter.stop()

local sectionNames, sectionValues = averageReporter.finish()
-- sectionNames: { "section1" }, sectionValues: { 15 }
```

Sections can be nested; values are returned in order of completion:

```luau
averageReporter.start("total")

averageReporter.start("part1")
averageReporter.report(1)
averageReporter.report(3)
averageReporter.stop()

averageReporter.start("part2")
averageReporter.report(5)
averageReporter.report(7)
averageReporter.stop()

averageReporter.stop()

local sectionNames, sectionValues = averageReporter.finish()
-- sectionNames: { "part1", "part2", "total" }, sectionValues: { 2, 6, 4 }
```

Every `start` must be closed with a `stop`. Reduction only happens in
`finish`, to keep the benchmark itself cheap.

## Profiler

Controls several reporters at once:

```luau
local profiler = initializeProfiler({ averageReporter, timeReporter }, function(metricName: string, value: any)
	print(`{metricName}: {value}`)
end)

profiler.start("render")
-- ... benchmark code ...
profiler.stop()
profiler.finish() -- calls the output function for each metric
```

An optional third argument to `initializeProfiler` is a prefix added to all
section names. Calling `stop` without a matching `start` errors.

## Custom Reporters in Benchmarks

Default reporters: FPS and SectionTime. Add custom ones; they arrive in the
`reporters` table:

```luau
beforeEach(function()
	CustomReporters.useCustomReporters({
		sum = initializeReporter("sum", function(numbers: { number }): number
			local sum = 0
			for _, value in numbers do
				sum += value
			end
			return sum
		end),
	})
end)

benchmark("total renders", function(Profiler, reporters)
	reporters.sum.report(getRenderCount())
end)

afterEach(function()
	CustomReporters.useDefaultReporters()
end)
```

## Custom Metric Logger

Override the default stdout output, e.g. from a `setupFilesAfterEnv` module:

```luau
local HttpService = game:GetService("HttpService")

local benchmarks: { string } = {}

beforeEach(function()
	MetricLogger.useCustomMetricLogger(function(metricName: string, value: any)
		table.insert(benchmarks, HttpService:JSONEncode({
			metric = metricName,
			value = value,
		}))
	end)
end)

afterAll(function()
	print(table.concat(benchmarks, "\n"))
	MetricLogger.useDefaultMetricLogger()
end)
```

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/JestBenchmarkAPI.md
-->
