--!strict
-- PreToolUse (Edit|Write): blocks edits to linter/formatter configs and the
-- sentinel settings file unless exempted by `lint-guard-allow`.

local Config = require("../lib/config")
local Io = require("../lib/io")
local Lint = require("../lib/lint")
local State = require("../lib/state")
local Types = require("../lib/types")

Io.runHook("lint-guard", function(): Types.HookOutput?
	local input = Io.readHookInput()
	if input.tool_name ~= "Write" and input.tool_name ~= "Edit" then
		return nil
	end

	local filePath = State.narrowToolInput(input)
	if
		Lint.isProtectedFile(filePath)
		and not Lint.isGuardAllowed(filePath, Config.readSettings().lintGuardAllow)
	then
		return {
			decision = "block",
			reason = "Modifying linter config is forbidden. Report to user if a rule blocks your task.",
		}
	end

	return nil
end)
