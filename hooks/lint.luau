--!strict
-- PostToolUse (Edit|Write): records the edited file and, in strict cadence,
-- formats it with StyLua and surfaces remaining selene errors.

local Config = require("../lib/config")
local Io = require("../lib/io")
local Lint = require("../lib/lint")
local Project = require("../lib/project")
local State = require("../lib/state")
local Types = require("../lib/types")

Io.runHook("lint", function(): Types.HookOutput?
	local settings = Config.readSettings()
	if not settings.lint then
		return nil
	end

	local input = Io.readHookInput()
	if input.tool_name ~= "Write" and input.tool_name ~= "Edit" then
		return nil
	end

	local filePath = State.narrowToolInput(input)
	if not Project.isInProject(filePath) then
		return nil
	end

	local output: Types.PostToolUseOutput? = nil
	if settings.lintCadence == "strict" then
		local log = Io.createLog(settings.debug)
		output = Lint.lint(filePath, settings, log)
		Io.flushLog(log, "lint")

		if output ~= nil then
			local count = State.incrementLintAttempt(input.session_id, filePath)
			local specific = output.hookSpecificOutput
			if count >= settings.maxLintAttempts and specific ~= nil then
				specific.additionalContext =
					`<workspace_diagnostics source="lint-loop">\n{filePath} has surfaced lint issues {count} times. The fix loop appears stuck — surface the remaining diagnostics to the user instead of editing further?\n</workspace_diagnostics>\n{specific.additionalContext}`
			end
		else
			State.clearLintAttempt(input.session_id, filePath)
		end
	end

	State.writeEditedFile(State.getBucketKey(input), filePath)
	return output
end)
