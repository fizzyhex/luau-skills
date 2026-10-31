--!strict
-- Project metadata: which repositories skills are generated or synced from.

export type VendorSkillMeta = {
	official: boolean?,
	-- Skills to sync verbatim: sourceSkillName -> outputSkillName.
	skills: { [string]: string },
	source: string,
}

local meta = {}

-- Repositories to clone as submodules (`sources/{name}`) and generate skills from.
meta.submodules = {
	["ecs-faq"] = "https://github.com/SanderMertens/ecs-faq",
	["flecs"] = "https://github.com/SanderMertens/flecs",
	["jecs"] = "https://github.com/Ukendio/jecs",
	["jest"] = "https://github.com/Roblox/jest-roblox",
	["luau"] = "https://github.com/luau-lang/site",
} :: { [string]: string }

-- Projects that already ship skills; synced from `vendor/{name}/skills/`.
meta.vendors = {} :: { [string]: VendorSkillMeta }

-- Hand-written skills.
meta.manual = { "ecs-design", "luau-tooling" } :: { string }

return meta
