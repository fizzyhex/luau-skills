--!strict
-- Lint pipeline: StyLua formats the file in place (the auto-fix), then
-- selene reports diagnostics. Each step is skipped (debug log only) when its
-- tool is not resolvable from the project or the project has no config for it.

local Config = require("./config")
local Glob = require("./glob")
local Io = require("./io")
local Path = require("./path")
local Project = require("./project")
local Tools = require("./tools")
local Types = require("./types")

type Settings = Config.Settings
type Log = Io.Log
type PostToolUseOutput = Types.PostToolUseOutput
type StopDecisionInput = Types.StopDecisionInput
type StopDecisionResult = Types.StopDecisionResult

export type FormattedErrors = {
	lines: { string },
	totalIssues: number,
}

local Lint = {}

Lint.LINTABLE_EXTENSIONS = { ".luau", ".lua" }
Lint.PROTECTED_FILES = {
	"selene.toml",
	"stylua.toml",
	".stylua.toml",
	".styluaignore",
	"sentinel.local.md",
}
Lint.STYLUA_CONFIGS = { "stylua.toml", ".stylua.toml" }
Lint.SELENE_CONFIGS = { "selene.toml" }
Lint.LINT_COMMAND = "selene ."
Lint.SOURCE = "lint"
Lint.DEFAULT_MAX_STOP_ATTEMPTS = 1

local NO_LOG = Io.createLog(false)

local function caseFold(value: string): string
	return if Path.isWindows then string.lower(value) else value
end

function Lint.isLintableFile(filePath: string, extensions: { string }?): boolean
	local extension = caseFold(Path.extension(filePath))
	local candidates: { string } = extensions or Lint.LINTABLE_EXTENSIONS
	for _, candidate in candidates do
		if extension == caseFold(candidate) then
			return true
		end
	end

	return false
end

--- True for linter/formatter configs and the sentinel settings file.
function Lint.isProtectedFile(fileName: string): boolean
	local name = caseFold(Path.basename(fileName))
	for _, protected in Lint.PROTECTED_FILES do
		if name == caseFold(protected) then
			return true
		end
	end

	return false
end

--- True when a protected file is exempted by `lint-guard-allow`. Patterns are
--- globs matched against the project-relative, `/`-separated path; files
--- outside the project are never exempt.
function Lint.isGuardAllowed(filePath: string, patterns: { string }): boolean
	if #patterns == 0 then
		return false
	end

	local relative = Project.relative(filePath)
	if relative == ".." or string.sub(relative, 1, 3) == "../" or Path.isAbsolute(relative) then
		return false
	end

	local target = caseFold(relative)
	for _, pattern in patterns do
		if Glob.matches(target, caseFold(Path.toSlash(pattern))) then
			return true
		end
	end

	return false
end

local function splitLines(text: string): { string }
	local lines: { string } = {}
	for line in string.gmatch((string.gsub(text, "\r\n", "\n")), "[^\n]+") do
		table.insert(lines, line)
	end

	return lines
end

--- Path to hand a tool running in `cwd`: relative when inside it.
local function toolPath(filePath: string, cwd: string): string
	if Path.isWithin(filePath, cwd) then
		return Path.relative(cwd, filePath)
	end

	return filePath
end

--- Formats `filePath` in place with StyLua. Returns diagnostic lines when
--- StyLua could not format the file (usually a syntax error).
function Lint.runStylua(filePath: string, log: Log?): { string }
	local logger = log or NO_LOG
	local resolved = Project.resolve(filePath)
	local config = Tools.findConfig(resolved, Lint.STYLUA_CONFIGS)
	if config == nil then
		logger.debug(`stylua: no stylua.toml for {filePath}, skipped`)
		return {}
	end

	local cwd = Path.dirname(config)
	if not Tools.isAvailable("stylua", cwd) then
		logger.debug(`stylua: not resolvable from {cwd}, skipped`)
		return {}
	end

	local result = Tools.exec(
		"stylua",
		{ "--config-path", config, "--respect-ignores", toolPath(resolved, cwd) },
		cwd
	)
	if result == nil or result.ok then
		return {}
	end

	local details: { string } = {}
	for _, line in splitLines(result.stderr .. "\n" .. result.stdout) do
		local detail = string.match(line, "^%s*%-%s*(.+)$")
		if detail ~= nil then
			table.insert(details, detail)
		end
	end

	local summary = if #details > 0
		then table.concat(details, "; ")
		else (string.gsub(result.stderr, "%s+$", ""))
	return { `error[stylua]: could not format file: {summary}` }
