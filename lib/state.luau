--!strict
-- Persistent hook state under `<project>/.claude/state/`:
--   edited-files.json            bucketKey -> { edited, lastSurfacedAt }
--   lint-attempts.json           sessionId -> { [file]: count }
--   stop-attempts.json           bucketKey -> count (lint Stop hook)
--   typecheck-stop-attempts.json bucketKey -> count (typecheck Stop hook)
--   sessions/<sessionId>         live-session registry (claude PID)

local datetime = require("@lune/datetime")
local fs = require("@lune/fs")
local process = require("@lune/process")

local Path = require("./path")
local Project = require("./project")
local Types = require("./types")

type HookInput = Types.HookInput

export type EditedFilesBucket = {
	edited: { string },
	lastSurfacedAt: number?,
}

export type EditedFilesState = { [string]: EditedFilesBucket }
export type LintAttemptsState = { [string]: { [string]: number } }
export type StopKind = "lint" | "typecheck"

local State = {}

State.EDITED_FILES = "edited-files.json"
State.LINT_ATTEMPTS = "lint-attempts.json"
State.STOP_ATTEMPTS = "stop-attempts.json"
State.TYPECHECK_STOP_ATTEMPTS = "typecheck-stop-attempts.json"
State.SESSIONS_DIR = "sessions"
State.CLAUDE_PID = "claude-pid"

--- Sessions whose PID could not be discovered stay "live" this long.
State.UNKNOWN_PID_TTL_SECONDS = 7 * 24 * 60 * 60

local function asMap(value: any): { [string]: any }
	if type(value) == "table" then
		return value
	end

	return {}
end

--- `<session_id>:main` on the main thread, `<session_id>:<agent_id>` inside a
--- subagent.
function State.getBucketKey(input: HookInput): string
	local agent = input.agent_id
	if type(agent) ~= "string" or agent == "" then
		agent = "main"
	end

	return `{input.session_id}:{agent}`
end

--- Extracts `tool_input.file_path` from an Edit/Write payload.
function State.narrowToolInput(input: HookInput): string
	local toolName = tostring(input.tool_name)
	local toolInput = input.tool_input
	if type(toolInput) ~= "table" then
		error(`Expected {toolName} tool_input to be an object, got {typeof(toolInput)}`)
	end

	local filePath = toolInput.file_path
	if type(filePath) ~= "string" or filePath == "" then
		error(`Expected {toolName} tool_input.file_path to be a non-empty string`)
	end

	return filePath
end

-- Edited files ------------------------------------------------------------

local function readEditedState(): EditedFilesState
	local raw = asMap(Project.readJson(Project.statePath(State.EDITED_FILES)))
	local state: EditedFilesState = {}
	for key, value in raw do
		if type(key) == "string" and type(value) == "table" then
			local edited: { string } = {}
			for _, file in asMap(value.edited) do
				if type(file) == "string" then
					table.insert(edited, file)
				end
			end

			local surfaced = value.lastSurfacedAt
			state[key] = {
				edited = edited,
				lastSurfacedAt = if type(surfaced) == "number" then surfaced else nil,
			}
		end
	end

	return state
end

local function writeEditedState(state: EditedFilesState)
	Project.writeJson(Project.statePath(State.EDITED_FILES), state)
end

function State.readEditedFiles(bucketKey: string): { string }
	local bucket = readEditedState()[bucketKey]
	return if bucket ~= nil then bucket.edited else {}
end

function State.writeEditedFile(bucketKey: string, filePath: string)
	local state = readEditedState()
	local bucket = state[bucketKey] or { edited = {}, lastSurfacedAt = nil }
	if table.find(bucket.edited, filePath) == nil then
		table.insert(bucket.edited, filePath)
	end

	state[bucketKey] = bucket
	writeEditedState(state)
end

function State.clearEditedFiles(bucketKey: string)
	local path = Project.statePath(State.EDITED_FILES)
	if not Project.isFile(path) then
		return
	end

	local raw = Project.readJson(path)
	if type(raw) ~= "table" then
		Project.removeFile(path)
		return
	end

	local state = readEditedState()
	if state[bucketKey] == nil then
		return
	end

	state[bucketKey] = nil
	if Project.isEmpty(state) then
		Project.removeFile(path)
	else
		writeEditedState(state)
	end
end

