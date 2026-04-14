-- @env: Matcha LuaVM
-- ============================================================
-- Loader — v2.2.0
-- ============================================================
--[[
    Loader.load(libName)   -> table   (with cache)
    Loader.unload(libName) -> void
    Loader.loaded()        -> { string }
]]

local BASE_URL = "https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/"

local _cache = {}

-- ============================================================
-- fetchSource
-- ============================================================

local function fetchSource(libName, url)
    local ok, result = pcall(game.HttpGet, game, url)
    if not ok then
        error(("Loader: network error fetching '%s': %s"):format(libName, tostring(result)), 2)
    end
    if type(result) ~= "string" or #result == 0 then
        error(("Loader: empty or invalid response for '%s' from %s"):format(libName, url), 2)
    end
    return result
end

-- ============================================================
-- compileAndRun
-- ============================================================

local function compileAndRun(libName, source)
    local body, retExpr = source:match("^(.*)\n[ \t]*return[ \t]+(.-)[ \t]*\n?$")

    if not retExpr then
        retExpr = source:match("^[ \t]*return[ \t]+(.-)[ \t]*$")
        body    = retExpr and "" or nil
    end

    if not retExpr then
        error(
            ("Loader: '%s' doesnt have `return` at the end of the file."):format(libName),
            2
        )
    end

    local chunk
    if body and body ~= "" then
        chunk = body .. "\n__MatchaResult = " .. retExpr
    else
        chunk = "__MatchaResult = " .. retExpr
    end

    local fn, compileErr = loadstring(chunk, "=" .. libName)
    if not fn then
        error(("Loader: compile error in '%s': %s"):format(libName, tostring(compileErr)), 2)
    end

    local ok, runErr = pcall(fn)
    if not ok then
        error(("Loader: runtime error in '%s': %s"):format(libName, tostring(runErr)), 2)
    end

    local lib = __MatchaResult
    __MatchaResult = nil

    if lib == nil then
        error(
            ("Loader: '%s' returned nil — library must return a table."):format(libName),
            2
        )
    end

    return lib
end

-- ============================================================
-- Public API
-- ============================================================

local Loader = {}

function Loader.load(libName)
    assert(type(libName) == "string" and #libName > 0,
        "Loader: libName must be a non-empty string.")

    if _cache[libName] then
        return _cache[libName]
    end

    local url    = BASE_URL .. libName .. ".luau"
    local source = fetchSource(libName, url)
    local lib    = compileAndRun(libName, source)

    _cache[libName] = lib
    return lib
end

function Loader.unload(libName)
    assert(type(libName) == "string" and #libName > 0,
        "Loader: libName must be a non-empty string.")
    _cache[libName] = nil
end

function Loader.loaded()
    local names = {}
    for name in pairs(_cache) do
        names[#names + 1] = name
    end
    return names
end

return Loader
