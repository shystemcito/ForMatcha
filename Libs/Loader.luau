-- @env: Matcha LuaVM
-- ============================================================
-- Loader — v1.1.0
-- Utility to load ForMatcha libraries from GitHub.
-- ============================================================
--[[
    Loader.load(libName: string) -> table
        libName : string - Name of the library file without extension.
                           Must match exactly the filename in the Libs/ folder.
        Returns the module table returned by the library.
        Errors on network failure, compile error, runtime error, or nil return.
]]
print("Using Loader 1.1.0")
local BASE_URL = "https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/"

local Loader = {}

function Loader.load(libName)
    assert(type(libName) == "string" and #libName > 0,
        "Loader: libName must be a non-empty string.")

    -- Fetch source
    local ok, source = pcall(game.HttpGet, game, BASE_URL .. libName .. ".luau")
    if not ok then
        error("Loader: network error fetching '" .. libName .. "': " .. tostring(source))
    end
    if type(source) ~= "string" or #source == 0 then
        error("Loader: empty or invalid response for '" .. libName .. "'.")
    end

    -- Compile
    local fn, compileErr = loadstring("MatchaLoaderTemp = (function()\n" .. source .. "\nend)()")
    if not fn then
        error("Loader: compile error in '" .. libName .. "': " .. tostring(compileErr))
    end

    -- Execute
    local runOk, runErr = pcall(fn)
    if not runOk then
        MatchaLoaderTemp = nil
        error("Loader: runtime error in '" .. libName .. "': " .. tostring(runErr))
    end

    -- Capture & clean
    local lib = MatchaLoaderTemp
    MatchaLoaderTemp = nil

    if lib == nil then
        error("Loader: '" .. libName .. "' returned nil — missing return statement in the library.")
    end

    return lib
end

return Loader
