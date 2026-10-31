--!strict
-- PostToolBatch (tiered/stop-only cadence): silently formats every file
-- edited in the bucket with StyLua. Nothing is surfaced.

local Config = require("../lib/config")
local Io = require("../lib/io")
local Lint = require("../lib/lint")
local State = require("../lib/state")
local Types = require("../lib/types")

Io.runHook("lint-batch", function(): Types.HookOutput?
	local settings = Config.readSettings()
	if not settings.lint or settings.lintCadence == "strict" or not settings.lintAutoFixOnBatch then
		return nil
	end

	local input = Io.readHookInput()
	local files = Lint.lintableFiles(State.readEditedFiles(State.getBucketKey(input)))
	if #files == 0 then
		return nil
	end

	local log = Io.createLog(settings.debug)
	Lint.autoFix(files, settings, log)
	Io.flushLog(log, "lint-batch")
	return nil
end)
