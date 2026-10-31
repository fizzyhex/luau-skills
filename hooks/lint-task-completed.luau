--!strict
-- TaskCompleted (tiered cadence): re-lints edited files at the task
-- checkpoint and surfaces remaining errors.

local Checkpoint = require("../lib/checkpoint")
local Io = require("../lib/io")

Io.runHook("lint-task-completed", Checkpoint.run)
