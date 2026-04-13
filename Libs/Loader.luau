-- @env: Matcha LuaVM
-- ============================================================
-- Loader — v1.0.0
-- Utility to load ForMatcha libraries from GitHub.
-- ============================================================

--[[
    Loader.load(libName: string) -> table
        libName : string - Name of the library file without extension.
                           Must match exactly the filename in the Libs/ folder.
]]

local BASE_URL = "https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/"

local Loader = {}

function Loader.load(libName)
    assert(type(libName) == "string", "Loader: libName must be a string.")

    local url    = BASE_URL .. libName .. ".luau"
    local source = game:HttpGet(url)

    local fn, err = loadstring("MatchaLoaderTemp = (function()\n" .. source .. "\nend)()")
    if not fn then
        error("Loader: compile error in '" .. libName .. "': " .. tostring(err))
    end

    fn()

    local lib = MatchaLoaderTemp
    MatchaLoaderTemp = nil

    assert(lib ~= nil, "Loader: '" .. libName .. "' returned nil — missing return statement.")

    return lib
end

return Loader
