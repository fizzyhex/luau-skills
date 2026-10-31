--!strict
-- Submodule management for skill sources.
--
-- Usage: lune run scripts/cli <command>
--   init     add any submodule from meta.luau that is missing
--   sync     copy vendored skills into skills/ and record SYNC.md
--   check    report how many commits each source is behind its remote
--   cleanup  remove submodules and skills no longer listed in meta.luau

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local meta = require("../meta")

local function warn(message: string)
	stdio.ewrite(`{message}\n`)
end

local function git(args: { string }, cwd: string?): (boolean, string)
	local result = process.exec("git", args, { cwd = cwd or process.cwd })
	if not result.ok then
		return false, result.stderr
	end
	return true, (string.gsub(result.stdout, "%s+$", ""))
end

local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function listDirectories(path: string): { string }
	if not fs.isDir(path) then
		return {}
	end
	local names = {}
	for _, name in fs.readDir(path) do
		if fs.isDir(`{path}/{name}`) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

local function copyTree(from: string, to: string)
	fs.writeDir(to)
	for _, name in fs.readDir(from) do
		local source, target = `{from}/{name}`, `{to}/{name}`
		if fs.isDir(source) then
			copyTree(source, target)
		else
			fs.copy(source, target, true)
		end
	end
end

local function addSubmodule(path: string, url: string)
	if fs.isDir(`{path}/.git`) or fs.isFile(`{path}/.git`) then
		return
	end
	local _, indexed = git({ "ls-files", "--", path })
	if indexed ~= "" then
		print(`= {path} (registered, checking out)`)
		git({ "submodule", "update", "--init", "--depth", "1", "--", path })
		return
	end
	print(`+ {path} <- {url}`)
	local ok, err = git({ "submodule", "add", "--depth", "1", url, path })
	if not ok then
		warn(`  failed: {err}`)
	end
end

local function removeSubmodule(path: string)
	print(`- {path}`)
	git({ "submodule", "deinit", "-f", path })
	git({ "rm", "-f", path })
	if fs.isDir(`.git/modules/{path}`) then
		fs.removeDir(`.git/modules/{path}`)
	end
end

local commands: { [string]: () -> () } = {}

function commands.init()
	for _, name in sortedKeys(meta.submodules) do
		addSubmodule(`sources/{name}`, meta.submodules[name])
	end
	for _, name in sortedKeys(meta.vendors) do
		addSubmodule(`vendor/{name}`, meta.vendors[name].source)
	end
end

function commands.sync()
	git({ "submodule", "update", "--remote", "--merge" })
	local date = os.date("!%Y-%m-%d")
	for _, vendor in sortedKeys(meta.vendors) do
		local vendorPath = `vendor/{vendor}`
		local _, sha = git({ "rev-parse", "HEAD" }, vendorPath)
		for sourceName, outputName in meta.vendors[vendor].skills do
			local from, to = `{vendorPath}/skills/{sourceName}`, `skills/{outputName}`
			if not fs.isDir(from) then
				warn(`missing {from}`)
				continue
			end
			if fs.isDir(to) then
				fs.removeDir(to)
			end
			copyTree(from, to)
			fs.writeFile(
				`{to}/SYNC.md`,
				`# Sync Info\n\n- **Source:** \`{from}\`\n- **Git SHA:** \`{sha}\`\n- **Synced:** {date}\n`
			)
			print(`synced {from} -> {to}`)
		end
	end
end

function commands.check()
	local paths = {}
	for _, name in sortedKeys(meta.submodules) do
		table.insert(paths, `sources/{name}`)
	end
	for _, name in sortedKeys(meta.vendors) do
		table.insert(paths, `vendor/{name}`)
	end
	for _, path in paths do
		if not fs.isDir(path) then
			print(`{path}: not initialised (run init)`)
			continue
		end
		git({ "fetch", "--quiet" }, path)
		git({ "remote", "set-head", "origin", "--auto" }, path)
		local ok, behind = git({ "rev-list", "--count", "HEAD..origin/HEAD" }, path)
		print(`{path}: {if ok then `{behind} commit(s) behind` else "no upstream"}`)
	end
end

function commands.cleanup()
	local expectedSkills: { [string]: boolean } = {}
	for name in meta.submodules do
		expectedSkills[name] = true
	end
	for _, vendor in meta.vendors do
		for _, outputName in vendor.skills do
			expectedSkills[outputName] = true
		end
	end
	for _, name in meta.manual do
		expectedSkills[name] = true
	end

	local listedByRoot: { [string]: { [string]: any } } = {
		sources = meta.submodules,
		vendor = meta.vendors,
	}
	for root, listed in listedByRoot do
		for _, name in listDirectories(root) do
			if listed[name] == nil then
				removeSubmodule(`{root}/{name}`)
			end
		end
	end
	for _, name in listDirectories("skills") do
		if not expectedSkills[name] then
			print(`- skills/{name}`)
			fs.removeDir(`skills/{name}`)
		end
	end
end

local command = process.args[1]
local run = command and commands[command]
if not run then
	print("usage: lune run scripts/cli <init|sync|check|cleanup>")
	process.exit(if command then 1 else 0)
end
assert(run, "unreachable")()
