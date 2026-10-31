--!strict
-- Type checking with `luau-lsp analyze`. The edited file is analysed together
-- with its transitive dependents (from the require graph) so breakages in
-- requiring modules surface too.

local Config = require("./config")
local Graph = require("./graph")
local Io = require("./io")
local LuauLsp = require("./luaulsp")
local Path = require("./path")
local Project = require("./project")
local Tools = require("./tools")
local Types = require("./types")

type Settings = Config.Settings
type Log = Io.Log
type PostToolUseOutput = Types.PostToolUseOutput
type StopDecisionInput = Types.StopDecisionInput
type StopDecisionResult = Types.StopDecisionResult

export type Diagnostic = {
	file: string,
	line: string,
}

export type TypeCheckOutputOptions = {
	dependencyErrors: { string },
	fileErrors: { string },
	totalDependencyErrors: number,
	totalFileErrors: number,
}

local Typecheck = {}

Typecheck.EXTENSIONS = { ".luau", ".lua" }
Typecheck.MAX_ERRORS = 5
Typecheck.DEFAULT_MAX_STOP_ATTEMPTS = 3

local NO_LOG = Io.createLog(false)

function Typecheck.isTypeCheckable(filePath: string): boolean
	local extension = string.lower(Path.extension(filePath))
	return table.find(Typecheck.EXTENSIONS, extension) ~= nil
end

--- Path to give luau-lsp (which runs in the project root).
local function analyzePath(filePath: string): string
	local resolved = Project.resolve(filePath)
	if Project.isInProject(resolved) and Path.isWithin(resolved, Project.root()) then
		return Path.relative(Project.root(), resolved)
	end

	return resolved
end

--- Arguments for `luau-lsp`. `typecheck-args` replaces the automatic project
--- flags. Returns nil when the check must be skipped.
function Typecheck.analyzeArgs(files: { string }, settings: Settings, log: Log?): { string }?
	local args: { string } = { "analyze" }
	if #settings.typecheckArgs > 0 then
		for _, arg in settings.typecheckArgs do
			table.insert(args, arg)
		end
	else
		local projectArgs = LuauLsp.projectArgs(true, log)
		if projectArgs == nil then
			return nil
		end

		for _, arg in projectArgs do
			table.insert(args, arg)
		end
	end

	for _, file in files do
		table.insert(args, analyzePath(file))
	end

	return args
end

--- Runs `luau-lsp analyze`. Returns its combined output when it reported
--- problems, or nil when clean or skipped.
function Typecheck.runAnalyze(files: { string }, settings: Settings, log: Log?): string?
	local logger = log or NO_LOG
	if #files == 0 then
		return nil
	end

	if not LuauLsp.isAvailable() then
		logger.debug("luau-lsp: not resolvable, skipped")
		return nil
	end

	local args = Typecheck.analyzeArgs(files, settings, logger)
	if args == nil then
		return nil
	end

	logger.debug(`luau-lsp {table.concat(args, " ")}`)
	local result = Tools.exec(LuauLsp.PROGRAM, args, Project.root())
	if result == nil or result.ok then
		return nil
	end

	return result.stdout .. "\n" .. result.stderr
end

--- Parses `path(line,col): KindError: message` lines; lint warnings and
--- informational output are ignored.
function Typecheck.parseDiagnostics(output: string): { Diagnostic }
	local diagnostics: { Diagnostic } = {}
	for line in string.gmatch((string.gsub(output, "\r\n", "\n")), "[^\n]+") do
		local file, kind = string.match(line, "^(.-)%(%d+,%d+%): (%w+): ")
		if file ~= nil and kind ~= nil and string.sub(kind, -5) == "Error" then
			table.insert(diagnostics, { file = Project.resolve(file), line = line })
		end
	end

	return diagnostics
end

function Typecheck.partitionErrors(
	diagnostics: { Diagnostic },
	filePath: string
): { dependencyErrors: { string }, fileErrors: { string } }
	local target = Project.resolve(filePath)
	local fileErrors: { string } = {}
	local dependencyErrors: { string } = {}
	for _, diagnostic in diagnostics do
		if Path.equals(diagnostic.file, target) then
			table.insert(fileErrors, diagnostic.line)
		else
			table.insert(dependencyErrors, diagnostic.line)
		end
	end

	return { dependencyErrors = dependencyErrors, fileErrors = fileErrors }
end

