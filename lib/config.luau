--!strict
-- Reads hook settings from the YAML frontmatter of
-- `<project>/.claude/sentinel.local.md`. See hooks/CONFIGURATION.md.

local fs = require("@lune/fs")

local Path = require("./path")
local Project = require("./project")

export type LintCadence = "strict" | "tiered" | "stop-only"

export type Settings = {
	debug: boolean,
	lint: boolean,
	lintAutoFixOnBatch: boolean,
	lintCadence: LintCadence,
	lintGuardAllow: { string },
	maxLintAttempts: number,
	maxLintErrors: number,
	selene: boolean,
	stylua: boolean,
	typecheck: boolean,
	typecheckArgs: { string },
}

local Config = {}

Config.SETTINGS_FILE = ".claude/sentinel.local.md"
local LINT_CADENCE_VALUES: { LintCadence } = { "strict", "tiered", "stop-only" }
local DEFAULT_LINT_CADENCE: LintCadence = "strict"

Config.LINT_CADENCE_VALUES = LINT_CADENCE_VALUES

Config.DEFAULT_MAX_LINT_ATTEMPTS = 1
Config.DEFAULT_MAX_LINT_ERRORS = 10
Config.DEFAULT_LINT_CADENCE = DEFAULT_LINT_CADENCE

function Config.defaults(): Settings
	return {
		debug = false,
		lint = true,
		lintAutoFixOnBatch = true,
		lintCadence = DEFAULT_LINT_CADENCE,
		lintGuardAllow = {},
		maxLintAttempts = Config.DEFAULT_MAX_LINT_ATTEMPTS,
		maxLintErrors = Config.DEFAULT_MAX_LINT_ERRORS,
		selene = true,
		stylua = true,
		typecheck = true,
		typecheckArgs = {},
	}
end

local function trim(value: string): string
	return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

--- Parses `key: value` pairs from a leading `---` fenced frontmatter block.
--- Values are kept as strings with surrounding quotes stripped.
function Config.parseFrontmatter(content: string): { [string]: string }
	local fields: { [string]: string } = {}
	local lines = string.split((string.gsub(content, "\r\n", "\n")), "\n")

	local start: number? = nil
	for index, line in lines do
		if line == "---" then
			start = index
			break
		end
	end

	if start == nil then
		return fields
	end

	local finish: number? = nil
	for index = start + 1, #lines do
		if string.sub(lines[index], 1, 3) == "---" then
			finish = index
			break
		end
	end

	if finish == nil then
		return fields
	end

	for index = start + 1, finish - 1 do
		local line = lines[index]
		local colon = string.find(line, ":", 1, true)
		if colon ~= nil and colon > 1 then
			local key = trim(string.sub(line, 1, colon - 1))
			local value = trim(string.sub(line, colon + 1))
			value = string.gsub(value, "^[\"']", "")
			value = string.gsub(value, "[\"']$", "")
			fields[key] = value
		end
	end

	return fields
end

--- Splits a comma-separated list, trimming entries and dropping empties.
function Config.parseList(raw: string?): { string }
	local result: { string } = {}
	if raw == nil then
		return result
	end

	for _, entry in string.split(raw, ",") do
		local trimmed = trim(entry)
		if trimmed ~= "" then
			table.insert(result, trimmed)
		end
	end

	return result
end

local function parseNumber(raw: string?, fallback: number): number
	if raw == nil then
		return fallback
	end

	local parsed = tonumber(raw)
	if parsed == nil or parsed ~= parsed or parsed == math.huge or parsed == -math.huge then
		return fallback
	end

	return parsed
end

local function parseCadence(raw: string?): LintCadence
	if raw == "tiered" then
		return "tiered"
	elseif raw == "stop-only" then
		return "stop-only"
	elseif raw == "strict" then
		return "strict"
	end

	return DEFAULT_LINT_CADENCE
end

local function parseBoolean(raw: string?, fallback: boolean): boolean
	if raw == "true" then
		return true
	end

	if raw == "false" then
		return false
	end

	return fallback
end

function Config.parseSettings(content: string?): Settings
	if content == nil then
		return Config.defaults()
	end

	local fields = Config.parseFrontmatter(content)
	return {
		debug = fields["debug"] == "true",
		lint = fields["lint"] ~= "false",
		lintAutoFixOnBatch = parseBoolean(fields["lint-auto-fix-on-batch"], true),
		lintCadence = parseCadence(fields["lint-cadence"]),
		lintGuardAllow = Config.parseList(fields["lint-guard-allow"]),
		maxLintAttempts = parseNumber(
			fields["max-lint-attempts"],
			Config.DEFAULT_MAX_LINT_ATTEMPTS
		),
		maxLintErrors = parseNumber(fields["max-lint-errors"], Config.DEFAULT_MAX_LINT_ERRORS),
		selene = fields["selene"] ~= "false",
		stylua = fields["stylua"] ~= "false",
		typecheck = fields["typecheck"] ~= "false",
		typecheckArgs = Config.parseList(fields["typecheck-args"]),
	}
end

function Config.settingsPath(): string
	return Path.join(Project.root(), Config.SETTINGS_FILE)
end

function Config.readSettings(): Settings
	local path = Config.settingsPath()
	if not Project.isFile(path) then
		return Config.defaults()
	end

	local ok, content = pcall(fs.readFile, path)
	if not ok then
		return Config.defaults()
	end

	return Config.parseSettings(content)
end

return Config
