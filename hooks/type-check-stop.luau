--!strict
-- Stop: type-checks the bucket's edited files plus their transitive
-- dependents with `luau-lsp analyze` and blocks the stop when errors remain.

local serde = require("@lune/serde")

local Config = require("../lib/config")
local Io = require("../lib/io")
local State = require("../lib/state")
local Typecheck = require("../lib/typecheck")
local Types = require("../lib/types")

Io.runHook("type-check-stop", function(): Types.HookOutput?
	local settings = Config.readSettings()
	if not settings.typecheck then
		return nil
	end

	local log = Io.createLog(settings.debug)
	local input = Io.readHookInput()
	local bucketKey = State.getBucketKey(input)

	local editedFiles = State.readEditedFiles(bucketKey)
	log.debug(`editedFiles={serde.encode("json", editedFiles)}`)
	if #editedFiles == 0 then
		return nil
	end

	local files = Typecheck.withDependents(editedFiles, log)
	log.debug(`type-checkable files: {serde.encode("json", files)}`)
	if #files == 0 then
		return nil
	end

	local output = Typecheck.runAnalyze(files, settings, log)
	local erroring = Typecheck.errorFiles(files, output)

	-- Report edited files by the path they were recorded under, so attempt
	-- counters (keyed by that path) line up.
	local errorFiles: { string } = {}
	local recorded: { [string]: string } = {}
	for _, file in editedFiles do
		recorded[Typecheck.keyOf(file)] = file
	end

	for _, file in erroring do
		table.insert(errorFiles, recorded[Typecheck.keyOf(file)] or file)
	end

	log.debug(`errorFiles: {serde.encode("json", errorFiles)}`)

	local stopAttempts = State.readStopAttempts("typecheck", bucketKey)
	local result = Typecheck.typecheckStopDecision({
		errorFiles = errorFiles,
		lintAttempts = State.readLintAttempts(input.session_id),
		maxLintAttempts = settings.maxLintAttempts,
		stopAttempts = stopAttempts,
	})
	log.debug(`stopDecision: {if result == nil then "undefined" else serde.encode("json", result)}`)

	if result == nil then
		if #log.lines > 0 then
			return { reason = `[type-check-stop debug]\n{table.concat(log.lines, "\n")}` }
		end

		return nil
	end

	if result.resetStopAttempts then
		State.writeStopAttempts("typecheck", bucketKey, 0)
		return nil
	end

	State.writeStopAttempts("typecheck", bucketKey, stopAttempts + 1)

	local hookOutput: Types.HookOutput = { decision = result.decision, reason = result.reason }
	if #log.lines > 0 then
		hookOutput.reason =
			`{result.reason or ""}\n\n[type-check-stop debug]\n{table.concat(log.lines, "\n")}`
	end

	return hookOutput
end)