function Typecheck.buildTypeCheckOutput(options: TypeCheckOutputOptions): PostToolUseOutput
	local sections: { string } = {}
	if options.totalFileErrors > 0 then
		local suffix = if options.totalFileErrors == 1 then "error" else "errors"
		table.insert(
			sections,
			`luau-lsp found {options.totalFileErrors} type {suffix} in edited file:\n{table.concat(
				options.fileErrors,
				"\n"
			)}`
		)
	end

	if options.totalDependencyErrors > 0 then
		local suffix = if options.totalDependencyErrors == 1 then "error" else "errors"
		table.insert(
			sections,
			`luau-lsp found {options.totalDependencyErrors} type {suffix} in other files:\n{table.concat(
				options.dependencyErrors,
				"\n"
			)}`
		)
	end

	local truncated = #options.fileErrors < options.totalFileErrors
		or #options.dependencyErrors < options.totalDependencyErrors
	local body = table.concat(sections, "\n\n")

	return {
		hookSpecificOutput = {
			hookEventName = "PostToolUse",
			additionalContext = body
				.. (if truncated then "\n(run typecheck to view more)" else ""),
		},
		systemMessage = body .. (if truncated then "\n..." else ""),
	}
end

local function take(list: { string }, count: number): { string }
	return { table.unpack(list, 1, math.min(#list, count)) }
end

--- `files` plus their transitive dependents that still exist on disk.
function Typecheck.withDependents(files: { string }, log: Log?): { string }
	local result: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(file: string)
		local resolved = Project.resolve(file)
		local key = Path.key(resolved)
		if not seen[key] and Typecheck.isTypeCheckable(resolved) and Project.isFile(resolved) then
			seen[key] = true
			table.insert(result, resolved)
		end
	end

	for _, file in files do
		add(file)
	end

	if #result > 0 then
		for _, dependent in Graph.getTransitiveDependents(result, log) do
			add(dependent)
		end
	end

	return result
end

--- Type-checks one edited file (plus dependents). Returns hook output when
--- luau-lsp reports type errors.
function Typecheck.typeCheck(filePath: string, settings: Settings, log: Log?): PostToolUseOutput?
	if not Typecheck.isTypeCheckable(filePath) then
		return nil
	end

	local files = Typecheck.withDependents({ filePath }, log)
	local output = Typecheck.runAnalyze(files, settings, log)
	if output == nil then
		return nil
	end

	local diagnostics = Typecheck.parseDiagnostics(output)
	if #diagnostics == 0 then
		return nil
	end

	local partition = Typecheck.partitionErrors(diagnostics, filePath)
	return Typecheck.buildTypeCheckOutput({
		dependencyErrors = take(partition.dependencyErrors, Typecheck.MAX_ERRORS),
		fileErrors = take(partition.fileErrors, Typecheck.MAX_ERRORS),
		totalDependencyErrors = #partition.dependencyErrors,
		totalFileErrors = #partition.fileErrors,
	})
end

--- Comparison key for a project file path.
function Typecheck.keyOf(filePath: string): string
	return Path.key(Project.resolve(filePath))
end

--- Which of `files` have at least one type error in `output`.
function Typecheck.errorFiles(files: { string }, output: string?): { string }
	if output == nil then
		return {}
	end

	local erroring: { [string]: boolean } = {}
	for _, diagnostic in Typecheck.parseDiagnostics(output) do
		erroring[Path.key(diagnostic.file)] = true
	end

	local result: { string } = {}
	for _, file in files do
		if erroring[Path.key(Project.resolve(file))] then
			table.insert(result, file)
		end
	end

	return result
end

function Typecheck.typecheckStopDecision(input: StopDecisionInput): StopDecisionResult?
	if #input.errorFiles == 0 then
		if input.stopAttempts > 0 then
			return { resetStopAttempts = true }
		end

		return nil
	end

	local allMaxed = true
	for _, file in input.errorFiles do
		if (input.lintAttempts[file] or 0) < input.maxLintAttempts then
			allMaxed = false
			break
		end
	end

	if allMaxed then
		return nil
	end

	local fileList = table.concat(input.errorFiles, ", ")
	if input.stopAttempts >= Typecheck.DEFAULT_MAX_STOP_ATTEMPTS then
		return {
			reason = `Unresolved type errors in: {fileList}. These may be pre-existing.`,
		}
	end

	return {
		decision = "block",
		reason = `Type errors detected in: {fileList}. If related to your changes, fix before finishing.`,
	}
end

return Typecheck