--- Empties the bucket's edit list and records when it was surfaced.
function State.markBucketSurfaced(bucketKey: string, timestamp: number?)
	local state = readEditedState()
	state[bucketKey] = {
		edited = {},
		lastSurfacedAt = timestamp or datetime.now().unixTimestampMillis,
	}
	writeEditedState(state)
end

function State.getLastSurfacedAt(bucketKey: string): number?
	local bucket = readEditedState()[bucketKey]
	return if bucket ~= nil then bucket.lastSurfacedAt else nil
end

-- Lint attempts -----------------------------------------------------------

local function readLintAttemptsState(): LintAttemptsState
	local raw = asMap(Project.readJson(Project.statePath(State.LINT_ATTEMPTS)))
	local state: LintAttemptsState = {}
	for session, attempts in raw do
		if type(session) == "string" and type(attempts) == "table" then
			local inner: { [string]: number } = {}
			for file, count in attempts do
				if type(file) == "string" and type(count) == "number" then
					inner[file] = count
				end
			end

			state[session] = inner
		end
	end

	return state
end

local function writeLintAttemptsState(state: LintAttemptsState)
	Project.writeJson(Project.statePath(State.LINT_ATTEMPTS), state)
end

function State.readLintAttempts(sessionId: string): { [string]: number }
	return readLintAttemptsState()[sessionId] or {}
end

function State.writeLintAttempts(sessionId: string, attempts: { [string]: number })
	local state = readLintAttemptsState()
	state[sessionId] = attempts
	writeLintAttemptsState(state)
end

function State.incrementLintAttempt(sessionId: string, filePath: string): number
	local state = readLintAttemptsState()
	local attempts = state[sessionId] or {}
	local count = (attempts[filePath] or 0) + 1
	attempts[filePath] = count
	state[sessionId] = attempts
	writeLintAttemptsState(state)
	return count
end

function State.clearLintAttempt(sessionId: string, filePath: string)
	local state = readLintAttemptsState()
	local attempts = state[sessionId]
	if attempts == nil or attempts[filePath] == nil then
		return
	end

	attempts[filePath] = nil
	if Project.isEmpty(attempts) then
		state[sessionId] = nil
	end

	if Project.isEmpty(state) then
		Project.removeFile(Project.statePath(State.LINT_ATTEMPTS))
	else
		writeLintAttemptsState(state)
	end
end

-- Stop attempts -----------------------------------------------------------

local function stopPath(kind: StopKind): string
	return Project.statePath(
		if kind == "lint" then State.STOP_ATTEMPTS else State.TYPECHECK_STOP_ATTEMPTS
	)
end

local function readStopState(kind: StopKind): { [string]: number }
	local state: { [string]: number } = {}
	for key, value in asMap(Project.readJson(stopPath(kind))) do
		if type(key) == "string" and type(value) == "number" then
			state[key] = value
		end
	end

	return state
end

function State.readStopAttempts(kind: StopKind, bucketKey: string): number
	return readStopState(kind)[bucketKey] or 0
end

function State.writeStopAttempts(kind: StopKind, bucketKey: string, count: number)
	local state = readStopState(kind)
	state[bucketKey] = count
	Project.writeJson(stopPath(kind), state)
end

-- Sessions ----------------------------------------------------------------

function State.isPidAlive(pid: number): boolean
	if pid <= 0 or pid ~= math.floor(pid) then
		return false
	end

	local ok, result = pcall(function(): boolean
		if Path.isWindows then
			local tasklist =
				process.exec("tasklist", { "/FI", `PID eq {pid}`, "/NH", "/FO", "CSV" })
			return tasklist.ok and string.find(tasklist.stdout, `"{pid}"`, 1, true) ~= nil
		end

		return process.exec("ps", { "-p", tostring(pid) }).ok
	end)
	return ok and result
end

local WINDOWS_PID_SCRIPT = [[
$self = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -Property ParentProcessId
$currentPid = $self.ParentProcessId
while ($currentPid -and $currentPid -ne 0) {
  $p = Get-CimInstance Win32_Process -Filter "ProcessId=$currentPid" -Property Name,ParentProcessId -ErrorAction SilentlyContinue
  if (-not $p) { break }
  if ($p.Name -eq 'claude.exe') { Write-Output $currentPid; exit }
  $currentPid = $p.ParentProcessId
}]]

