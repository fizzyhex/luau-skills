--!strict

local Glob = require("../lib/glob")
local Path = require("../lib/path")
local T = require("./harness")

T.describe("Path", function()
	T.it("normalizes separators, dots and drive letters", function()
		T.equal(Path.normalize("c:\\Users\\me\\.\\a\\..\\b\\"), "C:/Users/me/b")
		T.equal(Path.normalize("/srv//app/./x/../y"), "/srv/app/y")
		T.equal(Path.normalize("a/../../b"), "../b")
		T.equal(Path.normalize("C:/"), "C:/")
	end)

	T.it("detects absolute paths", function()
		T.truthy(Path.isAbsolute("C:\\x"))
		T.truthy(Path.isAbsolute("/x"))
		T.falsy(Path.isAbsolute("src/x.luau"))
	end)

	T.it("resolves relative paths against a base", function()
		T.equal(Path.resolve("src/a.luau", "C:/proj dir"), "C:/proj dir/src/a.luau")
		T.equal(Path.resolve("D:\\other\\b.luau", "C:/proj"), "D:/other/b.luau")
	end)

	T.it("computes dirname and basename", function()
		T.equal(Path.dirname("C:/a/b/c.luau"), "C:/a/b")
		T.equal(Path.dirname("C:/a"), "C:/")
		T.equal(Path.basename("C:\\a\\b\\c.luau"), "c.luau")
		T.equal(Path.extension("x/init.server.luau"), ".luau")
	end)

	T.it("computes relative paths", function()
		T.equal(Path.relative("/p", "/p/src/a.luau"), "src/a.luau")
		T.equal(Path.relative("/p/src", "/p/lib/b.luau"), "../lib/b.luau")
		T.equal(Path.relative("/p", "/p"), ".")
	end)

	T.it("checks containment without prefix false-positives", function()
		T.truthy(Path.isWithin("/p/src/a.luau", "/p"))
		T.truthy(Path.isWithin("/p", "/p"))
		T.falsy(Path.isWithin("/project-other/a.luau", "/project"))
	end)

	T.it("compares case-insensitively only on Windows", function()
		T.equal(Path.equals("C:/Proj/A.luau", "c:\\proj\\a.luau"), Path.isWindows)
		if Path.isWindows then
			T.equal(Path.relative("C:/PROJ", "c:/proj/src/a.luau"), "src/a.luau")
		end
	end)
end)

T.describe("Glob", function()
	T.it("matches exact paths", function()
		T.truthy(Glob.matches("packages/app/selene.toml", "packages/app/selene.toml"))
		T.falsy(Glob.matches("packages/lib/selene.toml", "packages/app/selene.toml"))
	end)

	T.it("supports * within a segment only", function()
		T.truthy(Glob.matches("tools/stylua.toml", "tools/*.toml"))
		T.falsy(Glob.matches("tools/x/stylua.toml", "tools/*.toml"))
	end)

	T.it("supports ** across directories, including zero", function()
		T.truthy(Glob.matches("tools/a/b/selene.toml", "tools/**/selene.toml"))
		T.truthy(Glob.matches("tools/selene.toml", "tools/**/selene.toml"))
		T.truthy(Glob.matches("x/y/z", "**"))
	end)

	T.it("supports ?, character classes and braces", function()
		T.truthy(Glob.matches("a1.toml", "a?.toml"))
		T.truthy(Glob.matches("b.toml", "[ab].toml"))
		T.falsy(Glob.matches("c.toml", "[ab].toml"))
		T.truthy(Glob.matches(".stylua.toml", "{stylua,.stylua}.toml"))
	end)

	T.it("escapes Lua pattern characters", function()
		T.truthy(Glob.matches("a-b+c(1).toml", "a-b+c(1).toml"))
		T.falsy(Glob.matches("axtoml", "a.toml"))
	end)
end)

return nil
