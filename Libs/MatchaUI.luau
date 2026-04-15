-- @env: Matcha LuaVM
-- @module: MatchaUI
-- @version: 3.0.0
-- @description: Drawing-based UI library for the Matcha external executor.
--               v3 fixes: visible background, ASCII-only chars, keybind listener,
--               full drag sync for all sub-elements, English-only strings.

print("[MatchaUI] v3.0.0 loaded.")

-- ============================================================
--  SAFETY GUARD
-- ============================================================
local _exec = identifyexecutor()
if _exec ~= "Matcha" then
    error("[MatchaUI] This library requires the Matcha executor.")
end

-- ============================================================
--  MODULE TABLE
-- ============================================================
local MatchaUI = {}

-- ============================================================
--  THEME
-- ============================================================
local Theme = {
    WindowBg        = Color3.fromRGB(18,  18,  24),
    TitleBarBg      = Color3.fromRGB(28,  28,  38),
    TitleText       = Color3.fromRGB(220, 220, 235),
    Border          = Color3.fromRGB(55,  55,  75),
    BorderAccent    = Color3.fromRGB(90,  90, 130),

    ControlBg       = Color3.fromRGB(30,  30,  42),
    ControlHover    = Color3.fromRGB(42,  42,  58),
    ControlActive   = Color3.fromRGB(55,  55,  80),
    ControlText     = Color3.fromRGB(200, 200, 215),
    Placeholder     = Color3.fromRGB(100, 100, 120),

    Accent          = Color3.fromRGB(100, 100, 220),
    AccentDim       = Color3.fromRGB(65,  65, 145),
    AccentText      = Color3.fromRGB(255, 255, 255),

    Success         = Color3.fromRGB( 80, 200, 120),
    Danger          = Color3.fromRGB(220,  80,  80),
    Warning         = Color3.fromRGB(220, 180,  60),

    Slider          = Color3.fromRGB(100, 100, 220),
    SliderTrack     = Color3.fromRGB(40,  40,  55),
    CheckMark       = Color3.fromRGB(100, 220, 150),
    TooltipBg       = Color3.fromRGB(22,  22,  32),
    NotifBg         = Color3.fromRGB(25,  25,  38),
    ScrollBar       = Color3.fromRGB(60,  60,  90),
    TabActive       = Color3.fromRGB(100, 100, 220),
    TabInactive     = Color3.fromRGB(35,  35,  50),
    TabText         = Color3.fromRGB(190, 190, 210),

    FontUI          = Drawing.Fonts.UI,
    FontMono        = Drawing.Fonts.Monospace,
    FontSize        = 14,
    TitleSize       = 15,

    Padding         = 6,
    ElementHeight   = 22,
    TitleHeight     = 26,
    CornerRadius    = 4,
    ZBase           = 10,
}

function MatchaUI.SetTheme(overrides)
    for k, v in pairs(overrides) do Theme[k] = v end
end

-- ============================================================
--  INTERNAL HELPERS
-- ============================================================
local Mouse = game:GetService("Players").LocalPlayer:GetMouse()

local function GetMousePos()
    return Mouse.X, Mouse.Y
end

local function PointInRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function MakeSquare(x, y, w, h, color, zindex, filled, corner, transparency)
    local s        = Drawing.new("Square")
    s.Position     = Vector2.new(x, y)
    s.Size         = Vector2.new(w, h)
    s.Color        = color
    s.Filled       = (filled == nil) and true or filled
    s.ZIndex       = zindex or Theme.ZBase
    s.Corner       = corner or 0
    s.Transparency = transparency or 0
    s.Visible      = true
    return s
end

local function MakeText(text, x, y, size, color, zindex, outline, center, font)
    local t    = Drawing.new("Text")
    t.Text     = text
    t.Position = Vector2.new(x, y)
    t.Size     = size or Theme.FontSize
    t.Color    = color or Theme.ControlText
    t.ZIndex   = zindex or Theme.ZBase + 1
    t.Outline  = (outline == nil) and true or outline
    t.Center   = center or false
    t.Font     = font or Theme.FontUI
    t.Visible  = true
    return t
end

-- Move a list of Drawing objects by (dx, dy)
local function ShiftObjects(objs, dx, dy)
    for _, obj in ipairs(objs) do
        obj.Position = Vector2.new(obj.Position.X + dx, obj.Position.Y + dy)
    end
end

-- ============================================================
--  OBJECT REGISTRY (global cleanup list)
-- ============================================================
local _AllObjects = {}

local function Track(obj)
    table.insert(_AllObjects, obj)
    return obj
end

function MatchaUI.Destroy()
    for _, obj in ipairs(_AllObjects) do
        pcall(function() obj:Remove() end)
    end
    _AllObjects = {}
end

-- ============================================================
--  WINDOW
-- ============================================================
local Window = {}
Window.__index = Window

function MatchaUI.NewWindow(cfg)
    local self          = setmetatable({}, Window)
    self.Title          = cfg.Title  or "MatchaUI"
    self.X              = cfg.X      or 100
    self.Y              = cfg.Y      or 100
    self.Width          = cfg.Width  or 280
    self.ZIndex         = cfg.ZIndex or Theme.ZBase
    self.Minimized      = false
    self._elements      = {}
    self._cursor        = 0
    self._contentH      = 0
    self._dragging      = false
    self._dragOffX      = 0
    self._dragOffY      = 0

    local z  = self.ZIndex
    local W  = self.Width
    local TH = Theme.TitleHeight

    -- Full window background — starts at TH height, grows with content
    self._bg         = Track(MakeSquare(self.X, self.Y, W, TH, Theme.WindowBg, z, true, Theme.CornerRadius))
    -- Title bar
    self._titleBar   = Track(MakeSquare(self.X, self.Y, W, TH, Theme.TitleBarBg, z + 1, true, Theme.CornerRadius))
    -- Title text
    self._titleText  = Track(MakeText(self.Title, self.X + Theme.Padding, self.Y + 6, Theme.TitleSize, Theme.TitleText, z + 2))
    -- Outer border
    self._border     = Track(MakeSquare(self.X, self.Y, W, TH, Theme.Border, z + 1, false, Theme.CornerRadius))
    -- Minimize button  (ASCII: "-" instead of "_")
    self._minBtn     = Track(MakeSquare(self.X + W - 22, self.Y + 5, 16, 16, Theme.ControlBg, z + 2, true, 2))
    self._minTxt     = Track(MakeText("-", self.X + W - 15, self.Y + 5, 13, Theme.ControlText, z + 3, false, true))
    -- Content panel (below title bar)
    self._contentBg  = Track(MakeSquare(self.X, self.Y + TH, W, 0, Theme.WindowBg, z, true, 0))
    self._contentBorder = Track(MakeSquare(self.X, self.Y + TH, W, 0, Theme.Border, z + 1, false, 0))

    -- Input polling loop
    task.spawn(function()
        while self._bg and self._bg.Visible do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()

            -- Minimize button
            local mbX = self.X + self.Width - 22
            local mbY = self.Y + 5
            if mb and PointInRect(mx, my, mbX, mbY, 16, 16) then
                task.wait(0.15)
                self:ToggleMinimize()
                task.wait(0.2)
            end

            -- Drag (excludes minimize button zone)
            if mb and PointInRect(mx, my, self.X, self.Y, self.Width - 24, TH) then
                if not self._dragging then
                    self._dragging = true
                    self._dragOffX = mx - self.X
                    self._dragOffY = my - self.Y
                end
            else
                self._dragging = false
            end

            if self._dragging and mb then
                self:_MoveTo(mx - self._dragOffX, my - self._dragOffY)
            end

            task.wait(0.02)
        end
    end)

    return self
