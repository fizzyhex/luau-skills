--!strict

local H = require("./helpers")
local Path = require("../lib/path")
local T = require("./harness")

type Scenario = {
	cadence: string,
	editedFiles: { string }?,
	lint: boolean?,
	lintAutoFixOnBatch: boolean?,
	tools: boolean?,
}

local BAD = "--!strict\nlocal   y = undefinedThing\nreturn   y\n"
local BASE_INPUT = { session_id = "session1", cwd = ".", transcript_path = "/tmp/t.json" }

local function setup(directory: string, scenario: Scenario)
	H.writeSettings(directory, {
		`lint: {tostring(if scenario.lint == nil then true else scenario.lint)}`,
		`lint-cadence: {scenario.cadence}`,
		`lint-auto-fix-on-batch: {tostring(
			if scenario.lintAutoFixOnBatch == nil then true else scenario.lintAutoFixOnBatch
		)}`,
	})
	H.write(directory, "src/bad.luau", BAD)
	if scenario.editedFiles ~= nil then
		local edited: { string } = {}
		for _, file in scenario.editedFiles do
			table.insert(edited, Path.join(directory, file))
		end

		H.writeState(directory, "edited-files.json", { ["session1:main"] = { edited = edited } })
	end
end

local function run(hook: string, scenario: Scenario, inspect: (H.HookResult, string) -> ())
	H.inSandbox(`cadence-{hook}`, { tools = scenario.tools, configs = true }, function(directory)
		setup(directory, scenario)
		inspect(H.runHook(hook, BASE_INPUT, directory), directory)
	end)
end

local function bucket(directory: string): any
	local state = H.readState(directory, "edited-files.json")
	return if state ~= nil then state["session1:main"] else nil
end

T.describe("lint-batch hook", function()
	T.it("short-circuits in strict cadence", function()
		run(
			"lint-batch",
			{ cadence = "strict", editedFiles = { "src/bad.luau" }, tools = true },
			function(result, directory)
				T.equal(result.code, 0)
				T.equal(result.stdout, "")
				T.equal(H.read(directory, "src/bad.luau"), BAD)
			end
		)
	end)

	T.it("short-circuits when lint-auto-fix-on-batch is false", function()
		run("lint-batch", {
			cadence = "tiered",
			editedFiles = { "src/bad.luau" },
			lintAutoFixOnBatch = false,
			tools = true,
		}, function(result, directory)
			T.equal(result.stdout, "")
			T.equal(H.read(directory, "src/bad.luau"), BAD)
		end)
	end)

	for _, cadence in { "tiered", "stop-only" } do
		T.it(`formats silently in {cadence} cadence`, function()
			run(
				"lint-batch",
				{ cadence = cadence, editedFiles = { "src/bad.luau" }, tools = true },
				function(result, directory)
					T.equal(result.code, 0, result.stderr)
					T.equal(result.stdout, "")
					T.equal(
						H.read(directory, "src/bad.luau"),
						"--!strict\nlocal y = undefinedThing\nreturn y\n"
					)
					T.equal(#bucket(directory).edited, 1, "batch does not surface the bucket")
				end
			)
		end)
	end

	T.it("exits cleanly when the bucket is empty", function()
		run("lint-batch", { cadence = "tiered" }, function(result)
			T.equal(result.code, 0)
			T.equal(result.stdout, "")
		end)
	end)
end)

for _, hook in { "lint-subagent-stop", "lint-task-completed" } do
	T.describe(`{hook} hook`, function()
		for _, cadence in { "strict", "stop-only" } do
			T.it(`short-circuits in {cadence} cadence`, function()
				run(
					hook,
					{ cadence = cadence, editedFiles = { "src/bad.luau" }, tools = true },
					function(result, directory)
						T.equal(result.stdout, "")
						T.equal(#bucket(directory).edited, 1)
					end
				)
			end)
		end

		T.it("exits cleanly with an empty bucket in tiered cadence", function()
			run(hook, { cadence = "tiered" }, function(result)
				T.equal(result.code, 0)
				T.equal(result.stdout, "")
			end)
		end)

		T.it("does not surface when the bucket has only non-lintable entries", function()
			run(
				hook,
				{ cadence = "tiered", editedFiles = { "README.md", "missing.luau" } },
				function(result, directory)
					T.equal(result.stdout, "")
					T.equal(#bucket(directory).edited, 2, "bucket untouched")
				end
			)
		end)

		T.it("surfaces remaining errors in tiered cadence and empties the bucket", function()
			run(
				hook,
				{ cadence = "tiered", editedFiles = { "src/bad.luau" }, tools = true },
				function(result, directory)
					T.equal(result.code, 0, result.stderr)
					T.contains(result.output.reason, "Lint issues remain in:")
					T.equal(result.output.systemMessage, result.output.reason)
					T.equal(bucket(directory).edited, {})
					T.truthy(bucket(directory).lastSurfacedAt)
				end
			)
		end)

		T.it("short-circuits when lint is disabled regardless of cadence", function()
			run(
				hook,
				{ cadence = "tiered", editedFiles = { "src/bad.luau" }, lint = false, tools = true },
				function(result)
					T.equal(result.stdout, "")
				end
			)
		end)
	end)
end

T.describe("clear-lint-state hook", function()
	T.it("registers the session and prunes dead sessions' state", function()
		H.inSandbox("clear-state", nil, function(directory)
			H.write(directory, ".claude/state/sessions/dead", "999999")
			H.writeState(directory, "edited-files.json", {
				["dead:main"] = { edited = { "a.luau" } },
				["session1:main"] = { edited = { "b.luau" } },
			})
			H.writeState(directory, "lint-attempts.json", { dead = { ["a.luau"] = 1 } })

			local result = H.runHook("clear-lint-state", BASE_INPUT, directory)
			T.equal(result.code, 0, result.stderr)
			T.equal(result.stdout, "")
			T.truthy(H.read(directory, ".claude/state/sessions/session1"))
			T.isNil(H.read(directory, ".claude/state/sessions/dead"))
			T.isNil(H.readState(directory, "lint-attempts.json"))
			local edited = H.readState(directory, "edited-files.json")
			T.isNil(edited["dead:main"])
		end)
	end)
end)

return nil
