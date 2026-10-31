--!strict

local Config = require("../lib/config")
local H = require("./helpers")
local Lint = require("../lib/lint")
local Path = require("../lib/path")
local Project = require("../lib/project")
local T = require("./harness")

local ERROR_LINE = "3:11: error[undefined_variable]: `foo` is not defined"

local function errorLines(count: number, rule: (index: number) -> string): string
	local lines: { string } = {}
	for index = 1, count do
		table.insert(lines, `{index}:1: error[{rule(index)}]: problem {index}`)
	end

	return table.concat(lines, "\n")
end

T.describe("Project.isInProject", function()
	T.it("returns true when CLAUDE_PROJECT_DIR is unset", function()
		H.withProject("", function()
			T.truthy(Project.isInProject("/anywhere/x.luau"))
		end)
	end)

	T.it("accepts children and the directory itself, rejects siblings", function()
		H.withProject("/work/project", function()
			T.truthy(Project.isInProject("/work/project/src/a.luau"))
			T.truthy(Project.isInProject("/work/project"))
			T.falsy(Project.isInProject("/work/other/a.luau"))
			T.falsy(Project.isInProject("/work/project-two/a.luau"))
		end)
	end)

	T.it("is case-insensitive only on Windows", function()
		H.withProject("C:\\Work\\Project", function()
			T.equal(Project.isInProject("c:/work/project/src/a.luau"), Path.isWindows)
			T.truthy(Project.isInProject("C:\\Work\\Project\\src\\a.luau"))
		end)
	end)
end)

T.describe("Lint.isLintableFile", function()
	T.it("accepts .luau and .lua, rejects others", function()
		T.truthy(Lint.isLintableFile("src/a.luau"))
		T.truthy(Lint.isLintableFile("src/a.lua"))
		T.falsy(Lint.isLintableFile("src/a.ts"))
		T.falsy(Lint.isLintableFile("README.md"))
	end)

	T.it("respects a custom extension list", function()
		T.truthy(Lint.isLintableFile("a.txt", { ".txt" }))
		T.falsy(Lint.isLintableFile("a.luau", { ".txt" }))
	end)
end)

T.describe("Lint.isProtectedFile", function()
	T.it("protects selene, stylua and sentinel config files", function()
		for _, name in
			{ "selene.toml", "stylua.toml", ".stylua.toml", ".styluaignore", "sentinel.local.md" }
		do
			T.truthy(Lint.isProtectedFile(name), name)
		end
	end)

	T.it("checks the basename, not the full path", function()
		T.truthy(Lint.isProtectedFile("C:\\proj\\packages\\app\\selene.toml"))
		T.falsy(Lint.isProtectedFile("/proj/selene.toml/notes.md"))
		T.falsy(Lint.isProtectedFile("/proj/src/stylua_helpers.luau"))
	end)

	T.it("leaves .luaurc and source files editable", function()
		T.falsy(Lint.isProtectedFile(".luaurc"))
		T.falsy(Lint.isProtectedFile("init.luau"))
	end)
end)

T.describe("Lint.isGuardAllowed", function()
	T.it("denies when no patterns are configured", function()
		H.withProject("/proj", function()
			T.falsy(Lint.isGuardAllowed("/proj/selene.toml", {}))
		end)
	end)

	T.it("allows exact and glob matches, denies siblings", function()
		H.withProject("/proj", function()
			T.truthy(
				Lint.isGuardAllowed(
					"/proj/packages/app/selene.toml",
					{ "packages/app/selene.toml" }
				)
			)
			T.truthy(Lint.isGuardAllowed("/proj/tools/a/b/stylua.toml", { "tools/**/stylua.toml" }))
			T.falsy(
				Lint.isGuardAllowed(
					"/proj/packages/lib/selene.toml",
					{ "packages/app/selene.toml" }
				)
			)
		end)
	end)

	T.it("denies files outside the project", function()
		H.withProject("/proj", function()
			T.falsy(Lint.isGuardAllowed("/elsewhere/selene.toml", { "**" }))
		end)
	end)

	T.it("resolves relative paths against the project root", function()
		H.withProject("/proj", function()
			T.truthy(Lint.isGuardAllowed("packages/app/selene.toml", { "packages/app/*" }))
		end)
	end)

	T.it("ignores case only on Windows", function()
		H.withProject("C:/Proj", function()
			T.equal(
				Lint.isGuardAllowed(
					"C:/Proj/Packages/App/selene.toml",
					{ "packages/app/selene.toml" }
				),
				Path.isWindows
			)
		end)
	end)
end)

