--!strict
-- Project location and JSON state-file helpers. Everything the hooks persist
-- lives under `<project>/.claude/state/`.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Path = require("./path")

local Project = {}

local function projectEnv(): string?
	local value = process.env.CLAUDE_PROJECT_DIR
	if value == nil or value == "" then
		return nil
	end

	return value
end

--- `CLAUDE_PROJECT_DIR`, falling back to the working directory.
function Project.root(): string
	local env = projectEnv()
	if env ~= nil then
		return Path.resolve(env)
	end

	return Path.cwd()
end

--- True when `filePath` lives inside `CLAUDE_PROJECT_DIR` (always true when
--- the variable is unset). Case-insensitive on Windows.
function Project.isInProject(filePath: string): boolean
	local env = projectEnv()
	if env == nil then
		return true
	end

	return Path.isWithin(Path.resolve(filePath), Path.resolve(env))
end

--- Resolves a possibly relative path against the project root.
function Project.resolve(filePath: string): string
	return Path.resolve(filePath, Project.root())
end

--- Project-relative, `/`-separated path (starts with `../` when outside).
function Project.relative(filePath: string): string
	return Path.relative(Project.root(), Project.resolve(filePath))
end

function Project.statePath(...: string): string
	return Path.join(Project.root(), ".claude", "state", ...)
end

function Project.isFile(path: string): boolean
	local ok, result = pcall(fs.isFile, path)
	return ok and result
end

function Project.isDir(path: string): boolean
	local ok, result = pcall(fs.isDir, path)
	return ok and result
end

--- Reads and decodes a JSON file. Returns nil when the file is missing,
--- unreadable or not valid JSON.
function Project.readJson(path: string): any
	if not Project.isFile(path) then
		return nil
	end

	local ok, decoded = pcall(function(): any
		return serde.decode("json", fs.readFile(path))
	end)
	if not ok then
		return nil
	end

	return decoded
end

function Project.writeJson(path: string, value: any)
	fs.writeDir(Path.dirname(path))
	fs.writeFile(path, serde.encode("json", value))
end

function Project.removeFile(path: string)
	if Project.isFile(path) then
		pcall(fs.removeFile, path)
	end
end

--- True when the table has no keys.
function Project.isEmpty(map: { [any]: any }): boolean
	return next(map) == nil
end

return Project
