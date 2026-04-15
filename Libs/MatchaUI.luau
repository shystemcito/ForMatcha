-- @env: Matcha LuaVM
-- @module: MatchaUI
-- @version: 1.0.0
-- @description: Comprehensive Drawing-based UI library for the Matcha external executor.
--               Provides 15 UI element types, drag-to-move windows, Z-index layering,
--               element grouping, auto-layout stacking, and minimize support.
--               No tweens or heavy animations — pure Draw system, minimal overhead.

-- ============================================================
--  SAFETY GUARD
-- ============================================================
local executor = identifyexecutor()
if executor ~= "Matcha" then
    error("[MatchaUI] This library requires the Matcha executor.")
end

-- ============================================================
--  MODULE TABLE
-- ============================================================
local MatchaUI = {}
MatchaUI.__index = MatchaUI

-- ============================================================
--  THEME (Dark, fully centralised)
-- ============================================================
local Theme = {
    -- Window
    WindowBg        = Color3.fromRGB(18,  18,  24),
    TitleBarBg      = Color3.fromRGB(28,  28,  38),
    TitleText       = Color3.fromRGB(220, 220, 235),
    Border          = Color3.fromRGB(55,  55,  75),
    BorderAccent    = Color3.fromRGB(90,  90, 130),

    -- Controls
    ControlBg       = Color3.fromRGB(30,  30,  42),
    ControlHover    = Color3.fromRGB(42,  42,  58),
    ControlActive   = Color3.fromRGB(55,  55,  80),
    ControlText     = Color3.fromRGB(200, 200, 215),
    Placeholder     = Color3.fromRGB(100, 100, 120),

    -- Accent
    Accent          = Color3.fromRGB(100, 100, 220),
    AccentDim       = Color3.fromRGB(65,  65, 145),
    AccentText      = Color3.fromRGB(255, 255, 255),

    -- States
    Success         = Color3.fromRGB( 80, 200, 120),
    Danger          = Color3.fromRGB(220,  80,  80),
    Warning         = Color3.fromRGB(220, 180,  60),

    -- Misc
    Slider          = Color3.fromRGB(100, 100, 220),
    SliderTrack     = Color3.fromRGB(40,  40,  55),
    CheckMark       = Color3.fromRGB(100, 220, 150),
    TooltipBg       = Color3.fromRGB(22,  22,  32),
    NotifBg         = Color3.fromRGB(25,  25,  38),
    ScrollBar       = Color3.fromRGB(60,  60,  90),
    TabActive       = Color3.fromRGB(100, 100, 220),
    TabInactive     = Color3.fromRGB(35,  35,  50),
    TabText         = Color3.fromRGB(190, 190, 210),

    -- Typography
    FontUI          = Drawing.Fonts.UI,
    FontMono        = Drawing.Fonts.Monospace,
    FontSize        = 14,
    TitleSize       = 15,

    -- Layout
    Padding         = 6,
    ElementHeight   = 22,
    TitleHeight     = 26,
    CornerRadius    = 4,
    ZBase           = 10,
}

-- Allow callers to override any theme value before creating windows.
function MatchaUI.SetTheme(overrides)
    for k, v in pairs(overrides) do
        Theme[k] = v
    end
end

-- ============================================================
--  INTERNAL HELPERS
-- ============================================================
local Mouse = game:GetService("Players").LocalPlayer:GetMouse()

-- Retrieve current cursor position.
local function GetMousePos()
    return Mouse.X, Mouse.Y
end

-- Test whether (mx,my) is inside a rect defined by (x,y,w,h).
local function PointInRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- Draw a quick filled square helper.
local function MakeSquare(x, y, w, h, color, zindex, filled, corner, transparency)
    local s       = Drawing.new("Square")
    s.Position    = Vector2.new(x, y)
    s.Size        = Vector2.new(w, h)
    s.Color       = color
    s.Filled      = (filled == nil) and true or filled
    s.ZIndex      = zindex or Theme.ZBase
    s.Corner      = corner or 0
    s.Transparency = transparency or 0
    s.Visible     = true
    return s
end

-- Draw a text label helper.
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

-- ============================================================
--  OBJECT REGISTRY (global cleanup list)
-- ============================================================
local _AllObjects = {} -- { drawingObj, ... }

local function Track(obj)
    table.insert(_AllObjects, obj)
    return obj
end

-- Call MatchaUI.Destroy() to remove every drawing object ever created.
function MatchaUI.Destroy()
    for _, obj in ipairs(_AllObjects) do
        pcall(function() obj:Remove() end)
    end
    _AllObjects = {}
end

-- ============================================================
--  WINDOW
-- ============================================================
--[[
  Creates a draggable, minimisable window that auto-stacks its children.

  Usage:
    local win = MatchaUI.Window({
        Title    = "My Script",
        X        = 100, Y = 100,
        Width    = 280,
        ZIndex   = 10,
    })

  win:Section("Header Text")         -- Group label
  win:Button({ ... })
  win:Slider({ ... })
  -- etc.
--]]

local Window = {}
Window.__index = Window

function MatchaUI.Window(cfg)
    local self         = setmetatable({}, Window)
    self.Title         = cfg.Title  or "MatchaUI"
    self.X             = cfg.X      or 100
    self.Y             = cfg.Y      or 100
    self.Width         = cfg.Width  or 280
    self.ZIndex        = cfg.ZIndex or Theme.ZBase
    self.Minimized     = false
    self._elements     = {}   -- list of element tables with :SetVisible(bool)
    self._cursor       = 0    -- Y offset for next element (relative to content area)
    self._contentH     = 0    -- current content height
    self._dragging     = false
    self._dragOffX     = 0
    self._dragOffY     = 0

    local z = self.ZIndex

    -- Background
    self._bg = Track(MakeSquare(self.X, self.Y, self.Width, Theme.TitleHeight, Theme.WindowBg, z, true, Theme.CornerRadius))
    -- Title bar
    self._titleBar = Track(MakeSquare(self.X, self.Y, self.Width, Theme.TitleHeight, Theme.TitleBarBg, z + 1, true, Theme.CornerRadius))
    -- Title text
    self._titleText = Track(MakeText(self.Title, self.X + Theme.Padding, self.Y + 5, Theme.TitleSize, Theme.TitleText, z + 2))
    -- Border
    self._border = Track(MakeSquare(self.X, self.Y, self.Width, Theme.TitleHeight, Theme.Border, z, false, Theme.CornerRadius))

    -- Minimize button  [ _ ]
    self._minBtn = Track(MakeSquare(self.X + self.Width - 22, self.Y + 5, 16, 16, Theme.ControlBg, z + 2, true, 2))
    self._minTxt = Track(MakeText("_", self.X + self.Width - 16, self.Y + 4, 13, Theme.ControlText, z + 3))

    -- Content area background (will resize)
    self._contentBg = Track(MakeSquare(self.X, self.Y + Theme.TitleHeight, self.Width, 0, Theme.WindowBg, z, true, 0))
    self._contentBorder = Track(MakeSquare(self.X, self.Y + Theme.TitleHeight, self.Width, 0, Theme.Border, z, false, 0))

    -- Start drag/minimize polling loop
    task.spawn(function()
        while self._bg.Visible do
            local mx, my = GetMousePos()
            local mb = ismouse1pressed()

            -- ---- Minimize button click ----
            local mbX = self.X + self.Width - 22
            local mbY = self.Y + 5
            if mb and PointInRect(mx, my, mbX, mbY, 16, 16) then
                task.wait(0.15) -- debounce
                self:ToggleMinimize()
                task.wait(0.2)
            end

            -- ---- Drag title bar ----
            if mb and PointInRect(mx, my, self.X, self.Y, self.Width - 24, Theme.TitleHeight) then
                if not self._dragging then
                    self._dragging = true
                    self._dragOffX = mx - self.X
                    self._dragOffY = my - self.Y
                end
            else
                self._dragging = false
            end

            if self._dragging and mb then
                local nx = mx - self._dragOffX
                local ny = my - self._dragOffY
                self:_MoveTo(nx, ny)
            end

            task.wait(0.02)
        end
    end)

    return self
