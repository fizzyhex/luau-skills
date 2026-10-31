--!strict

local H = require("./helpers")
local Path = require("../lib/path")
local T = require("./harness")

local BAD = "--!strict\nlocal   y = undefinedThing\nreturn   y\n"
local CLEAN = "--!strict\nlocal x = 1\nreturn x\n"

local function edit(directory: string, sessionId: string, filePath: string): H.HookResult
	return H.runHook("lint", {
		session_id = sessionId,
		tool_name = "Edit",
		tool_input = { file_path = filePath },
	}, directory)
end

local function editedIn(directory: string, bucketKey: string): { string }
	local state = H.readState(directory, "edited-files.json")
	if state == nil or state[bucketKey] == nil then
		return {}
	end

	return state[bucketKey].edited or {}
end

T.describe("lint hook (PostToolUse) cadence", function()
	for _, cadence in { "tiered", "stop-only" } do
		T.it(`records the file in {cadence} mode without linting or surfacing`, function()
			H.inSandbox(`lint-{cadence}`, { tools = true, configs = true }, function(directory)
				H.writeSettings(directory, { `lint-cadence: {cadence}` })
				H.write(directory, "src/bad.luau", BAD)
				local file = Path.join(directory, "src/bad.luau")

				local result = edit(directory, "s-" .. cadence, file)
				T.equal(result.code, 0, result.stderr)
				T.equal(result.stdout, "")
				T.equal(H.read(directory, "src/bad.luau"), BAD, "file must not be formatted")
				T.contains(editedIn(directory, `s-{cadence}:main`), file)
			end)
		end)
	end

	T.it("records the file, formats it and surfaces errors in strict mode", function()
		H.inSandbox("lint-strict", { tools = true, configs = true }, function(directory)
			H.write(directory, "src/bad.luau", BAD)
			local file = Path.join(directory, "src/bad.luau")

			local result = edit(directory, "s-strict", file)
			T.equal(result.code, 0, result.stderr)
			local specific = result.output.hookSpecificOutput
			T.equal(specific.hookEventName, "PostToolUse")
			T.contains(specific.additionalContext, "error[undefined_variable]")
			T.contains(specific.additionalContext, 'source="lint-loop"')
			T.equal(
				H.read(directory, "src/bad.luau"),
				"--!strict\nlocal y = undefinedThing\nreturn y\n"
			)
			T.contains(editedIn(directory, "s-strict:main"), file)
			T.equal(H.readState(directory, "lint-attempts.json")["s-strict"][file], 1)
		end)
	end)

	T.it("clears the attempt counter once the file lints clean", function()
		H.inSandbox("lint-strict-clear", { tools = true, configs = true }, function(directory)
			H.write(directory, "src/a.luau", BAD)
			local file = Path.join(directory, "src/a.luau")
			edit(directory, "s1", file)
			H.write(directory, "src/a.luau", CLEAN)
			T.equal(edit(directory, "s1", file).stdout, "")
			T.isNil(H.readState(directory, "lint-attempts.json"))
		end)
	end)

	T.it("ignores files outside the project", function()
		H.inSandbox("lint-outside", { tools = true, configs = true }, function(directory)
			local result = edit(directory, "s1", "/somewhere/else/x.luau")
			T.equal(result.stdout, "")
			T.isNil(H.readState(directory, "edited-files.json"))
		end)
	end)

	T.it("does nothing when lint is disabled", function()
		H.inSandbox("lint-disabled", { tools = true, configs = true }, function(directory)
			H.writeSettings(directory, { "lint: false" })
			H.write(directory, "src/bad.luau", BAD)
			T.equal(edit(directory, "s1", Path.join(directory, "src/bad.luau")).stdout, "")
			T.isNil(H.readState(directory, "edited-files.json"))
		end)
	end)

	T.it("never blocks when the tools are not resolvable", function()
		H.inSandbox("lint-notools", { configs = true }, function(directory)
			H.write(directory, "src/bad.luau", BAD)
			local result = edit(directory, "s1", Path.join(directory, "src/bad.luau"))
			T.equal(result.code, 0, result.stderr)
			T.equal(result.stdout, "")
		end)
	end)
end)

