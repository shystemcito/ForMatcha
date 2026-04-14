-- @env: Matcha LuaVM
-- ============================================================
-- Loader — v2.1.0
-- Utility to load ForMatcha libraries from GitHub.
-- ============================================================
--[[
    CAMBIO v2.1.0 respecto a v2.0.x:
    • Eliminado el wrapper IIFE "(function()\n...\nend)()" que causaba:
        - "Cannot use '...' outside of a vararg function" en libs que usan varargs.
        - Pérdida del valor de retorno porque _G no es confiable en Matcha LuaVM.
    • Ahora loadstring ejecuta el chunk directamente y captura su retorno
      via los valores que devuelve pcall(fn), que SÍ propaga `return` en Matcha.

    Loader.load(libName: string) -> table
        libName : string - Nombre del archivo sin extensión.
                           Debe coincidir exactamente con el filename en Libs/.
        Retorna la tabla del módulo.
        Lanza error en: fallo de red, error de compilación, o retorno nil.

    Loader.unload(libName: string) -> void
        Elimina una librería del caché, forzando un re-fetch en el próximo load().

    Loader.loaded() -> { string }
        Lista de nombres de librerías actualmente en caché.
]]

local BASE_URL = "https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/"

-- ============================================================
-- Estado interno
-- ============================================================

local _cache = {}

-- ============================================================
-- Helpers internos
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

local function compileAndRun(libName, source)
    -- Compilar sin wrapper: así `...` funciona y el `return` se propaga
    -- directamente como valor de retorno de la función compilada.
    local fn, compileErr = loadstring(source, "=" .. libName)
    if not fn then
        error(("Loader: compile error in '%s': %s"):format(libName, tostring(compileErr)), 2)
    end

    -- pcall(fn) retorna: ok, [retval1, retval2, ...]
    -- El primer valor extra es el `return` del chunk (o el mensaje de error).
    local ok, libOrErr = pcall(fn)

    if not ok then
        error(("Loader: runtime error initializing '%s': %s"):format(libName, tostring(libOrErr)), 2)
    end

    -- libOrErr es el valor que el chunk devolvió con `return`.
    if libOrErr == nil then
        error(("Loader: '%s' returned nil — missing return statement in the library."):format(libName), 2)
    end

    return libOrErr
end

-- ============================================================
-- API pública
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
