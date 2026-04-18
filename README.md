# ForMatcha — Library Repository (Claude)
Collection of Lua libraries designed for Matcha LuaVM.
## matcha-luavm.skill
This is a .skill file for Claude. It will help Claude write code for the Matcha environment without needing to be convinced or told exactly what to use. (It may be outdated; the documentation does not include the changes from April 2nd since they were not in the Matcha documentation.)

## Loading libraries

### First — load the Loader

The Loader itself must be bootstrapped once using the raw wrapper:

```lua
local loaderSource = game:HttpGet("https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/Loader.luau")
local fn, err = loadstring("MatchaLib = (function()\n" .. loaderSource .. "\nend)()")
if not fn then error("COMPILE ERROR: " .. tostring(err)) return end
fn()
local Loader = MatchaLib
```

### Then — load any library with one line

```lua
local TweenService     = Loader.load("TweenService")
local CharacterService = Loader.load("CharacterService")
local TabService       = Loader.load("TabService")
```

## Available libraries

| Library | Description |
|---------|-------------|
| Loader | Utility to load ForMatcha libraries from GitHub |
| TweenService | Position animation with easing styles for BasePart instances |
| CharacterService | Character lifecycle management (spawn, respawn, death) |
| TabService | Robust tab lifecycle management for Matcha's UI system | (Dont use this)
| MatchaUI | UI Library for matcha |

## Per-library usage

Each library file contains its own documentation block at the top
with all available functions, arguments, and types.

## Examples

### TweenService — move 100 studs up

```lua
local TweenService = Loader.load("TweenService")
local Players      = game:GetService("Players")
local root         = Players.LocalPlayer.Character.HumanoidRootPart

local tween = TweenService.new(root, {
    position      = root.Position + Vector3.new(0, 100, 0),
    speed         = 500,
    style         = "Sine",
    direction     = "Out",
    freezePhysics = true,
    onComplete    = function() print("Done.") end,
})
tween:Play()
```

### CharacterService — detect respawn

```lua
local CharacterService = Loader.load("CharacterService")
local Players          = game:GetService("Players")
local charService      = CharacterService.new(Players.LocalPlayer)

charService:OnCharacterAdded(function(character)
    print("Respawned as: " .. character.Name)
end)
```
