--!strict
-- Hook stdin/stdout plumbing, debug logging and the shared entry-point
-- runner. Hooks never block the agent on an internal failure: errors are
-- reported on stderr with a non-blocking exit code.

local datetime = require("@lune/datetime")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local Project = require("./project")
local Types = require("./types")

type HookInput = Types.HookInput
type HookOutput = Types.HookOutput

export type Log = {
	enabled: boolean,
	lines: { string },
	debug: (message: string) -> (),
}

local Io = {}

function Io.readStdinJson(): any
	local raw = stdio.readToEnd()
	local ok, decoded = pcall(serde.decode, "json" :: "json", raw)
	if not ok then
		error(`Failed to parse JSON input: {decoded}`)
	end

	return decoded
end

--- Reads the hook payload and checks the fields every hook relies on.
function Io.readHookInput(): HookInput
	local decoded = Io.readStdinJson()
	if type(decoded) ~= "table" then
		error("Expected hook input to be a JSON object")
	end

	if type(decoded.session_id) ~= "string" then
		decoded.session_id = tostring(decoded.session_id or "unknown")
	end

	return decoded :: HookInput
end

function Io.encode(output: HookOutput): string
	return serde.encode("json", output)
end

function Io.writeStdoutJson(output: HookOutput)
	stdio.write(Io.encode(output) .. "\n")
end

function Io.createLog(enabled: boolean): Log
	local lines: { string } = {}
	return {
		enabled = enabled,
		lines = lines,
		debug = function(message: string)
			if enabled then
				table.insert(lines, message)
			end
		end,
	}
end

--- Appends collected debug lines to `.claude/state/debug.log`.
function Io.flushLog(log: Log, hookName: string)
	if not log.enabled or #log.lines == 0 then
		return
	end

	local path = Project.statePath("debug.log")
	pcall(function()
		local previous = if Project.isFile(path) then fs.readFile(path) else ""
		local stamp = datetime.now():toIsoDate()
		local entry = `[{stamp}] [{hookName}]\n{table.concat(log.lines, "\n")}\n`
		fs.writeDir(Project.statePath())
		fs.writeFile(path, previous .. entry)
	end)
end

--- Runs a hook body, writing its JSON result (if any) to stdout. Internal
--- errors go to stderr with exit code 1, which Claude Code treats as a
--- non-blocking hook failure.
function Io.runHook(name: string, body: () -> HookOutput?)
	local ok, result = xpcall(body, function(err: any): string
		return debug.traceback(tostring(err), 2)
	end)
	if not ok then
		stdio.ewrite(`\n[{name}] Hook failed:\n{result}\n`)
		process.exit(1)
		return
	end

	if result ~= nil then
		Io.writeStdoutJson(result)
	end
end

return Io