end

--- Lints `filePath` with selene. Returns selene's quiet-style lines with the
--- file path prefix removed, e.g. `3:11: error[undefined_variable]: ...`.
function Lint.runSelene(filePath: string, log: Log?): { string }
	local logger = log or NO_LOG
	local resolved = Project.resolve(filePath)
	local config = Tools.findConfig(resolved, Lint.SELENE_CONFIGS)
	if config == nil then
		logger.debug(`selene: no selene.toml for {filePath}, skipped`)
		return {}
	end

	local cwd = Path.dirname(config)
	if not Tools.isAvailable("selene", cwd) then
		logger.debug(`selene: not resolvable from {cwd}, skipped`)
		return {}
	end

	local target = toolPath(resolved, cwd)
	local result = Tools.exec("selene", {
		"--config",
		config,
		"--display-style=quiet",
		"--no-summary",
		"--color",
		"Never",
		target,
	}, cwd)
	if result == nil or result.ok then
		return {}
	end

	local lines: { string } = {}
	local prefix = target .. ":"
	for _, line in splitLines(result.stdout) do
		if string.sub(line, 1, #prefix) == prefix then
			table.insert(lines, string.sub(line, #prefix + 1))
		else
			table.insert(lines, line)
		end
	end

	if #lines == 0 then
		for _, line in splitLines(result.stderr) do
			table.insert(lines, `error[selene]: {line}`)
		end
	end

	return lines
end

local function isErrorLine(line: string): boolean
	if string.find(line, "warning%[") ~= nil then
		return false
	end

	return string.find(line, "error%[") ~= nil or string.find(line, "%f[%a][Ee]rror%f[%A]") ~= nil
end

local function extractRule(line: string): string?
	return string.match(line, "error%[([^%]]+)%]")
end

--- Keeps error lines, clusters repeats of the same rule and caps the result.
function Lint.formatErrors(output: string, max: number?): FormattedErrors
	local limit = max or Config.DEFAULT_MAX_LINT_ERRORS
	local errorLines: { string } = {}
	for _, line in splitLines(output) do
		if isErrorLine(line) then
			table.insert(errorLines, line)
		end
	end

	local order: { string } = {}
	local counts: { [string]: { count: number, sample: string } } = {}
	local ungrouped: { string } = {}
	for _, line in errorLines do
		local rule = extractRule(line)
		if rule == nil then
			table.insert(ungrouped, line)
			continue
		end

		local existing = counts[rule]
		if existing == nil then
			counts[rule] = { count = 1, sample = line }
			table.insert(order, rule)
		else
			existing.count += 1
		end
	end

	local merged: { string } = {}
	for _, rule in order do
		local entry = counts[rule]
		table.insert(
			merged,
			if entry.count > 1
				then `{entry.sample}  (x{entry.count}, rule: {rule})`
				else entry.sample
		)
	end

	for _, line in ungrouped do
		table.insert(merged, line)
	end

	return {
		lines = { table.unpack(merged, 1, math.min(#merged, math.max(limit, 0))) },
		totalIssues = #errorLines,
	}
end

function Lint.buildHookOutput(
	filePath: string,
	errors: FormattedErrors,
	debugInfo: string?
): PostToolUseOutput
	local remaining = errors.totalIssues - #errors.lines
	local overflow = if remaining > 0
		then `\n+ {remaining} more issues — run \`{Lint.LINT_COMMAND}\` to see all`
		else ""
	local issueWord = if errors.totalIssues == 1 then "issue" else "issues"
	local heading = `{filePath} shows {errors.totalIssues} {issueWord}:`
	local body = `{heading}\n{table.concat(errors.lines, "\n")}{overflow}{debugInfo or ""}`
	local wrapped =
		`<workspace_diagnostics source="{Lint.SOURCE}">\n{body}\n</workspace_diagnostics>`

	return {
		hookSpecificOutput = {
			hookEventName = "PostToolUse",
			additionalContext = wrapped,
		},
		systemMessage = wrapped,
	}
end

--- Formats then lints one file. Returns hook output when errors remain.
function Lint.lint(filePath: string, settings: Settings, log: Log?): PostToolUseOutput?
	if not Lint.isLintableFile(filePath) or not Project.isFile(Project.resolve(filePath)) then
		return nil
	end

	local lines: { string } = {}
	if settings.stylua then
		for _, line in Lint.runStylua(filePath, log) do
			table.insert(lines, line)
		end
	end

	if settings.selene then
		for _, line in Lint.runSelene(filePath, log) do
			table.insert(lines, line)
		end
	end

	if #lines == 0 then
		return nil
	end

	local errors = Lint.formatErrors(table.concat(lines, "\n"), settings.maxLintErrors)
	if #errors.lines == 0 then
		return nil
	end

	return Lint.buildHookOutput(filePath, errors)
end

--- Silent batch fix: formats every file with StyLua, reporting nothing.
function Lint.autoFix(files: { string }, settings: Settings, log: Log?)
	if not settings.stylua then
		return
	end

	for _, file in files do
		Lint.runStylua(file, log)
	end
end

--- Existing, lintable files from an edited-files list (deduplicated).
function Lint.lintableFiles(files: { string }): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for _, file in files do
		local key = Path.key(Project.resolve(file))
		if
			not seen[key]
			and Lint.isLintableFile(file)
			and Project.isFile(Project.resolve(file))
		then
			seen[key] = true
			table.insert(result, file)
		end
	end

	return result
end

local function endsWithSegment(haystack: string, needle: string): boolean
	if haystack == needle then
		return true
	end

	if string.find(needle, "/", 1, true) == nil then
		return false
	end

	local suffix = "/" .. needle
	return string.sub(haystack, -#suffix) == suffix
end

--- Attempt count for `file`, tolerating absolute/relative and `\`/`/`
--- differences between the recorded key and the stop-time path.
function Lint.findAttempts(file: string, lintAttempts: { [string]: number }): number
	local direct = lintAttempts[file]
	if direct ~= nil then
		return direct
	end

	local normalized = Path.toSlash(file)
	for key, count in lintAttempts do
		local normalizedKey = Path.toSlash(key)
		if
			endsWithSegment(normalizedKey, normalized) or endsWithSegment(normalized, normalizedKey)
		then
			return count
		end
	end

	return 0
end

function Lint.stopDecision(input: StopDecisionInput): StopDecisionResult?
	if #input.errorFiles == 0 then
		if input.stopAttempts > 0 then
			return { resetStopAttempts = true }
		end

		return nil
	end

	local allMaxed = true
	for _, file in input.errorFiles do
		if Lint.findAttempts(file, input.lintAttempts) < input.maxLintAttempts then
			allMaxed = false
			break
		end
	end

	if allMaxed then
		return nil
	end

	local fileList = table.concat(input.errorFiles, ", ")
	if input.stopAttempts >= Lint.DEFAULT_MAX_STOP_ATTEMPTS then
		return {
			reason = `<workspace_diagnostics source="{Lint.SOURCE}">\nUnresolved lint issues remain in: {fileList}. They may be pre-existing.\n</workspace_diagnostics>`,
		}
	end

	return {
		decision = "block",
		reason = `<workspace_diagnostics source="{Lint.SOURCE}">\nLint issues remain in: {fileList}. If related to recent changes, address before continuing?\n</workspace_diagnostics>`,
	}
end

--- Checkpoint reason used by SubagentStop/TaskCompleted.
function Lint.checkpointReason(errorFiles: { string }): string
	return `<workspace_diagnostics source="{Lint.SOURCE}">\nLint issues remain in: {table.concat(
		errorFiles,
		", "
	)}. If related to recent changes, address before continuing?\n</workspace_diagnostics>`
end

return Lint