T.describe("Lint.formatErrors", function()
	T.it("keeps only error lines", function()
		local output = `{ERROR_LINE}\n4:1: warning[unused_variable]: error is unused\n`
		local result = Lint.formatErrors(output)
		T.equal(result.lines, { ERROR_LINE })
		T.equal(result.totalIssues, 1)
	end)

	T.it("caps surfaced lines at the configured max", function()
		local result = Lint.formatErrors(
			errorLines(15, function(index)
				return `rule_{index}`
			end),
			10
		)
		T.equal(#result.lines, 10)
		T.equal(result.totalIssues, 15)
	end)

	T.it("clusters repeated rule violations with a count", function()
		local result = Lint.formatErrors(errorLines(7, function()
			return "undefined_variable"
		end))
		T.equal(#result.lines, 1)
		T.contains(result.lines[1], "(x7, rule: undefined_variable)")
		T.equal(result.totalIssues, 7)
	end)

	T.it("keeps distinct rules separate", function()
		local result = Lint.formatErrors(errorLines(3, function(index)
			return `rule_{index}`
		end))
		T.equal(#result.lines, 3)
	end)
end)

T.describe("Lint.buildHookOutput", function()
	T.it("wraps output in workspace_diagnostics with third-person voice", function()
		local result = Lint.buildHookOutput("foo.luau", { lines = { ERROR_LINE }, totalIssues = 1 })
		local specific = T.present(result.hookSpecificOutput)
		T.equal(specific.hookEventName, "PostToolUse")
		local message = T.present(result.systemMessage)
		T.contains(message, '<workspace_diagnostics source="lint">')
		T.contains(message, "</workspace_diagnostics>")
		T.contains(message, "foo.luau shows 1 issue:")
		T.isNil((string.find(string.lower(message), "%f[%a]you%f[%A]")))
		T.equal(specific.additionalContext, message)
	end)

	T.it("appends an overflow notice only when issues were capped", function()
		local capped = Lint.buildHookOutput("foo.luau", { lines = { ERROR_LINE }, totalIssues = 8 })
		T.contains(capped.systemMessage, "+ 7 more issues")
		T.contains(capped.systemMessage, Lint.LINT_COMMAND)
		local exact = Lint.buildHookOutput("foo.luau", { lines = { ERROR_LINE }, totalIssues = 1 })
		T.notContains(exact.systemMessage, "more issues")
	end)
end)

T.describe("Lint.stopDecision", function()
	local function decide(
		errorFiles: { string },
		attempts: { [string]: number },
		stopAttempts: number
	)
		return Lint.stopDecision({
			errorFiles = errorFiles,
			lintAttempts = attempts,
			maxLintAttempts = 1,
			stopAttempts = stopAttempts,
		})
	end

	T.it("allows stop when there are no errors", function()
		T.isNil(decide({}, {}, 0))
	end)

	T.it("resets stop attempts when errors cleared after prior blocks", function()
		T.equal(decide({}, {}, 2), { resetStopAttempts = true })
	end)

	T.it("blocks when errors exist and attempts are below max", function()
		local result = T.present(decide({ "src/foo.luau" }, {}, 0))
		T.equal(result.decision, "block")
		local reason = T.present(result.reason)
		T.contains(reason, "src/foo.luau")
		T.contains(reason, '<workspace_diagnostics source="lint">')
		T.matches(reason, "%?%s*</workspace_diagnostics>")
	end)

	T.it("allows stop when every erroring file has maxed its attempts", function()
		T.isNil(decide({ "src/foo.luau" }, { ["src/foo.luau"] = 3 }, 0))
	end)

	T.it("matches attempts across absolute/relative and separator differences", function()
		T.isNil(decide({ "src/foo.luau" }, { ["D:/projects/app/src/foo.luau"] = 3 }, 0))
		T.isNil(decide({ "src\\foo.luau" }, { ["src/foo.luau"] = 3 }, 0))
	end)

	T.it("does not false-match different files sharing a suffix", function()
		local result = T.present(decide({ "foo.luau" }, { ["b/foo.luau"] = 3 }, 0))
		T.equal(result.decision, "block")
	end)

	T.it("lets the stop through with an informational reason after a block", function()
		local result = T.present(decide({ "src/foo.luau" }, {}, 1))
		T.isNil(result.decision)
		T.contains(result.reason, "Unresolved lint issues")
	end)
end)

T.describe("Lint.lint (real StyLua + selene)", function()
	local BAD =
		"--!strict\nlocal   M={}\nlocal y = undefinedThing\nfunction M.go()   return y end\nreturn M\n"
	local FORMATTED =
		"--!strict\nlocal M = {}\nlocal y = undefinedThing\nfunction M.go()\n\treturn y\nend\nreturn M\n"

	T.it("formats the file in place and surfaces selene errors", function()
		H.inSandbox("lint-real", { tools = true, configs = true }, function(directory)
			H.write(directory, "src/bad.luau", BAD)
			local file = Path.join(directory, "src/bad.luau")
			local result = Lint.lint(file, Config.defaults())
			T.equal(H.read(directory, "src/bad.luau"), FORMATTED)
			local output = T.present(result)
			T.contains(output.systemMessage, "shows 1 issue")
			T.contains(output.systemMessage, "error[undefined_variable]")
		end)
	end)

	T.it("returns nil for a clean file", function()
		H.inSandbox("lint-clean", { tools = true, configs = true }, function(directory)
			H.write(directory, "src/ok.luau", "--!strict\nlocal x = 1\nreturn x\n")
			T.isNil(Lint.lint(Path.join(directory, "src/ok.luau"), Config.defaults()))
		end)
	end)

	T.it("reports StyLua parse failures", function()
		H.inSandbox("lint-syntax", { tools = true, configs = true }, function(directory)
			H.write(directory, "src/broken.luau", "local x = (\n")
			local settings = Config.defaults()
			settings.selene = false
			local output = T.present(Lint.lint(Path.join(directory, "src/broken.luau"), settings))
			T.contains(output.systemMessage, "error[stylua]")
		end)
	end)

	T.it("honours the stylua/selene toggles", function()
		H.inSandbox("lint-toggles", { tools = true, configs = true }, function(directory)
			H.write(directory, "src/bad.luau", BAD)
			local settings = Config.defaults()
			settings.stylua = false
			settings.selene = false
			T.isNil(Lint.lint(Path.join(directory, "src/bad.luau"), settings))
			T.equal(H.read(directory, "src/bad.luau"), BAD)
		end)
	end)

	T.it("skips silently when the project has no configs", function()
		H.inSandbox("lint-noconfig", { tools = true }, function(directory)
			H.write(directory, "src/bad.luau", BAD)
			T.isNil(Lint.lint(Path.join(directory, "src/bad.luau"), Config.defaults()))
			T.equal(H.read(directory, "src/bad.luau"), BAD)
		end)
	end)

	T.it("skips silently when the tools are not resolvable", function()
		H.inSandbox("lint-notools", { configs = true }, function(directory)
			H.write(directory, "src/bad.luau", BAD)
			T.isNil(Lint.lint(Path.join(directory, "src/bad.luau"), Config.defaults()))
		end)
	end)

	T.it("ignores non-lintable and missing files", function()
		H.inSandbox("lint-skip", { tools = true, configs = true }, function(directory)
			H.write(directory, "notes.md", "# hi")
			T.isNil(Lint.lint(Path.join(directory, "notes.md"), Config.defaults()))
			T.isNil(Lint.lint(Path.join(directory, "missing.luau"), Config.defaults()))
		end)
	end)
end)

return nil