T.describe("lint-stop hook cadence", function()
	local function stop(directory: string): H.HookResult
		return H.runHook("lint-stop", { session_id = "s1" }, directory)
	end

	T.it("exits cleanly when the bucket is empty regardless of cadence", function()
		for _, cadence in { "strict", "tiered", "stop-only" } do
			H.inSandbox(`stop-empty-{cadence}`, nil, function(directory)
				H.writeSettings(directory, { `lint-cadence: {cadence}` })
				local result = stop(directory)
				T.equal(result.code, 0, cadence)
				T.equal(result.stdout, "", cadence)
			end)
		end
	end)

	T.it("short-circuits in tiered mode when the bucket was emptied by a surface", function()
		H.inSandbox("stop-surfaced", { tools = true, configs = true }, function(directory)
			H.writeSettings(directory, { "lint-cadence: tiered" })
			H.write(directory, "src/bad.luau", BAD)
			H.writeState(
				directory,
				"edited-files.json",
				{ ["s1:main"] = { edited = {}, lastSurfacedAt = 1 } }
			)
			T.equal(stop(directory).stdout, "")
		end)
	end)

	for _, cadence in { "tiered", "stop-only", "strict" } do
		T.it(
			`blocks once on unsurfaced edits in {cadence} mode, then lets the stop through`,
			function()
				H.inSandbox(
					`stop-block-{cadence}`,
					{ tools = true, configs = true },
					function(directory)
						H.writeSettings(directory, { `lint-cadence: {cadence}` })
						H.write(directory, "src/bad.luau", BAD)
						local file = Path.join(directory, "src/bad.luau")
						H.writeState(
							directory,
							"edited-files.json",
							{ ["s1:main"] = { edited = { file }, lastSurfacedAt = 1 } }
						)

						local first = stop(directory)
						T.equal(first.code, 0, first.stderr)
						T.equal(first.output.decision, "block")
						T.contains(first.output.reason, "Lint issues remain in:")
						T.equal(H.readState(directory, "stop-attempts.json")["s1:main"], 1)
						T.equal(editedIn(directory, "s1:main"), {}, "bucket is surfaced")

						-- A new edit after the block: the stop is no longer blocked.
						H.writeState(
							directory,
							"edited-files.json",
							{ ["s1:main"] = { edited = { file } } }
						)
						local second = stop(directory)
						T.isNil(second.output.decision)
						T.contains(second.output.reason, "Unresolved lint issues")
					end
				)
			end
		)
	end

	T.it("resets stop attempts once the files are clean", function()
		H.inSandbox("stop-reset", { tools = true, configs = true }, function(directory)
			H.write(directory, "src/ok.luau", CLEAN)
			local file = Path.join(directory, "src/ok.luau")
			H.writeState(directory, "edited-files.json", { ["s1:main"] = { edited = { file } } })
			H.writeState(directory, "stop-attempts.json", { ["s1:main"] = 2 })
			T.equal(stop(directory).stdout, "")
			T.equal(H.readState(directory, "stop-attempts.json")["s1:main"], 0)
		end)
	end)

	T.it("attaches a debug trace when debug is enabled", function()
		H.inSandbox("stop-debug", { tools = true, configs = true }, function(directory)
			H.writeSettings(directory, { "debug: true" })
			H.write(directory, "src/ok.luau", CLEAN)
			H.writeState(
				directory,
				"edited-files.json",
				{ ["s1:main"] = { edited = { Path.join(directory, "src/ok.luau") } } }
			)
			local result = stop(directory)
			T.contains(result.output.reason, "[lint-stop debug]")
			T.contains(result.output.reason, "stopDecision: undefined")
		end)
	end)
end)

T.describe("type-check hooks", function()
	T.it("surfaces type errors on PostToolUse and records the file", function()
		H.inSandbox("tc-hook", { tools = true }, function(directory)
			H.write(directory, "src/bad.luau", '--!strict\nlocal n: number = "x"\nreturn n\n')
			local file = Path.join(directory, "src/bad.luau")
			local result = H.runHook("type-check", {
				session_id = "s1",
				tool_name = "Write",
				tool_input = { file_path = file },
			}, directory)
			T.equal(result.code, 0, result.stderr)
			T.contains(result.output.hookSpecificOutput.additionalContext, "CRITICAL:")
			T.contains(result.output.systemMessage, "luau-lsp found 1 type error in edited file")
			T.contains(editedIn(directory, "s1:main"), file)
		end)
	end)

	T.it("blocks the stop on type errors in edited files and their dependents", function()
		H.inSandbox("tc-stop", { tools = true }, function(directory)
			H.writeSettings(directory, { "max-lint-attempts: 5" })
			H.write(
				directory,
				"src/lib.luau",
				"--!strict\nreturn { go = function(): number return 1 end }\n"
			)
			H.write(
				directory,
				"src/user.luau",
				'--!strict\nlocal s: string = require("./lib").go()\nreturn s\n'
			)
			H.writeState(
				directory,
				"edited-files.json",
				{ ["s1:main"] = { edited = { Path.join(directory, "src/lib.luau") } } }
			)

			local result = H.runHook("type-check-stop", { session_id = "s1" }, directory)
			T.equal(result.code, 0, result.stderr)
			T.equal(result.output.decision, "block")
			T.contains(result.output.reason, "user.luau")
			T.equal(H.readState(directory, "typecheck-stop-attempts.json")["s1:main"], 1)
		end)
	end)

	T.it("does nothing when typecheck is disabled", function()
		H.inSandbox("tc-disabled", { tools = true }, function(directory)
			H.writeSettings(directory, { "typecheck: false" })
			H.write(directory, "src/bad.luau", '--!strict\nlocal n: number = "x"\nreturn n\n')
			local result = H.runHook("type-check", {
				session_id = "s1",
				tool_name = "Edit",
				tool_input = { file_path = Path.join(directory, "src/bad.luau") },
			}, directory)
			T.equal(result.stdout, "")
		end)
	end)
end)

return nil
