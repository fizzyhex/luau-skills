---
name: Timer Mocks
description: |
    Controlling time with fake timers for delay, tick, task.delay, task.wait,
    os.time, DateTime, and engine frame time.
---

# Timer Mocks

## Import

```luau
local JestGlobals = require(Packages.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest
```

## Enable Fake Timers

```luau
jest.useFakeTimers()
```

Replaces these with fakes:

- `delay`, `tick`, `time`
- `task.delay`, `task.cancel`, `task.wait`
- `os.time`, `os.clock`
- `DateTime`

Restore the originals (commonly in `afterEach`):

```luau
jest.useRealTimers()
```

Both return the `jest` object.

**Units:** `task.delay` takes seconds, but every Jest timer API
(`advanceTimersByTime`, `setEngineFrameTime`) takes **milliseconds**.

## Running Timers

### `jest.runAllTimers()`

Execute all pending timers, including ones they schedule, until the queue is
empty:

```luau
jest.useFakeTimers()

it("fires the callback after a delay", function()
	local callback, callbackFn = jest.fn()

	task.delay(1, callbackFn)

	expect(callback).never.toHaveBeenCalled()

	jest.runAllTimers()

	expect(callback).toHaveBeenCalledTimes(1)
end)
```

Pass the forwarding function (second return value of `jest.fn()`) to
`task.delay`, which requires a real function.

### `jest.runOnlyPendingTimers()`

Execute only currently pending timers, not ones they schedule. Use for
recursive timers that would make `runAllTimers` loop forever:

```luau
it("handles a recursive timer", function()
	local callback = jest.fn()

	local function loop()
		task.delay(1, function()
			callback()
			loop() -- schedules another timer
		end)
	end
	loop()

	jest.runOnlyPendingTimers()

	expect(callback).toHaveBeenCalledTimes(1)
end)
```

### `jest.advanceTimersByTime(ms)`

Advance time by `ms` milliseconds, running every timer due in that window
(including ones scheduled during it):

```luau
it("fires after one second", function()
	local callback, callbackFn = jest.fn()

	task.delay(1, callbackFn)

	jest.advanceTimersByTime(999)
	expect(callback).never.toHaveBeenCalled()

	jest.advanceTimersByTime(1)
	expect(callback).toHaveBeenCalledTimes(1)
end)
```

### `jest.advanceTimersToNextTimer(steps?)`

Advance to the next scheduled timer and run it. `steps` runs that many
successive timers.

## Querying and Clearing Timers

```luau
jest.getTimerCount() -- number of fake timers still pending
jest.clearAllTimers() -- drop all pending timers without running them
```

## System Time

```luau
jest.setSystemTime(1000) -- set the fake clock (number or DateTime)
jest.getRealSystemTime() -- real wall-clock time while time is mocked
```

`setSystemTime` changes the current fake time (e.g. what `DateTime.now()`
reports) but does not fire any timers.

## Engine Frame Time (Roblox-Specific)

By default, fake timers run in continuous time. The engine only resumes
timers once per frame; to simulate that, set a frame time in milliseconds:

```luau
it("processes a short delay on the next frame", function()
	local callback, callbackFn = jest.fn()
	jest.setEngineFrameTime(1000 / 60) -- ~16.67 ms per frame

	task.delay(0.01, callbackFn)
	expect(callback).never.toHaveBeenCalled()

	-- Advancing by 0 still steps one frame, like task.wait()
	jest.advanceTimersByTime(0)

	expect(callback).toHaveBeenCalledTimes(1)
end)
```

`jest.getEngineFrameTime()` returns the current setting. `0` (the default)
means continuous time.

<!--
Source references:
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/TimerMocks.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/JestObjectAPI.md
- https://github.com/Roblox/jest-roblox/blob/main/docs/docs/Deviations.md
-->
