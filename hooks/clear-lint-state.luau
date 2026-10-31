--!strict
-- SessionStart: registers the session, prunes state left behind by dead
-- sessions and warms the Roblox definitions cache for the typecheck hooks.

local Config = require("../lib/config")
local Io = require("../lib/io")
local LuauLsp = require("../lib/luaulsp")
local State = require("../lib/state")
local Types = require("../lib/types")

Io.runHook("clear-lint-state", function(): Types.HookOutput?
	local input = Io.readHookInput()
	State.registerSession(input.session_id, State.getClaudePid())
	State.pruneDeadSessions(State.loadLiveSessions())

	local settings = Config.readSettings()
	if
		settings.typecheck
		and #settings.typecheckArgs == 0
		and LuauLsp.detectPlatform() == "roblox"
		and LuauLsp.isAvailable()
	then
		local log = Io.createLog(settings.debug)
		LuauLsp.ensureRobloxDefinitions(log)
		Io.flushLog(log, "clear-lint-state")
	end

	return nil
end)