end

MatchaUI.Window = MatchaUI.NewWindow

function Window:_MoveTo(nx, ny)
    local dx = nx - self.X
    local dy = ny - self.Y
    self.X   = nx
    self.Y   = ny

    -- Move all root drawing objects
    ShiftObjects({
        self._bg, self._titleBar, self._border,
        self._contentBg, self._contentBorder,
        self._titleText, self._minBtn, self._minTxt,
    }, dx, dy)

    -- Move each registered element
    for _, entry in ipairs(self._elements) do
        local el = entry.el
        entry.absX = entry.absX + dx
        entry.absY = entry.absY + dy
        if el._drawObjects then
            ShiftObjects(el._drawObjects, dx, dy)
        end
        if el._onMove then
            pcall(el._onMove, el, dx, dy)
        end
    end
end

function Window:ToggleMinimize()
    self.Minimized = not self.Minimized
    local show = not self.Minimized
    self._contentBg.Visible     = show
    self._contentBorder.Visible = show
    for _, entry in ipairs(self._elements) do
        entry.el:SetVisible(show)
    end
    -- ASCII: "+" when minimized, "-" when open
    self._minTxt.Text = self.Minimized and "+" or "-"
    self:_RefreshSize()
end

function Window:_RefreshSize()
    local TH = Theme.TitleHeight
    if self.Minimized then
        self._bg.Size            = Vector2.new(self.Width, TH)
        self._titleBar.Size      = Vector2.new(self.Width, TH)
        self._border.Size        = Vector2.new(self.Width, TH)
        self._contentBg.Size     = Vector2.new(self.Width, 0)
        self._contentBorder.Size = Vector2.new(self.Width, 0)
    else
        local bodyH  = self._contentH + Theme.Padding
        local totalH = TH + bodyH
        -- _bg covers the entire window including title bar
        self._bg.Size            = Vector2.new(self.Width, totalH)
        self._titleBar.Size      = Vector2.new(self.Width, TH)
        self._border.Size        = Vector2.new(self.Width, totalH)
        self._contentBg.Size     = Vector2.new(self.Width, bodyH)
        self._contentBorder.Size = Vector2.new(self.Width, bodyH)
    end
end

function Window:_NextY()
    return self.Y + Theme.TitleHeight + Theme.Padding + self._cursor
end

function Window:_Advance(h)
    self._cursor   = self._cursor + h + Theme.Padding
    self._contentH = self._cursor
    self:_RefreshSize()
end

function Window:_Register(el, absX, absY)
    table.insert(self._elements, { el = el, absX = absX or 0, absY = absY or 0 })
end

-- ============================================================
--  SECTION
-- ============================================================
function Window:Section(label)
    local x = self.X + Theme.Padding
    local y = self:_NextY()
    local w = self.Width - Theme.Padding * 2

    local line = Track(MakeSquare(x, y + 8, w, 1, Theme.BorderAccent, self.ZIndex + 1))
    local txt  = Track(MakeText(label, x + 4, y, Theme.FontSize - 1, Theme.BorderAccent, self.ZIndex + 2))

    local el = {
        _drawObjects = {line, txt},
        SetVisible = function(_, v)
            line.Visible = v
            txt.Visible  = v
        end,
    }
    self:_Register(el, x, y)
    self:_Advance(16)
    return el
end

-- ============================================================
--  BUTTON
-- ============================================================
function Window:Button(cfg)
    local label   = cfg.Label   or "Button"
    local onClick = cfg.OnClick or function() end

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY

    local bg  = Track(MakeSquare(ax, ay, w, h, Theme.ControlBg, z, true, 3))
    local txt = Track(MakeText(label, ax + w/2, ay + 4, Theme.FontSize, Theme.ControlText, z + 1, true, true))
    local brd = Track(MakeSquare(ax, ay, w, h, Theme.Border, z, false, 3))

    local el = { _drawObjects = {bg, txt, brd} }
    el._absX = ax; el._absY = ay
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx
        el._absY = el._absY + dy
    end
    el.SetVisible = function(_, v)
        bg.Visible = v; txt.Visible = v; brd.Visible = v
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local hover  = PointInRect(mx, my, el._absX, el._absY, w, h)
            local mb     = ismouse1pressed()

            bg.Color  = hover and (mb and Theme.ControlActive or Theme.ControlHover) or Theme.ControlBg
            brd.Color = hover and Theme.Accent or Theme.Border

            if hover and mb and not clicked then
                clicked = true
                pcall(onClick)
            elseif not mb then
                clicked = false
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  TOGGLE
-- ============================================================
function Window:Toggle(cfg)
    local label    = cfg.Label    or "Toggle"
    local state    = cfg.Default  ~= nil and cfg.Default or false
    local onChange = cfg.OnChange or function() end

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY

    local bg   = Track(MakeSquare(ax, ay, w, h, Theme.ControlBg, z, true, 3))
    local pill = Track(MakeSquare(ax + w - 38, ay + 4, 32, h - 8, Theme.SliderTrack, z + 1, true, 6))
    local knob = Track(MakeSquare(ax + w - 36 + (state and 14 or 0), ay + 6, 14, h - 12,
                    state and Theme.Accent or Theme.Placeholder, z + 2, true, 4))
    local txt  = Track(MakeText(label, ax + Theme.Padding, ay + 4, Theme.FontSize, Theme.ControlText, z + 1))
    local brd  = Track(MakeSquare(ax, ay, w, h, Theme.Border, z, false, 3))

    local el = { _drawObjects = {bg, pill, knob, txt, brd}, Value = state }
    el._absX = ax; el._absY = ay
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
    end
    el.SetVisible = function(_, v)
        for _, d in ipairs(el._drawObjects) do d.Visible = v end
    end
    el.SetValue = function(_, v)
        state    = v; el.Value = v
        knob.Color    = v and Theme.Accent or Theme.Placeholder
        knob.Position = Vector2.new(el._absX + w - 36 + (v and 14 or 0), knob.Position.Y)
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local hover  = PointInRect(mx, my, el._absX, el._absY, w, h)
            local mb     = ismouse1pressed()

            bg.Color  = hover and Theme.ControlHover or Theme.ControlBg
            brd.Color = hover and Theme.Accent or Theme.Border

            if hover and mb and not clicked then
                clicked = true; state = not state
                el:SetValue(state); pcall(onChange, state)
            elseif not mb then clicked = false end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  SLIDER
