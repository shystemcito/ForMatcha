-- @env: Matcha LuaVM
-- ============================================================
-- TabService - v1.1.0
-- Robust wrapper around Matcha's UI.AddTab / Section system.
-- Provides lifecycle management, state isolation, typed
-- widget builders, and safe teardown.
-- ============================================================

--[[
    TabService.new(tabName: string) -> Tab
        Creates and registers a new Matcha tab.
        tabName : string - Label shown in Matcha's sidebar.

    Tab:setBuilder(fn: function) -> void
        fn(ctx) - Called every render frame. Receives a Ctx object.
        Must be set before :mount() is called.

    Tab:mount() -> void
        Registers the tab with UI.AddTab and shows a loading
        screen until :ready() is called.

    Tab:ready() -> void
        Signals that async setup is done. Triggers first real render.

    Tab:unmount() -> void
        Calls UI.RemoveTab and cleans up all internal state.
        Safe to call multiple times.

    Tab:notify(message: string, duration: number?) -> void
        Shows a Matcha notification tied to this tab's name.

    -- Ctx object (passed to the builder function) --

    Ctx:leftSection(title: string, subTabs: table?) -> Section
    Ctx:rightSection(title: string, subTabs: table?) -> Section
        Creates a Left/Right panel. subTabs is an optional string array.
        Returns a Section object.

    Section.page : number
        Current sub-tab index (0-based). Only present when subTabs was given.

    Section:text(content: string) -> void
    Section:spacing() -> void

    Section:button(label: string, fn: function) -> void
    Section:button(label: string, w: number, h: number, fn: function) -> void

    Section:toggle(key: string, label: string, default: boolean?) -> boolean
        Native Matcha flip-switch. Returns the current boolean value.
        State is persisted automatically by Matcha via the key.

    Section:checkbox(key: string, label: string, default: boolean?) -> boolean
        Native Matcha checkbox. Returns the current boolean value.

    Section:slider(key: string, label: string, min: number, max: number, default: number?) -> number
        Native Matcha slider. Returns the current numeric value.

    Section:inputText(key: string, placeholder: string, default: string?) -> void
    Section:combo(key: string, label: string, options: table, idx: number?) -> void

    -- State helpers (namespaced to tab name, no key collisions) --

    Ctx:get(key: string) -> any
    Ctx:set(key: string, value: any) -> void
]]

--  internal helpers 

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

--  Section wrapper 

local Section = {}
Section.__index = Section

function Section._new(raw, subTabs)
    local self = setmetatable({}, Section)
    self._raw = raw
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

function Section:button(label, w, h, fn)
    assertStr(label, "label")
    -- short form: button(label, fn)
    if type(w) == "function" then
        fn = w
        self._raw:Button(label, fn)
    else
        assertFn(fn, "fn")
        self._raw:Button(label, w, h, fn)
    end
end

function Section:toggle(key, label, default)
    -- Native Matcha flip-switch widget.
    -- State is owned by Matcha (UI.GetValue/SetValue).
    -- Returns current boolean so callers can branch on the value.
    assertStr(key,   "key")
    assertStr(label, "label")
    local init = (default == true) and true or false
    self._raw:Toggle(key, label, init)
    local val = UI.GetValue(key)
    return (val == true or val == 1)
end

function Section:checkbox(key, label, default)
    -- Native Matcha checkbox widget.
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

--  Ctx (render context) 

local Ctx = {}
Ctx.__index = Ctx

function Ctx._new(tab, rawTab)
    local self = setmetatable({}, Ctx)
    self._tab    = tab
    self._rawTab = rawTab
    return self
end

function Ctx:_ns(key)
    -- prefix key with tab name to avoid global collisions
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
    return Section._new(raw, subTabs)
end

function Ctx:rightSection(title, subTabs)
    assertStr(title, "title")
    local raw = self._rawTab:Section(title, "Right", subTabs)
    return Section._new(raw, subTabs)
end

--  Tab 

local Tab = {}
Tab.__index = Tab

function Tab._new(name)
    assertStr(name, "tabName")
    local self = setmetatable({}, Tab)
    self._name    = name
    self._builder = nil
    self._mounted = false
    self._ready   = false
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
            local s = rawTab:Section("Please wait", "Left")
            s:Text("[ " .. self_._name .. " ] Loading...")
            return
        end

        local ok, err = pcall(self_._builder, ctx)
        if not ok then
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
    pcall(UI.RemoveTab, self._name)
    self._mounted = false
    self._ready   = false
end

function Tab:notify(message, duration)
    assert(type(message) == "string", "TabService: notify message must be a string.")
    notify(message, self._name, duration or 5)
end

--  Public API 

local TabService = {}

function TabService.new(tabName)
    return Tab._new(tabName)
end

return TabService
