-- @env: Matcha LuaVM
-- ============================================================
-- TabService — v2.0.0
-- Robust wrapper around Matcha's UI.AddTab / Section system.
-- Provides lifecycle management, state isolation, typed
-- widget builders, and safe teardown.
-- ============================================================

--[[
    TabService.new(tabName: string) -> Tab

    Tab:setBuilder(fn: function) -> void
        fn(ctx) called every render frame. Receives a Ctx object.

    Tab:mount() -> void
    Tab:ready() -> void
    Tab:unmount() -> void
        unmount() now cancels all running worker threads.

    Tab:notify(message: string, duration: number?) -> void

    == Ctx ==================================================

    Ctx:leftSection(title: string, subTabs: table?) -> Section
    Ctx:rightSection(title: string, subTabs: table?) -> Section

    Ctx:get(key: string) -> any
    Ctx:set(key: string, value: any) -> void

    == Section ===============================================

    Section:text(content: string) -> void
    Section:spacing() -> void

    Section:button(label: string, fn: function, opts?: table) -> void
    Section:button(label: string, w: number, h: number, fn: function, opts?: table) -> void
        opts.debounce : number   — cooldown in seconds between clicks. Default: 0.25.
        opts.async    : boolean  — run fn in task.spawn. Default: true (always).
        fn always runs asynchronously regardless of opts.async.

    Section:toggle(key: string, label: string, default: boolean?, callbacks?) -> boolean
        callbacks can be:
            - nil        : no side-effect, just reads and returns state.
            - function   : treated as a loop body. Spawned in a worker thread
                           while the toggle is ON. Worker is cancelled when OFF.
                           The function is called repeatedly with task.wait(0)
                           between iterations so it never blocks the render thread.
            - table      : { onEnable: function?, onDisable: function? }
                           onEnable fires once when toggle switches ON.
                           onDisable fires once when toggle switches OFF.
        Returns the current boolean state.

    Section:checkbox(key: string, label: string, default: boolean?) -> boolean
    Section:slider(key: string, label: string, min: number, max: number, default: number?) -> number
    Section:inputText(key: string, placeholder: string, default: string?) -> void
    Section:combo(key: string, label: string, options: table, idx: number?) -> void
]]

-- ============================================================
-- Internal helpers
-- ============================================================

local function assertStr(v, name)
    assert(type(v) == "string" and #v > 0,
        "TabService: '" .. name .. "' must be a non-empty string.")
end

local function assertFn(v, name)
    assert(type(v) == "function",
        "TabService: '" .. name .. "' must be a function.")
end

local function assertNum(v, name)
    assert(type(v) == "number",
        "TabService: '" .. name .. "' must be a number.")
end

-- Safely calls a function and warns on error without crashing.
local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[TabService] callback error: " .. tostring(err))
    end
end

-- ============================================================
-- WorkerRegistry — tracks all active worker threads per Tab
-- so unmount() can cancel them all cleanly.
-- ============================================================

local WorkerRegistry = {}
WorkerRegistry.__index = WorkerRegistry

function WorkerRegistry.new()
    local self = setmetatable({}, WorkerRegistry)
    -- _threads[key] = { thread: thread, loopMode: boolean }
    self._threads = {}
    return self
end

-- Spawns a new worker thread and registers it under `key`.
-- If a thread already exists for that key, it is cancelled first.
function WorkerRegistry:spawn(key, fn)
    -- type: (key: string, fn: function) -> void
    self:cancel(key)
    local thread = task.spawn(fn)
    self._threads[key] = thread
end

-- Cancels the worker thread registered under `key`, if any.
function WorkerRegistry:cancel(key)
    -- type: (key: string) -> void
    local thread = self._threads[key]
    if thread then
        pcall(task.cancel, thread)
        self._threads[key] = nil
    end
end

-- Cancels ALL registered worker threads.
-- Called by Tab:unmount().
function WorkerRegistry:cancelAll()
    -- type: () -> void
    for key, thread in pairs(self._threads) do
        pcall(task.cancel, thread)
        self._threads[key] = nil
    end
end

-- ============================================================
-- Section wrapper
-- ============================================================

local Section = {}
Section.__index = Section

function Section._new(raw, subTabs, workers)
    -- workers: WorkerRegistry shared with the parent Tab
    local self = setmetatable({}, Section)
    self._raw     = raw
    self._workers = workers
    if subTabs then
        self.page = raw.page
    end
    return self
