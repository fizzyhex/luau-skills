--!strict
-- Tiny test harness: describe/it registration plus assertion helpers.

local stdio = require("@lune/stdio")

type Test = {
	name: string,
	body: () -> (),
}

local Harness = {}

local tests: { Test } = {}
local scopes: { string } = {}

function Harness.describe(name: string, body: () -> ())
	table.insert(scopes, name)
	body()
	table.remove(scopes)
end

function Harness.it(name: string, body: () -> ())
	local parts = table.clone(scopes)
	table.insert(parts, name)
	table.insert(tests, { name = table.concat(parts, " > "), body = body })
end

local function render(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end

	if type(value) ~= "table" then
		return tostring(value)
	end

	local keys: { string } = {}
	for key in value do
		table.insert(keys, tostring(key))
	end

	table.sort(keys)
	local parts: { string } = {}
	for _, key in keys do
		local raw = value[key]
		if raw == nil then
			raw = value[tonumber(key)]
		end

		table.insert(parts, `{key}={render(raw)}`)
	end

	return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(left: any, right: any): boolean
	if type(left) ~= "table" or type(right) ~= "table" then
		return left == right
	end

	for key, value in left do
		if not deepEqual(value, right[key]) then
			return false
		end
	end

	for key in right do
		if left[key] == nil then
			return false
		end
	end

	return true
end

local function fail(message: string, context: string?)
	error(if context ~= nil then `{context}: {message}` else message, 3)
end

function Harness.equal(actual: any, expected: any, context: string?)
	if not deepEqual(actual, expected) then
		fail(`expected {render(expected)}, got {render(actual)}`, context)
	end
end

function Harness.truthy(value: any, context: string?)
	if not value then
		fail(`expected a truthy value, got {render(value)}`, context)
	end
end

function Harness.falsy(value: any, context: string?)
	if value then
		fail(`expected a falsy value, got {render(value)}`, context)
	end
end

--- Asserts `value` is non-nil and returns it, narrowed.
function Harness.present<V>(value: V?, context: string?): V
	if value == nil then
		fail("expected a value, got nil", context)
	end

	return value :: V
end

function Harness.isNil(value: any, context: string?)
	if value ~= nil then
		fail(`expected nil, got {render(value)}`, context)
	end
end

local function contains(haystack: any, needle: any): boolean
	if type(haystack) == "string" then
		return string.find(haystack, tostring(needle), 1, true) ~= nil
	end

	if type(haystack) == "table" then
		for _, value in haystack do
			if deepEqual(value, needle) then
				return true
			end
		end
	end

	return false
end

function Harness.contains(haystack: any, needle: any, context: string?)
	if not contains(haystack, needle) then
		fail(`expected {render(haystack)} to contain {render(needle)}`, context)
	end
end

function Harness.notContains(haystack: any, needle: any, context: string?)
	if contains(haystack, needle) then
		fail(`expected {render(haystack)} not to contain {render(needle)}`, context)
	end
end

function Harness.matches(value: string, pattern: string, context: string?)
	if string.find(value, pattern) == nil then
		fail(`expected {render(value)} to match pattern {render(pattern)}`, context)
	end
end

function Harness.throws(body: () -> (), needle: string?, context: string?)
	local ok, err = pcall(function(): nil
		body()
		return nil
	end)
	if ok then
		fail("expected an error to be thrown", context)
	elseif needle ~= nil and string.find(tostring(err), needle, 1, true) == nil then
		fail(`expected error containing {render(needle)}, got {render(tostring(err))}`, context)
	end
end

--- Runs every registered test whose name contains `filter`.
function Harness.run(filter: string?): (number, number)
	local passed, failed = 0, 0
	for _, test in tests do
		if filter ~= nil and string.find(test.name, filter, 1, true) == nil then
			continue
		end

		local ok, err = xpcall(function(): nil
			test.body()
			return nil
		end, function(message: any): string
			return tostring(message)
		end)
		if ok then
			passed += 1
			stdio.write(`{stdio.color("green")}PASS{stdio.color("reset")} {test.name}\n`)
		else
			failed += 1
			stdio.write(`{stdio.color("red")}FAIL{stdio.color("reset")} {test.name}\n    {err}\n`)
		end
	end

	stdio.write(`\n{passed} passed, {failed} failed\n`)
	return passed, failed
end

return Harness
