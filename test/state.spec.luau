--!strict

local H = require("./helpers")
local Path = require("../lib/path")
local State = require("../lib/state")
local T = require("./harness")

-- PID 4 is the System process on Windows; PID 1 is init elsewhere.
local ALIVE_PID = if Path.isWindows then 4 else 1
local DEAD_PID = 999999

T.describe("State.getBucketKey", function()
	T.it("uses :main when agent_id is absent", function()
		T.equal(State.getBucketKey({ session_id = "s1" } :: any), "s1:main")
	end)

	T.it("uses the agent_id inside a subagent", function()
		T.equal(State.getBucketKey({ session_id = "s1", agent_id = "a7" } :: any), "s1:a7")
	end)
end)

T.describe("State.narrowToolInput", function()
	T.it("returns file_path for Edit and Write input", function()
		for _, tool in { "Edit", "Write" } do
			local input =
				{ session_id = "s", tool_name = tool, tool_input = { file_path = "/x.luau" } }
			T.equal(State.narrowToolInput(input :: any), "/x.luau")
		end
	end)

	T.it("throws on malformed input", function()
		T.throws(function()
			State.narrowToolInput({ session_id = "s", tool_name = "Edit", tool_input = "x" } :: any)
		end, "to be an object")
		T.throws(function()
			State.narrowToolInput({ session_id = "s", tool_name = "Edit", tool_input = {} } :: any)
		end, "non-empty string")
		T.throws(function()
			State.narrowToolInput(
				{ session_id = "s", tool_name = "Edit", tool_input = { file_path = "" } } :: any
			)
		end, "non-empty string")
		T.throws(function()
			State.narrowToolInput(
				{ session_id = "s", tool_name = "Edit", tool_input = { file_path = 5 } } :: any
			)
		end, "non-empty string")
	end)
end)

T.describe("State edited files", function()
	T.it("returns empty for a missing file, unknown bucket or corrupt JSON", function()
		H.inSandbox("state-edited-empty", nil, function(directory)
			T.equal(State.readEditedFiles("s:main"), {})
			State.writeEditedFile("s:main", "a.luau")
			T.equal(State.readEditedFiles("other:main"), {})
			H.write(directory, ".claude/state/edited-files.json", "{not json")
			T.equal(State.readEditedFiles("s:main"), {})
		end)
	end)

	T.it("appends, deduplicates and keeps buckets isolated", function()
		H.inSandbox("state-edited", nil, function()
			State.writeEditedFile("s:main", "a.luau")
			State.writeEditedFile("s:main", "b.luau")
			State.writeEditedFile("s:main", "a.luau")
			State.writeEditedFile("s:agent", "c.luau")
			T.equal(State.readEditedFiles("s:main"), { "a.luau", "b.luau" })
			T.equal(State.readEditedFiles("s:agent"), { "c.luau" })
		end)
	end)

	T.it("marks a bucket surfaced and preserves the timestamp across writes", function()
		H.inSandbox("state-surfaced", nil, function()
			T.isNil(State.getLastSurfacedAt("s:main"))
			State.writeEditedFile("s:main", "a.luau")
			State.markBucketSurfaced("s:main", 1234)
			T.equal(State.readEditedFiles("s:main"), {})
			T.equal(State.getLastSurfacedAt("s:main"), 1234)
			State.writeEditedFile("s:main", "b.luau")
			T.equal(State.getLastSurfacedAt("s:main"), 1234)
		end)
	end)

	T.it("clears a bucket and deletes the file when it was the last", function()
		H.inSandbox("state-clear", nil, function(directory)
			State.clearEditedFiles("s:main")
			State.writeEditedFile("s:main", "a.luau")
			State.writeEditedFile("s:agent", "b.luau")
			State.clearEditedFiles("s:main")
			T.equal(State.readEditedFiles("s:agent"), { "b.luau" })
			State.clearEditedFiles("s:agent")
			T.isNil(H.read(directory, ".claude/state/edited-files.json"))
		end)
	end)

	T.it("deletes a corrupt file on clear", function()
		H.inSandbox("state-clear-corrupt", nil, function(directory)
			H.write(directory, ".claude/state/edited-files.json", "{oops")
			State.clearEditedFiles("s:main")
			T.isNil(H.read(directory, ".claude/state/edited-files.json"))
		end)
	end)
end)

