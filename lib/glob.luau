--!strict
-- Minimal glob matcher for `/`-separated relative paths. Supports `*`, `?`,
-- `[...]` character classes, `{a,b}` alternation and `**` (zero or more
-- directories).

local Glob = {}

local function expandBraces(pattern: string): { string }
	local open = string.find(pattern, "{", 1, true)
	if open == nil then
		return { pattern }
	end

	local depth = 0
	local close: number? = nil
	for index = open, #pattern do
		local char = string.sub(pattern, index, index)
		if char == "{" then
			depth += 1
		elseif char == "}" then
			depth -= 1
			if depth == 0 then
				close = index
				break
			end
		end
	end

	if close == nil then
		return { pattern }
	end

	local prefix = string.sub(pattern, 1, open - 1)
	local suffix = string.sub(pattern, close + 1)
	local body = string.sub(pattern, open + 1, close - 1)

	local options: { string } = {}
	local current = ""
	depth = 0
	for index = 1, #body do
		local char = string.sub(body, index, index)
		if char == "," and depth == 0 then
			table.insert(options, current)
			current = ""
		else
			if char == "{" then
				depth += 1
			elseif char == "}" then
				depth -= 1
			end

			current ..= char
		end
	end

	table.insert(options, current)

	local results: { string } = {}
	for _, option in options do
		for _, expanded in expandBraces(prefix .. option .. suffix) do
			table.insert(results, expanded)
		end
	end

	return results
end

local function segmentToLuaPattern(segment: string): string
	local out: { string } = { "^" }
	local index = 1
	while index <= #segment do
		local char = string.sub(segment, index, index)
		if char == "*" then
			table.insert(out, ".*")
		elseif char == "?" then
			table.insert(out, ".")
		elseif char == "[" then
			local close = string.find(segment, "]", index + 1, true)
			if close == nil then
				table.insert(out, "%[")
			else
				local class = string.sub(segment, index + 1, close - 1)
				if string.sub(class, 1, 1) == "!" then
					class = "^" .. string.sub(class, 2)
				end

				class = string.gsub(class, "%%", "%%%%")
				table.insert(out, "[" .. class .. "]")
				index = close
			end
		elseif string.find(char, "^[%^%$%(%)%%%.%]%+%-]") ~= nil then
			table.insert(out, "%" .. char)
		else
			table.insert(out, char)
		end

		index += 1
	end

	table.insert(out, "$")
	return table.concat(out)
end

local function splitSegments(value: string): { string }
	local segments: { string } = {}
	for segment in string.gmatch(value, "[^/]+") do
		table.insert(segments, segment)
	end

	return segments
end

local function matchSegments(
	patterns: { string },
	patternIndex: number,
	parts: { string },
	partIndex: number
): boolean
	if patternIndex > #patterns then
		return partIndex > #parts
	end

	local pattern = patterns[patternIndex]
	if pattern == "**" then
		for next = partIndex, #parts + 1 do
			if matchSegments(patterns, patternIndex + 1, parts, next) then
				return true
			end
		end

		return false
	end

	if partIndex > #parts then
		return false
	end

	if string.find(parts[partIndex], segmentToLuaPattern(pattern)) == nil then
		return false
	end

	return matchSegments(patterns, patternIndex + 1, parts, partIndex + 1)
end

--- Returns true when `path` matches the glob `pattern`.
function Glob.matches(path: string, pattern: string): boolean
	local parts = splitSegments(path)
	for _, expanded in expandBraces(pattern) do
		if matchSegments(splitSegments(expanded), 1, parts, 1) then
			return true
		end
	end

	return false
end

return Glob
