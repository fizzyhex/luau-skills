--!strict

local Config = require("../lib/config")
local H = require("./helpers")
local T = require("./harness")

local function parse(lines: { string }): Config.Settings
	return Config.parseSettings("---\n" .. table.concat(lines, "\n") .. "\n---\n")
end

T.describe("Config.readSettings", function()
	T.it("returns defaults when no settings file exists", function()
		H.inSandbox("config-defaults", nil, function()
			T.equal(Config.readSettings(), {
				debug = false,
				lint = true,
				lintAutoFixOnBatch = true,
				lintCadence = "strict",
				lintGuardAllow = {},
				maxLintAttempts = 1,
				maxLintErrors = 10,
				selene = true,
				stylua = true,
				typecheck = true,
				typecheckArgs = {},
			})
		end)
	end)

	T.it("reads the project's .claude/sentinel.local.md", function()
		H.inSandbox("config-read", nil, function(directory)
			H.writeSettings(directory, { "lint-cadence: tiered", "debug: true" })
			local settings = Config.readSettings()
			T.equal(settings.lintCadence, "tiered")
			T.truthy(settings.debug)
		end)
	end)

	T.it("returns defaults when the file has no frontmatter", function()
		T.equal(Config.parseSettings("# just markdown\nlint: false\n"), Config.defaults())
	end)

	T.it("tolerates CRLF line endings", function()
		T.equal(Config.parseSettings("---\r\nlint: false\r\n---\r\n").lint, false)
	end)

	T.it("skips malformed lines", function()
		local settings = parse({ "not a pair", ": no key", "lint-cadence: tiered" })
		T.equal(settings.lintCadence, "tiered")
	end)

	T.it("parses the stylua and selene toggles (default on)", function()
		local settings = parse({ "stylua: false", "selene: false" })
		T.falsy(settings.stylua)
		T.falsy(settings.selene)
		T.truthy(parse({ "stylua: yes" }).stylua)
	end)

	T.it("only disables lint/typecheck on the literal false", function()
		T.falsy(parse({ "lint: false" }).lint)
		T.falsy(parse({ "typecheck: false" }).typecheck)
		T.truthy(parse({ "lint: no" }).lint)
	end)

	T.it("parses each lint cadence and falls back to strict", function()
		T.equal(parse({ "lint-cadence: tiered" }).lintCadence, "tiered")
		T.equal(parse({ "lint-cadence: stop-only" }).lintCadence, "stop-only")
		T.equal(parse({ "lint-cadence: sometimes" }).lintCadence, "strict")
	end)

	T.it("parses numbers and falls back on non-numeric values", function()
		T.equal(parse({ "max-lint-errors: 25" }).maxLintErrors, 25)
		T.equal(parse({ "max-lint-errors: lots" }).maxLintErrors, 10)
		T.equal(parse({ "max-lint-attempts: 3" }).maxLintAttempts, 3)
		T.equal(parse({ "max-lint-attempts: abc" }).maxLintAttempts, 1)
	end)

	T.it("parses lint-auto-fix-on-batch and falls back on invalid values", function()
		T.falsy(parse({ "lint-auto-fix-on-batch: false" }).lintAutoFixOnBatch)
		T.truthy(parse({ "lint-auto-fix-on-batch: maybe" }).lintAutoFixOnBatch)
	end)

	T.it("parses comma-separated lists and strips quotes", function()
		local settings = parse({
			'lint-guard-allow: "packages/app/selene.toml, tools/**/stylua.toml,"',
			"typecheck-args: --platform=standard, --formatter=plain",
		})
		T.equal(settings.lintGuardAllow, { "packages/app/selene.toml", "tools/**/stylua.toml" })
		T.equal(settings.typecheckArgs, { "--platform=standard", "--formatter=plain" })
	end)
end)

return nil
