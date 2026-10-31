--!strict
-- Stop: re-lints the bucket's edited files and blocks the stop (once) when
-- errors remain. StyLua/selene are per-file tools, so unlike the TypeScript
-- original no transitive dependents are re-linted.

local serde = require("@lune/serde")

local Config = require("../lib/config")
local Io = require("../lib/io")
local Lint = require("../lib/lint")
local State = require("../lib/state")
local Types = require("../lib/types")

Io.runHook("lint-stop", function(): Types.HookOutput?
	local settings = Config.readSettings()
	if not settings.lint then
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

	local files = Lint.lintableFiles(editedFiles)
	log.debug(`lintable files: {serde.encode("json", files)}`)
	if #files == 0 then
		return nil
	end

	local errorFiles: { string } = {}
	for _, file in files do
		log.debug(`linting: {file}`)
		local result = Lint.lint(file, settings, log)
		log.debug(`result: {if result == nil then "ok" else "errors"}`)
		if result ~= nil then
			table.insert(errorFiles, file)
		end
	end

	log.debug(`errorFiles: {serde.encode("json", errorFiles)}`)

	local stopAttempts = State.readStopAttempts("lint", bucketKey)
	local result = Lint.stopDecision({
		errorFiles = errorFiles,
		lintAttempts = State.readLintAttempts(input.session_id),
		maxLintAttempts = settings.maxLintAttempts,
		stopAttempts = stopAttempts,
	})
	log.debug(`stopDecision: {if result == nil then "undefined" else serde.encode("json", result)}`)

	if result == nil then
		if #log.lines > 0 then
			return { reason = `[lint-stop debug]\n{table.concat(log.lines, "\n")}` }
		end

		return nil
	end

	if result.resetStopAttempts then
		State.writeStopAttempts("lint", bucketKey, 0)
		return nil
	end

	State.writeStopAttempts("lint", bucketKey, stopAttempts + 1)

	local output: Types.HookOutput = { decision = result.decision, reason = result.reason }
	if #log.lines > 0 then
		output.reason =
			`{result.reason or ""}\n\n[lint-stop debug]\n{table.concat(log.lines, "\n")}`
	end

	State.markBucketSurfaced(bucketKey)
	return output
end)
