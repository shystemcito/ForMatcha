-- @env: Matcha LuaVM
-- ============================================================
-- CharacterService — v1.0.0
-- Character lifecycle management library for Matcha LuaVM.
-- Handles character existence, respawn detection, and
-- root/humanoid access using polling and memory address
-- comparison since Matcha has no CharacterAdded event.
-- ============================================================

--[[
    MODULE: CharacterService
    Exports a single constructor: CharacterService.new(player)

    Respawn detection is based on the character's .Address property
    (memory address of the Instance). Since each respawn creates a
    new object in memory, its address always changes — even if the
    respawn happens faster than the polling interval.

    ──────────────────────────────────────────────────────────
    CharacterService.new(player) -> CharacterService
    ──────────────────────────────────────────────────────────
        player : Player - The player to watch. Usually Players.LocalPlayer.

    ──────────────────────────────────────────────────────────
    CharacterService:GetCharacter() -> Model | nil
    ──────────────────────────────────────────────────────────
        Returns the current character if it exists, nil otherwise.

    ──────────────────────────────────────────────────────────
    CharacterService:GetRoot() -> BasePart | nil
    ──────────────────────────────────────────────────────────
        Returns HumanoidRootPart if available, nil otherwise.

    ──────────────────────────────────────────────────────────
    CharacterService:GetHumanoid() -> Humanoid | nil
    ──────────────────────────────────────────────────────────
        Returns the Humanoid if available, nil otherwise.

    ──────────────────────────────────────────────────────────
    CharacterService:WaitForCharacter(timeout) -> Model | nil
    ──────────────────────────────────────────────────────────
        Yields until the character and HumanoidRootPart are available.
        timeout : number - Max seconds to wait. 0 = wait forever. Default: 0.
        Returns the character, or nil if timed out.

    ──────────────────────────────────────────────────────────
    CharacterService:IsAlive() -> boolean
    ──────────────────────────────────────────────────────────
        Returns true if the character exists and Humanoid.Health > 0.

    ──────────────────────────────────────────────────────────
    CharacterService:OnCharacterAdded(callback) -> nil
    ──────────────────────────────────────────────────────────
        Registers a callback invoked every time a new character spawns
        or respawns. Uses .Address comparison to detect respawns that
        happen faster than the polling interval.
        callback : function - Receives (character: Model).

    ──────────────────────────────────────────────────────────
    CharacterService:OnCharacterRemoving(callback) -> nil
    ──────────────────────────────────────────────────────────
        Registers a callback invoked every time the character is removed
        or replaced. Uses .Address comparison for reliable detection.
        callback : function - No arguments.

    ──────────────────────────────────────────────────────────
    CharacterService:StopWatching() -> nil
    ──────────────────────────────────────────────────────────
        Stops all polling loops started by this instance.
        Safe to call multiple times.
]]

local POLL_INTERVAL     = 0.1
local ROOT_WAIT_TIMEOUT = 5
local ROOT_WAIT_STEP    = 0.05

-- ============================================================
-- Internal utilities
-- ============================================================

local function getAddress(instance)
    if instance == nil then return nil end
    return instance.Address
end

local function waitForRoot(character)
    local elapsed = 0
    while not character:FindFirstChild("HumanoidRootPart") and elapsed < ROOT_WAIT_TIMEOUT do
        task.wait(ROOT_WAIT_STEP)
        elapsed = elapsed + ROOT_WAIT_STEP
    end
end

local function safeCall(callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("CharacterService: callback error: " .. tostring(err))
    end
end

-- ============================================================
-- CharacterService class
-- ============================================================

local CharacterService = {}
CharacterService.__index = CharacterService

function CharacterService.new(player)
    assert(player, "CharacterService: 'player' cannot be nil.")

    local self = setmetatable({}, CharacterService)

    self._player   = player
    self._watching = false
    self._threads  = {}

    return self
end

-- ── Internal ──────────────────────────────────────────────────

function CharacterService:_hasValidCharacter()
    local char = self._player.Character
    return char ~= nil and char:FindFirstChild("HumanoidRootPart") ~= nil
end

function CharacterService:_spawnThread(fn)
    local thread = task.spawn(fn)
    table.insert(self._threads, thread)
    return thread
end

-- ── Public API ────────────────────────────────────────────────

function CharacterService:GetCharacter()
    return self._player.Character
end

function CharacterService:GetRoot()
    local char = self._player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

function CharacterService:GetHumanoid()
    local char = self._player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

function CharacterService:WaitForCharacter(timeout)
    timeout = timeout or 0
    local elapsed = 0

    while not self:_hasValidCharacter() do
        task.wait(POLL_INTERVAL)
        elapsed = elapsed + POLL_INTERVAL
        if timeout > 0 and elapsed >= timeout then
            return nil
        end
    end

    return self._player.Character
end

function CharacterService:IsAlive()
    if not self:_hasValidCharacter() then return false end
    local humanoid = self:GetHumanoid()
    return humanoid ~= nil and humanoid.Health > 0
end

function CharacterService:OnCharacterAdded(callback)
    assert(type(callback) == "function", "CharacterService: callback must be a function.")

    self._watching = true

    self:_spawnThread(function()
        local lastChar    = self._player.Character
        local lastAddress = getAddress(lastChar)

        while self._watching do
            task.wait(POLL_INTERVAL)

            local currentChar    = self._player.Character
            local currentAddress = getAddress(currentChar)

            -- Address change = new Instance in memory = spawn or respawn
            if currentAddress ~= lastAddress then
                if currentChar ~= nil then
                    -- Wait until HumanoidRootPart is ready before firing
                    waitForRoot(currentChar)
                    safeCall(callback, currentChar)
                end

                lastChar    = currentChar
                lastAddress = currentAddress
            end
        end
    end)
end

function CharacterService:OnCharacterRemoving(callback)
    assert(type(callback) == "function", "CharacterService: callback must be a function.")

    self._watching = true

    self:_spawnThread(function()
        local lastChar    = self._player.Character
        local lastAddress = getAddress(lastChar)

        while self._watching do
            task.wait(POLL_INTERVAL)

            local currentChar    = self._player.Character
            local currentAddress = getAddress(currentChar)

            -- Address changed = old character was removed or replaced
            if currentAddress ~= lastAddress then
                safeCall(callback)

                lastChar    = currentChar
                lastAddress = currentAddress
            end
        end
    end)
end

function CharacterService:StopWatching()
    self._watching = false

    for _, thread in ipairs(self._threads) do
        task.cancel(thread)
    end

    self._threads = {}
end

return CharacterService