end

function Section:text(content)
    assert(type(content) == "string", "TabService: Section:text() expects a string.")
    self._raw:Text(content)
end

function Section:spacing()
    self._raw:Spacing()
end

--[[
    button(label, fn, opts?)
    button(label, w, h, fn, opts?)

    fn is ALWAYS executed asynchronously in task.spawn.
    opts.debounce (number, default 0.25): minimum seconds between clicks.
]]
function Section:button(label, w, h, fn, opts)
    assertStr(label, "label")

    -- Resolve short-form: button(label, fn, opts?)
    if type(w) == "function" then
        opts = h       -- h slot holds opts in short form
        fn   = w
        w    = nil
        h    = nil
    end

    assertFn(fn, "fn")

    local debounce  = (opts and type(opts.debounce) == "number") and opts.debounce or 0.25
    local lastPress = 0

    -- Wrapper: enforces debounce and always runs fn in a new thread.
    -- This ensures fn can contain loops, yields, or heavy work
    -- without ever blocking the UI render thread.
    local wrapped = function()
        local now = os.clock()
        if now - lastPress < debounce then return end
        lastPress = now
        task.spawn(safeCall, fn)
    end

    if w and h then
        self._raw:Button(label, w, h, wrapped)
    else
        self._raw:Button(label, wrapped)
    end
end

