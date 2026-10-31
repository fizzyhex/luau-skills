---
name: feature-roblox-types
description: |
    Use when typing Roblox Instances, services, FindFirstChild/WaitForChild
    results, Enum values, attributes, characters, or validating RemoteEvent and
    RemoteFunction arguments in typed Luau
---

# Roblox Types

Every Roblox class (`Part`, `Humanoid`, `Players`, ...), data type
(`Vector3`, `CFrame`, `RaycastResult`, ...) and enum (`Enum.Material`) can be
used directly as a type. Subclasses are assignable to their parents, so a
`Part` fits wherever a `BasePart` or `Instance` is expected.

## What each lookup returns

| Call                                       | Type                         |
| ------------------------------------------ | ---------------------------- |
| `game:GetService("Players")`               | `Players`                    |
| `Instance.new("Part")`                     | `Part`                       |
| `inst:Clone()`                             | Same type as `inst`          |
| `inst:FindFirstChild("X")`                 | `Instance?`                  |
| `inst:FindFirstChildOfClass("Humanoid")`   | `Humanoid?`                  |
| `inst:FindFirstChildWhichIsA("BasePart")`  | `BasePart?`                  |
| `inst:FindFirstAncestorOfClass("Model")`   | `Model?`                     |
| `inst:WaitForChild("X")`                   | `Instance` (can yield forever) |
| `inst:WaitForChild("X", 5)`                | `Instance?` (nil on timeout) |
| `inst:GetChildren()` / `GetDescendants()`  | `{ Instance }`               |
| `inst:GetAttribute("X")`                   | `unknown?`, so refine it     |
| `Players.LocalPlayer`                      | `Player` (nil on the server!) |
| `player.Character`                         | `Model?`                     |
| `model.PrimaryPart`                        | `BasePart?`                  |
| `workspace.SomeChild` (dot access)         | Error without a sourcemap; `any`/typed with one (see luau-tooling) |

## Getting instances safely

```luau
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- WaitForChild returns Instance: refine to the class you need
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local damageRemote = remotesFolder:WaitForChild("Damage")
assert(damageRemote:IsA("RemoteEvent"), "Damage must be a RemoteEvent")
-- damageRemote: RemoteEvent from here on

-- FindFirstChild* returns optional: handle nil
local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

-- Casting is acceptable when the hierarchy is guaranteed (e.g. built by your own code)
local hud = ReplicatedStorage:WaitForChild("Hud") :: ScreenGui

print(Players, getHumanoid, hud)
```

Prefer `:IsA()` or `assert(x:IsA(...))` over `::` casts. A cast fails silently
at runtime, while `IsA` fails loudly in the right place. Never cast
`FindFirstChild(...) :: Part` without a nil check.

## Validating remote arguments

The server receives `(player: Player, ...any)`. Clients can send **anything**,
so treat each argument as `unknown` and validate it before use:

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("BuyItem")
assert(remote:IsA("RemoteEvent"))

local ITEM_PRICES: { [string]: number } = { apple = 5, rice = 12 }

remote.OnServerEvent:Connect(function(player: Player, itemId: unknown, quantity: unknown)
	if type(itemId) ~= "string" or type(quantity) ~= "number" then
		return
	end
	-- numbers from clients can be NaN, inf, negative or fractional
	if quantity ~= quantity or quantity < 1 or quantity > 99 or quantity % 1 ~= 0 then
		return
	end
	local price = ITEM_PRICES[itemId] :: number? -- indexers don't add nil; be explicit
	if not price then
		return
	end
	print(player.Name, "buys", quantity, itemId, "for", price * quantity)
end)
```

- Annotate the callback parameters as `unknown`. If you leave them out, they
  become `any`, and `any` hides missing validation.
- Instances sent by a client may be `nil` (not replicated) or something the
  client shouldn't control. Check with `typeof(x) == "Instance" and
  x:IsA(...)` and verify ownership.
- Use `typeof` (not `type`) for Roblox datatypes: `typeof(v) == "Vector3"`,
  `"CFrame"`, `"EnumItem"`, `"Instance"`.

## Attributes

```luau
--!strict
local part = Instance.new("Part")
part:SetAttribute("Cooked", 0.5)

local raw = part:GetAttribute("Cooked") -- unknown?
local cooked = if type(raw) == "number" then raw else 0
print(cooked)
```

## Signals and connections

```luau
--!strict
local Players = game:GetService("Players")

local conn: RBXScriptConnection = Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		print(character.Name)
	end)
end)

-- Clean up when done
conn:Disconnect()
```

Signal callbacks are typed through `RBXScriptSignal<T...>`, so their parameter
types are inferred. Annotating them still helps readability.

## Key points

- Lowercase deprecated APIs (`part:remove()`, `workspace:findFirstChild()`)
  are flagged. Use the PascalCase versions.
- Prefer `task.wait`, `task.spawn`, `task.delay` and `task.defer` over the
  deprecated `wait`, `spawn` and `delay`.
- `game:GetService(...)` is the reliable way to get a service. `game.Players`
  depends on the instance name.
- `script` is typed `LuaSourceContainer`, and `script.Parent` is `Instance?`.
  Refine before use, or require siblings by string (see core-modules-require).
- For your own place hierarchy, generate a sourcemap (Rojo/Azul) so that
  `workspace.Kitchen.Stove` is typed. Without one, prefer `WaitForChild` with
  `IsA`.

<!--
Source references:
- https://luau.org/types/roblox-types
- https://create.roblox.com/docs/reference/engine/classes/Instance
- https://create.roblox.com/docs/reference/engine/classes/RemoteEvent
- https://github.com/JohnnyMorganz/luau-lsp/blob/main/scripts/globalTypes.d.luau
-->
