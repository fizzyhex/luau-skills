# Luau Skills & Claude Code Extensions

[Agent Skills](https://agentskills.io/home) and Claude Code hooks for Roblox
development in **typed Luau**, not roblox-ts or TypeScript.

This is a Luau fork of
[christopher-buss/skills](https://github.com/christopher-buss/skills), which
itself started as a fork of [antfu/skills](https://github.com/antfu/skills).
Every skill example, hook, script, and test here is strict typed Luau. The
tooling runs on [Lune](https://github.com/lune-org/lune).

## What's here

- **Skills**: typed Luau, the Luau/Roblox toolchain, jecs, ECS design, and
  Jest Roblox
- **Hooks** (`sentinel-luau` plugin): formatting with StyLua, linting with
  selene, and type-checking with `luau-lsp analyze` after every edit and at stop
- **Output style**: XP Programmer

## Installation

### Skills

```bash
npx skills add fizzyhex/luau-skills --skill '*' --agent claude-code github-copilot --copy
```

This installs project-level skills into `.claude/skills/` (Claude Code) and
`.github/skills/` (GitHub Copilot in VS Code). Add `-g` to install globally.
Other agents are listed by the [skills CLI](https://github.com/vercel-labs/skills).

### Hooks plugin

The hooks need `lune` on `PATH`. They also use `stylua`, `selene`, and
`luau-lsp` when the project provides them, for example through `rokit.toml`. A
missing tool is skipped. Enable the plugin in the project's
`.claude/settings.json`:

```json
{
	"extraKnownMarketplaces": {
		"luau-skills": {
			"source": { "source": "github", "repo": "fizzyhex/luau-skills" }
		}
	},
	"enabledPlugins": {
		"sentinel-luau@luau-skills": true
	}
}
```

Per-project settings are documented in [hooks/CONFIGURATION.md](hooks/CONFIGURATION.md).

## Skills

### Hand-maintained

| Skill                                 | Description                                                  |
| ------------------------------------- | ------------------------------------------------------------ |
| [ecs-design](skills/ecs-design)       | Best practices for designing Entity Component Systems in Luau |
| [luau-tooling](skills/luau-tooling)   | rokit, Rojo/Azul, wally/pesde, StyLua, selene, luau-lsp, Lune, darklua |

### Generated from documentation

| Skill                 | Description                         | Source                                                  |
| --------------------- | ----------------------------------- | ------------------------------------------------------- |
| [luau](skills/luau)   | Strict, typed Luau for Roblox        | [luau-lang/site](https://github.com/luau-lang/site)     |
| [jecs](skills/jecs)   | Entity Component System for Roblox  | [Ukendio/jecs](https://github.com/Ukendio/jecs)         |
| [jest](skills/jest)   | Jest Roblox testing                 | [Roblox/jest-roblox](https://github.com/Roblox/jest-roblox) |

### Synced

| Skill                                   | Source                                                   |
| --------------------------------------- | -------------------------------------------------------- |
| [diagnose](.agents/skills/diagnose)     | [mattpocock/skills](https://github.com/mattpocock/skills) |

## Development

```bash
rokit install                  # lune, selene, StyLua, luau-lsp
lune run scripts/cli init      # clone skill sources as submodules
lune run scripts/cli check     # see which sources have upstream changes
lune run test/run              # hook tests
stylua --check lib hooks scripts test meta.luau
selene lib hooks scripts test meta.luau
```

See [AGENTS.md](AGENTS.md) for how skills are generated and maintained.

## Differences from upstream

- roblox-ts skill replaced by `luau`; pnpm skill replaced by `luau-tooling`
- jecs, ecs-design, and jest examples rewritten in typed Luau; the
  TypeScript-only jest-extended reference was removed
- Hooks rewritten from TypeScript/Node (eslint_d, tsgo, madge) to Luau/Lune
  (StyLua, selene, luau-lsp)
- `commitlint-preflight` plugin removed, because it depends on Node and
  commitlint

## License

[MIT](LICENSE). Vendored skills keep their original licenses.
