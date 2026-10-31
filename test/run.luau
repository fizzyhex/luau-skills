--!strict
-- Test runner: `lune run test/run [name filter]` from the repository root.

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local T = require("./harness")

local SPECS = {
	"cadence-hooks.spec",
	"config.spec",
	"lint-guard.spec",
	"lint-hooks.spec",
	"lint.spec",
	"path.spec",
	"state.spec",
	"type-check.spec",
}

require("./cadence-hooks.spec")
require("./config.spec")
require("./lint-guard.spec")
require("./lint-hooks.spec")
require("./lint.spec")
require("./path.spec")
require("./state.spec")
require("./type-check.spec")

-- Guard against a spec file being added without being registered above.
for _, entry in fs.readDir("test") do
	local name = string.match(entry, "^(.+%.spec)%.luau$")
	if name ~= nil and table.find(SPECS, name) == nil then
		stdio.ewrite(`test/{entry} is not registered in test/run.luau\n`)
		process.exit(1)
	end
end

local _, failed = T.run(process.args[1])
if failed > 0 then
	process.exit(1)
end
