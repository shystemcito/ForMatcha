# ForMatcha — Library Repository (Claude)
Collection of Lua libraries designed for Matcha LuaVM.

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
| TabService | Robust tab lifecycle management for Matcha's UI system |

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

### TabService — create a managed tab with async loading

```lua
local TabService = Loader.load("TabService")

local tab = TabService.new("My Hub")

tab:setBuilder(function(ctx)
    local left  = ctx:leftSection("Options", {"General", "Advanced"})
    local right = ctx:rightSection("Info")

    if left.page == 0 then
        left:inputText("query", "Search...", "")
        left:spacing()
        left:button("Execute", 200, 34, function()
            -- logic here
        end)
    elseif left.page == 1 then
        left:combo("sort", "Order", {"A-Z", "Z-A"}, ctx:get("sort") or 0)
    end

    local q = ctx:get("query") or ""
    right:text("Query: " .. q)
end)

tab:mount()

task.spawn(function()
    -- async setup (HTTP, parsing, etc.)
    task.wait(2)
    tab:ready()
    tab:notify("Hub ready")
end)
```
