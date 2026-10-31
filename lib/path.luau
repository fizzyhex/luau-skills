--!strict
-- Platform-aware path helpers. Every path is handled with `/` separators
-- internally; Windows drive letters and case-insensitive comparison are
-- supported so hooks behave the same on every OS.

local process = require("@lune/process")

local Path = {}

Path.isWindows = process.os == "windows"

local function splitRoot(path: string): (string, string)
	local drive = string.match(path, "^(%a:)/")
	if drive ~= nil then
		return string.upper(string.sub(drive, 1, 1)) .. ":/", string.sub(path, 4)
	end

	if string.match(path, "^%a:$") ~= nil then
		return string.upper(string.sub(path, 1, 1)) .. ":/", ""
	end

	if string.sub(path, 1, 2) == "//" then
		return "//", string.sub(path, 3)
	end

	if string.sub(path, 1, 1) == "/" then
		return "/", string.sub(path, 2)
	end

	return "", path
end

function Path.toSlash(path: string): string
	return (string.gsub(path, "\\", "/"))
end

function Path.isAbsolute(path: string): boolean
	local root = splitRoot(Path.toSlash(path))
	return root ~= ""
end

--- Collapses `.`/`..` segments and duplicate separators.
function Path.normalize(path: string): string
	local root, rest = splitRoot(Path.toSlash(path))
	local segments: { string } = {}
	for segment in string.gmatch(rest, "[^/]+") do
		if segment == "." then
			continue
		end

		if segment == ".." then
			local last = segments[#segments]
			if last ~= nil and last ~= ".." then
				table.remove(segments)
			elseif root == "" then
				table.insert(segments, "..")
			end

			continue
		end

		table.insert(segments, segment)
	end

	local joined = table.concat(segments, "/")
	if root == "" and joined == "" then
		return "."
	end

	return root .. joined
end

function Path.join(...: string): string
	local parts: { string } = {}
	for _, part in { ... } do
		if part ~= "" then
			table.insert(parts, part)
		end
	end

	return Path.normalize(table.concat(parts, "/"))
end

function Path.cwd(): string
	return Path.normalize(process.cwd)
end

--- Resolves `path` against `base` (default: the process working directory).
function Path.resolve(path: string, base: string?): string
	if Path.isAbsolute(path) then
		return Path.normalize(path)
	end

	return Path.join(base or Path.cwd(), path)
end

function Path.dirname(path: string): string
	local normalized = Path.normalize(path)
	local root, rest = splitRoot(normalized)
	local index = string.find(rest, "/[^/]*$")
	if index == nil then
		if root ~= "" then
			return root
		end

		return "."
	end

	return root .. string.sub(rest, 1, index - 1)
end

function Path.basename(path: string): string
	local normalized = Path.toSlash(path)
	return string.match(normalized, "([^/]*)/*$") or normalized
end

function Path.extension(path: string): string
	return string.match(Path.basename(path), "(%.[^%.]+)$") or ""
end

--- Comparison key: normalized, and lower-cased on Windows.
function Path.key(path: string): string
	local resolved = Path.resolve(path)
	if Path.isWindows then
		return string.lower(resolved)
	end

	return resolved
end

function Path.equals(left: string, right: string): boolean
	return Path.key(left) == Path.key(right)
end

--- True when `child` is `parent` or lives somewhere beneath it.
function Path.isWithin(child: string, parent: string): boolean
	local childKey = Path.key(child)
	local parentKey = Path.key(parent)
	if childKey == parentKey then
		return true
	end

	local prefix = if string.sub(parentKey, -1) == "/" then parentKey else parentKey .. "/"
	return string.sub(childKey, 1, #prefix) == prefix
end

local function segmentsOf(path: string): (string, { string })
	local root, rest = splitRoot(Path.resolve(path))
	local segments: { string } = {}
	for segment in string.gmatch(rest, "[^/]+") do
		table.insert(segments, segment)
	end

	return root, segments
end

local function sameSegment(left: string, right: string): boolean
	if Path.isWindows then
		return string.lower(left) == string.lower(right)
	end

	return left == right
end

--- Relative path from directory `from` to `to`, `/`-separated. Returns the
--- absolute `to` when the two paths live on different roots.
function Path.relative(from: string, to: string): string
	local fromRoot, fromSegments = segmentsOf(from)
	local toRoot, toSegments = segmentsOf(to)
	if not sameSegment(fromRoot, toRoot) then
		return Path.resolve(to)
	end

	local common = 0
	while
		common < #fromSegments
		and common < #toSegments
		and sameSegment(fromSegments[common + 1], toSegments[common + 1])
	do
		common += 1
	end

	local parts: { string } = {}
	for _ = common + 1, #fromSegments do
		table.insert(parts, "..")
	end

	for index = common + 1, #toSegments do
		table.insert(parts, toSegments[index])
	end

	if #parts == 0 then
		return "."
	end

	return table.concat(parts, "/")
end

return Path
