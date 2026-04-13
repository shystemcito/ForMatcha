# ForMatcha — Library Repository

Collection of Lua libraries designed for Matcha LuaVM.

## Loading any library

Since Matcha's `loadstring` does not propagate return values from the chunk
scope, every library must be loaded using this wrapper pattern:

```lua
local source = game:HttpGet(
    "https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/LibraryName.luau"
)
local fn, err = loadstring("MatchaLib = (function()\n" .. source .. "\nend)()")
if not fn then
    print("COMPILE ERROR: " .. tostring(err))
    return
end
fn()
local LibraryName = MatchaLib
```

Replace `LibraryName` with the name of the library you want to load.
The global `MatchaLib` is a temporary bridge — reassign it immediately
to a local variable so it does not conflict with other libraries.

## Available libraries

| Library | Description |
|---------|-------------|
| TweenService | Position animation with easing styles for BasePart instances |

## Per-library usage

Each library file contains its own documentation block at the top
with all available functions, arguments, and types.
