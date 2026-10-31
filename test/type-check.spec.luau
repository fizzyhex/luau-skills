--!strict

local process = require("@lune/process")

local Config = require("../lib/config")
local Graph = require("../lib/graph")
local H = require("./helpers")
local LuauLsp = require("../lib/luaulsp")
local Path = require("../lib/path")
local T = require("./harness")
local Typecheck = require("../lib/typecheck")

local OUTPUT = table.concat({
	"[INFO] sourcemap is disabled",
	"src/a.luau(3,1): TypeError: Expected this to be 'number', but got 'string'",
	"src/a.luau(4,7): LocalUnused: Variable 'x' is never used",
	"src/b.luau(1,1): SyntaxError: Expected identifier",
	"src/a.luau(9,2): TypeError: Unknown global 'foo'",
}, "\n")

T.describe("Typecheck helpers", function()
	T.it("type-checks .luau and .lua files only", function()
		T.truthy(Typecheck.isTypeCheckable("a.luau"))
		T.truthy(Typecheck.isTypeCheckable("a.lua"))
		T.falsy(Typecheck.isTypeCheckable("a.json"))
		T.falsy(Typecheck.isTypeCheckable("a.ts"))
	end)

	T.it("parses error diagnostics and ignores lint warnings", function()
		H.withProject("/proj", function()
			local diagnostics = Typecheck.parseDiagnostics(OUTPUT)
			T.equal(#diagnostics, 3)
			T.equal(diagnostics[1].file, "/proj/src/a.luau")
			T.equal(diagnostics[2].file, "/proj/src/b.luau")
		end)
	end)

	T.it("separates edited-file errors from dependency errors", function()
		H.withProject("/proj", function()
			local partition =
				Typecheck.partitionErrors(Typecheck.parseDiagnostics(OUTPUT), "/proj/src/a.luau")
			T.equal(#partition.fileErrors, 2)
			T.equal(
				partition.dependencyErrors,
				{ "src/b.luau(1,1): SyntaxError: Expected identifier" }
			)
		end)
	end)

	T.it("lists which files have errors", function()
		H.withProject("/proj", function()
			local files = { "/proj/src/a.luau", "src/b.luau", "/proj/src/c.luau" }
			T.equal(Typecheck.errorFiles(files, OUTPUT), { "/proj/src/a.luau", "src/b.luau" })
			T.equal(Typecheck.errorFiles(files, nil), {})
		end)
	end)
end)

T.describe("Typecheck.buildTypeCheckOutput", function()
	T.it("formats file errors and dependency errors separately", function()
		local result = Typecheck.buildTypeCheckOutput({
			dependencyErrors = { "b.luau(1,1): TypeError: y" },
			fileErrors = { "a.luau(1,1): TypeError: x" },
			totalDependencyErrors = 1,
			totalFileErrors = 1,
		})
		local message = T.present(result.systemMessage)
		T.contains(message, "luau-lsp found 1 type error in edited file:")
		T.contains(message, "luau-lsp found 1 type error in other files:")
		T.equal(T.present(result.hookSpecificOutput).hookEventName, "PostToolUse")
	end)

	T.it("shows totals and a truncation hint when capped", function()
		local result = Typecheck.buildTypeCheckOutput({
			dependencyErrors = {},
			fileErrors = { "a", "b" },
			totalDependencyErrors = 0,
			totalFileErrors = 9,
		})
		T.contains(result.systemMessage, "9 type errors in edited file")
		T.contains(result.systemMessage, "\n...")
		T.contains(
			T.present(result.hookSpecificOutput).additionalContext,
			"(run typecheck to view more)"
		)
	end)

	T.it("only shows dependency errors when the edited file is clean", function()
		local result = Typecheck.buildTypeCheckOutput({
			dependencyErrors = { "b" },
			fileErrors = {},
			totalDependencyErrors = 1,
			totalFileErrors = 0,
		})
		T.notContains(result.systemMessage, "edited file")
		T.contains(result.systemMessage, "other files")
	end)
end)

T.describe("Typecheck.typecheckStopDecision", function()
	local function decide(
		errorFiles: { string },
		attempts: { [string]: number },
		stopAttempts: number
	)
		return Typecheck.typecheckStopDecision({
			errorFiles = errorFiles,
			lintAttempts = attempts,
			maxLintAttempts = 1,
			stopAttempts = stopAttempts,
		})
	end

	T.it("returns nil when there are no errors", function()
		T.isNil(decide({}, {}, 0))
	end)

	T.it("blocks while attempts remain", function()
		local result = T.present(decide({ "a.luau" }, {}, 0))
		T.equal(result.decision, "block")
		T.contains(result.reason, "Type errors detected in: a.luau")
	end)

	T.it("allows stop when every file is maxed out", function()
		T.isNil(decide({ "a.luau" }, { ["a.luau"] = 1 }, 0))
	end)

	T.it("allows stop after the max stop attempts with a reason", function()
		local result = T.present(decide({ "a.luau" }, {}, 3))
		T.isNil(result.decision)
		T.contains(result.reason, "Unresolved type errors")
	end)

	T.it("resets stop attempts when errors are resolved", function()
		T.equal(decide({}, {}, 2), { resetStopAttempts = true })
	end)
end)

T.describe("luau-lsp project arguments", function()
	T.it("uses the standard platform for plain projects", function()
		H.inSandbox("tc-standard", nil, function()
			T.equal(LuauLsp.detectPlatform(), "standard")
			T.equal(LuauLsp.projectArgs(true), { "--platform=standard" })
		end)
	end)

	T.it("passes sourcemap, base .luaurc and cached Roblox definitions", function()
		H.inSandbox("tc-roblox", nil, function(directory)
			H.write(directory, "sourcemap.json", "{}")
			H.write(directory, ".luaurc", "{}")
			H.write(directory, ".claude/state/luau-lsp/globalTypes.d.luau", "declare game: any\n")
			T.equal(LuauLsp.detectPlatform(), "roblox")
			T.equal(LuauLsp.projectArgs(true), {
				"--platform=roblox",
				`--definitions={Path.join(directory, ".claude/state/luau-lsp/globalTypes.d.luau")}`,
				`--sourcemap={Path.join(directory, "sourcemap.json")}`,
				`--base-luaurc={Path.join(directory, ".luaurc")}`,
			})
		end)
	end)

	T.it("detects Rojo project files and honours .vscode platform settings", function()
		H.inSandbox("tc-detect", nil, function(directory)
			H.write(directory, "default.project.json", "{}")
			T.equal(LuauLsp.detectPlatform(), "roblox")
			H.write(
				directory,
				".vscode/settings.json",
				'{\n\t// jsonc\n\t"luau-lsp.platform.type": "standard",\n}\n'
			)
			T.equal(LuauLsp.detectPlatform(), "standard")
		end)
	end)

	T.it("replaces the automatic flags with typecheck-args", function()
		H.inSandbox("tc-args", nil, function(directory)
			H.write(directory, "sourcemap.json", "{}")
			local settings = Config.defaults()
			settings.typecheckArgs = { "--platform=standard", "--formatter=plain" }
			T.equal(
				Typecheck.analyzeArgs({ Path.join(directory, "src/a.luau") }, settings),
				{ "analyze", "--platform=standard", "--formatter=plain", "src/a.luau" }
			)
		end)
	end)
end)

T.describe("Graph.scanTargets", function()
	T.it("falls back to the project root outside git", function()
		H.inSandbox("graph-nogit", nil, function(directory)
			T.equal(Graph.scanTargets(), { directory })
		end)
	end)

	T.it("lists tracked and untracked Luau files, skipping ignored ones", function()
		H.inSandbox("graph-git", nil, function(directory)
			process.exec("git", { "init", "-q" }, { cwd = directory })
			H.write(directory, ".gitignore", "Packages/\n")
			H.write(directory, "src/a.luau", "return 1\n")
			H.write(directory, "src/b.lua", "return 2\n")
			H.write(directory, "Packages/dep.luau", "return 3\n")
			H.write(directory, "notes.md", "# notes\n")
			local targets = Graph.scanTargets()
			table.sort(targets)
			T.equal(targets, { "src/a.luau", "src/b.lua" })
		end)
	end)
end)

T.describe("Graph.dependentsIn", function()
	local graph = {
		nodes = {},
		edges = {
			{ "/p/b.luau", "/p/a.luau" },
			{ "/p/c.luau", "/p/b.luau" },
			{ "/p/d.luau", "/p/a.luau" },
			{ "/p/a.luau", "/p/e.luau" },
		},
	}

	T.it("returns direct and transitive importers, excluding the inputs", function()
		H.withProject("/p", function()
			local dependents = Graph.dependentsIn(graph, { "/p/a.luau" })
			table.sort(dependents)
			T.equal(dependents, { "/p/b.luau", "/p/c.luau", "/p/d.luau" })
		end)
	end)

	T.it("does not include files that are themselves inputs", function()
		H.withProject("/p", function()
			local dependents = Graph.dependentsIn(graph, { "/p/a.luau", "/p/b.luau" })
			table.sort(dependents)
			T.equal(dependents, { "/p/c.luau", "/p/d.luau" })
		end)
	end)

	T.it("returns nothing for a leaf module", function()
		H.withProject("/p", function()
			T.equal(Graph.dependentsIn(graph, { "/p/c.luau" }), {})
		end)
	end)
end)

T.describe("Typecheck.typeCheck (real luau-lsp)", function()
	T.it("reports errors in the edited file and its dependents", function()
		H.inSandbox("tc-real", { tools = true }, function(directory)
			H.write(
				directory,
				"src/lib.luau",
				"--!strict\nlocal M = {}\nfunction M.go(): number\n\treturn 1\nend\nreturn M\n"
			)
			H.write(
				directory,
				"src/user.luau",
				'--!strict\nlocal lib = require("./lib")\nlocal s: string = lib.go()\nreturn s\n'
			)
			H.write(directory, "src/own.luau", '--!strict\nlocal n: number = "x"\nreturn n\n')

			local deps =
				Typecheck.typeCheck(Path.join(directory, "src/lib.luau"), Config.defaults())
			local depMessage = T.present(T.present(deps).systemMessage)
			T.contains(depMessage, "in other files")
			T.contains(depMessage, "src/user.luau(3,1)")

			local own = Typecheck.typeCheck(Path.join(directory, "src/own.luau"), Config.defaults())
			T.contains(T.present(own).systemMessage, "1 type error in edited file")
		end)
	end)

	T.it("returns nil for clean files and when luau-lsp is unavailable", function()
		H.inSandbox("tc-clean", { tools = true }, function(directory)
			H.write(directory, "src/ok.luau", "--!strict\nlocal n: number = 1\nreturn n\n")
			T.isNil(Typecheck.typeCheck(Path.join(directory, "src/ok.luau"), Config.defaults()))
		end)

		H.inSandbox("tc-notools", nil, function(directory)
			H.write(directory, "src/bad.luau", '--!strict\nlocal n: number = "x"\nreturn n\n')
			T.isNil(Typecheck.typeCheck(Path.join(directory, "src/bad.luau"), Config.defaults()))
		end)
	end)
end)

return nil