end

function Window:_MoveTo(nx, ny)
    local dx = nx - self.X
    local dy = ny - self.Y
    self.X   = nx
    self.Y   = ny

    -- Move all root drawing objects
    for _, obj in ipairs({self._bg, self._titleBar, self._border, self._contentBg, self._contentBorder}) do
        obj.Position = Vector2.new(obj.Position.X + dx, obj.Position.Y + dy)
    end
    self._titleText.Position = Vector2.new(self._titleText.Position.X + dx, self._titleText.Position.Y + dy)
    self._minBtn.Position    = Vector2.new(self._minBtn.Position.X + dx, self._minBtn.Position.Y + dy)
    self._minTxt.Position    = Vector2.new(self._minTxt.Position.X + dx, self._minTxt.Position.Y + dy)

    -- Move all child element drawing objects
    for _, el in ipairs(self._elements) do
        if el._drawObjects then
            for _, d in ipairs(el._drawObjects) do
                d.Position = Vector2.new(d.Position.X + dx, d.Position.Y + dy)
            end
        end
    end
end

function Window:ToggleMinimize()
    self.Minimized = not self.Minimized
    local showContent = not self.Minimized
    self._contentBg.Visible     = showContent
    self._contentBorder.Visible = showContent
    for _, el in ipairs(self._elements) do
        el:SetVisible(showContent)
    end
    self._minTxt.Text = self.Minimized and "+" or "_"
    self:_RefreshSize()
end

function Window:_RefreshSize()
    if self.Minimized then
        self._bg.Size = Vector2.new(self.Width, Theme.TitleHeight)
        self._titleBar.Size = Vector2.new(self.Width, Theme.TitleHeight)
        self._border.Size   = Vector2.new(self.Width, Theme.TitleHeight)
    else
        local totalH = Theme.TitleHeight + self._contentH + Theme.Padding
        self._bg.Size           = Vector2.new(self.Width, totalH)
        self._contentBg.Size    = Vector2.new(self.Width, self._contentH + Theme.Padding)
        self._contentBorder.Size= Vector2.new(self.Width, self._contentH + Theme.Padding)
        self._border.Size       = Vector2.new(self.Width, totalH)
    end
end

-- Returns the absolute Y where the next element should start.
function Window:_NextY()
    return self.Y + Theme.TitleHeight + Theme.Padding + self._cursor
end

function Window:_Advance(h)
    self._cursor   = self._cursor + h + Theme.Padding
    self._contentH = self._cursor
    self:_RefreshSize()
end

function Window:_Register(el)
    table.insert(self._elements, el)
end

-- ============================================================
--  SECTION (group label)
-- ============================================================
function Window:Section(label)
    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2

    local line = Track(MakeSquare(x, y + 8, w, 1, Theme.BorderAccent, self.ZIndex + 1))
    local txt  = Track(MakeText(label, x + 4, y, Theme.FontSize - 1, Theme.BorderAccent, self.ZIndex + 2))

    local el = {
        _drawObjects = {line, txt},
        SetVisible = function(self_, v)
            line.Visible = v
            txt.Visible  = v
        end,
    }
    self:_Register(el)
    self:_Advance(16)
    return el
end

