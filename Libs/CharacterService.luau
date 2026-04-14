-- @env: Matcha LuaVM
-- ============================================================
-- CharacterService — v2.0.0
-- Character lifecycle management library for Matcha LuaVM.
-- Handles character existence, respawn detection, and
-- root/humanoid access using polling and memory address
-- comparison since Matcha has no CharacterAdded event.
--
-- CHANGES FROM v1.0.0:
--   - Unified single watcher thread: OnCharacterAdded and
--     OnCharacterRemoving previously each spawned their own
--     polling loop, reading the same data redundantly and
--     risking inconsistent state if one loop ticked before
--     the other. Now a single internal loop drives both,
--     dispatching to all registered callbacks.
--   - Multiple callbacks supported: both OnCharacterAdded and
--     OnCharacterRemoving now accept multiple registrations.
--     Each new call appends to the list; all fire on the event.
--   - Callbacks dispatched in their own task.spawn to avoid
--     one slow callback blocking others or the watcher loop.
--   - Added WhenCharacterReady(callback, timeout?): non-blocking
--     alternative to WaitForCharacter. Safe to call from the
--     builder thread (render thread) without causing lag.
--   - StopWatching uses cooperative flag (_watching = false)
--     as primary signal, with task.cancel as backup. The single
--     watcher thread makes cancellation deterministic.
-- ============================================================

--[[
    MODULE: CharacterService
    Exports a single constructor: CharacterService.new(player)

    ==========================================================
    CharacterService.new(player: Player) -> CharacterService
    ==========================================================

    == Immediate accessors (no yield) =======================

    CharacterService:GetCharacter()  -> Model | nil
    CharacterService:GetRoot()       -> BasePart | nil
    CharacterService:GetHumanoid()   -> Humanoid | nil
    CharacterService:IsAlive()       -> boolean

    == Blocking wait (use from task.spawn only) =============

    CharacterService:WaitForCharacter(timeout?: number) -> Model | nil
        Yields the calling thread until character + HumanoidRootPart
        are available. timeout = 0 means wait forever.
        ⚠️ Do NOT call from the builder/render thread.

    == Non-blocking (safe from any thread) ==================

    CharacterService:WhenCharacterReady(callback: function, timeout?: number) -> void
        Spawns an internal thread that waits for the character
        and then calls callback(character). Safe to call from anywhere,
        including the UI builder. callback is wrapped in pcall.

    == Event registration ====================================

    CharacterService:OnCharacterAdded(callback: function) -> void
        Registers a callback fired every time a new character spawns.
        Multiple registrations are supported; all fire on each spawn.
        callback receives (character: Model).

    CharacterService:OnCharacterRemoving(callback: function) -> void
        Registers a callback fired every time the character is removed.
        Multiple registrations are supported.
        callback receives no arguments.

    == Lifecycle =============================================

    CharacterService:StopWatching() -> void
        Stops the internal watcher thread and cancels it.
        Clears all registered callbacks. Safe to call multiple times.
]]

local POLL_INTERVAL     = 0.1   -- seconds between address checks
local ROOT_WAIT_TIMEOUT = 5     -- max seconds to wait for HumanoidRootPart
local ROOT_WAIT_STEP    = 0.05  -- polling step while waiting for root

-- ============================================================
-- Internal utilities
-- ============================================================

local function getAddress(instance)
    -- type: (instance: Instance | nil) -> number | nil
    if instance == nil then return nil end
    return instance.Address
end

-- Yields until HumanoidRootPart appears in the character,
-- or ROOT_WAIT_TIMEOUT seconds pass.
local function waitForRoot(character)
    -- type: (character: Model) -> void
    local elapsed = 0
    while not character:FindFirstChild("HumanoidRootPart")
          and elapsed < ROOT_WAIT_TIMEOUT do
        task.wait(ROOT_WAIT_STEP)
        elapsed = elapsed + ROOT_WAIT_STEP
    end
end

-- Dispatches a callback in its own thread so one slow callback
-- cannot block the watcher loop or other callbacks.
local function dispatch(callback, ...)
    -- type: (callback: function, ...: any) -> void
    task.spawn(function()
        local ok, err = pcall(callback, ...)
        if not ok then
            warn("CharacterService: callback error: " .. tostring(err))
        end
    end)
end

-- ============================================================
-- CharacterService class
-- ============================================================

local CharacterService = {}
CharacterService.__index = CharacterService

function CharacterService.new(player)
    assert(player ~= nil, "CharacterService: 'player' cannot be nil.")

    local self = setmetatable({}, CharacterService)

    self._player   = player
    self._watching = false

    -- Callback lists — multiple registrations allowed.
    self._addedCallbacks    = {}  -- { function }
    self._removingCallbacks = {}  -- { function }

    -- Single watcher thread reference for clean cancellation.
    self._watcherThread = nil

    return self
end

-- == Internal ==================================================

