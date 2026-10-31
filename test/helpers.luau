--!strict
-- Sandbox projects and hook subprocess helpers for the specs. Tests run from
-- the repository root (`lune run test/run`).

local datetime = require("@lune/datetime")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Path = require("../lib/path")
local Tools = require("../lib/tools")

export type HookResult = {
	code: number,
	stdout: string,
	stderr: string,
	output: any,
}

export type SandboxOptions = {
	-- Copy the repo's rokit.toml so stylua/selene/luau-lsp resolve.
	tools: boolean?,
	-- Write stylua.toml and selene.toml (std = "luau").
	configs: boolean?,
}

local Helpers = {}

Helpers.REPO_ROOT = Path.cwd()

assert(
	fs.isFile(Path.join(Helpers.REPO_ROOT, "hooks", "lint.luau")),
	"run the tests from the repository root: lune run test/run"
)

local counter = 0

local function tempRoot(): string
	local base = process.env.TEMP or process.env.TMPDIR or process.env.TMP or "/tmp"
	return Path.resolve(base)
end

function Helpers.write(directory: string, relative: string, content: string)
	local path = Path.join(directory, relative)
	fs.writeDir(Path.dirname(path))
	fs.writeFile(path, content)
end

function Helpers.read(directory: string, relative: string): string?
	local path = Path.join(directory, relative)
	if not fs.isFile(path) then
		return nil
	end

	return fs.readFile(path)
end

--- Creates an empty project directory (with a space in its name, to cover
--- quoting) under the OS temp directory.
function Helpers.makeSandbox(prefix: string, options: SandboxOptions?): string
	counter += 1
	local name =
		`sentinel {prefix}-{datetime.now().unixTimestampMillis}-{counter}-{math.random(1e6)}`
	local directory = Path.join(tempRoot(), name)
	fs.writeDir(directory)

	local opts: SandboxOptions = options or {}
	if opts.tools then
		fs.writeFile(
			Path.join(directory, "rokit.toml"),
			fs.readFile(Path.join(Helpers.REPO_ROOT, "rokit.toml"))
		)
	end

	if opts.configs then
		Helpers.write(directory, "stylua.toml", 'indent_type = "Tabs"\nsyntax = "Luau"\n')
		Helpers.write(directory, "selene.toml", 'std = "luau"\n')
	end

	return directory
end

function Helpers.removeSandbox(directory: string)
	pcall(fs.removeDir, directory)
end

--- Runs `body` with `CLAUDE_PROJECT_DIR` pointing at `directory`.
function Helpers.withProject(directory: string, body: () -> ())
	local previous = process.env.CLAUDE_PROJECT_DIR
	process.env.CLAUDE_PROJECT_DIR = directory
	Tools.resetCache()
	local ok, err = pcall(function(): nil
		body()
		return nil
	end)
	process.env.CLAUDE_PROJECT_DIR = previous
	if not ok then
		error(err, 0)
	end
end

--- Creates a sandbox, runs `body` inside it and always removes it.
function Helpers.inSandbox(
	prefix: string,
	options: SandboxOptions?,
	body: (directory: string) -> ()
)
	local directory = Helpers.makeSandbox(prefix, options)
	local ok, err = pcall(function(): nil
		Helpers.withProject(directory, function()
			body(directory)
		end)
		return nil
	end)
	Helpers.removeSandbox(directory)
	if not ok then
		error(err, 0)
	end
end

function Helpers.writeSettings(directory: string, lines: { string })
	Helpers.write(
		directory,
		".claude/sentinel.local.md",
		"---\n" .. table.concat(lines, "\n") .. "\n---\n"
	)
end

function Helpers.readState(directory: string, name: string): any
	local raw = Helpers.read(directory, `.claude/state/{name}`)
	if raw == nil then
		return nil
	end

	return serde.decode("json", raw)
end

function Helpers.writeState(directory: string, name: string, value: any)
	Helpers.write(directory, `.claude/state/{name}`, serde.encode("json", value))
end

--- Runs `hooks/<name>.luau` as Claude Code would: JSON piped on stdin and
--- `CLAUDE_PROJECT_DIR` set to the sandbox. Uses `process.create` because
--- `process.exec`'s `stdio.stdin` option intermittently delivers an empty
--- stdin in Lune 0.11.1.
function Helpers.runHook(name: string, input: { [string]: any }, directory: string): HookResult
	local child = process.create(
		"lune",
		{ "run", Path.join(Helpers.REPO_ROOT, "hooks", `{name}.luau`) },
		{
			cwd = Helpers.REPO_ROOT,
			env = { CLAUDE_PROJECT_DIR = directory },
		}
	)
	child.stdin:write(serde.encode("json", input))
	child.stdin:close()
	local stdout = child.stdout:readToEnd()
	local stderr = child.stderr:readToEnd()
	local status = child:status()

	local output: any = nil
	local trimmed = string.gsub(stdout, "^%s*(.-)%s*$", "%1")
	if trimmed ~= "" then
		local ok, decoded = pcall(serde.decode, "json" :: "json", trimmed)
		output = if ok then decoded else nil
	end

	return {
		code = status.code,
		stdout = trimmed,
		stderr = stderr,
		output = output,
	}
end

return Helpers
