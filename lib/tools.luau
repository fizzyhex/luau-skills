--!strict
-- Spawning external tools (StyLua, selene, luau-lsp). Tools are resolved from
-- the target project's working directory, so Rokit/Aftman/Foreman shims pick
-- up the project's own toolchain. A tool that cannot be spawned, or whose
-- shim reports it is not installed, is treated as unavailable.

local process = require("@lune/process")

local Path = require("./path")
local Project = require("./project")

export type ExecResult = {
	ok: boolean,
	code: number,
	stdout: string,
	stderr: string,
}

local Tools = {}

local availability: { [string]: boolean } = {}

--- Runs `program` with `args` in `cwd`. Returns nil when the program could
--- not be spawned at all.
function Tools.exec(program: string, args: { string }, cwd: string): ExecResult?
	local ok, result = pcall(process.exec, program, args, { cwd = cwd })
	if not ok then
		return nil
	end

	return {
		ok = result.ok,
		code = result.code,
		stdout = result.stdout,
		stderr = result.stderr,
	}
end

--- Probes `<program> --version` once per (program, cwd).
function Tools.isAvailable(program: string, cwd: string): boolean
	local key = `{program}\0{Path.key(cwd)}`
	local cached = availability[key]
	if cached ~= nil then
		return cached
	end

	local result = Tools.exec(program, { "--version" }, cwd)
	local available = result ~= nil and result.ok
	availability[key] = available
	return available
end

--- Forgets cached availability probes (used by tests).
function Tools.resetCache()
	table.clear(availability)
end

--- Walks up from the file's directory to the project root (or the
--- filesystem root when the file is outside the project) looking for the
--- first of `names`. Returns the config path.
function Tools.findConfig(filePath: string, names: { string }): string?
	local root = Project.root()
	local resolved = Project.resolve(filePath)
	local stopAtRoot = Path.isWithin(resolved, root)
	local directory = Path.dirname(resolved)

	while true do
		for _, name in names do
			local candidate = Path.join(directory, name)
			if Project.isFile(candidate) then
				return candidate
			end
		end

		if stopAtRoot and Path.equals(directory, root) then
			return nil
		end

		local parent = Path.dirname(directory)
		if parent == directory then
			return nil
		end

		directory = parent
	end
end

return Tools
