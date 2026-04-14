-- @env: Matcha LuaVM
-- ============================================================
-- Loader — v1.2.1
-- Utility to load ForMatcha libraries from GitHub.
-- ============================================================

--[[
    Loader.load(libName: string) -> table
        libName : string - Name of the library file without extension.
                           Must match exactly the filename in the Libs/ folder.
        Returns the module table returned by the library.
        Errors on network failure, compile error, runtime error, or nil return.

    NOTE (v1.2.1):
        Reverted execution strategy to the v1.0.0 upvalue pattern that is
        proven to work in Matcha's LuaVM. The v1.2.0 pcall-upvalue approach
        broke because Matcha's pcall does NOT forward return values — the
        loadstring chunk runs fine, but the return value is lost.

        The working pattern wraps the source in:
            MatchaLoaderTemp = (function() <source> end)()
        The IIFE executes the source and assigns its return value to the
        global MatchaLoaderTemp, which we then read and clear.
        This bypasses Matcha's pcall return-value limitation entirely.
]]

print("Using V1.2.1")

local BASE_URL = "https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/"

local Loader = {}

function Loader.load(libName)
    -- type: (libName: string) -> table
    assert(type(libName) == "string" and #libName > 0,
        "Loader: libName must be a non-empty string.")

    -- == Fetch source ==========================================
    local source = game:HttpGet(BASE_URL .. libName .. ".luau")
    if type(source) ~= "string" or #source == 0 then
        error("Loader: empty or invalid response for '" .. libName .. "'.")
    end

    -- == Compile + Execute =====================================
    -- Wrap in an IIFE and assign the return value to a known global.
    -- This is the only reliable way to capture a chunk's return value
    -- in Matcha's LuaVM (pcall does not forward return values).
    local fn, err = loadstring("MatchaLoaderTemp = (function()\n" .. source .. "\nend)()")
    if not fn then
        error("Loader: compile error in '" .. libName .. "': " .. tostring(err))
    end

    fn()

    local lib = MatchaLoaderTemp
    MatchaLoaderTemp = nil

    -- == Validate ==============================================
    assert(lib ~= nil,
        "Loader: '" .. libName .. "' returned nil — missing return statement.")

    return lib
end

return Loader