-- ============================================================
function Window:Slider(cfg)
    local label    = cfg.Label    or "Slider"
    local minVal   = cfg.Min      or 0
    local maxVal   = cfg.Max      or 100
    local value    = cfg.Default  ~= nil and cfg.Default or minVal
    local onChange = cfg.OnChange or function() end
    local decimals = cfg.Decimals or 0

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY
    local trackY  = ay + h - 7

    local bg     = Track(MakeSquare(ax, ay, w, h, Theme.ControlBg, z, true, 3))
    local track  = Track(MakeSquare(ax + 4, trackY, w - 8, 4, Theme.SliderTrack, z + 1, true, 2))
    local fill   = Track(MakeSquare(ax + 4, trackY, 1, 4, Theme.Slider, z + 2, true, 2))
    local knob   = Track(MakeSquare(ax + 4, trackY - 3, 8, 10, Theme.Accent, z + 3, true, 3))
    local lTxt   = Track(MakeText(label, ax + Theme.Padding, ay + 3, Theme.FontSize, Theme.ControlText, z + 1))
    local valTxt = Track(MakeText(tostring(value), ax + w - 30, ay + 3, Theme.FontSize - 1, Theme.Placeholder, z + 1, false))

    local el = { _drawObjects = {bg, track, fill, knob, lTxt, valTxt}, Value = value }
    el._absX = ax; el._absY = ay
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
    end

    local function UpdateFill(v)
        local t   = (v - minVal) / (maxVal - minVal)
        local fw  = math.floor((w - 8) * t)
        fill.Size = Vector2.new(math.max(fw, 1), 4)
        knob.Position = Vector2.new(el._absX + 4 + fw - 4, knob.Position.Y)
        valTxt.Text   = string.format("%." .. decimals .. "f", v)
        value = v; el.Value = v
    end
    UpdateFill(value)

    el.SetVisible = function(_, v)
        for _, d in ipairs(el._drawObjects) do d.Visible = v end
    end
    el.SetValue = function(_, v)
        v = math.clamp(v, minVal, maxVal)
        UpdateFill(v)
    end

    task.spawn(function()
        local dragging = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, el._absX, el._absY, w, h)

            bg.Color = hover and Theme.ControlHover or Theme.ControlBg

            if hover and mb then dragging = true end
            if not mb then dragging = false end

            if dragging then
                local t = math.clamp((mx - (el._absX + 4)) / (w - 8), 0, 1)
                local v = minVal + (maxVal - minVal) * t
                local places = 10^decimals
                v = math.floor(v * places + 0.5) / places
                if v ~= value then
                    UpdateFill(v); pcall(onChange, v)
                end
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  DROPDOWN
--  FIX: option rows are stored as absolute objects and are shifted
--       via _onMove when the window drags.
-- ============================================================
function Window:Dropdown(cfg)
    local label    = cfg.Label    or "Dropdown"
    local options  = cfg.Options  or {}
    local selIdx   = cfg.Default  or 1
    local onChange = cfg.OnChange or function() end

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY

    local bg      = Track(MakeSquare(ax, ay, w, h, Theme.ControlBg, z, true, 3))
    local brd     = Track(MakeSquare(ax, ay, w, h, Theme.Border, z, false, 3))
    local selTxt  = Track(MakeText(options[selIdx] or "---", ax + Theme.Padding, ay + 4, Theme.FontSize, Theme.ControlText, z + 1))
    -- ASCII arrow: "v" / "^"
    local arrowTxt= Track(MakeText("v", ax + w - 14, ay + 4, Theme.FontSize, Theme.Placeholder, z + 1))

    local isOpen = false
    local optBgs = {}
    for i, opt in ipairs(options) do
        local oy  = ay + h * i
        local ob  = Track(MakeSquare(ax, oy, w, h, Theme.ControlBg, z + 5, true, 0))
        local ot  = Track(MakeText(opt, ax + Theme.Padding, oy + 4, Theme.FontSize, Theme.ControlText, z + 6))
        local obl = Track(MakeSquare(ax, oy, w, h, Theme.Border, z + 5, false, 0))
        ob.Visible = false; ot.Visible = false; obl.Visible = false
        table.insert(optBgs, {bg = ob, txt = ot, brd = obl, offsetY = h * i})
    end

    -- Collect all option draw objects for the _drawObjects list
    local el = { _drawObjects = {bg, brd, selTxt, arrowTxt}, Value = options[selIdx], Index = selIdx }
    for _, ob in ipairs(optBgs) do
        table.insert(el._drawObjects, ob.bg)
        table.insert(el._drawObjects, ob.txt)
        table.insert(el._drawObjects, ob.brd)
    end

    el._absX = ax; el._absY = ay
    -- FIX: _onMove updates _absX/_absY so option hit-tests stay correct.
    -- The Drawing objects are already shifted by the global ShiftObjects in _MoveTo.
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
    end

    local function Close()
        isOpen = false; arrowTxt.Text = "v"
        for _, ob in ipairs(optBgs) do
            ob.bg.Visible = false; ob.txt.Visible = false; ob.brd.Visible = false
        end
    end
    local function Open()
        isOpen = true; arrowTxt.Text = "^"
        for _, ob in ipairs(optBgs) do
            ob.bg.Visible = true; ob.txt.Visible = true; ob.brd.Visible = true
        end
    end

    el.SetVisible = function(_, v)
        bg.Visible = v; brd.Visible = v; selTxt.Visible = v; arrowTxt.Visible = v
        if not v then Close() end
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local ax_, ay_ = el._absX, el._absY
            local hover  = PointInRect(mx, my, ax_, ay_, w, h)

            bg.Color  = hover and Theme.ControlHover or Theme.ControlBg
            brd.Color = hover and Theme.Accent or Theme.Border

            if hover and mb and not clicked then
                clicked = true
                if isOpen then Close() else Open() end
            elseif not mb then clicked = false end

            if isOpen then
                for i, ob in ipairs(optBgs) do
                    -- Compute option row Y from current element abs position
                    local oy  = ay_ + h * i
                    local hov = PointInRect(mx, my, ax_, oy, w, h)
                    ob.bg.Color = hov and Theme.ControlHover or Theme.ControlBg
                    if hov and mb and not clicked then
                        clicked = true; selIdx = i
                        el.Value = options[i]; el.Index = i
                        selTxt.Text = options[i]
                        pcall(onChange, options[i], i); Close()
                    end
                end
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  TEXT INPUT
-- ============================================================
function Window:TextInput(cfg)
    local placeholder = cfg.Placeholder or "Type here..."
    local text        = cfg.Default     or ""
    local onChange    = cfg.OnChange    or function() end
    local onSubmit    = cfg.OnSubmit    or function() end
    local maxLen      = cfg.MaxLength   or 64

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY

    local bg     = Track(MakeSquare(ax, ay, w, h, Theme.ControlBg, z, true, 3))
    local brd    = Track(MakeSquare(ax, ay, w, h, Theme.Border, z, false, 3))
    local cursor = Track(MakeSquare(ax + Theme.Padding, ay + 4, 1, h - 8, Theme.Accent, z + 2))
    cursor.Visible = false

    local displayColor = #text > 0 and Theme.ControlText or Theme.Placeholder
    local txt = Track(MakeText(#text > 0 and text or placeholder, ax + Theme.Padding, ay + 4, Theme.FontSize, displayColor, z + 1))

    local focused = false
    local el = { _drawObjects = {bg, brd, txt, cursor}, Value = text }
    el._absX = ax; el._absY = ay
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
    end
    el.SetVisible = function(_, v)
        bg.Visible = v; brd.Visible = v; txt.Visible = v
        if not v then cursor.Visible = false end
    end
    el.SetValue = function(_, v)
        text = tostring(v); el.Value = text
        txt.Text  = #text > 0 and text or placeholder
        txt.Color = #text > 0 and Theme.ControlText or Theme.Placeholder
    end

    local shiftKeys = {
        [0x31]="!", [0x32]="@", [0x33]="#", [0x34]="$", [0x35]="%",
        [0x36]="^", [0x37]="&", [0x38]="*", [0x39]="(", [0x30]=")",
        [0xBD]="_", [0xBB]="+", [0xDB]="{", [0xDD]="}", [0xBA]=":",
        [0xDE]='"', [0xBC]="<", [0xBE]=">", [0xBF]="?",
    }
    local normalKeys = {
        [0x30]="0",[0x31]="1",[0x32]="2",[0x33]="3",[0x34]="4",
        [0x35]="5",[0x36]="6",[0x37]="7",[0x38]="8",[0x39]="9",
        [0x41]="a",[0x42]="b",[0x43]="c",[0x44]="d",[0x45]="e",
        [0x46]="f",[0x47]="g",[0x48]="h",[0x49]="i",[0x4A]="j",
        [0x4B]="k",[0x4C]="l",[0x4D]="m",[0x4E]="n",[0x4F]="o",
        [0x50]="p",[0x51]="q",[0x52]="r",[0x53]="s",[0x54]="t",
        [0x55]="u",[0x56]="v",[0x57]="w",[0x58]="x",[0x59]="y",
        [0x5A]="z",[0x20]=" ",[0xBD]="-",[0xBB]="=",[0xDB]="[",
        [0xDD]="]",[0xBA]=";",[0xDE]="'",[0xBC]=",",[0xBE]=".",[0xBF]="/",
    }

    local heldKey = nil; local heldTimer = 0

    task.spawn(function()
        local clickCooldown = false
        local blinkTimer = 0; local blinkState = true

        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, el._absX, el._absY, w, h)

            if mb and hover and not clickCooldown then
                focused = true; clickCooldown = true; brd.Color = Theme.Accent
            elseif mb and not hover and not clickCooldown then
                focused = false; clickCooldown = true
                brd.Color = Theme.Border; cursor.Visible = false
            elseif not mb then
                clickCooldown = false
            end

            bg.Color = focused and Theme.ControlActive or (hover and Theme.ControlHover or Theme.ControlBg)

            if focused then
                blinkTimer = blinkTimer + 0.03
                if blinkTimer >= 0.5 then
                    blinkState = not blinkState; blinkTimer = 0
                    cursor.Visible = blinkState
                    local tw = #text * (Theme.FontSize * 0.55)
                    cursor.Position = Vector2.new(el._absX + Theme.Padding + tw, el._absY + 4)
                end

                local shift = iskeypressed(0x10) or iskeypressed(0xA0) or iskeypressed(0xA1)
                if iskeypressed(0x08) then
                    if heldKey ~= 0x08 then
                        heldKey = 0x08; heldTimer = 0
                        if #text > 0 then
                            text = text:sub(1,-2); el.Value = text
                            txt.Text = #text > 0 and text or placeholder
                            txt.Color = #text > 0 and Theme.ControlText or Theme.Placeholder
                            pcall(onChange, text)
                        end
                    else
                        heldTimer = heldTimer + 0.03
                        if heldTimer > 0.4 and #text > 0 then
                            text = text:sub(1,-2); el.Value = text
                            txt.Text = #text > 0 and text or placeholder
                            txt.Color = #text > 0 and Theme.ControlText or Theme.Placeholder
                            pcall(onChange, text); task.wait(0.05)
                        end
                    end
                elseif iskeypressed(0x0D) then
                    if heldKey ~= 0x0D then heldKey = 0x0D; pcall(onSubmit, text) end
                else
                    heldKey = nil; heldTimer = 0
                    for vk, ch in pairs(normalKeys) do
                        if iskeypressed(vk) and #text < maxLen then
                            local c = shift and (shiftKeys[vk] or ch:upper()) or ch
                            text = text .. c; el.Value = text
                            txt.Text = text; txt.Color = Theme.ControlText
                            pcall(onChange, text); task.wait(0.08); break
                        end
                    end
                end
            else
                heldKey = nil; heldTimer = 0
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  CHECKBOX
-- ============================================================
function Window:Checkbox(cfg)
    local label    = cfg.Label    or "Checkbox"
    local state    = cfg.Default  ~= nil and cfg.Default or false
    local onChange = cfg.OnChange or function() end

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY
    local bx, by = ax + 2, ay + 3
    local bs     = h - 6

    local bg    = Track(MakeSquare(ax, ay, w, h, Theme.ControlBg, z, true, 3))
    local box   = Track(MakeSquare(bx, by, bs, bs, Theme.ControlBg, z + 1, true, 2))
    local boxBrd= Track(MakeSquare(bx, by, bs, bs, Theme.Border, z + 1, false, 2))
    -- ASCII checkmark: "x" instead of Unicode checkmark
    local check = Track(MakeText("x", bx + 2, by, bs - 2, Theme.CheckMark, z + 2, false))
    check.Visible = state
    local txt   = Track(MakeText(label, bx + bs + 6, ay + 4, Theme.FontSize, Theme.ControlText, z + 1))

    local el = { _drawObjects = {bg, box, boxBrd, check, txt}, Value = state }
    el._absX = ax; el._absY = ay
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
    end
    el.SetVisible = function(_, v)
        bg.Visible = v; box.Visible = v; boxBrd.Visible = v; txt.Visible = v
        check.Visible = v and state
    end
    el.SetValue = function(_, v)
        state = v; el.Value = v; check.Visible = v
        boxBrd.Color = v and Theme.Accent or Theme.Border
    end
    if state then boxBrd.Color = Theme.Accent end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, el._absX, el._absY, w, h)

            bg.Color = hover and Theme.ControlHover or Theme.ControlBg
            if not state then boxBrd.Color = hover and Theme.AccentDim or Theme.Border end

            if hover and mb and not clicked then
                clicked = true; state = not state
                el:SetValue(state); pcall(onChange, state)
            elseif not mb then clicked = false end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  VALUE LABEL
-- ============================================================
function Window:ValueLabel(cfg)
    local label = cfg.Label or "Label"
    local val   = tostring(cfg.Value or "")

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY

    local bg   = Track(MakeSquare(ax, ay, w, h, Theme.ControlBg, z, true, 3))
    local lTxt = Track(MakeText(label, ax + Theme.Padding, ay + 4, Theme.FontSize, Theme.Placeholder, z + 1))
    local vTxt = Track(MakeText(val, ax + w - 60, ay + 4, Theme.FontSize, Theme.ControlText, z + 1))

    local el = { _drawObjects = {bg, lTxt, vTxt}, Value = val }
    el._absX = ax; el._absY = ay
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
    end
    el.SetVisible = function(_, v)
        bg.Visible = v; lTxt.Visible = v; vTxt.Visible = v
    end
    el.SetValue = function(_, v)
        el.Value = tostring(v); vTxt.Text = el.Value
    end

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  COLOR PICKER
--  FIX: expanded slider rows now move properly with the window.
-- ============================================================
function Window:ColorPicker(cfg)
    local label    = cfg.Label    or "Color"
    local color    = cfg.Default  or Color3.fromRGB(100, 100, 220)
    local onChange = cfg.OnChange or function() end

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY

    local bg      = Track(MakeSquare(ax, ay, w, h, Theme.ControlBg, z, true, 3))
    local lTxt    = Track(MakeText(label, ax + Theme.Padding, ay + 4, Theme.FontSize, Theme.ControlText, z + 1))
    local swatch  = Track(MakeSquare(ax + w - 28, ay + 3, 24, h - 6, color, z + 1, true, 3))
    local swatchB = Track(MakeSquare(ax + w - 28, ay + 3, 24, h - 6, Theme.Border, z + 1, false, 3))

    local expanded  = false
    local pickerH   = 18 * 3 + Theme.Padding * 4
    local pickerBg  = Track(MakeSquare(ax, ay + h, w, pickerH, Theme.TitleBarBg, z + 4, true, 3))
    local pickerBrd = Track(MakeSquare(ax, ay + h, w, pickerH, Theme.Border, z + 4, false, 3))
    pickerBg.Visible = false; pickerBrd.Visible = false

    local function RGBtoHSV(c)
        local r, g, b = c.R, c.G, c.B
        local mx = math.max(r,g,b); local mn = math.min(r,g,b); local d = mx-mn
        local hv = 0
        if d ~= 0 then
            if mx == r then hv = ((g-b)/d)%6
            elseif mx == g then hv = (b-r)/d+2
            else hv = (r-g)/d+4 end
            hv = hv/6
        end
        return hv, mx == 0 and 0 or d/mx, mx
    end

    local h_, s_, v_ = RGBtoHSV(color)
    local trackW = w - 8
    local chLabels = {"H","S","V"}
    local vals     = {h_, s_, v_}
    local tracks = {}; local fills = {}; local knobs = {}; local valTxts = {}
    local rowLbls = {}
    -- Store row base Y offsets (relative to picker panel top = ay+h)
    local rowBaseYs = {}

    local extraObjs = {pickerBg, pickerBrd}

    local function RebuildColor()
        color = Color3.fromHSV(vals[1], vals[2], vals[3])
        swatch.Color = color; pcall(onChange, color)
    end

    for i = 1, 3 do
        local ryOff = Theme.Padding + (i-1) * (18 + Theme.Padding / 2)
        rowBaseYs[i] = ryOff
        local ry  = ay + h + ryOff
        local lbl = Track(MakeText(chLabels[i], ax + 4, ry + 2, 12, Theme.Placeholder, z + 5))
        local tr  = Track(MakeSquare(ax + 16, ry + 5, trackW - 16, 4, Theme.SliderTrack, z + 5, true, 2))
        local fw  = math.floor((trackW - 16) * vals[i])
        local fl  = Track(MakeSquare(ax + 16, ry + 5, math.max(fw,1), 4, Theme.Slider, z + 6, true, 2))
        local kn  = Track(MakeSquare(ax + 16 + fw - 4, ry + 2, 8, 10, Theme.Accent, z + 7, true, 3))
        local vt  = Track(MakeText(string.format("%.2f", vals[i]), ax + w - 30, ry + 2, 11, Theme.Placeholder, z + 5))
        for _, obj in ipairs({lbl,tr,fl,kn,vt}) do obj.Visible = false; table.insert(extraObjs, obj) end
        tracks[i] = tr; fills[i] = fl; knobs[i] = kn; valTxts[i] = vt; rowLbls[i] = lbl
    end

    local allDraw = {bg, lTxt, swatch, swatchB}
    for _, o in ipairs(extraObjs) do table.insert(allDraw, o) end

    local el = { _drawObjects = allDraw, Value = color }
    el._absX = ax; el._absY = ay
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
    end
    el.SetVisible = function(_, v)
        bg.Visible = v; lTxt.Visible = v; swatch.Visible = v; swatchB.Visible = v
        if not v then
            expanded = false; pickerBg.Visible = false; pickerBrd.Visible = false
            for i = 1,3 do
                tracks[i].Visible=false; fills[i].Visible=false
                knobs[i].Visible=false; valTxts[i].Visible=false
                rowLbls[i].Visible=false
            end
        end
    end

    -- Slider interaction threads (use el._absX/Y for hit-tests after drag)
    for i = 1, 3 do
        local iCopy = i
        task.spawn(function()
            while bg.Visible ~= nil do
                if expanded then
                    local mx, my = GetMousePos()
                    local mb     = ismouse1pressed()
                    local ry = el._absY + h + rowBaseYs[iCopy]
                    if mb and PointInRect(mx, my, el._absX+16, ry, trackW-16, 14) then
                        local t = math.clamp((mx-(el._absX+16))/(trackW-16), 0, 1)
                        vals[iCopy] = t
                        local nfw = math.floor((trackW-16)*t)
                        fills[iCopy].Size = Vector2.new(math.max(nfw,1), 4)
                        knobs[iCopy].Position = Vector2.new(el._absX+16+nfw-4, ry+2)
                        valTxts[iCopy].Text = string.format("%.2f", t)
                        RebuildColor()
                    end
                end
                task.wait(0.03)
            end
        end)
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hov    = PointInRect(mx, my, el._absX + w - 28, el._absY + 3, 24, h - 6)
            if hov and mb and not clicked then
                clicked = true; expanded = not expanded
                pickerBg.Visible = expanded; pickerBrd.Visible = expanded
                for i = 1,3 do
                    tracks[i].Visible = expanded; fills[i].Visible = expanded
                    knobs[i].Visible = expanded; valTxts[i].Visible = expanded
                    rowLbls[i].Visible = expanded
                end
            elseif not mb then clicked = false end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  KEYBIND
--  FIX 1: Wait for mouse button release before scanning new key,
--          so the click that entered listen mode is never captured.
--  FIX 2: Added a `TriggerKey` function so external code can use
--          the bound key via keypress/keyrelease.
-- ============================================================
function Window:Keybind(cfg)
    local label    = cfg.Label    or "Keybind"
    local vk       = cfg.Default  or 0x72
    local onChange = cfg.OnChange or function() end

    local VKNames = {
        [0x08]="Backspace",[0x09]="Tab",[0x0D]="Enter",[0x10]="Shift",
        [0x11]="Ctrl",[0x12]="Alt",[0x1B]="Esc",[0x20]="Space",
        [0x70]="F1",[0x71]="F2",[0x72]="F3",[0x73]="F4",[0x74]="F5",
        [0x75]="F6",[0x76]="F7",[0x77]="F8",[0x78]="F9",[0x79]="F10",
        [0x7A]="F11",[0x7B]="F12",
        [0xBD]="Minus",[0xBB]="Plus",[0xBC]="Comma",[0xBE]="Period",
    }
    for i = 0x41, 0x5A do VKNames[i] = string.char(i) end
    for i = 0x30, 0x39 do VKNames[i] = string.char(i) end
    for i = 0x60, 0x69 do VKNames[i] = "Num" .. (i - 0x60) end

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY

    local bg   = Track(MakeSquare(ax, ay, w, h, Theme.ControlBg, z, true, 3))
    local brd  = Track(MakeSquare(ax, ay, w, h, Theme.Border, z, false, 3))
    local lTxt = Track(MakeText(label, ax + Theme.Padding, ay + 4, Theme.FontSize, Theme.ControlText, z + 1))
    local kTxt = Track(MakeText("[" .. (VKNames[vk] or "???") .. "]", ax + w - 60, ay + 4, Theme.FontSize, Theme.Accent, z + 1))

    local listening = false
    local el = { _drawObjects = {bg, brd, lTxt, kTxt}, Value = vk, Name = VKNames[vk] or "???" }
    el._absX = ax; el._absY = ay
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
    end
    el.SetVisible = function(_, v)
        bg.Visible = v; brd.Visible = v; lTxt.Visible = v; kTxt.Visible = v
    end

    -- TriggerKey: simulate press of the bound key inside Roblox
    el.TriggerKey = function(_)
        if isrbxactive() then
            setrobloxinput(true)
            keypress(vk)
            task.wait(0.05)
            keyrelease(vk)
            setrobloxinput(false)
        end
    end

    task.spawn(function()
        local wasClicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, el._absX, el._absY, w, h)

            bg.Color  = listening and Theme.ControlActive or (hover and Theme.ControlHover or Theme.ControlBg)
            brd.Color = listening and Theme.Accent or Theme.Border
            kTxt.Text = listening and "[...]" or "[" .. (VKNames[vk] or string.format("0x%X", vk)) .. "]"

            -- Enter listen mode on click
            if hover and mb and not wasClicked then
                wasClicked = true; listening = true
            end
            if not mb then wasClicked = false end

            if listening then
                -- Wait until mouse button is fully released before accepting a key
                -- so the click that triggered listen mode is not captured as the bind.
                if not mb then
                    for code = 0x08, 0x7B do
                        -- Skip mouse buttons (0x01, 0x02, 0x04) and ignored codes
                        if code ~= 0x01 and code ~= 0x02 and code ~= 0x04 then
                            if iskeypressed(code) then
                                vk = code; el.Value = vk
                                el.Name = VKNames[vk] or string.format("0x%X", vk)
                                listening = false
                                pcall(onChange, vk, el.Name)
                                task.wait(0.15)
                                break
                            end
                        end
                    end
                end
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  SEARCH BAR
-- ============================================================
function Window:SearchBar(cfg)
    cfg = cfg or {}
    -- ASCII search icon: "[?]" prefix in placeholder instead of Unicode glyph
    cfg.Placeholder = cfg.Placeholder or "Search..."
    local onChangeCfg = cfg.OnChange or function() end

    local iconOffX = Theme.Padding
    local iconOffY = Theme.TitleHeight + Theme.Padding + self._cursor
    local ax, ay   = self.X + iconOffX, self.Y + iconOffY
    local z        = self.ZIndex + 1

    -- "S>" is a readable ASCII stand-in for the search glyph
    local icon = Track(MakeText("S>", ax + 3, ay + 4, Theme.FontSize - 2, Theme.Placeholder, z + 2, false))

    cfg.OnChange = onChangeCfg
    local el = self:TextInput(cfg)
    table.insert(el._drawObjects, icon)

    local origOnMove = el._onMove
    el._onMove = function(self_, dx, dy)
        if origOnMove then origOnMove(self_, dx, dy) end
        icon.Position = Vector2.new(icon.Position.X + dx, icon.Position.Y + dy)
    end

    -- Nudge text right to make room for icon
    local txtObj = el._drawObjects[3]
    if txtObj then
        txtObj.Position = Vector2.new(txtObj.Position.X + 16, txtObj.Position.Y)
    end

    return el
end

-- ============================================================
--  TAB SYSTEM
-- ============================================================
function Window:Tabs(tabNames)
    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1
    local tw   = math.floor(w / #tabNames)

    local ax, ay = self.X + offX, self.Y + offY
    local active  = 1
    local callbacks = {}
    local groups = {}
    for i = 1, #tabNames do groups[i] = {} end

    local bgs  = {}; local txts = {}; local lines = {}; local allD = {}

    for i, name in ipairs(tabNames) do
        local tx  = ax + (i-1)*tw
        local isA = (i == active)
        local bg  = Track(MakeSquare(tx, ay, tw, h, isA and Theme.TabActive or Theme.TabInactive, z, true, 0))
        local txt = Track(MakeText(name, tx + tw/2, ay + 4, Theme.FontSize, Theme.TabText, z + 1, true, true))
        local ln  = Track(MakeSquare(tx, ay + h - 2, tw, 2, isA and Theme.Accent or Theme.TabInactive, z + 1, true))
        bgs[i] = bg; txts[i] = txt; lines[i] = ln
        table.insert(allD, bg); table.insert(allD, txt); table.insert(allD, ln)
    end

    local tabEl = { _drawObjects = allD, ActiveTab = 1 }
    tabEl._absX = ax; tabEl._absY = ay
    tabEl._onMove = function(_, dx, dy)
        tabEl._absX = tabEl._absX + dx; tabEl._absY = tabEl._absY + dy
    end
    tabEl.SetVisible = function(_, v)
        for _, d in ipairs(allD) do d.Visible = v end
        if v then
            for i, grp in ipairs(groups) do
                local show = (i == active)
                for _, ge in ipairs(grp) do ge:SetVisible(show) end
            end
        else
            for _, grp in ipairs(groups) do
                for _, ge in ipairs(grp) do ge:SetVisible(false) end
            end
        end
    end

    local function SwitchTo(idx)
        active = idx; tabEl.ActiveTab = idx
        for i = 1, #tabNames do
            local isA = (i == idx)
            bgs[i].Color   = isA and Theme.TabActive  or Theme.TabInactive
            lines[i].Color = isA and Theme.Accent      or Theme.TabInactive
            for _, ge in ipairs(groups[i]) do ge:SetVisible(isA) end
        end
        if callbacks[idx] then pcall(callbacks[idx]) end
    end

    tabEl.OnTab = function(_, name, cb)
        for i, n in ipairs(tabNames) do
            if n == name then
                callbacks[i] = cb
                if i == active then pcall(cb) end
            end
        end
    end

    tabEl.Group = function(_, name)
        local groupIdx = nil
        for i, n in ipairs(tabNames) do
            if n == name then groupIdx = i; break end
        end
        if not groupIdx then
            error("[MatchaUI] Tab group '" .. tostring(name) .. "' not found.")
        end

        local grp    = {}
        local parent = self

        local function wrapEl(elem)
            table.insert(groups[groupIdx], elem)
            if groupIdx ~= active then elem:SetVisible(false) end
            return elem
        end

        function grp:Section(label)  return wrapEl(parent:Section(label))  end
        function grp:Button(c)       return wrapEl(parent:Button(c))       end
        function grp:Toggle(c)       return wrapEl(parent:Toggle(c))       end
        function grp:Slider(c)       return wrapEl(parent:Slider(c))       end
        function grp:Checkbox(c)     return wrapEl(parent:Checkbox(c))     end
        function grp:Dropdown(c)     return wrapEl(parent:Dropdown(c))     end
        function grp:TextInput(c)    return wrapEl(parent:TextInput(c))    end
        function grp:SearchBar(c)    return wrapEl(parent:SearchBar(c))    end
        function grp:Keybind(c)      return wrapEl(parent:Keybind(c))      end
        function grp:ColorPicker(c)  return wrapEl(parent:ColorPicker(c))  end
        function grp:ValueLabel(c)   return wrapEl(parent:ValueLabel(c))   end
        function grp:ScrollFrame(c)  return wrapEl(parent:ScrollFrame(c))  end
        return grp
    end

    task.spawn(function()
        local clicked = false
        while bgs[1] and bgs[1].Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local ax_, ay_ = tabEl._absX, tabEl._absY
            for i = 1, #tabNames do
                local tx  = ax_ + (i-1)*tw
                local hov = PointInRect(mx, my, tx, ay_, tw, h)
                if hov and mb and not clicked then
                    clicked = true
                    if i ~= active then SwitchTo(i) end
                elseif not mb then
                    clicked = false
                end
            end
            task.wait(0.03)
        end
    end)

    self:_Register(tabEl, ax, ay)
    self:_Advance(h + 2)
    return tabEl
end

-- ============================================================
--  SCROLL FRAME
-- ============================================================
function Window:ScrollFrame(cfg)
    local visH  = cfg.Height       or 120
    local lines = cfg.ContentLines or {}
    local lineH = cfg.LineHeight   or 16

    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY

    local totalH    = #lines * lineH
    local scrollY   = 0
    local maxScroll = math.max(0, totalH - visH)

    local bg  = Track(MakeSquare(ax, ay, w, visH, Theme.ControlBg, z, true, 3))
    local brd = Track(MakeSquare(ax, ay, w, visH, Theme.Border, z, false, 3))

    local sbW  = 5; local sbX = ax + w - sbW - 2
    local sbTr = Track(MakeSquare(sbX, ay + 2, sbW, visH - 4, Theme.SliderTrack, z + 1, true, 2))
    local sbH  = math.max(20, math.floor((visH / math.max(totalH, 1)) * (visH - 4)))
    local sbFl = Track(MakeSquare(sbX, ay + 2, sbW, sbH, Theme.ScrollBar, z + 2, true, 2))

    local maxVis  = math.floor(visH / lineH)
    local txtObjs = {}
    for i = 1, math.min(maxVis + 1, math.max(#lines, 1)) do
        local t = Track(MakeText("", ax + 4, ay + (i-1)*lineH, lineH - 2, Theme.ControlText, z + 1, false))
        t.Font = Theme.FontMono
        table.insert(txtObjs, t)
    end

    local allD = {bg, brd, sbTr, sbFl}
    for _, t in ipairs(txtObjs) do table.insert(allD, t) end

    local el = { _drawObjects = allD, Lines = lines }
    el._absX = ax; el._absY = ay

    local function Refresh()
        local startLine = math.floor(scrollY / lineH) + 1
        for i, txtObj in ipairs(txtObjs) do
            local li = startLine + i - 1
            if li >= 1 and li <= #lines then
                txtObj.Text = lines[li]; txtObj.Visible = true
            else
                txtObj.Visible = false
            end
            txtObj.Position = Vector2.new(el._absX + 4, el._absY + (i-1)*lineH - (scrollY % lineH))
        end
        local t = maxScroll > 0 and scrollY / maxScroll or 0
        sbFl.Position = Vector2.new(sbX, el._absY + 2 + math.floor(t * (visH - 4 - sbH)))
    end
    Refresh()

    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
        Refresh()
    end
    el.SetVisible = function(_, v)
        for _, d in ipairs(allD) do d.Visible = v end
    end
    el.AddLine = function(_, line)
        table.insert(lines, line)
        totalH    = #lines * lineH
        maxScroll = math.max(0, totalH - visH)
        scrollY   = maxScroll
        Refresh()
    end
    el.Clear = function(_)
        lines = {}; totalH = 0; maxScroll = 0; scrollY = 0
        for _, t in ipairs(txtObjs) do t.Visible = false end
    end

    task.spawn(function()
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local hover  = PointInRect(mx, my, el._absX, el._absY, w, visH)
            if hover then
                if iskeypressed(0x26) then
                    scrollY = math.max(0, scrollY - lineH); Refresh(); task.wait(0.1)
                elseif iskeypressed(0x28) then
                    scrollY = math.min(maxScroll, scrollY + lineH); Refresh(); task.wait(0.1)
                end
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(visH)
    return el
end

-- ============================================================
--  CLOSE BUTTON
-- ============================================================
function Window:CloseButton(onClose)
    local cb   = onClose or function() end
    local offX = Theme.Padding
    local offY = Theme.TitleHeight + Theme.Padding + self._cursor
    local w    = self.Width - Theme.Padding * 2
    local h    = Theme.ElementHeight
    local z    = self.ZIndex + 1

    local ax, ay = self.X + offX, self.Y + offY

    local bg  = Track(MakeSquare(ax, ay, w, h, Theme.Danger, z, true, 3))
    -- ASCII: "X  Close" (no Unicode)
    local txt = Track(MakeText("X  Close", ax + w/2, ay + 4, Theme.FontSize, Theme.AccentText, z + 1, true, true))

    local el = { _drawObjects = {bg, txt} }
    el._absX = ax; el._absY = ay
    el._onMove = function(_, dx, dy)
        el._absX = el._absX + dx; el._absY = el._absY + dy
    end
    el.SetVisible = function(_, v)
        bg.Visible = v; txt.Visible = v
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, el._absX, el._absY, w, h)

            bg.Color = hover and (mb and Color3.fromRGB(180,50,50) or Color3.fromRGB(200,60,60)) or Theme.Danger

            if hover and mb and not clicked then
                clicked = true
                for _, d in ipairs({self._bg, self._titleBar, self._titleText,
                                    self._border, self._minBtn, self._minTxt,
                                    self._contentBg, self._contentBorder}) do
                    d.Visible = false
                end
                for _, entry in ipairs(self._elements) do
                    entry.el:SetVisible(false)
                end
                pcall(cb)
            elseif not mb then
                clicked = false
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el, ax, ay)
    self:_Advance(h)
    return el
end

-- ============================================================
--  TOOLTIP
-- ============================================================
function MatchaUI.Tooltip(cfg)
    local text = cfg.Text   or "Tooltip"
    local bx   = cfg.BoundX or 0
    local by   = cfg.BoundY or 0
    local bw   = cfg.BoundW or 100
    local bh   = cfg.BoundH or 20
    local zTop = 200

    local tw = math.max(#text * 7 + 12, 60)
    local th = 20

    local bg  = Track(MakeSquare(0, 0, tw, th, Theme.TooltipBg, zTop, true, 3))
    local brd = Track(MakeSquare(0, 0, tw, th, Theme.BorderAccent, zTop, false, 3))
    local txt = Track(MakeText(text, 0, 0, Theme.FontSize - 1, Theme.ControlText, zTop + 1))
    bg.Visible = false; brd.Visible = false; txt.Visible = false

    local alive = true
    task.spawn(function()
        while alive do
            local mx, my = GetMousePos()
            local show = PointInRect(mx, my, bx, by, bw, bh)
            bg.Visible = show; brd.Visible = show; txt.Visible = show
            if show then
                local tx_ = mx + 12; local ty_ = my + 16
                bg.Position  = Vector2.new(tx_, ty_)
                brd.Position = Vector2.new(tx_, ty_)
                txt.Position = Vector2.new(tx_ + 6, ty_ + 3)
            end
            task.wait(0.04)
        end
    end)

    return {
        Remove = function()
            alive = false
            bg:Remove(); brd:Remove(); txt:Remove()
        end,
        SetBounds = function(_, x, y, w2, h2)
            bx = x; by = y; bw = w2; bh = h2
        end,
    }
end

-- ============================================================
--  NOTIFICATION
-- ============================================================
local _notifSlot = 0

function MatchaUI.Notify(cfg)
    local title   = cfg.Title    or "Notice"
    local message = cfg.Message  or ""
    local dur     = cfg.Duration or 4
    local ntype   = cfg.Type     or "info"

    local accentColor = ({
        success = Theme.Success,
        danger  = Theme.Danger,
        warning = Theme.Warning,
        info    = Theme.Accent,
    })[ntype] or Theme.Accent

    local cam    = workspace.CurrentCamera
    local sw, sh = cam.ViewportSize.X, cam.ViewportSize.Y
    local nw, nh = 240, 54
    local margin = 12
    _notifSlot   = _notifSlot + 1
    local nx     = sw - nw - margin
    local ny     = sh - margin - nh - (_notifSlot - 1) * (nh + 6)
    local z      = 500

    local bg   = Track(MakeSquare(nx, ny, nw, nh, Theme.NotifBg, z, true, 4))
    local bar  = Track(MakeSquare(nx, ny, 4, nh, accentColor, z + 1, true, 0))
    local brd  = Track(MakeSquare(nx, ny, nw, nh, accentColor, z + 1, false, 4))
    local titT = Track(MakeText(title, nx + 10, ny + 7, Theme.FontSize, accentColor, z + 2))
    local msgT = Track(MakeText(message, nx + 10, ny + 24, Theme.FontSize - 1, Theme.ControlText, z + 2))

    task.spawn(function()
        task.wait(dur)
        pcall(function() bg:Remove(); bar:Remove(); brd:Remove(); titT:Remove(); msgT:Remove() end)
        _notifSlot = math.max(0, _notifSlot - 1)
    end)
end

-- ============================================================
--  RETURN MODULE
-- ============================================================
return MatchaUI