--[[
    toggle(key, label, default?, callbacks?) -> boolean

    callbacks variants:
        nil      — no side-effect.
        function — loop body, runs repeatedly in a worker thread while ON.
                   Worker is cancelled automatically when toggle turns OFF.
        table    — { onEnable: function?, onDisable: function? }
                   Each fires once on state transition.

    The builder runs every frame, so toggle() is called every frame.
    Worker threads are only started/stopped when state actually changes
    (tracked via _workers registry keyed by the toggle's key).
    This is O(1) per frame when state is stable.
]]
function Section:toggle(key, label, default, callbacks)
    assertStr(key,   "key")
    assertStr(label, "label")

    local init = (default == true) and true or false
    self._raw:Toggle(key, label, init)

    local val   = UI.GetValue(key)
    local isOn  = (val == true or val == 1)

    -- Determine callback mode
    local cbMode = type(callbacks)
    -- cbMode == "function" : loop mode
    -- cbMode == "table"    : onEnable / onDisable mode
    -- cbMode == "nil"      : no callbacks

    -- Internal worker key uses toggle key directly.
    -- WorkerRegistry handles dedup (won't re-spawn if already running).
    local workerKey  = "toggle::" .. key
    -- State-change tracking key (persisted across frames via UI.GetValue namespace)
    local prevKey    = "tabsvc::prev::" .. key

    local prevRaw    = UI.GetValue(prevKey)
    local wasOn      = (prevRaw == true or prevRaw == 1)

    -- Only act on state transitions, not every frame.
    if isOn ~= wasOn then
        UI.SetValue(prevKey, isOn)

        if cbMode == "function" then
            -- Loop mode: spawn a worker that calls the function repeatedly
            -- with a yield between iterations. task.wait(0) yields control
            -- back to the scheduler each iteration, so the render thread
            -- is never starved even if callbacks is a tight computation.
            if isOn then
                self._workers:spawn(workerKey, function()
                    while UI.GetValue(key) == true or UI.GetValue(key) == 1 do
                        safeCall(callbacks)
                        task.wait(0) -- cooperative yield — never blocks render
                    end
                    -- Clean up registry entry when loop exits naturally
                    self._workers:cancel(workerKey)
                end)
            else
                -- Toggle turned off — cancel the worker thread immediately.
                self._workers:cancel(workerKey)
            end

        elseif cbMode == "table" then
            -- onEnable / onDisable mode: fire once per transition.
            if isOn and type(callbacks.onEnable) == "function" then
                task.spawn(safeCall, callbacks.onEnable)
            elseif not isOn and type(callbacks.onDisable) == "function" then
                task.spawn(safeCall, callbacks.onDisable)
            end
        end
        -- cbMode == "nil": nothing to do
    end

    return isOn
end

function Section:checkbox(key, label, default)
    assertStr(key,   "key")
    assertStr(label, "label")
    local init = (default == true) and true or false
    self._raw:Checkbox(key, label, init)
    local val = UI.GetValue(key)
    return (val == true or val == 1)
end

function Section:slider(key, label, min, max, default)
    assertStr(key,   "key")
    assertStr(label, "label")
    assertNum(min,   "min")
    assertNum(max,   "max")
    local init = (type(default) == "number") and default or min
    self._raw:Slider(key, label, min, max, init)
    return UI.GetValue(key) or init
end

function Section:inputText(key, placeholder, default)
    assertStr(key,         "key")
    assertStr(placeholder, "placeholder")
    self._raw:InputText(key, placeholder, default or "")
end

function Section:combo(key, label, options, idx)
    assertStr(key,   "key")
    assertStr(label, "label")
    assert(type(options) == "table", "TabService: combo options must be a table.")
    self._raw:Combo(key, label, options, idx or 0)
end

-- ============================================================
-- Ctx (render context passed to the builder each frame)
-- ============================================================

local Ctx = {}
Ctx.__index = Ctx

function Ctx._new(tab, rawTab)
    local self = setmetatable({}, Ctx)
    self._tab    = tab
    self._rawTab = rawTab
    return self
end

function Ctx:_ns(key)
    -- Namespace key with tab name to avoid collisions across tabs.
    return self._tab._name .. "::" .. key
end

function Ctx:get(key)
    return UI.GetValue(self:_ns(key))
end

function Ctx:set(key, value)
    UI.SetValue(self:_ns(key), value)
end

function Ctx:leftSection(title, subTabs)
    assertStr(title, "title")
    local raw = self._rawTab:Section(title, "Left", subTabs)
    return Section._new(raw, subTabs, self._tab._workers)
end

function Ctx:rightSection(title, subTabs)
    assertStr(title, "title")
    local raw = self._rawTab:Section(title, "Right", subTabs)
    return Section._new(raw, subTabs, self._tab._workers)
end

-- ============================================================
-- Tab
-- ============================================================

local Tab = {}
Tab.__index = Tab

function Tab._new(name)
    assertStr(name, "tabName")
    local self = setmetatable({}, Tab)
    self._name    = name
    self._builder = nil
    self._mounted = false
    self._ready   = false
    -- WorkerRegistry is created once per Tab and shared with all
    -- Section instances created during the builder's execution.
    self._workers = WorkerRegistry.new()
    return self
end

function Tab:setBuilder(fn)
    assertFn(fn, "fn")
    assert(not self._mounted,
        "TabService: setBuilder() must be called before mount().")
    self._builder = fn
end

function Tab:mount()
    assert(self._builder,
        "TabService: call setBuilder() before mount().")
    assert(not self._mounted,
        "TabService: tab '" .. self._name .. "' is already mounted.")

    self._mounted = true
    local self_ = self

    UI.AddTab(self._name, function(rawTab)
        local ctx = Ctx._new(self_, rawTab)

        if not self_._ready then
            -- Show a loading placeholder while async setup runs.
            local s = rawTab:Section("Please wait", "Left")
            s:Text("[ " .. self_._name .. " ] Loading...")
            return
        end

        -- Builder runs on the render thread — must stay lightweight.
        -- All heavy work is pushed to worker threads by Section methods.
        local ok, err = pcall(self_._builder, ctx)
        if not ok then
            -- Render the error inside the tab instead of crashing.
            local errSec = rawTab:Section("TabService Error", "Left")
            errSec:Text("Builder crashed:")
            errSec:Spacing()
            errSec:Text(tostring(err))
            warn("[TabService] Builder error in '" .. self_._name .. "': " .. tostring(err))
        end
    end)
end

function Tab:ready()
    assert(self._mounted,
        "TabService: call mount() before ready().")
    self._ready = true
end

function Tab:unmount()
    if not self._mounted then return end

    -- Cancel ALL active worker threads before removing the tab.
    -- Without this, toggle loops and other workers would continue
    -- running as zombie threads after the tab is gone.
    self._workers:cancelAll()

    pcall(UI.RemoveTab, self._name)

    self._mounted = false
    self._ready   = false
end

function Tab:notify(message, duration)
    assert(type(message) == "string", "TabService: notify message must be a string.")
    notify(message, self._name, duration or 5)
end

-- ============================================================
-- Public API
-- ============================================================

local TabService = {}

function TabService.new(tabName)
    return Tab._new(tabName)
end

return TabService