function CharacterService:_hasValidCharacter()
    local char = self._player.Character
    return char ~= nil and char:FindFirstChild("HumanoidRootPart") ~= nil
end

-- Starts the single unified polling loop if not already running.
-- Called automatically by OnCharacterAdded and OnCharacterRemoving.
-- Safe to call multiple times — only one loop runs at a time.
function CharacterService:_startWatcher()
    -- type: () -> void
    if self._watcherThread ~= nil then return end

    self._watching      = true
    local lastAddress   = getAddress(self._player.Character)
    local self_         = self

    self._watcherThread = task.spawn(function()
        while self_._watching do
            task.wait(POLL_INTERVAL)

            local current        = self_._player.Character
            local currentAddress = getAddress(current)

            if currentAddress ~= lastAddress then
                -- Address changed — a spawn or removal occurred.

                -- Fire Removing callbacks if there was a previous character.
                if lastAddress ~= nil then
                    for _, cb in ipairs(self_._removingCallbacks) do
                        dispatch(cb)
                    end
                end

                -- Fire Added callbacks if a new character is present.
                if current ~= nil then
                    -- Wait for HumanoidRootPart before notifying.
                    -- Done inline in the watcher thread so dispatch
                    -- receives a fully ready character.
                    waitForRoot(current)
                    for _, cb in ipairs(self_._addedCallbacks) do
                        dispatch(cb, current)
                    end
                end

                lastAddress = currentAddress
            end
        end

        -- Watcher exited cooperatively; clear thread reference.
        self_._watcherThread = nil
    end)
end

-- == Public: immediate accessors ===============================

function CharacterService:GetCharacter()
    -- type: () -> Model | nil
    return self._player.Character
end

function CharacterService:GetRoot()
    -- type: () -> BasePart | nil
    local char = self._player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

function CharacterService:GetHumanoid()
    -- type: () -> Humanoid | nil
    local char = self._player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

function CharacterService:IsAlive()
    -- type: () -> boolean
    if not self:_hasValidCharacter() then return false end
    local humanoid = self:GetHumanoid()
    return humanoid ~= nil and humanoid.Health > 0
end

-- == Public: blocking wait =====================================

--[[
    WaitForCharacter(timeout?: number) -> Model | nil

    Yields the calling thread. Do NOT call from the render/builder thread.
    For a non-blocking alternative, use WhenCharacterReady().
]]
function CharacterService:WaitForCharacter(timeout)
    -- type: (timeout?: number) -> Model | nil
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

-- == Public: non-blocking wait =================================

--[[
    WhenCharacterReady(callback: function, timeout?: number) -> void

    Spawns an internal thread that waits for the character,
    then calls callback(character). Safe to call from any thread
    including the UI builder/render thread. callback is pcall-wrapped.
    If timeout is reached, callback is NOT called.
]]
function CharacterService:WhenCharacterReady(callback, timeout)
    -- type: (callback: function, timeout?: number) -> void
    assert(type(callback) == "function",
        "CharacterService: WhenCharacterReady callback must be a function.")

    task.spawn(function()
        local char = self:WaitForCharacter(timeout or 0)
        if char ~= nil then
            local ok, err = pcall(callback, char)
            if not ok then
                warn("CharacterService: WhenCharacterReady callback error: " .. tostring(err))
            end
        end
    end)
end

-- == Public: event registration ================================

--[[
    OnCharacterAdded(callback: function) -> void

    Appends a callback to the Added list.
    Starts the watcher if not already running.
    All registered callbacks fire on every spawn.
]]
function CharacterService:OnCharacterAdded(callback)
    -- type: (callback: function) -> void
    assert(type(callback) == "function",
        "CharacterService: OnCharacterAdded callback must be a function.")

    table.insert(self._addedCallbacks, callback)
    self:_startWatcher()
end

--[[
    OnCharacterRemoving(callback: function) -> void

    Appends a callback to the Removing list.
    Starts the watcher if not already running.
    All registered callbacks fire on every removal.
]]
function CharacterService:OnCharacterRemoving(callback)
    -- type: (callback: function) -> void
    assert(type(callback) == "function",
        "CharacterService: OnCharacterRemoving callback must be a function.")

    table.insert(self._removingCallbacks, callback)
    self:_startWatcher()
end

-- == Public: lifecycle =========================================

--[[
    StopWatching() -> void

    Sets the cooperative stop flag, then cancels the watcher
    thread as a backup. Clears all registered callbacks.
    Safe to call multiple times.
]]
function CharacterService:StopWatching()
    -- type: () -> void

    -- Signal the loop to exit on its next iteration.
    self._watching = false

    -- Hard-cancel as backup in case the loop is mid-wait.
    if self._watcherThread then
        pcall(task.cancel, self._watcherThread)
        self._watcherThread = nil
    end

    -- Clear callback lists so re-registration after a restart
    -- doesn't fire stale callbacks.
    self._addedCallbacks    = {}
    self._removingCallbacks = {}
end

return CharacterService
