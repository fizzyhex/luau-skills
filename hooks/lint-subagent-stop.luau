--!strict
-- SubagentStop (tiered cadence): re-lints the subagent's edited files and
-- surfaces remaining errors.

local Checkpoint = require("../lib/checkpoint")
local Io = require("../lib/io")

Io.runHook("lint-subagent-stop", Checkpoint.run)
