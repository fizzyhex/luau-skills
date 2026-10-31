--!strict
-- Reverse require graph via `luau-lsp require-graph`, which understands
-- require-by-string, `.luaurc` aliases and (with a sourcemap) Roblox
-- `require(script.Parent...)` instance paths.

local serde = require("@lune/serde")

local Io = require("./io")
local LuauLsp = require("./luaulsp")
local Path = require("./path")
local Project = require("./project")
local Tools = require("./tools")

type Log = Io.Log

export type RequireGraph = {
	nodes: { string },
	edges: { { string } },
}

local Graph = {}

local NO_LOG = Io.createLog(false)

-- Keep each invocation comfortably under the Windows command-line limit.
local MAX_ARGS_LENGTH = 24000

--- Files to scan: git-visible Luau files (tracked plus untracked, honouring
--- `.gitignore`, so submodules and installed `Packages/` are skipped), or the
--- whole project directory outside a git repository.
function Graph.scanTargets(): { string }
	local root = Project.root()
	local result = Tools.exec(
		"git",
		{ "ls-files", "--cached", "--others", "--exclude-standard", "--", "*.luau", "*.lua" },
		root
	)
	if result == nil or not result.ok then
		return { root }
	end

	local files: { string } = {}
	for line in string.gmatch(result.stdout, "[^\r\n]+") do
		if Project.isFile(Path.join(root, line)) then
			table.insert(files, line)
		end
	end

	return files
end

local function chunk(targets: { string }): { { string } }
	local chunks: { { string } } = {}
	local current: { string } = {}
	local length = 0
	for _, target in targets do
		if #current > 0 and length + #target + 1 > MAX_ARGS_LENGTH then
			table.insert(chunks, current)
			current = {}
			length = 0
		end

		table.insert(current, target)
		length += #target + 1
	end

	if #current > 0 then
		table.insert(chunks, current)
	end

	return chunks
end

--- Builds the project's require graph. Edges are `{ requirer, required }`.
function Graph.requireGraph(log: Log?): RequireGraph?
	local logger = log or NO_LOG
	if not LuauLsp.isAvailable() then
		logger.debug("require-graph: luau-lsp not resolvable, skipped")
		return nil
	end

	local projectArgs = LuauLsp.projectArgs(false, logger)
	if projectArgs == nil then
		return nil
	end

	local root = Project.root()
	local targets = Graph.scanTargets()
	local graph: RequireGraph = { nodes = {}, edges = {} }
	if #targets == 0 then
		return graph
	end

	local seenNodes: { [string]: boolean } = {}
	local seenEdges: { [string]: boolean } = {}
	for _, group in chunk(targets) do
		local args = table.clone(projectArgs)
		table.insert(args, 1, "require-graph")
		table.move(group, 1, #group, #args + 1, args)

		local result = Tools.exec(LuauLsp.PROGRAM, args, root)
		if result == nil or not result.ok then
			logger.debug("require-graph: luau-lsp require-graph failed")
			return nil
		end

		local ok, decoded = pcall(serde.decode, "json" :: "json", result.stdout)
		if not ok or type(decoded) ~= "table" or type(decoded.edges) ~= "table" then
			logger.debug("require-graph: unexpected output")
			return nil
		end

		for _, node in decoded.nodes or {} do
			if type(node) == "string" then
				local normalized = Path.normalize(node)
				if not seenNodes[Path.key(normalized)] then
					seenNodes[Path.key(normalized)] = true
					table.insert(graph.nodes, normalized)
				end
			end
		end

		for _, edge in decoded.edges do
			if
				type(edge) == "table"
				and type(edge[1]) == "string"
				and type(edge[2]) == "string"
			then
				local from, to = Path.normalize(edge[1]), Path.normalize(edge[2])
				local key = Path.key(from) .. "|" .. Path.key(to)
				if not seenEdges[key] then
					seenEdges[key] = true
					table.insert(graph.edges, { from, to })
				end
			end
		end
	end

	return graph
end

--- Files that (transitively) require `target` within `graph`.
function Graph.importersOf(graph: RequireGraph, target: string): { string }
	local key = Path.key(target)
	local importers: { string } = {}
	for _, edge in graph.edges do
		if Path.key(edge[2]) == key then
			table.insert(importers, edge[1])
		end
	end

	return importers
end

--- Transitive dependents of `files`, excluding the files themselves.
function Graph.dependentsIn(graph: RequireGraph, files: { string }): { string }
	local visited: { [string]: boolean } = {}
	local queue: { string } = {}
	for _, file in files do
		local resolved = Project.resolve(file)
		local key = Path.key(resolved)
		if not visited[key] then
			visited[key] = true
			table.insert(queue, resolved)
		end
	end

	local originals = table.clone(visited)
	local dependents: { string } = {}
	local index = 1
	while index <= #queue do
		local current = queue[index]
		index += 1
		for _, importer in Graph.importersOf(graph, current) do
			local key = Path.key(importer)
			if not visited[key] then
				visited[key] = true
				table.insert(queue, importer)
				if not originals[key] then
					table.insert(dependents, importer)
				end
			end
		end
	end

	return dependents
end

--- Transitive dependents of `files` in the current project; empty when the
--- graph cannot be built.
function Graph.getTransitiveDependents(files: { string }, log: Log?): { string }
	if #files == 0 then
		return {}
	end

	local graph = Graph.requireGraph(log)
	if graph == nil then
		return {}
	end

	return Graph.dependentsIn(graph, files)
end

return Graph
