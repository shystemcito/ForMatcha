-- @env: Matcha LuaVM
-- ============================================================
-- Loader — v1.2.0
-- Utility to load ForMatcha libraries from GitHub.
-- ============================================================
--[[
    Loader.load(libName: string) -> table
        libName : string - Name of the library file without extension.
                           Must match exactly the filename in the Libs/ folder.
        Returns the module table returned by the library.
        Errors on network failure, compile error, runtime error, or nil return.

    FIXED in v1.1.1:
        Removed the (function()...end)() wrapper that stripped the chunk's
        implicit vararg context and caused "Cannot use '...' outside of a
        vararg function" in libraries that used '...' at chunk level.

    FIXED in v1.2.0:
        Matcha's pcall does NOT forward the wrapped function's return values —
        it returns only (true/false, errorMessage). Writing:
            local runOk, lib = pcall(fn)
        always leaves `lib` as nil even when fn() returns a table successfully.

        Fix: capture the return value via an upvalue inside the pcall wrapper.
        The function passed to pcall assigns fn()'s result to a local upvalue,
        and we read that upvalue after pcall confirms success. This is the only
        pattern that works reliably in Matcha's LuaVM.
]]

print("Using V1.2.0")
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
    -- Matcha's pcall does not forward return values from the wrapped
    -- function, so we cannot write:
    --     local runOk, lib = pcall(fn)   -- lib is always nil in Matcha!
    --
    -- Instead, we capture the return value through an upvalue that the
    -- inner closure writes to before pcall can observe it.
    local lib = nil
    local runOk, runErr = pcall(function()
        lib = fn()
    end)
    if not runOk then
        error("Loader: runtime error in '" .. libName .. "': " .. tostring(runErr))
    end

    -- == Validate ==============================================
    if lib == nil then
        error("Loader: '" .. libName .. "' returned nil — missing return statement in the library.")
    end

    return lib
end

return Loader
