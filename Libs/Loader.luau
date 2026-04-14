-- @env: Matcha LuaVM
-- ============================================================
-- Loader - v2.0.1
-- Utility to load ForMatcha libraries from GitHub.
-- ============================================================

--[[
    Loader.load(libName: string) -> table
        libName : string - Name of the library file without extension.
                           Must match exactly the filename in the Libs/ folder.
        Returns the module table returned by the library.
        Errors on network failure, compile error, or nil return.

    Loader.unload(libName: string) -> void
        Removes a library from the cache, forcing a fresh fetch
        on the next Loader.load() call for that library.

    Loader.loaded() -> { string }
        Returns a list of currently cached library names.
]]

local BASE_URL = "https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/"

-- ============================================================
-- Internal state
-- ============================================================

-- _cache[libName] = compiled module table
-- Populated on first load; reused on all subsequent calls.
local _cache = {}

-- ============================================================
-- Internal helpers
-- ============================================================

-- Fetches raw source from GitHub with error propagation.
-- Returns: (source: string) or errors with a descriptive message.
local function fetchSource(libName, url)
    local ok, result = pcall(game.HttpGet, game, url)
    if not ok then
        error(
            ("Loader: network error fetching '%s': %s"):format(libName, tostring(result)),
            2
        )
    end
    if type(result) ~= "string" or #result == 0 then
        error(
            ("Loader: empty or invalid response for '%s' from %s"):format(libName, url),
            2
        )
    end
    return result
end

-- Compiles and executes source, returning the module value.
-- Strategy: injects a unique global key before running the chunk so
-- the library's `return` value is captured via that global instead of
-- relying on loadstring's return propagation, which is unreliable in
-- the Matcha LuaVM when chunks contain nested returns or IIFE wrappers.
-- The temporary global is always cleaned up after the call.
-- Returns: (lib: table) or errors with a descriptive message.
local function compileAndRun(libName, source)
    -- Build a unique global key that won't collide with user globals.
    local globalKey = "__MatchaLoader_" .. libName:gsub("[^%w]", "_") .. "_" .. tostring(os.clock()):gsub("%.", "")

    -- Wrap source so the return value is stored in the temp global,
    -- making it retrievable regardless of loadstring return behaviour.
    local chunk = globalKey .. " = (function()\n" .. source .. "\nend)()"

    local fn, compileErr = loadstring(chunk, "=" .. libName)
    if not fn then
        error(
            ("Loader: compile error in '%s': %s"):format(libName, tostring(compileErr)),
            2
        )
    end

    local ok, runErr = pcall(fn)

    -- Always clean up the temp global, even on error.
    local lib = _G[globalKey]
    _G[globalKey] = nil

    if not ok then
        error(
            ("Loader: runtime error initializing '%s': %s"):format(libName, tostring(runErr)),
            2
        )
    end

    if lib == nil then
        error(
            ("Loader: '%s' returned nil — missing return statement in the library."):format(libName),
            2
        )
    end

    return lib
end

-- ============================================================
-- Public API
-- ============================================================

local Loader = {}

-- Loads a ForMatcha library by name.
-- On first call: fetches from GitHub, compiles, caches, returns.
-- On subsequent calls: returns the cached module immediately.
function Loader.load(libName)
    -- type: (libName: string) -> table

    assert(type(libName) == "string" and #libName > 0,
        "Loader: libName must be a non-empty string.")

    -- Cache hit — return immediately without any network or compile work.
    if _cache[libName] then
        return _cache[libName]
    end

    local url    = BASE_URL .. libName .. ".luau"
    local source = fetchSource(libName, url)
    local lib    = compileAndRun(libName, source)

    -- Store in cache before returning.
    _cache[libName] = lib

    return lib
end

-- Removes a library from the cache.
-- Useful when you want to force a fresh re-fetch (e.g. hot-reload).
function Loader.unload(libName)
    -- type: (libName: string) -> void
    assert(type(libName) == "string" and #libName > 0,
        "Loader: libName must be a non-empty string.")
    _cache[libName] = nil
end

-- Returns a snapshot list of currently cached library names.
function Loader.loaded()
    -- type: () -> { string }
    local names = {}
    for name in pairs(_cache) do
        names[#names + 1] = name
    end
    return names
end

-- ============================================================
-- Loader.bootstrap(source: string) -> Loader
-- ============================================================
-- Static helper for scripts that need to self-load the Loader
-- from a raw source string (e.g. fetched via game:HttpGet).
-- Avoids the unreliable loadstring return-value pattern by using
-- the same temp-global strategy as compileAndRun internally.
-- Usage:
--   local src    = game:HttpGet("<url>/Loader.luau")
--   local Loader = Loader.bootstrap(src)  -- wait, use the static form:
--
--   local src    = game:HttpGet("<url>/Loader.luau")
--   local Loader = (function()
--       local key = "__MatchaLoaderBoot"
--       local fn  = loadstring(key .. " = (function()\n" .. src .. "\nend)()")
--       fn()
--       local lib = _G[key]; _G[key] = nil
--       return lib
--   end)()
--
-- Or just call this static method after a first compileAndRun:
function Loader.bootstrap(source)
    assert(type(source) == "string" and #source > 0,
        "Loader.bootstrap: source must be a non-empty string.")
    return compileAndRun("Loader", source)
end

return Loader
