# ForMatcha — Library Repository

Collection of Lua libraries designed for Matcha LuaVM.

## Loading libraries

### First — load the Loader

The Loader itself must be bootstrapped once using the raw wrapper:

```lua
local loaderSource = game:HttpGet(
    "https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/Loader.luau"
)
local fn, err = loadstring("MatchaLib = (function()\n" .. loaderSource .. "\nend)()")
if not fn then
    print("COMPILE ERROR: " .. tostring(err))
    return
end
fn()
local Loader = MatchaLib
```

### Then — load any library with one line

```lua
local TweenService = Loader.load("TweenService")
local OtraLib      = Loader.load("OtraLib")
```

## Available libraries

| Library | Description |
|---------|-------------|
| Loader | Utility to load ForMatcha libraries from GitHub |
| TweenService | Position animation with easing styles for BasePart instances |

## Per-library usage

Each library file contains its own documentation block at the top
with all available functions, arguments, and types.