-- ============================================================
--  BUTTON
-- ============================================================
--[[
  cfg = {
    Label    = "Click Me",
    OnClick  = function() end,
  }
--]]
function Window:Button(cfg)
    local label   = cfg.Label   or "Button"
    local onClick = cfg.OnClick or function() end

    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1

    local bg  = Track(MakeSquare(x, y, w, h, Theme.ControlBg, z, true, 3))
    local txt = Track(MakeText(label, x + w/2, y + 4, Theme.FontSize, Theme.ControlText, z + 1, true, true))
    local brd = Track(MakeSquare(x, y, w, h, Theme.Border, z, false, 3))

    local el = { _drawObjects = {bg, txt, brd}, _active = true }
    el.SetVisible = function(_, v)
        bg.Visible  = v
        txt.Visible = v
        brd.Visible = v
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local hover  = PointInRect(mx, my, x, y, w, h)
            local mb     = ismouse1pressed()

            bg.Color = hover and (mb and Theme.ControlActive or Theme.ControlHover) or Theme.ControlBg
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

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  TOGGLE BUTTON
-- ============================================================
--[[
  cfg = {
    Label    = "Toggle Me",
    Default  = false,
    OnChange = function(state: boolean) end,
  }
--]]
function Window:Toggle(cfg)
    local label    = cfg.Label    or "Toggle"
    local state    = cfg.Default  ~= nil and cfg.Default or false
    local onChange = cfg.OnChange or function() end

    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1

    local bg      = Track(MakeSquare(x, y, w, h, Theme.ControlBg, z, true, 3))
    local pill    = Track(MakeSquare(x + w - 38, y + 4, 32, h - 8, Theme.SliderTrack, z + 1, true, 6))
    local knob    = Track(MakeSquare(x + w - 36 + (state and 14 or 0), y + 6, 14, h - 12, state and Theme.Accent or Theme.Placeholder, z + 2, true, 4))
    local txt     = Track(MakeText(label, x + Theme.Padding, y + 4, Theme.FontSize, Theme.ControlText, z + 1))
    local brd     = Track(MakeSquare(x, y, w, h, Theme.Border, z, false, 3))

    local el = { _drawObjects = {bg, pill, knob, txt, brd}, Value = state }
    el.SetVisible = function(_, v)
        for _, d in ipairs(el._drawObjects) do d.Visible = v end
    end
    el.SetValue = function(_, v)
        state     = v
        el.Value  = v
        knob.Color    = v and Theme.Accent or Theme.Placeholder
        knob.Position = Vector2.new(x + w - 36 + (v and 14 or 0), knob.Position.Y)
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local hover  = PointInRect(mx, my, x, y, w, h)
            local mb     = ismouse1pressed()

            bg.Color  = hover and Theme.ControlHover or Theme.ControlBg
            brd.Color = hover and Theme.Accent or Theme.Border

            if hover and mb and not clicked then
                clicked = true
                state   = not state
                el:SetValue(state)
                pcall(onChange, state)
            elseif not mb then
                clicked = false
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  SLIDER
-- ============================================================
--[[
  cfg = {
    Label    = "Speed",
    Min      = 0, Max = 100, Default = 50,
    OnChange = function(value: number) end,
    Decimals = 0,    -- decimal places in display
  }
--]]
function Window:Slider(cfg)
    local label    = cfg.Label    or "Slider"
    local minVal   = cfg.Min      or 0
    local maxVal   = cfg.Max      or 100
    local value    = cfg.Default  ~= nil and cfg.Default or minVal
    local onChange = cfg.OnChange or function() end
    local decimals = cfg.Decimals or 0

    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1

    local trackY = y + h - 7
    local bg     = Track(MakeSquare(x, y, w, h, Theme.ControlBg, z, true, 3))
    local track  = Track(MakeSquare(x + 4, trackY, w - 8, 4, Theme.SliderTrack, z + 1, true, 2))
    local fill   = Track(MakeSquare(x + 4, trackY, 1, 4, Theme.Slider, z + 2, true, 2))
    local knob   = Track(MakeSquare(x + 4, trackY - 3, 8, 10, Theme.Accent, z + 3, true, 3))
    local txt    = Track(MakeText(label, x + Theme.Padding, y + 3, Theme.FontSize, Theme.ControlText, z + 1))
    local valTxt = Track(MakeText(tostring(value), x + w - Theme.Padding, y + 3, Theme.FontSize - 1, Theme.Placeholder, z + 1, false, false))
    valTxt.Position = Vector2.new(x + w - 30, y + 3)

    local function UpdateFill(v)
        local t    = (v - minVal) / (maxVal - minVal)
        local fw   = math.floor((w - 8) * t)
        fill.Size  = Vector2.new(math.max(fw, 1), 4)
        knob.Position = Vector2.new(x + 4 + fw - 4, trackY - 3)
        local fmt  = "%." .. decimals .. "f"
        valTxt.Text = string.format(fmt, v)
        value = v
    end
    UpdateFill(value)

    local el = { _drawObjects = {bg, track, fill, knob, txt, valTxt}, Value = value }
    el.SetVisible = function(_, v)
        for _, d in ipairs(el._drawObjects) do d.Visible = v end
    end
    el.SetValue = function(_, v)
        v = math.clamp(v, minVal, maxVal)
        UpdateFill(v)
        el.Value = v
    end

    task.spawn(function()
        local dragging = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, x, y, w, h)

            bg.Color = hover and Theme.ControlHover or Theme.ControlBg

            if hover and mb then dragging = true end
            if not mb then dragging = false end

            if dragging then
                local t = math.clamp((mx - (x + 4)) / (w - 8), 0, 1)
                local v = minVal + (maxVal - minVal) * t
                local places = 10^decimals
                v = math.floor(v * places + 0.5) / places
                if v ~= value then
                    UpdateFill(v)
                    el.Value = v
                    pcall(onChange, v)
                end
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  DROPDOWN
-- ============================================================
--[[
  cfg = {
    Label    = "Mode",
    Options  = {"Option A", "Option B", "Option C"},
    Default  = 1,
    OnChange = function(option: string, index: number) end,
  }
--]]
function Window:Dropdown(cfg)
    local label    = cfg.Label    or "Dropdown"
    local options  = cfg.Options  or {}
    local selIdx   = cfg.Default  or 1
    local onChange = cfg.OnChange or function() end

    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1

    local bg      = Track(MakeSquare(x, y, w, h, Theme.ControlBg, z, true, 3))
    local brd     = Track(MakeSquare(x, y, w, h, Theme.Border, z, false, 3))
    local selTxt  = Track(MakeText(options[selIdx] or "---", x + Theme.Padding, y + 4, Theme.FontSize, Theme.ControlText, z + 1))
    local arrowTxt= Track(MakeText("v", x + w - 14, y + 4, Theme.FontSize, Theme.Placeholder, z + 1))

    -- Dropdown list (hidden until open)
    local isOpen    = false
    local optBgs    = {}
    local optTxts   = {}
    for i, opt in ipairs(options) do
        local oy  = y + h * i
        local ob  = Track(MakeSquare(x, oy, w, h, Theme.ControlBg, z + 5, true, 0))
        local ot  = Track(MakeText(opt, x + Theme.Padding, oy + 4, Theme.FontSize, Theme.ControlText, z + 6))
        local obl = Track(MakeSquare(x, oy, w, h, Theme.Border, z + 5, false, 0))
        ob.Visible  = false
        ot.Visible  = false
        obl.Visible = false
        table.insert(optBgs,  {bg = ob, txt = ot, brd = obl})
        table.insert(_AllObjects, obl)
    end

    local el = { _drawObjects = {bg, brd, selTxt, arrowTxt}, Value = options[selIdx], Index = selIdx }
    -- Include option objects in draw list for move support
    for _, ob in ipairs(optBgs) do
        table.insert(el._drawObjects, ob.bg)
        table.insert(el._drawObjects, ob.txt)
        table.insert(el._drawObjects, ob.brd)
    end

    local function Close()
        isOpen = false
        arrowTxt.Text = "v"
        for _, ob in ipairs(optBgs) do
            ob.bg.Visible  = false
            ob.txt.Visible = false
            ob.brd.Visible = false
        end
    end
    local function Open()
        isOpen = true
        arrowTxt.Text = "^"
        for _, ob in ipairs(optBgs) do
            ob.bg.Visible  = true
            ob.txt.Visible = true
            ob.brd.Visible = true
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
            local hover  = PointInRect(mx, my, x, y, w, h)

            bg.Color  = hover and Theme.ControlHover or Theme.ControlBg
            brd.Color = hover and Theme.Accent or Theme.Border

            -- Toggle open/close
            if hover and mb and not clicked then
                clicked = true
                if isOpen then Close() else Open() end
            elseif not mb then
                clicked = false
            end

            -- Check option clicks when open
            if isOpen then
                for i, ob in ipairs(optBgs) do
                    local oy = y + h * i
                    local hov= PointInRect(mx, my, x, oy, w, h)
                    ob.bg.Color = hov and Theme.ControlHover or Theme.ControlBg
                    if hov and mb and not clicked then
                        clicked = true
                        selIdx  = i
                        el.Value = options[i]
                        el.Index = i
                        selTxt.Text = options[i]
                        pcall(onChange, options[i], i)
                        Close()
                    end
                end
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  TEXT INPUT
-- ============================================================
--[[
  cfg = {
    Placeholder = "Enter text...",
    Default     = "",
    OnChange    = function(text: string) end,
    OnSubmit    = function(text: string) end,  -- called on Enter key (VK 0x0D)
    MaxLength   = 64,
  }
--]]
function Window:TextInput(cfg)
    local placeholder = cfg.Placeholder or "Type here..."
    local text        = cfg.Default     or ""
    local onChange    = cfg.OnChange    or function() end
    local onSubmit    = cfg.OnSubmit    or function() end
    local maxLen      = cfg.MaxLength   or 64

    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1

    local bg     = Track(MakeSquare(x, y, w, h, Theme.ControlBg, z, true, 3))
    local brd    = Track(MakeSquare(x, y, w, h, Theme.Border, z, false, 3))
    local cursor = Track(MakeSquare(x + Theme.Padding, y + 4, 1, h - 8, Theme.Accent, z + 2))
    cursor.Visible = false

    local function DisplayText()
        return #text > 0 and text or placeholder
    end
    local displayColor = #text > 0 and Theme.ControlText or Theme.Placeholder
    local txt = Track(MakeText(DisplayText(), x + Theme.Padding, y + 4, Theme.FontSize, displayColor, z + 1))

    local focused = false
    local el = { _drawObjects = {bg, brd, txt, cursor}, Value = text }
    el.SetVisible = function(_, v)
        bg.Visible = v; brd.Visible = v; txt.Visible = v
        if not v then cursor.Visible = false end
    end
    el.SetValue = function(_, v)
        text     = tostring(v)
        el.Value = text
        txt.Text  = #text > 0 and text or placeholder
        txt.Color = #text > 0 and Theme.ControlText or Theme.Placeholder
    end

    -- Key map for printable ASCII (VK -> char)
    -- We rely on iskeypressed polling for a subset of common keys.
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

    local heldKey   = nil
    local heldTimer = 0

    task.spawn(function()
        local clickCooldown = false
        local blinkTimer    = 0
        local blinkState    = true

        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, x, y, w, h)

            -- Focus
            if mb and hover and not clickCooldown then
                focused       = true
                clickCooldown = true
                brd.Color     = Theme.Accent
            elseif mb and not hover and not clickCooldown then
                focused       = false
                clickCooldown = true
                brd.Color     = Theme.Border
                cursor.Visible = false
            elseif not mb then
                clickCooldown = false
            end

            bg.Color = focused and Theme.ControlActive or (hover and Theme.ControlHover or Theme.ControlBg)

            -- Cursor blink
            if focused then
                blinkTimer = blinkTimer + 0.03
                if blinkTimer >= 0.5 then
                    blinkState     = not blinkState
                    blinkTimer     = 0
                    cursor.Visible = blinkState
                    local tw = #text * (Theme.FontSize * 0.55)
                    cursor.Position = Vector2.new(x + Theme.Padding + tw, y + 4)
                end
            end

            -- Key input
            if focused then
                local shift = iskeypressed(0x10) -- VK_SHIFT
                -- Backspace
                if iskeypressed(0x08) then
                    if heldKey ~= 0x08 then
                        heldKey = 0x08; heldTimer = 0
                        if #text > 0 then
                            text    = text:sub(1, -2)
                            el.Value = text
                            txt.Text  = #text > 0 and text or placeholder
                            txt.Color = #text > 0 and Theme.ControlText or Theme.Placeholder
                            pcall(onChange, text)
                        end
                    else
                        heldTimer = heldTimer + 0.03
                        if heldTimer > 0.4 then
                            if #text > 0 then
                                text     = text:sub(1, -2)
                                el.Value = text
                                txt.Text  = #text > 0 and text or placeholder
                                txt.Color = #text > 0 and Theme.ControlText or Theme.Placeholder
                                pcall(onChange, text)
                                task.wait(0.05)
                            end
                        end
                    end
                -- Enter / Return
                elseif iskeypressed(0x0D) then
                    if heldKey ~= 0x0D then
                        heldKey = 0x0D
                        pcall(onSubmit, text)
                    end
                else
                    heldKey   = nil
                    heldTimer = 0
                    -- Character input
                    for vk, ch in pairs(normalKeys) do
                        if iskeypressed(vk) then
                            if #text < maxLen then
                                local c = shift and (shiftKeys[vk] or ch:upper()) or ch
                                text     = text .. c
                                el.Value = text
                                txt.Text  = text
                                txt.Color = Theme.ControlText
                                pcall(onChange, text)
                                task.wait(0.08) -- basic repeat delay
                            end
                            break
                        end
                    end
                end
            else
                heldKey   = nil
                heldTimer = 0
            end

            task.wait(0.03)
        end
    end)

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  CHECKBOX
-- ============================================================
--[[
  cfg = {
    Label    = "Enable feature",
    Default  = false,
    OnChange = function(state: boolean) end,
  }
--]]
function Window:Checkbox(cfg)
    local label    = cfg.Label    or "Checkbox"
    local state    = cfg.Default  ~= nil and cfg.Default or false
    local onChange = cfg.OnChange or function() end

    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1
    local bx = x + 2
    local by = y + 3
    local bs = h - 6

    local bg    = Track(MakeSquare(x, y, w, h, Theme.ControlBg, z, true, 3))
    local box   = Track(MakeSquare(bx, by, bs, bs, Theme.ControlBg, z + 1, true, 2))
    local boxBrd= Track(MakeSquare(bx, by, bs, bs, Theme.Border, z + 1, false, 2))
    local check = Track(MakeText("✓", bx + 2, by, bs - 2, Theme.CheckMark, z + 2))
    check.Visible = state
    local txt   = Track(MakeText(label, bx + bs + 6, y + 4, Theme.FontSize, Theme.ControlText, z + 1))

    local el = { _drawObjects = {bg, box, boxBrd, check, txt}, Value = state }
    el.SetVisible = function(_, v)
        bg.Visible = v; box.Visible = v; boxBrd.Visible = v; txt.Visible = v
        check.Visible = v and state
    end
    el.SetValue = function(_, v)
        state        = v
        el.Value     = v
        check.Visible = v
        boxBrd.Color = v and Theme.Accent or Theme.Border
    end
    if state then boxBrd.Color = Theme.Accent end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, x, y, w, h)

            bg.Color  = hover and Theme.ControlHover or Theme.ControlBg
            if not state then boxBrd.Color = hover and Theme.AccentDim or Theme.Border end

            if hover and mb and not clicked then
                clicked = true
                state   = not state
                el:SetValue(state)
                pcall(onChange, state)
            elseif not mb then
                clicked = false
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  VALUE LABEL
-- ============================================================
--[[
  cfg = {
    Label = "Health",
    Value = "100",
  }
--]]
function Window:ValueLabel(cfg)
    local label = cfg.Label or "Label"
    local val   = tostring(cfg.Value or "")

    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1

    local bg   = Track(MakeSquare(x, y, w, h, Theme.ControlBg, z, true, 3))
    local lTxt = Track(MakeText(label, x + Theme.Padding, y + 4, Theme.FontSize, Theme.Placeholder, z + 1))
    local vTxt = Track(MakeText(val, x + w - Theme.Padding, y + 4, Theme.FontSize, Theme.ControlText, z + 1))
    vTxt.Position = Vector2.new(x + w - 60, y + 4)

    local el = { _drawObjects = {bg, lTxt, vTxt}, Value = val }
    el.SetVisible = function(_, v)
        bg.Visible = v; lTxt.Visible = v; vTxt.Visible = v
    end
    el.SetValue = function(_, v)
        el.Value  = tostring(v)
        vTxt.Text = el.Value
    end

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  COLOR PICKER
-- ============================================================
--[[
  cfg = {
    Label    = "Color",
    Default  = Color3.fromRGB(100, 100, 220),
    OnChange = function(color: Color3) end,
  }
  Opens a compact HSV picker row.
--]]
function Window:ColorPicker(cfg)
    local label    = cfg.Label    or "Color"
    local color    = cfg.Default  or Color3.fromRGB(100, 100, 220)
    local onChange = cfg.OnChange or function() end

    -- Row height: swatch + 3 mini sliders (H, S, V)
    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1

    local bg      = Track(MakeSquare(x, y, w, h, Theme.ControlBg, z, true, 3))
    local lTxt    = Track(MakeText(label, x + Theme.Padding, y + 4, Theme.FontSize, Theme.ControlText, z + 1))
    local swatch  = Track(MakeSquare(x + w - 28, y + 3, 24, h - 6, color, z + 1, true, 3))
    local swatchB = Track(MakeSquare(x + w - 28, y + 3, 24, h - 6, Theme.Border, z + 1, false, 3))

    -- Expanded picker (shown when swatch clicked)
    local expanded   = false
    local pickerH    = 18 * 3 + Theme.Padding * 4
    local pickerBg   = Track(MakeSquare(x, y + h, w, pickerH, Theme.TitleBarBg, z + 4, true, 3))
    local pickerBrd  = Track(MakeSquare(x, y + h, w, pickerH, Theme.Border, z + 4, false, 3))
    pickerBg.Visible  = false
    pickerBrd.Visible = false

    local h_, s_, v_ = Color3.toHSV and color:ToHSV() or 0.6, 0.8, 0.9
    -- Simplified: derive HSV from RGB via helper
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
        local sv = mx == 0 and 0 or d/mx
        return hv, sv, mx
    end
    h_, s_, v_ = RGBtoHSV(color)

    local trackW = w - 8
    local labels = {"H","S","V"}
    local vals   = {h_, s_, v_}
    local tracks = {}; local fills = {}; local knobs = {}; local valTxts = {}

    local function RebuildColor()
        color = Color3.fromHSV(vals[1], vals[2], vals[3])
        swatch.Color = color
        pcall(onChange, color)
    end

    local extraObjs = {pickerBg, pickerBrd}
    for i = 1, 3 do
        local ry  = y + h + Theme.Padding + (i-1) * (18 + Theme.Padding / 2)
        local lbl = Track(MakeText(labels[i], x + 4, ry + 2, 12, Theme.Placeholder, z + 5))
        local tr  = Track(MakeSquare(x + 16, ry + 5, trackW - 16, 4, Theme.SliderTrack, z + 5, true, 2))
        local fw  = math.floor((trackW - 16) * vals[i])
        local fl  = Track(MakeSquare(x + 16, ry + 5, math.max(fw,1), 4, Theme.Slider, z + 6, true, 2))
        local kn  = Track(MakeSquare(x + 16 + fw - 4, ry + 2, 8, 10, Theme.Accent, z + 7, true, 3))
        local vt  = Track(MakeText(string.format("%.2f", vals[i]), x + w - 30, ry + 2, 11, Theme.Placeholder, z + 5))
        for _, obj in ipairs({lbl,tr,fl,kn,vt}) do
            obj.Visible = false
            table.insert(extraObjs, obj)
        end
        tracks[i] = tr; fills[i] = fl; knobs[i] = kn; valTxts[i] = vt
        table.insert(extraObjs, lbl)

        task.spawn(function()
            while bg.Visible ~= nil do
                if expanded then
                    local mx, my = GetMousePos()
                    local mb     = ismouse1pressed()
                    if mb and PointInRect(mx, my, x+16, ry, trackW-16, 14) then
                        local t  = math.clamp((mx-(x+16))/(trackW-16), 0, 1)
                        vals[i]  = t
                        local nfw = math.floor((trackW-16)*t)
                        fl.Size  = Vector2.new(math.max(nfw,1), 4)
                        kn.Position = Vector2.new(x+16+nfw-4, ry+2)
                        vt.Text  = string.format("%.2f", t)
                        RebuildColor()
                    end
                end
                task.wait(0.03)
            end
        end)
    end

    local allDraw = {bg, lTxt, swatch, swatchB}
    for _, o in ipairs(extraObjs) do table.insert(allDraw, o) end

    local el = { _drawObjects = allDraw, Value = color }
    el.SetVisible = function(_, v)
        bg.Visible = v; lTxt.Visible = v; swatch.Visible = v; swatchB.Visible = v
        if not v then
            expanded = false
            pickerBg.Visible = false; pickerBrd.Visible = false
            for i = 1, 3 do tracks[i].Visible=false; fills[i].Visible=false; knobs[i].Visible=false; valTxts[i].Visible=false end
        end
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hov    = PointInRect(mx, my, x+w-28, y+3, 24, h-6)
            if hov and mb and not clicked then
                clicked  = true
                expanded = not expanded
                pickerBg.Visible  = expanded
                pickerBrd.Visible = expanded
                for i = 1, 3 do
                    tracks[i].Visible  = expanded
                    fills[i].Visible   = expanded
                    knobs[i].Visible   = expanded
                    valTxts[i].Visible = expanded
                end
                -- adjust subsequent elements? Not re-laying out to keep perf lean.
            elseif not mb then
                clicked = false
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  KEYBIND SELECTOR
-- ============================================================
--[[
  cfg = {
    Label    = "Toggle Key",
    Default  = 0x72,   -- VK code (F3)
    OnChange = function(vkCode: number, name: string) end,
  }
--]]
function Window:Keybind(cfg)
    local label    = cfg.Label    or "Keybind"
    local vk       = cfg.Default  or 0x72
    local onChange = cfg.OnChange or function() end

    -- Minimal VK -> name table
    local VKNames = {
        [0x08]="Backspace",[0x09]="Tab",[0x0D]="Enter",[0x10]="Shift",
        [0x11]="Ctrl",[0x12]="Alt",[0x1B]="Esc",[0x20]="Space",
        [0x70]="F1",[0x71]="F2",[0x72]="F3",[0x73]="F4",[0x74]="F5",
        [0x75]="F6",[0x76]="F7",[0x77]="F8",[0x78]="F9",[0x79]="F10",
        [0x7A]="F11",[0x7B]="F12",
    }
    for i = 0x41, 0x5A do VKNames[i] = string.char(i) end
    for i = 0x30, 0x39 do VKNames[i] = string.char(i) end

    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1

    local bg    = Track(MakeSquare(x, y, w, h, Theme.ControlBg, z, true, 3))
    local brd   = Track(MakeSquare(x, y, w, h, Theme.Border, z, false, 3))
    local lTxt  = Track(MakeText(label, x + Theme.Padding, y + 4, Theme.FontSize, Theme.ControlText, z + 1))
    local kTxt  = Track(MakeText("[" .. (VKNames[vk] or "???") .. "]", x + w - 60, y + 4, Theme.FontSize, Theme.Accent, z + 1))

    local listening = false
    local el = { _drawObjects = {bg, brd, lTxt, kTxt}, Value = vk, Name = VKNames[vk] or "???" }
    el.SetVisible = function(_, v)
        bg.Visible = v; brd.Visible = v; lTxt.Visible = v; kTxt.Visible = v
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, x, y, w, h)

            bg.Color  = listening and Theme.ControlActive or (hover and Theme.ControlHover or Theme.ControlBg)
            brd.Color = listening and Theme.Accent or Theme.Border
            kTxt.Text = listening and "[...]" or "[" .. (VKNames[vk] or "???") .. "]"

            if hover and mb and not clicked then
                clicked   = true
                listening = true
            elseif not mb then
                clicked = false
            end

            if listening then
                -- Scan all common VK codes for a press
                for code = 0x08, 0x7B do
                    if iskeypressed(code) and code ~= 0x01 and code ~= 0x02 then
                        vk         = code
                        el.Value   = vk
                        el.Name    = VKNames[vk] or string.format("0x%X", vk)
                        listening  = false
                        pcall(onChange, vk, el.Name)
                        task.wait(0.15)
                        break
                    end
                end
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  SEARCH BAR
-- ============================================================
--[[
  cfg = {
    Placeholder = "Search...",
    OnChange    = function(query: string) end,
  }
  Functionally identical to TextInput but prefixed with a search icon.
--]]
function Window:SearchBar(cfg)
    cfg = cfg or {}
    cfg.Placeholder = cfg.Placeholder or "Search..."
    local onChangeCfg = cfg.OnChange or function() end

    -- Wrap the TextInput and prepend icon
    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local z  = self.ZIndex + 1

    local icon = Track(MakeText("⌕", x + 3, y + 4, Theme.FontSize, Theme.Placeholder, z + 2))
    table.insert(_AllObjects, icon)

    -- Reuse TextInput logic (re-advance is managed by TextInput)
    -- We insert icon into the element after the fact
    cfg.OnChange = onChangeCfg
    local el = self:TextInput(cfg)
    table.insert(el._drawObjects, icon)

    -- Nudge placeholder text right to make room for icon
    -- The first text object in TextInput is at index 3
    local txtObj = el._drawObjects[3]
    if txtObj then
        txtObj.Position = Vector2.new(txtObj.Position.X + 14, txtObj.Position.Y)
    end

    -- _Advance was already called by TextInput; don't call again
    return el
