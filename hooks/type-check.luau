--!strict
-- PostToolUse (Edit|Write): type-checks the edited file and its dependents
-- with `luau-lsp analyze` and surfaces type errors.

local Config = require("../lib/config")
local Io = require("../lib/io")
local Project = require("../lib/project")
local State = require("../lib/state")
local Typecheck = require("../lib/typecheck")
local Types = require("../lib/types")

Io.runHook("type-check", function(): Types.HookOutput?
	local settings = Config.readSettings()
	if not settings.typecheck then
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

	local log = Io.createLog(settings.debug)
	local output = Typecheck.typeCheck(filePath, settings, log)
	Io.flushLog(log, "type-check")

	if output ~= nil then
		local count = State.incrementLintAttempt(input.session_id, filePath)
		local specific = output.hookSpecificOutput
		if count >= settings.maxLintAttempts and specific ~= nil then
			specific.additionalContext =
				`CRITICAL: {filePath} failed type-check {count} times. If you're stuck in a loop, STOP editing this file and report type errors to user for assistance.\n{specific.additionalContext}`
		end
	else
		State.clearLintAttempt(input.session_id, filePath)
	end

	State.writeEditedFile(State.getBucketKey(input), filePath)
	return output
end)
