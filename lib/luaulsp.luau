--!strict
-- Shared luau-lsp plumbing: platform detection, Roblox type definitions and
-- the project-level flags passed to `analyze` and `require-graph`.
--
-- `luau-lsp analyze` never downloads definitions itself. For Roblox projects
-- the hooks download luau-lsp's published `globalTypes.d.luau` once, cache it
-- at `.claude/state/luau-lsp/globalTypes.d.luau`, refresh it weekly and pass
-- it with `--definitions=<path>` alongside `--platform=roblox`.

local datetime = require("@lune/datetime")
local fs = require("@lune/fs")
local net = require("@lune/net")
local serde = require("@lune/serde")

local Io = require("./io")
local Path = require("./path")
local Project = require("./project")
local Tools = require("./tools")

type Log = Io.Log

export type Platform = "roblox" | "standard"

local LuauLsp = {}

LuauLsp.PROGRAM = "luau-lsp"
LuauLsp.ROBLOX_DEFINITIONS_URL =
	"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
LuauLsp.DEFINITIONS_MAX_AGE_SECONDS = 7 * 24 * 60 * 60

local NO_LOG = Io.createLog(false)

function LuauLsp.isAvailable(): boolean
	return Tools.isAvailable(LuauLsp.PROGRAM, Project.root())
end

function LuauLsp.definitionsPath(): string
	return Project.statePath("luau-lsp", "globalTypes.d.luau")
end

local function vscodePlatform(root: string): Platform?
	local path = Path.join(root, ".vscode", "settings.json")
	if not Project.isFile(path) then
		return nil
	end

	local ok, decoded = pcall(function(): any
		return serde.decode("jsonc", fs.readFile(path))
	end)
	if not ok or type(decoded) ~= "table" then
		return nil
	end

	local value = decoded["luau-lsp.platform.type"]
	if value == "roblox" then
		return "roblox"
	elseif value == "standard" then
		return "standard"
	end

	return nil
end

--- `luau-lsp.platform.type` from `.vscode/settings.json` when set; otherwise
--- `roblox` when the project has a `sourcemap.json` or a `*.project.json`
--- (Rojo/Azul), else `standard`.
function LuauLsp.detectPlatform(): Platform
	local root = Project.root()
	local configured = vscodePlatform(root)
	if configured ~= nil then
		return configured :: Platform
	end

	if Project.isFile(Path.join(root, "sourcemap.json")) then
		return "roblox"
	end

	local ok, entries = pcall(fs.readDir, root)
	if ok then
		for _, entry in entries do
			if string.match(string.lower(entry), "%.project%.json$") ~= nil then
				return "roblox"
			end
		end
	end

	return "standard"
end

local function isFresh(path: string): boolean
	local ok, metadata = pcall(fs.metadata, path)
	if not ok or metadata.modifiedAt == nil then
		return false
	end

	local age = datetime.now().unixTimestamp - metadata.modifiedAt.unixTimestamp
	return age <= LuauLsp.DEFINITIONS_MAX_AGE_SECONDS
end

--- Returns a usable Roblox definitions file, downloading or refreshing the
--- cached copy when needed. A stale copy is used if the refresh fails.
function LuauLsp.ensureRobloxDefinitions(log: Log?): string?
	local logger = log or NO_LOG
	local path = LuauLsp.definitionsPath()
	local exists = Project.isFile(path)
	if exists and isFresh(path) then
		return path
	end

	local ok, response = pcall(net.request, LuauLsp.ROBLOX_DEFINITIONS_URL)
	if ok and response.ok and #response.body > 0 then
		local written = pcall(function()
			fs.writeDir(Path.dirname(path))
			fs.writeFile(path, response.body)
		end)
		if written then
			logger.debug(`luau-lsp: downloaded Roblox definitions to {path}`)
			return path
		end
	end

	logger.debug(
		`luau-lsp: could not download Roblox definitions from {LuauLsp.ROBLOX_DEFINITIONS_URL}`
	)
	if exists then
		return path
	end

	return nil
end

--- Flags describing the project to luau-lsp: platform, definitions,
--- sourcemap and base `.luaurc`. Returns nil when the project needs Roblox
--- definitions that are not available (the caller should skip the check).
function LuauLsp.projectArgs(withDefinitions: boolean, log: Log?): { string }?
	local logger = log or NO_LOG
	local root = Project.root()
	local args: { string } = {}

	local platform = LuauLsp.detectPlatform()
	table.insert(args, `--platform={platform}`)
	if platform == "roblox" and withDefinitions then
		local definitions = LuauLsp.ensureRobloxDefinitions(logger)
		if definitions == nil then
			logger.debug("luau-lsp: Roblox definitions unavailable, skipped")
			return nil
		end

		table.insert(args, `--definitions={definitions}`)
	end

	local sourcemap = Path.join(root, "sourcemap.json")
	if Project.isFile(sourcemap) then
		table.insert(args, `--sourcemap={sourcemap}`)
	end

	local luaurc = Path.join(root, ".luaurc")
	if Project.isFile(luaurc) then
		table.insert(args, `--base-luaurc={luaurc}`)
	end

	return args
end

return LuauLsp
