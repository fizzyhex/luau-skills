--!strict

local H = require("./helpers")
local Path = require("../lib/path")
local T = require("./harness")

local function guard(directory: string, filePath: string, toolName: string?): H.HookResult
	return H.runHook("lint-guard", {
		session_id = "s1",
		tool_name = toolName or "Edit",
		tool_input = { file_path = filePath },
	}, directory)
end

T.describe("lint-guard hook", function()
	T.it("blocks edits to selene and stylua configs", function()
		H.inSandbox("guard-block", nil, function(directory)
			for _, name in { "selene.toml", "stylua.toml", ".stylua.toml" } do
				local result = guard(directory, Path.join(directory, name))
				T.equal(result.code, 0, name)
				T.equal(result.output.decision, "block", name)
				T.contains(result.output.reason, "Modifying linter config is forbidden", name)
			end
		end)
	end)

	T.it("outputs nothing for normal files and other tools", function()
		H.inSandbox("guard-pass", nil, function(directory)
			T.equal(guard(directory, Path.join(directory, "src/init.luau")).stdout, "")
			T.equal(guard(directory, Path.join(directory, "selene.toml"), "Read").stdout, "")
		end)
	end)

	T.it("checks the basename, not the full path", function()
		H.inSandbox("guard-basename", nil, function(directory)
			T.equal(guard(directory, Path.join(directory, "selene.toml/notes.md")).stdout, "")
		end)
	end)

	T.it("allows a config covered by lint-guard-allow and still blocks others", function()
		H.inSandbox("guard-allow", nil, function(directory)
			H.writeSettings(directory, { "lint-guard-allow: packages/app/selene.toml" })
			T.equal(guard(directory, Path.join(directory, "packages/app/selene.toml")).stdout, "")
			T.equal(
				guard(directory, Path.join(directory, "packages/lib/selene.toml")).output.decision,
				"block"
			)
		end)
	end)

	T.it("blocks edits to the sentinel settings file", function()
		H.inSandbox("guard-settings", nil, function(directory)
			local result =
				guard(directory, Path.join(directory, ".claude/sentinel.local.md"), "Write")
			T.equal(result.output.decision, "block")
		end)
	end)

	T.it("accepts Windows-style backslash paths", function()
		H.inSandbox("guard-backslash", nil, function(directory)
			local native = string.gsub(Path.join(directory, "stylua.toml"), "/", "\\")
			T.equal(guard(directory, native).output.decision, "block")
		end)
	end)
end)

return nil