local UNIX_PID_SCRIPT = [[
pid=$PPID
while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
  comm=$(ps -o comm= -p "$pid" 2>/dev/null)
  case "$comm" in *claude*) echo "$pid"; exit 0;; esac
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done]]

--- Finds the PID of the `claude` process that launched this hook by walking
--- the process tree. Cached in `.claude/state/claude-pid[-<sse port>]`.
function State.getClaudePid(): string?
	local port = process.env.CLAUDE_CODE_SSE_PORT or ""
	local cacheFile =
		Project.statePath(if port ~= "" then `{State.CLAUDE_PID}-{port}` else State.CLAUDE_PID)

	if Project.isFile(cacheFile) then
		local ok, cached = pcall(fs.readFile, cacheFile)
		if ok then
			local trimmed = string.gsub(cached, "%s+", "")
			local pid = tonumber(trimmed)
			if pid ~= nil and State.isPidAlive(pid) then
				return trimmed
			end
		end
	end

	local ok, discovered = pcall(function(): string
		local result = if Path.isWindows
			then process.exec("powershell.exe", { "-NoProfile", "-Command", WINDOWS_PID_SCRIPT })
			else process.exec("sh", { "-c", UNIX_PID_SCRIPT })
		return (string.gsub(result.stdout, "%s+", ""))
	end)
	if ok and tonumber(discovered) ~= nil then
		pcall(function()
			fs.writeDir(Project.statePath())
			fs.writeFile(cacheFile, discovered)
		end)
		return discovered
	end

	return nil
end

--- Records the session in the live-session registry. `pid` of nil records
--- `unknown`; such sessions are kept for `UNKNOWN_PID_TTL_SECONDS`.
function State.registerSession(sessionId: string, pid: string?)
	local directory = Project.statePath(State.SESSIONS_DIR)
	fs.writeDir(directory)
	fs.writeFile(Path.join(directory, sessionId), pid or "unknown")
end

local function isFreshUnknown(lockfile: string): boolean
	local ok, metadata = pcall(fs.metadata, lockfile)
	if not ok or metadata.modifiedAt == nil then
		return false
	end

	local age = datetime.now().unixTimestamp - metadata.modifiedAt.unixTimestamp
	return age <= State.UNKNOWN_PID_TTL_SECONDS
end

--- Returns the set of registered sessions whose claude process is alive.
--- Dead or malformed entries are deleted as a side effect.
function State.loadLiveSessions(): { [string]: boolean }
	local live: { [string]: boolean } = {}
	local directory = Project.statePath(State.SESSIONS_DIR)
	if not Project.isDir(directory) then
		return live
	end

	for _, entry in fs.readDir(directory) do
		local lockfile = Path.join(directory, entry)
		local ok, content = pcall(fs.readFile, lockfile)
		local trimmed = if ok then string.gsub(content, "%s+", "") else ""
		local pid = tonumber(trimmed)

		local isLive = if pid ~= nil
			then State.isPidAlive(pid)
			else trimmed == "unknown" and isFreshUnknown(lockfile)

		if isLive then
			live[entry] = true
		else
			Project.removeFile(lockfile)
		end
	end

	return live
end

local function pruneStateFile(path: string, keepKey: (key: string) -> boolean)
	if not Project.isFile(path) then
		return
	end

	local parsed = Project.readJson(path)
	if type(parsed) ~= "table" then
		Project.removeFile(path)
		return
	end

	local survivors: { [string]: any } = {}
	local dropped = false
	for key, value in parsed do
		if type(key) == "string" and keepKey(key) then
			survivors[key] = value
		else
			dropped = true
		end
	end

	if not dropped then
		return
	end

	if Project.isEmpty(survivors) then
		Project.removeFile(path)
	else
		Project.writeJson(path, survivors)
	end
end

local function sessionOfBucket(key: string): string
	return string.match(key, "^([^:]*)") or key
end

--- Drops every state entry whose owning session is not in `liveSessions`.
function State.pruneDeadSessions(liveSessions: { [string]: boolean })
	pruneStateFile(Project.statePath(State.LINT_ATTEMPTS), function(key: string): boolean
		return liveSessions[key] == true
	end)

	for _, name in { State.STOP_ATTEMPTS, State.TYPECHECK_STOP_ATTEMPTS, State.EDITED_FILES } do
		pruneStateFile(Project.statePath(name), function(key: string): boolean
			return liveSessions[sessionOfBucket(key)] == true
		end)
	end
end

return State
