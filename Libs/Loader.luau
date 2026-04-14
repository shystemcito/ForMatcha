-- @env: Matcha LuaVM
-- ============================================================
-- Loader — v1.1.1
-- Utility to load ForMatcha libraries from GitHub.
-- ============================================================
--[[
    Loader.load(libName: string) -> table
        libName : string - Name of the library file without extension.
                           Must match exactly the filename in the Libs/ folder.
        Returns the module table returned by the library.
        Errors on network failure, compile error, runtime error, or nil return.

    FIXED in v1.1.1:
        The previous wrapping strategy
            loadstring("MatchaLoaderTemp = (function()\n" .. source .. "\nend)()")
        broke any library that uses '...' at chunk level (a valid Luau pattern),
        because wrapping in an anonymous function removes the vararg context.
        It also relied on a shared global (MatchaLoaderTemp) which is fragile.

        Fix: pass the raw source directly to loadstring. The chunk is already an
        implicit vararg function in Luau, so '...' is always valid. The return
        value of the chunk is captured by calling fn() directly — no global needed.
]]

print("Using V1.1.1")
local BASE_URL = "https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/"

local Loader = {}

function Loader.load(libName)
    -- type: (libName: string) -> table
    assert(type(libName) == "string" and #libName > 0,
        "Loader: libName must be a non-empty string.")

    -- == Fetch source ==========================================
    local ok, source = pcall(game.HttpGet, game, BASE_URL .. libName .. ".luau")
    if not ok then
        error("Loader: network error fetching '" .. libName .. "': " .. tostring(source))
    end
    if type(source) ~= "string" or #source == 0 then
        error("Loader: empty or invalid response for '" .. libName .. "'.")
    end

    -- == Compile ===============================================
    -- loadstring returns the source as a chunk function.
    -- The chunk is an implicit vararg function, so libraries may
    -- safely use '...' at the top level (e.g. for module args).
    -- We do NOT wrap in an extra (function()...end)() — that would
    -- strip the vararg context and cause "Cannot use '...' outside
    -- of a vararg function" errors in any library that relies on it.
    local fn, compileErr = loadstring(source, libName)
    if not fn then
        error("Loader: compile error in '" .. libName .. "': " .. tostring(compileErr))
    end

    -- == Execute ===============================================
    -- Call the chunk directly; its return value IS the library table.
    -- No shared global is needed.
    local runOk, lib = pcall(fn)
    if not runOk then
        error("Loader: runtime error in '" .. libName .. "': " .. tostring(lib))
    end

    -- == Validate ==============================================
    if lib == nil then
        error("Loader: '" .. libName .. "' returned nil — missing return statement in the library.")
    end

    return lib
end

return Loader