T.describe("State lint attempts", function()
	T.it("increments per session and file", function()
		H.inSandbox("state-attempts", nil, function()
			T.equal(State.readLintAttempts("s1"), {})
			T.equal(State.incrementLintAttempt("s1", "a.luau"), 1)
			T.equal(State.incrementLintAttempt("s1", "a.luau"), 2)
			T.equal(State.incrementLintAttempt("s2", "a.luau"), 1)
			T.equal(State.readLintAttempts("s1"), { ["a.luau"] = 2 })
		end)
	end)

	T.it("preserves sibling sessions when writing", function()
		H.inSandbox("state-attempts-write", nil, function()
			State.writeLintAttempts("s1", { ["a.luau"] = 1 })
			State.writeLintAttempts("s2", { ["b.luau"] = 2 })
			T.equal(State.readLintAttempts("s1"), { ["a.luau"] = 1 })
		end)
	end)

	T.it("clears entries, sessions and finally the file", function()
		H.inSandbox("state-attempts-clear", nil, function(directory)
			State.clearLintAttempt("s1", "a.luau")
			State.incrementLintAttempt("s1", "a.luau")
			State.incrementLintAttempt("s1", "b.luau")
			State.clearLintAttempt("s1", "a.luau")
			T.equal(State.readLintAttempts("s1"), { ["b.luau"] = 1 })
			State.clearLintAttempt("s1", "b.luau")
			T.isNil(H.read(directory, ".claude/state/lint-attempts.json"))
		end)
	end)

	T.it("returns empty on corrupt JSON", function()
		H.inSandbox("state-attempts-corrupt", nil, function(directory)
			H.write(directory, ".claude/state/lint-attempts.json", "[[[")
			T.equal(State.readLintAttempts("s1"), {})
		end)
	end)
end)

T.describe("State stop attempts", function()
	T.it("tracks lint and typecheck counters separately per bucket", function()
		H.inSandbox("state-stop", nil, function()
			T.equal(State.readStopAttempts("lint", "s:main"), 0)
			State.writeStopAttempts("lint", "s:main", 2)
			State.writeStopAttempts("lint", "s:agent", 1)
			State.writeStopAttempts("typecheck", "s:main", 3)
			T.equal(State.readStopAttempts("lint", "s:main"), 2)
			T.equal(State.readStopAttempts("lint", "s:agent"), 1)
			T.equal(State.readStopAttempts("typecheck", "s:main"), 3)
		end)
	end)
end)

T.describe("State sessions", function()
	T.it("reports live and dead PIDs", function()
		T.truthy(State.isPidAlive(ALIVE_PID))
		T.falsy(State.isPidAlive(DEAD_PID))
		T.falsy(State.isPidAlive(-1))
	end)

	T.it("registers sessions and drops dead or malformed ones", function()
		H.inSandbox("state-sessions", nil, function(directory)
			T.equal(State.loadLiveSessions(), {})
			State.registerSession("alive", tostring(ALIVE_PID))
			State.registerSession("dead", tostring(DEAD_PID))
			State.registerSession("unknown", nil)
			H.write(directory, ".claude/state/sessions/garbage", "not-a-pid")

			T.equal(State.loadLiveSessions(), { alive = true, unknown = true })
			T.isNil(H.read(directory, ".claude/state/sessions/dead"))
			T.isNil(H.read(directory, ".claude/state/sessions/garbage"))
			T.equal(H.read(directory, ".claude/state/sessions/unknown"), "unknown")
		end)
	end)

	T.it("prunes every state file by session id", function()
		H.inSandbox("state-prune", nil, function(directory)
			H.writeState(directory, "lint-attempts.json", { live = { a = 1 }, dead = { b = 1 } })
			H.writeState(directory, "stop-attempts.json", { ["live:main"] = 1, ["dead:main"] = 1 })
			H.writeState(directory, "typecheck-stop-attempts.json", { ["dead:main"] = 2 })
			H.writeState(directory, "edited-files.json", {
				["live:main"] = { edited = { "a" } },
				["live-longer:main"] = { edited = { "b" } },
			})

			State.pruneDeadSessions({ live = true })

			T.equal(H.readState(directory, "lint-attempts.json"), { live = { a = 1 } })
			T.equal(H.readState(directory, "stop-attempts.json"), { ["live:main"] = 1 })
			T.isNil(H.read(directory, ".claude/state/typecheck-stop-attempts.json"))
			-- "live" must not keep "live-longer" alive via a prefix match.
			T.equal(
				H.readState(directory, "edited-files.json"),
				{ ["live:main"] = { edited = { "a" } } }
			)
		end)
	end)

	T.it("leaves files untouched when every session is live and unlinks corrupt ones", function()
		H.inSandbox("state-prune-noop", nil, function(directory)
			H.write(directory, ".claude/state/stop-attempts.json", '{"live:main":1}')
			H.write(directory, ".claude/state/lint-attempts.json", "{corrupt")
			State.pruneDeadSessions({ live = true })
			T.equal(H.read(directory, ".claude/state/stop-attempts.json"), '{"live:main":1}')
			T.isNil(H.read(directory, ".claude/state/lint-attempts.json"))
		end)
	end)
end)

return nil
