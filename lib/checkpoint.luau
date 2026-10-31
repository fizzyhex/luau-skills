--!strict
-- Shared body of the tiered-cadence checkpoint hooks (SubagentStop and
-- TaskCompleted): re-lint the bucket's edited files and surface what remains.

local Config = require("./config")
local Io = require("./io")
local Lint = require("./lint")
local State = require("./state")
local Types = require("./types")

type HookOutput = Types.HookOutput

local Checkpoint = {}

function Checkpoint.run(): HookOutput?
	local settings = Config.readSettings()
	if not settings.lint or settings.lintCadence ~= "tiered" then
		return nil
	end

	local input = Io.readHookInput()
	local bucketKey = State.getBucketKey(input)
	local files = Lint.lintableFiles(State.readEditedFiles(bucketKey))
	if #files == 0 then
		return nil
	end

	local log = Io.createLog(settings.debug)
	local errorFiles: { string } = {}
	for _, file in files do
		if Lint.lint(file, settings, log) ~= nil then
			table.insert(errorFiles, file)
		end
	end

	State.markBucketSurfaced(bucketKey)
	Io.flushLog(log, "lint-checkpoint")

	if #errorFiles == 0 then
		return nil
	end

	local reason = Lint.checkpointReason(errorFiles)
	return { reason = reason, systemMessage = reason }
end

return Checkpoint