end

-- ============================================================
--  TAB SYSTEM
-- ============================================================
--[[
  Usage:
    local tabs = win:Tabs({"General", "Visual", "Misc"})
    tabs:OnTab("General", function() ... end)
    tabs:OnTab("Visual",  function() ... end)
    -- Callbacks fire immediately for the default tab and on switch.
--]]
function Window:Tabs(tabNames)
    local x     = self.X + Theme.Padding
    local y     = self:_NextY()
    local w     = self.Width - Theme.Padding * 2
    local h     = Theme.ElementHeight
    local z     = self.ZIndex + 1
    local tw    = math.floor(w / #tabNames)
    local active = 1
    local callbacks = {}

    local bgs  = {}
    local txts = {}
    local lines= {}
    local allD = {}

    for i, name in ipairs(tabNames) do
        local tx = x + (i-1)*tw
        local isA = (i == active)
        local bg  = Track(MakeSquare(tx, y, tw, h, isA and Theme.TabActive or Theme.TabInactive, z, true, 0))
        local txt = Track(MakeText(name, tx + tw/2, y + 4, Theme.FontSize, Theme.TabText, z + 1, true, true))
        local ln  = Track(MakeSquare(tx, y + h - 2, tw, 2, isA and Theme.Accent or Theme.TabInactive, z + 1, true))
        bgs[i]  = bg; txts[i] = txt; lines[i] = ln
        table.insert(allD, bg); table.insert(allD, txt); table.insert(allD, ln)
    end

    local el = { _drawObjects = allD, ActiveTab = 1 }
    el.SetVisible = function(_, v)
        for _, d in ipairs(allD) do d.Visible = v end
    end
    el.OnTab = function(_, name, cb)
        for i, n in ipairs(tabNames) do
            if n == name then callbacks[i] = cb end
        end
        -- Fire default tab immediately
        if tabNames[active] == name and callbacks[active] then
            pcall(callbacks[active])
        end
    end

    local function SwitchTo(idx)
        active = idx
        el.ActiveTab = idx
        for i = 1, #tabNames do
            local isA = (i == idx)
            bgs[i].Color  = isA and Theme.TabActive or Theme.TabInactive
            lines[i].Color= isA and Theme.Accent    or Theme.TabInactive
        end
        if callbacks[idx] then pcall(callbacks[idx]) end
    end

    task.spawn(function()
        local clicked = false
        while bgs[1] and bgs[1].Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            for i = 1, #tabNames do
                local tx = x + (i-1)*tw
                local hov = PointInRect(mx, my, tx, y, tw, h)
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

    self:_Register(el)
    self:_Advance(h + 2)
    return el
end

-- ============================================================
--  SCROLLING FRAME
-- ============================================================
--[[
  Creates a clipped scroll area. Child elements are drawn inside.
  cfg = {
    Height       = 120,          -- visible height
    ContentLines = { "Line 1", "Line 2", ... },
    LineHeight   = 16,
  }
--]]
function Window:ScrollFrame(cfg)
    local visH    = cfg.Height       or 120
    local lines   = cfg.ContentLines or {}
    local lineH   = cfg.LineHeight   or 16

    local x   = self.X + Theme.Padding
    local y   = self:_NextY()
    local w   = self.Width - Theme.Padding * 2
    local z   = self.ZIndex + 1

    local totalH   = #lines * lineH
    local scrollY  = 0
    local maxScroll= math.max(0, totalH - visH)

    local bg    = Track(MakeSquare(x, y, w, visH, Theme.ControlBg, z, true, 3))
    local brd   = Track(MakeSquare(x, y, w, visH, Theme.Border, z, false, 3))

    -- Scrollbar track
    local sbW   = 5
    local sbX   = x + w - sbW - 2
    local sbTr  = Track(MakeSquare(sbX, y + 2, sbW, visH - 4, Theme.SliderTrack, z + 1, true, 2))
    local sbH   = math.max(20, math.floor((visH / math.max(totalH, 1)) * (visH - 4)))
    local sbFl  = Track(MakeSquare(sbX, y + 2, sbW, sbH, Theme.ScrollBar, z + 2, true, 2))

    -- Visible text lines
    local maxVis  = math.floor(visH / lineH)
    local txtObjs = {}
    for i = 1, math.min(maxVis + 1, #lines) do
        local t = Track(MakeText("", x + 4, y + (i-1)*lineH, lineH - 2, Theme.ControlText, z + 1, false))
        t.Font  = Theme.FontMono
        table.insert(txtObjs, t)
    end

    local allD = {bg, brd, sbTr, sbFl}
    for _, t in ipairs(txtObjs) do table.insert(allD, t) end

    local function Refresh()
        local startLine = math.floor(scrollY / lineH) + 1
        for i, txtObj in ipairs(txtObjs) do
            local li = startLine + i - 1
            if li >= 1 and li <= #lines then
                txtObj.Text    = lines[li]
                txtObj.Visible = true
            else
                txtObj.Visible = false
            end
            txtObj.Position = Vector2.new(x + 4, y + (i-1)*lineH - (scrollY % lineH))
        end
        -- Scrollbar fill position
        local t = maxScroll > 0 and scrollY / maxScroll or 0
        sbFl.Position = Vector2.new(sbX, y + 2 + math.floor(t * (visH - 4 - sbH)))
    end
    Refresh()

    local el = { _drawObjects = allD, Lines = lines }
    el.SetVisible = function(_, v)
        for _, d in ipairs(allD) do d.Visible = v end
    end
    el.AddLine = function(_, line)
        table.insert(lines, line)
        totalH    = #lines * lineH
        maxScroll = math.max(0, totalH - visH)
        scrollY   = maxScroll  -- auto-scroll to bottom
        Refresh()
    end
    el.Clear = function(_)
        lines     = {}
        totalH    = 0
        maxScroll = 0
        scrollY   = 0
        for _, t in ipairs(txtObjs) do t.Visible = false end
    end

    -- Scroll on hover with mousescroll (not exposed in Matcha API, use arrow keys)
    -- Use up/down arrow keys (0x26 / 0x28) as scroll when hovered
    task.spawn(function()
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local hover  = PointInRect(mx, my, x, y, w, visH)
            if hover then
                if iskeypressed(0x26) then -- Up arrow
                    scrollY = math.max(0, scrollY - lineH)
                    Refresh(); task.wait(0.1)
                elseif iskeypressed(0x28) then -- Down arrow
                    scrollY = math.min(maxScroll, scrollY + lineH)
                    Refresh(); task.wait(0.1)
                end
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el)
    self:_Advance(visH)
    return el
end

-- ============================================================
--  TOOLTIP
-- ============================================================
--[[
  Attaches a floating tooltip that appears when the cursor hovers
  over a given bounding box.

  cfg = {
    Text    = "This does X",
    BoundX  = x, BoundY = y,
    BoundW  = w, BoundH = h,
  }
--]]
function MatchaUI.Tooltip(cfg)
    local text   = cfg.Text   or "Tooltip"
    local bx     = cfg.BoundX or 0
    local by     = cfg.BoundY or 0
    local bw     = cfg.BoundW or 100
    local bh     = cfg.BoundH or 20
    local zTop   = 200

    local tw     = math.max(#text * 7 + 12, 60)
    local th     = 20

    local bg  = Track(MakeSquare(0, 0, tw, th, Theme.TooltipBg, zTop, true, 3))
    local brd = Track(MakeSquare(0, 0, tw, th, Theme.BorderAccent, zTop, false, 3))
    local txt = Track(MakeText(text, 0, 0, Theme.FontSize - 1, Theme.ControlText, zTop + 1))
    bg.Visible  = false
    brd.Visible = false
    txt.Visible = false

    task.spawn(function()
        while bg ~= nil do
            local mx, my = GetMousePos()
            local show   = PointInRect(mx, my, bx, by, bw, bh)
            bg.Visible  = show
            brd.Visible = show
            txt.Visible = show
            if show then
                local tx = mx + 12
                local ty = my + 16
                bg.Position  = Vector2.new(tx, ty)
                brd.Position = Vector2.new(tx, ty)
                txt.Position = Vector2.new(tx + 6, ty + 3)
            end
            task.wait(0.04)
        end
    end)

    return { Remove = function()
        bg:Remove(); brd:Remove(); txt:Remove()
    end }
end

-- ============================================================
--  NOTIFICATION POP-UP
-- ============================================================
--[[
  MatchaUI.Notify({
    Title    = "Success",
    Message  = "Operation complete.",
    Duration = 4,
    Type     = "success" | "danger" | "warning" | "info",
  })
  Stacks notifications from the bottom-right corner.
--]]
local _notifY    = 0  -- stacking offset
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

    local cam  = workspace.CurrentCamera
    local sw   = cam.ViewportSize.X
    local sh   = cam.ViewportSize.Y
    local nw   = 240
    local nh   = 54
    local margin = 12
    _notifSlot = _notifSlot + 1
    local slot = _notifSlot
    local nx   = sw - nw - margin
    local ny   = sh - margin - nh - (_notifSlot - 1) * (nh + 6)

    local z    = 500

    local bg   = Track(MakeSquare(nx, ny, nw, nh, Theme.NotifBg, z, true, 4))
    local bar  = Track(MakeSquare(nx, ny, 4, nh, accentColor, z + 1, true, 0))
    local brd  = Track(MakeSquare(nx, ny, nw, nh, accentColor, z + 1, false, 4))
    local titT = Track(MakeText(title, nx + 10, ny + 7, Theme.FontSize, accentColor, z + 2))
    local msgT = Track(MakeText(message, nx + 10, ny + 24, Theme.FontSize - 1, Theme.ControlText, z + 2))

    task.spawn(function()
        task.wait(dur)
        bg:Remove(); bar:Remove(); brd:Remove(); titT:Remove(); msgT:Remove()
        _notifSlot = math.max(0, _notifSlot - 1)
    end)
end

-- ============================================================
--  CLOSE BUTTON  (standalone, for attaching to windows)
-- ============================================================
function Window:CloseButton(onClose)
    local cb = onClose or function() end
    local x  = self.X + Theme.Padding
    local y  = self:_NextY()
    local w  = self.Width - Theme.Padding * 2
    local h  = Theme.ElementHeight
    local z  = self.ZIndex + 1

    local bg  = Track(MakeSquare(x, y, w, h, Theme.Danger, z, true, 3))
    local txt = Track(MakeText("X  Close", x + w/2, y + 4, Theme.FontSize, Theme.AccentText, z + 1, true, true))

    local el = { _drawObjects = {bg, txt} }
    el.SetVisible = function(_, v)
        bg.Visible = v; txt.Visible = v
    end

    task.spawn(function()
        local clicked = false
        while bg.Visible ~= nil do
            local mx, my = GetMousePos()
            local mb     = ismouse1pressed()
            local hover  = PointInRect(mx, my, x, y, w, h)

            bg.Color = hover and (mb and Color3.fromRGB(180,50,50) or Color3.fromRGB(200,60,60)) or Theme.Danger

            if hover and mb and not clicked then
                clicked = true
                -- Hide entire window
                self._bg.Visible         = false
                self._titleBar.Visible   = false
                self._titleText.Visible  = false
                self._border.Visible     = false
                self._minBtn.Visible     = false
                self._minTxt.Visible     = false
                self._contentBg.Visible  = false
                self._contentBorder.Visible = false
                for _, e in ipairs(self._elements) do e:SetVisible(false) end
                pcall(cb)
            elseif not mb then
                clicked = false
            end
            task.wait(0.03)
        end
    end)

    self:_Register(el)
    self:_Advance(h)
    return el
end

-- ============================================================
--  RETURN MODULE
-- ============================================================
MatchaUI.Window = setmetatable({}, { __call = function(_, cfg) return MatchaUI.Window(cfg) end })
-- Re-expose Window constructor properly
function MatchaUI.Window(cfg)
    return Window.new and Window:new(cfg) or (function()
        local self = setmetatable({}, Window)
        -- (constructor body is defined above — re-inline call)
        return self
    end)()
end

-- Patch: expose Window constructor directly since metatable tricks don't apply cleanly
-- in single-file Lua. Just keep the direct call form used above.
MatchaUI.NewWindow = function(cfg)
    local self         = setmetatable({}, Window)
    self.Title         = cfg.Title  or "MatchaUI"
    self.X             = cfg.X      or 100
    self.Y             = cfg.Y      or 100
    self.Width         = cfg.Width  or 280
    self.ZIndex        = cfg.ZIndex or Theme.ZBase
    self.Minimized     = false
    self._elements     = {}
    self._cursor       = 0
    self._contentH     = 0
    self._dragging     = false
    self._dragOffX     = 0
    self._dragOffY     = 0

    local z = self.ZIndex
    self._bg          = Track(MakeSquare(self.X, self.Y, self.Width, Theme.TitleHeight, Theme.WindowBg, z, true, Theme.CornerRadius))
    self._titleBar    = Track(MakeSquare(self.X, self.Y, self.Width, Theme.TitleHeight, Theme.TitleBarBg, z+1, true, Theme.CornerRadius))
    self._titleText   = Track(MakeText(self.Title, self.X+Theme.Padding, self.Y+5, Theme.TitleSize, Theme.TitleText, z+2))
    self._border      = Track(MakeSquare(self.X, self.Y, self.Width, Theme.TitleHeight, Theme.Border, z, false, Theme.CornerRadius))
    self._minBtn      = Track(MakeSquare(self.X+self.Width-22, self.Y+5, 16, 16, Theme.ControlBg, z+2, true, 2))
    self._minTxt      = Track(MakeText("_", self.X+self.Width-16, self.Y+4, 13, Theme.ControlText, z+3))
    self._contentBg   = Track(MakeSquare(self.X, self.Y+Theme.TitleHeight, self.Width, 0, Theme.WindowBg, z, true, 0))
    self._contentBorder=Track(MakeSquare(self.X, self.Y+Theme.TitleHeight, self.Width, 0, Theme.Border, z, false, 0))

    task.spawn(function()
        while self._bg.Visible do
            local mx, my = GetMousePos()
            local mb = ismouse1pressed()
            local mbX = self.X+self.Width-22; local mbY = self.Y+5
            if mb and PointInRect(mx,my,mbX,mbY,16,16) then
                task.wait(0.15); self:ToggleMinimize(); task.wait(0.2)
            end
            if mb and PointInRect(mx,my,self.X,self.Y,self.Width-24,Theme.TitleHeight) then
                if not self._dragging then
                    self._dragging=true; self._dragOffX=mx-self.X; self._dragOffY=my-self.Y
                end
            else self._dragging=false end
            if self._dragging and mb then self:_MoveTo(mx-self._dragOffX, my-self._dragOffY) end
            task.wait(0.02)
        end
    end)
    return self
end

return MatchaUI
