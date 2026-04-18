-- @env: Matcha LuaVM
-- MatchaUI v1.0 — Modular Drawing-based UI Library
-- Designed for Matcha external executor overlay rendering
-- No tweens, no heavy animations. Pure Drawing API.

print("Wonder how this works")
local MatchaUI = {}
MatchaUI.__index = MatchaUI

-- ─────────────────────────────────────────────────────────────
-- THEME
-- ─────────────────────────────────────────────────────────────
-- Centralized accent color — change this one value to re-theme all lime-green
-- elements across the entire UI without touching any other variable.
local AccentColor = Color3.fromHex("#39FF14")  -- Lime Green

local Theme = {
    Background      = Color3.fromHex("#0A0A0A"),
    TopBar          = Color3.fromHex("#111111"),
    LeftBar         = Color3.fromHex("#141414"),
    CategoryActive  = AccentColor,
    CategoryHover   = Color3.fromHex("#1F1F1F"),
    CategoryText    = Color3.fromHex("#FFFFFF"),
    ContentBg       = Color3.fromHex("#0A0A0A"),
    ElementBg       = Color3.fromHex("#141414"),
    ElementBorder   = Color3.fromHex("#2A2A2A"),
    AccentOn        = AccentColor,
    AccentOff       = Color3.fromHex("#2A2A2A"),
    TextPrimary     = Color3.fromHex("#FFFFFF"),
    TextSecondary   = Color3.fromHex("#AAAAAA"),
    TextDisabled    = Color3.fromHex("#555555"),
    SliderTrack     = Color3.fromHex("#2A2A2A"),
    SliderFill      = AccentColor,
    SliderKnob      = Color3.fromHex("#FFFFFF"),
    DropdownBg      = Color3.fromHex("#111111"),
    DropdownItem    = Color3.fromHex("#0A0A0A"),
    DropdownHover   = Color3.fromHex("#1F1F1F"),
    InputBg         = Color3.fromHex("#0D0D0D"),
    InputBorder     = AccentColor,
    TooltipBg       = Color3.fromHex("#050505"),
    NotifBg         = Color3.fromHex("#111111"),
    NotifBorder     = AccentColor,

    ScrollBar       = Color3.fromHex("#1A1A1A"),
    ScrollThumb     = AccentColor,
    TitleText       = Color3.fromHex("#FFFFFF"),
    CloseBtn        = Color3.fromHex("#CC2200"),
    MinimizeBtn     = Color3.fromHex("#444444"),
    SectionHeader   = Color3.fromHex("#1A1A1A"),
    SectionText     = AccentColor,
}

-- ─────────────────────────────────────────────────────────────
-- INTERNAL HELPERS
-- ─────────────────────────────────────────────────────────────
local _objects  = {}   -- all Drawing objects for cleanup
local _windows  = {}   -- registered windows
local _notifs   = {}   -- active notifications
local _tooltips = {}   -- active tooltips

local function newDraw(type)
    local obj = Drawing.new(type)
    table.insert(_objects, obj)
    return obj
end

local function makeRect(x, y, w, h, color, zIndex, filled, thickness)
    local r = newDraw("Square")
    r.Position    = Vector2.new(x, y)
    r.Size        = Vector2.new(w, h)
    r.Color       = color or Theme.ElementBg
    r.ZIndex      = zIndex or 10
    r.Filled      = (filled ~= false)
    r.Thickness   = thickness or 1
    r.Transparency = 1
    r.Visible     = true
    return r
end

local function makeText(text, x, y, size, color, zIndex, centered, outline)
    local t = newDraw("Text")
    t.Text         = tostring(text)
    t.Position     = Vector2.new(x, y)
    t.Size         = size or 14
    t.Color        = color or Theme.TextPrimary
    t.ZIndex       = zIndex or 11
    t.Center       = centered or false
    t.Outline      = (outline ~= false)
    t.Font         = Drawing.Fonts.UI
    t.Transparency = 1
    t.Visible      = true
    return t
end

local function inBounds(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function setGroupVisible(group, state)
    for _, obj in ipairs(group) do
        if obj and obj.Remove then
            pcall(function() obj.Visible = state end)
        end
    end
end

-- ─────────────────────────────────────────────────────────────
-- INPUT STATE
-- ─────────────────────────────────────────────────────────────
local Mouse        = game.Players.LocalPlayer:GetMouse()
local _lastMouse1  = false
local _mouseJustDown  = false
local _mouseJustUp    = false

-- Key name lookup table
local KeyNames = {
    [8]="Backspace",[9]="Tab",[13]="Enter",[16]="Shift",[17]="Ctrl",
    [18]="Alt",[20]="CapsLock",[27]="Esc",[32]="Space",[33]="PageUp",
    [34]="PageDown",[35]="End",[36]="Home",[37]="Left",[38]="Up",
    [39]="Right",[40]="Down",[45]="Insert",[46]="Delete",
    [48]="0",[49]="1",[50]="2",[51]="3",[52]="4",[53]="5",
    [54]="6",[55]="7",[56]="8",[57]="9",
    [65]="A",[66]="B",[67]="C",[68]="D",[69]="E",[70]="F",
    [71]="G",[72]="H",[73]="I",[74]="J",[75]="K",[76]="L",
    [77]="M",[78]="N",[79]="O",[80]="P",[81]="Q",[82]="R",
    [83]="S",[84]="T",[85]="U",[86]="V",[87]="W",[88]="X",
    [89]="Y",[90]="Z",
    [112]="F1",[113]="F2",[114]="F3",[115]="F4",[116]="F5",
    [117]="F6",[118]="F7",[119]="F8",[120]="F9",[121]="F10",
    [122]="F11",[123]="F12",
}

-- Mouse VK codes to exclude from keybind detection
local MouseVKCodes = {
    [1]=true,   -- VK_LBUTTON
    [2]=true,   -- VK_RBUTTON
    [4]=true,   -- VK_MBUTTON
    [5]=true,   -- VK_XBUTTON1
    [6]=true,   -- VK_XBUTTON2
}

-- Explicit allowlist of VK codes that are valid keybind targets.
-- Only keyboard keys with readable names are accepted; mouse buttons and
-- unmappable codes (3, 7, 0xA–0x0F, etc.) are silently skipped.
local VALID_KEYBIND_KEYS = {
    -- Special
    [8]=true,  [9]=true,  [13]=true, [16]=true, [17]=true,
    [18]=true, [20]=true, [27]=true, [32]=true,
    [33]=true, [34]=true, [35]=true, [36]=true,
    [37]=true, [38]=true, [39]=true, [40]=true,
    [45]=true, [46]=true,
    -- Digits 0–9
    [48]=true,[49]=true,[50]=true,[51]=true,[52]=true,
    [53]=true,[54]=true,[55]=true,[56]=true,[57]=true,
    -- Letters A–Z
    [65]=true,[66]=true,[67]=true,[68]=true,[69]=true,
    [70]=true,[71]=true,[72]=true,[73]=true,[74]=true,
    [75]=true,[76]=true,[77]=true,[78]=true,[79]=true,
    [80]=true,[81]=true,[82]=true,[83]=true,[84]=true,
    [85]=true,[86]=true,[87]=true,[88]=true,[89]=true,
    [90]=true,
    -- F1–F12
    [112]=true,[113]=true,[114]=true,[115]=true,[116]=true,
    [117]=true,[118]=true,[119]=true,[120]=true,[121]=true,
    [122]=true,[123]=true,
}

-- ─────────────────────────────────────────────────────────────
-- ACCENT COLOR REGISTRY
-- ─────────────────────────────────────────────────────────────
-- Must be declared before CreateWindow so element builder closures
-- can call trackAccent(). SetAccentColor() iterates this table to
-- repaint every accent-colored Drawing object live.
local _accentObjects = {}  -- array of Drawing objects whose .Color = AccentColor

local function trackAccent(obj)
    table.insert(_accentObjects, obj)
end

-- ─────────────────────────────────────────────────────────────
-- WINDOW CONSTRUCTOR
-- ─────────────────────────────────────────────────────────────
-- Returns a Window object. All elements are added to a window.
-- Layout:
--   TopBar  (title, minimize, close)
--   LeftBar (categories)
--   Content (element panels per category)

local TOPBAR_H    = 28
local LEFTBAR_W   = 120
local CONTENT_PAD = 8
local CAT_H       = 28
local ELEM_H      = 32
local ELEM_PAD    = 6

function MatchaUI.CreateWindow(opts)
    opts = opts or {}
    local wx      = opts.X       or 100
    local wy      = opts.Y       or 80
    local ww      = opts.Width   or 500
    local wh      = opts.Height  or 380
    local title   = opts.Title   or "MatchaUI"
    local baseZ   = opts.ZIndex  or 100

    local win = {
        X = wx, Y = wy, W = ww, H = wh,
        BaseZ      = baseZ,
        Visible    = true,
        Minimized  = false,
        Dragging   = false,
        DragOffX   = 0, DragOffY = 0,
        Categories = {},
        ActiveCat  = nil,
        _draws     = {},
        _elements  = {},
    }

    local function draw(d) table.insert(win._draws, d) return d end

    -- ── Shadow / border
    local shadow = draw(makeRect(wx-2, wy-2, ww+4, wh+4, Color3.fromHex("#000000"), baseZ, true))
    shadow.Transparency = 0.6

    -- ── Main background
    local bg = draw(makeRect(wx, wy, ww, wh, Theme.Background, baseZ+1, true))

    -- ── TopBar
    local topBar = draw(makeRect(wx, wy, ww, TOPBAR_H, Theme.TopBar, baseZ+2, true))

    -- Title text
    local titleTxt = draw(makeText(title, wx + 10, wy + 7, 14, Theme.TitleText, baseZ+3, false, true))

    -- Minimize button
    local minBtn  = draw(makeRect(wx + ww - 52, wy + 6, 18, 16, Theme.MinimizeBtn, baseZ+3, true))
    local minTxt  = draw(makeText("-", wx + ww - 52 + 6, wy + 7, 13, Color3.fromHex("#FFFFFF"), baseZ+4, false, false))

    -- Close button
    local closeBtn  = draw(makeRect(wx + ww - 26, wy + 6, 18, 16, Theme.CloseBtn, baseZ+3, true))
    local closeTxt  = draw(makeText("X", wx + ww - 26 + 5, wy + 7, 12, Color3.fromHex("#FFFFFF"), baseZ+4, false, false))

    -- ── LeftBar
    local leftBar = draw(makeRect(wx, wy + TOPBAR_H, LEFTBAR_W, wh - TOPBAR_H, Theme.LeftBar, baseZ+2, true))

    -- ── Content area background
    local contentBg = draw(makeRect(wx + LEFTBAR_W, wy + TOPBAR_H, ww - LEFTBAR_W, wh - TOPBAR_H, Theme.ContentBg, baseZ+2, true))

    -- ─────────────────────────────
    -- Reposition helper (drag)
    -- ─────────────────────────────
    local function reposition(nx, ny)
        local dx, dy = nx - win.X, ny - win.Y
        win.X, win.Y = nx, ny

        shadow.Position    = Vector2.new(nx-2, ny-2)
        bg.Position        = Vector2.new(nx, ny)
        topBar.Position    = Vector2.new(nx, ny)
        titleTxt.Position  = Vector2.new(nx+10, ny+7)
        minBtn.Position    = Vector2.new(nx+ww-52, ny+6)
        minTxt.Position    = Vector2.new(nx+ww-52+6, ny+7)
        closeBtn.Position  = Vector2.new(nx+ww-26, ny+6)
        closeTxt.Position  = Vector2.new(nx+ww-26+5, ny+7)
        leftBar.Position   = Vector2.new(nx, ny+TOPBAR_H)
        contentBg.Position = Vector2.new(nx+LEFTBAR_W, ny+TOPBAR_H)

        -- Shift category labels and content
        for _, cat in ipairs(win.Categories) do
            cat._label.Position = cat._label.Position + Vector2.new(dx, dy)
            cat._bg.Position    = cat._bg.Position    + Vector2.new(dx, dy)
            for _, elem in ipairs(cat._elemObjs) do
                for _, obj in ipairs(elem) do
                    pcall(function() obj.Position = obj.Position + Vector2.new(dx, dy) end)
                end
            end
        end
        -- Update element descriptor position fields used for hit-testing
        for _, elem in ipairs(win._elements) do
            if elem._x then elem._x = elem._x + dx end
            if elem._y then elem._y = elem._y + dy end
            -- Toggle track
            if elem._tx then elem._tx = elem._tx + dx end
            if elem._ty then elem._ty = elem._ty + dy end
            -- Slider track
            if elem._trackX then elem._trackX = elem._trackX + dx end
            if elem._trackY then elem._trackY = elem._trackY + dy end
            -- ValueLabel stable anchor
            if elem._valRightEdge then elem._valRightEdge = elem._valRightEdge + dx end
            -- Dropdown items
            if elem._itemObjs then
                for _, item in ipairs(elem._itemObjs) do
                    if item._x then item._x = item._x + dx end
                    if item._y then item._y = item._y + dy end
                end
            end
            -- ColorPicker swatches
            if elem._swatches then
                for _, sw in ipairs(elem._swatches) do
                    if sw._x then sw._x = sw._x + dx end
                    if sw._y then sw._y = sw._y + dy end
                end
            end
        end
    end

    -- ─────────────────────────────
    -- Visibility helpers
    -- ─────────────────────────────
    local function setWinVisible(state)
        win.Visible = state
        for _, d in ipairs(win._draws) do
            pcall(function() d.Visible = state end)
        end
        -- When becoming visible, show ONLY the active category's elements.
        -- All other categories must stay hidden.
        for _, cat in ipairs(win.Categories) do
            local showCat = state and (win.ActiveCat == cat)
            for _, elem in ipairs(cat._elemObjs) do
                for _, obj in ipairs(elem) do
                    pcall(function() obj.Visible = showCat end)
                end
            end
            -- On show, restore correct per-element sub-object states for active cat
            if showCat then
                for _, elem in ipairs(win._elements) do
                    if elem._cat ~= cat then continue end
                    if elem.Type == "Checkbox" and elem._check then
                        elem._check.Visible = elem.State
                    end
                    if elem.Type == "TextInput" and elem._cursor then
                        elem._cursor.Visible = false
                    end
                    if elem.Type == "Dropdown" then
                        elem._isOpen = false
                        elem._arrow.Text = "v"
                        for _, item in ipairs(elem._itemObjs) do
                            item._bg.Visible  = false
                            item._txt.Visible = false
                        end
                    end
                end
            end
        end
        -- Clear focused input on hide
        if not state and _focusedInput then
            _focusedInput.Focused = false
            if _focusedInput._cursor then _focusedInput._cursor.Visible = false end
            _focusedInput = nil
        end
    end

    local function minimize()
        win.Minimized = not win.Minimized
        local showContent = not win.Minimized
        bg.Size         = showContent and Vector2.new(ww, wh) or Vector2.new(ww, TOPBAR_H)
        shadow.Size     = showContent and Vector2.new(ww+4, wh+4) or Vector2.new(ww+4, TOPBAR_H+4)
        leftBar.Visible     = showContent
        contentBg.Visible   = showContent
        for _, cat in ipairs(win.Categories) do
            cat._label.Visible = showContent
            cat._bg.Visible    = showContent
            if win.ActiveCat == cat then
                for _, elem in ipairs(cat._elemObjs) do
                    for _, obj in ipairs(elem) do
                        pcall(function() obj.Visible = showContent end)
                    end
                end
                -- On un-minimize, restore correct per-element sub-object states
                if showContent then
                    for _, elem in ipairs(win._elements) do
                        if elem._cat ~= cat then continue end
                        if elem.Type == "Checkbox" and elem._check then
                            elem._check.Visible = elem.State
                        end
                        if (elem.Type == "TextInput") and elem._cursor then
                            elem._cursor.Visible = false
                        end
                        if elem.Type == "Dropdown" then
                            elem._isOpen = false
                            elem._arrow.Text = "v"
                            for _, item in ipairs(elem._itemObjs) do
                                item._bg.Visible  = false
                                item._txt.Visible = false
                            end
                        end
                    end
                else
                    -- On minimize, clear focused input if it belongs to this window
                    if _focusedInput and _focusedInput._cat == cat then
                        _focusedInput.Focused = false
                        if _focusedInput._cursor then _focusedInput._cursor.Visible = false end
                        _focusedInput = nil
                    end
                end
            end
        end
        minTxt.Text = win.Minimized and "+" or "-"
    end

    -- ─────────────────────────────
    -- Add Category
    -- ─────────────────────────────
    local function addCategory(name)
        local idx  = #win.Categories
        local cy   = win.Y + TOPBAR_H + idx * CAT_H + 4
        local cx   = win.X + 4

        local catBg = draw(makeRect(cx, cy, LEFTBAR_W - 8, CAT_H - 2, Theme.LeftBar, baseZ+3, true))
        local catLbl = draw(makeText(name, cx + 8, cy + 7, 13, Theme.CategoryText, baseZ+4, false, true))

        local cat = {
            Name      = name,
            _bg       = catBg,
            _label    = catLbl,
            _elemObjs = {},      -- list of draw-object arrays per element
            _elems    = {},      -- element descriptors
            _scrollY  = 0,
        }
        table.insert(win.Categories, cat)

        if not win.ActiveCat then
            win.ActiveCat = cat
            catBg.Color   = Theme.CategoryActive
        end

        return cat
    end

    -- Content cursor tracker (returns current Y for next element)
    local function contentCursorY(cat)
        local baseY = win.Y + TOPBAR_H + CONTENT_PAD + cat._scrollY
        for _, eObjs in ipairs(cat._elemObjs) do
            -- each element stores its height in eObjs._h
            baseY = baseY + (eObjs._h or ELEM_H) + ELEM_PAD
        end
        return baseY
    end

    local function contentX()
        return win.X + LEFTBAR_W + CONTENT_PAD
    end

    local function contentW()
        return ww - LEFTBAR_W - CONTENT_PAD * 2
    end

    -- Activate a category (show its content, hide others)
    local function activateCategory(cat)
        if win.ActiveCat == cat then return end
        -- hide old
        if win.ActiveCat then
            win.ActiveCat._bg.Color = Theme.LeftBar
            for _, elem in ipairs(win.ActiveCat._elemObjs) do
                for _, obj in ipairs(elem) do
                    pcall(function() obj.Visible = false end)
                end
            end
            -- Ensure the focused input loses focus when switching categories
            if _focusedInput and _focusedInput._cat == win.ActiveCat then
                _focusedInput.Focused = false
                if _focusedInput._cursor then _focusedInput._cursor.Visible = false end
                _focusedInput = nil
            end
        end
        win.ActiveCat = cat
        cat._bg.Color = Theme.CategoryActive
        -- Show the new category's base draw objects
        for _, elem in ipairs(cat._elemObjs) do
            for _, obj in ipairs(elem) do
                pcall(function() obj.Visible = true end)
            end
        end
        -- Correct per-element sub-object states AFTER making the base set visible
        for _, elem in ipairs(win._elements) do
            if elem._cat ~= cat then continue end
            -- Checkbox: marker only visible if checked
            if elem.Type == "Checkbox" and elem._check then
                elem._check.Visible = elem.State
            end
            -- TextInput: cursor always starts hidden until re-focused
            if (elem.Type == "TextInput") and elem._cursor then
                elem._cursor.Visible = false
            end
            -- Dropdown: item list always starts closed
            if elem.Type == "Dropdown" then
                elem._isOpen = false
                elem._arrow.Text = "v"
                for _, item in ipairs(elem._itemObjs) do
                    item._bg.Visible  = false
                    item._txt.Visible = false
                end
            end
        end
    end

    -- ─────────────────────────────
    -- ELEMENT BUILDERS
    -- (all return an element table)
    -- ─────────────────────────────

    -- Helper: register element draw-objects with a category
    local function registerElem(cat, objs, h)
        objs._h = h or ELEM_H
        table.insert(cat._elemObjs, objs)
        -- hide if not active
        if win.ActiveCat ~= cat then
            for _, obj in ipairs(objs) do
                pcall(function() obj.Visible = false end)
            end
        end
    end

    -- Helper: register an element descriptor and tag it with its category
    local function registerElemDesc(cat, elem)
        elem._cat = cat
        table.insert(win._elements, elem)
        return elem
    end

    -- ── SECTION HEADER (grouping label)
    local function addSection(cat, labelText)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local objs = {}
        local bg   = draw(makeRect(cx, cy, cw, 20, Theme.SectionHeader, baseZ+5, true))
        local lbl  = draw(makeText(labelText, cx + 6, cy + 4, 12, Theme.SectionText, baseZ+6, false, true))
        trackAccent(lbl)
        table.insert(objs, bg)   -- BUGFIX: bg must be in objs so it is shown/hidden with the category
        table.insert(objs, lbl)  -- and repositioned correctly during window drag
        registerElem(cat, objs, 20)
        return objs
    end

    -- ── BUTTON
    local function addButton(cat, labelText, callback)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local objs  = {}
        local btnBg = draw(makeRect(cx, cy, cw, ELEM_H, Theme.ElementBg, baseZ+5, true))
        local btnLbl = draw(makeText(labelText, cx + cw/2, cy + ELEM_H/2 - 6, 14, Theme.TextPrimary, baseZ+6, true, false))
        table.insert(objs, btnBg)
        table.insert(objs, btnLbl)
        registerElem(cat, objs, ELEM_H)
        local elem = {
            Type = "Button", _bg = btnBg, _draws = objs,
            _x=cx, _y=cy, _w=cw, _h=ELEM_H,
            Callback = callback,
        }
        registerElemDesc(cat, elem)
        return elem
    end

    -- ── TOGGLE
    local function addToggle(cat, labelText, default, callback)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local state = default or false
        local objs = {}
        local bg  = draw(makeRect(cx, cy, cw, ELEM_H, Theme.ElementBg, baseZ+5, true))
        local lbl = draw(makeText(labelText, cx + 8, cy + ELEM_H/2 - 7, 13, Theme.TextPrimary, baseZ+6, false, true))
        -- toggle track
        local trackW, trackH = 36, 16
        local tx = cx + cw - trackW - 8
        local ty = cy + ELEM_H/2 - trackH/2
        local track   = draw(makeRect(tx, ty, trackW, trackH, state and Theme.AccentOn or Theme.AccentOff, baseZ+6, true))
        -- knob
        local knobSz  = 12
        local knob    = draw(makeRect(
            state and (tx + trackW - knobSz - 2) or (tx + 2),
            ty + 2, knobSz, knobSz, Theme.SliderKnob, baseZ+7, true
        ))
        table.insert(objs, bg) table.insert(objs, lbl)
        table.insert(objs, track) table.insert(objs, knob)
        registerElem(cat, objs, ELEM_H)
        local elem = {
            Type="Toggle", _bg=bg, _draws=objs,
            _x=cx, _y=cy, _w=cw, _h=ELEM_H,
            _tx=tx, _ty=ty, _trackW=trackW, _trackH=trackH,
            _knob=knob, _track=track, _knobSz=knobSz,
            State=state, Callback=callback,
        }
        registerElemDesc(cat, elem)
        return elem
    end

    -- ── SLIDER
    local function addSlider(cat, labelText, min, max, default, callback)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local h   = ELEM_H + 10
        local val = default or min
        local objs = {}
        local bg  = draw(makeRect(cx, cy, cw, h, Theme.ElementBg, baseZ+5, true))
        local lbl = draw(makeText(labelText, cx + 8, cy + 6, 12, Theme.TextPrimary, baseZ+6, false, true))
        local valLbl = draw(makeText(tostring(math.floor(val)), cx + cw - 30, cy + 6, 12, Theme.AccentOn, baseZ+6, false, true))
        trackAccent(valLbl)
        -- track
        local trackPad = 8
        local trackW = cw - trackPad*2
        local trackY  = cy + h - 12
        local trackBg = draw(makeRect(cx + trackPad, trackY, trackW, 4, Theme.SliderTrack, baseZ+6, true))
        -- fill
        local fillPct = (val - min) / math.max(max - min, 0.001)
        local fillW   = math.floor(trackW * fillPct)
        local fillRect = draw(makeRect(cx + trackPad, trackY, math.max(fillW,1), 4, Theme.SliderFill, baseZ+7, true))
        trackAccent(fillRect)
        -- knob
        local knobW, knobH = 10, 14
        local knobX = cx + trackPad + fillW - knobW/2
        local knobY = trackY - 5
        local knob  = draw(makeRect(knobX, knobY, knobW, knobH, Theme.SliderKnob, baseZ+8, true))
        table.insert(objs, bg) table.insert(objs, lbl) table.insert(objs, valLbl)
        table.insert(objs, trackBg) table.insert(objs, fillRect) table.insert(objs, knob)
        registerElem(cat, objs, h)
        local elem = {
            Type="Slider", _bg=bg, _draws=objs,
            _x=cx, _y=cy, _w=cw, _h=h,
            _trackX = cx + trackPad, _trackY = trackY,
            _trackW = trackW,
            _fillRect = fillRect, _knob = knob, _valLbl = valLbl,
            _knobW = knobW, _knobH = knobH,
            Min=min, Max=max, Value=val,
            Dragging=false, Callback=callback,
        }
        registerElemDesc(cat, elem)
        return elem
    end

    -- ── DROPDOWN
    local function addDropdown(cat, labelText, options, default, callback)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local selected = default or (options and options[1]) or ""
        local isOpen   = false
        local objs     = {}
        local bg  = draw(makeRect(cx, cy, cw, ELEM_H, Theme.ElementBg, baseZ+5, true))
        local lbl = draw(makeText(labelText, cx + 8, cy + ELEM_H/2 - 7, 12, Theme.TextSecondary, baseZ+6, false, true))
        local boxBg  = draw(makeRect(cx + cw - 130, cy + 4, 122, 22, Theme.InputBg, baseZ+6, true))
        local selTxt = draw(makeText(selected, cx + cw - 126, cy + 9, 12, Theme.TextPrimary, baseZ+7, false, true))
        local arrow  = draw(makeText("v", cx + cw - 14, cy + 9, 11, Theme.AccentOn, baseZ+7, false, false))
        trackAccent(arrow)
        table.insert(objs, bg) table.insert(objs, lbl) table.insert(objs, boxBg)
        table.insert(objs, selTxt) table.insert(objs, arrow)

        -- Dropdown items (hidden by default, high Z)
        local itemObjs = {}
        local dropBaseZ = baseZ + 50  -- always on top
        for i, opt in ipairs(options or {}) do
            local iy = cy + ELEM_H + (i-1)*22
            local iBg  = draw(makeRect(cx + cw - 130, iy, 122, 22, Theme.DropdownItem, dropBaseZ, true))
            local iTxt = draw(makeText(opt, cx + cw - 126, iy + 4, 12, Theme.TextPrimary, dropBaseZ+1, false, true))
            iBg.Visible  = false
            iTxt.Visible = false
            table.insert(itemObjs, {_bg=iBg, _txt=iTxt, _value=opt, _x=cx+cw-130, _y=iy})
            table.insert(objs, iBg)
            table.insert(objs, iTxt)
        end
        registerElem(cat, objs, ELEM_H)
        local elem = {
            Type="Dropdown", _bg=bg, _draws=objs,
            _x=cx+cw-130, _y=cy, _w=122, _h=ELEM_H,
            _selTxt=selTxt, _itemObjs=itemObjs, _arrow=arrow,
            _isOpen=isOpen, Selected=selected,
            Callback=callback, Options=options or {},
        }
        registerElemDesc(cat, elem)
        return elem
    end

    -- ── TEXT INPUT
    local function addTextInput(cat, labelText, placeholder, callback)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local text = ""
        local focused = false
        local objs = {}
        local bg  = draw(makeRect(cx, cy, cw, ELEM_H, Theme.ElementBg, baseZ+5, true))
        local lbl = draw(makeText(labelText, cx + 8, cy + ELEM_H/2 - 7, 12, Theme.TextSecondary, baseZ+6, false, true))
        local inputBg = draw(makeRect(cx + cw - 160, cy + 4, 152, 22, Theme.InputBg, baseZ+6, true))
        local inputTxt = draw(makeText(placeholder or "", cx + cw - 156, cy + 9, 12, Theme.TextDisabled, baseZ+7, false, true))
        local cursor   = draw(makeRect(cx + cw - 156, cy + 7, 1, 14, Theme.AccentOn, baseZ+8, true))
        trackAccent(cursor)
        cursor.Visible = false
        table.insert(objs, bg) table.insert(objs, lbl) table.insert(objs, inputBg)
        table.insert(objs, inputTxt) table.insert(objs, cursor)
        registerElem(cat, objs, ELEM_H)
        local elem = {
            Type="TextInput", _bg=bg, _draws=objs,
            _x=cx+cw-160, _y=cy, _w=160, _h=ELEM_H,
            _inputTxt=inputTxt, _cursor=cursor, _inputBg=inputBg,
            _placeholder=placeholder or "",
            Text=text, Focused=focused, Callback=callback,
        }
        registerElemDesc(cat, elem)
        return elem
    end

    -- ── CHECKBOX
    local function addCheckbox(cat, labelText, default, callback)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local state = default or false
        local objs = {}
        local bg  = draw(makeRect(cx, cy, cw, ELEM_H, Theme.ElementBg, baseZ+5, true))
        local lbl = draw(makeText(labelText, cx + 30, cy + ELEM_H/2 - 7, 13, Theme.TextPrimary, baseZ+6, false, true))
        local boxSz = 16
        local bx = cx + 8
        local by = cy + ELEM_H/2 - boxSz/2
        local box  = draw(makeRect(bx, by, boxSz, boxSz, Theme.InputBg, baseZ+6, true))
        -- border
        local boxBorder = draw(makeRect(bx, by, boxSz, boxSz, Theme.ElementBorder, baseZ+6, false))
        boxBorder.Thickness = 1
        boxBorder.Filled = false
        -- check mark (filled accent square inside)
        local check = draw(makeRect(bx+3, by+3, boxSz-6, boxSz-6, Theme.AccentOn, baseZ+7, true))
        trackAccent(check)
        check.Visible = state
        table.insert(objs, bg) table.insert(objs, lbl) table.insert(objs, box)
        table.insert(objs, boxBorder) table.insert(objs, check)
        registerElem(cat, objs, ELEM_H)
        local elem = {
            Type="Checkbox", _bg=bg, _draws=objs,
            _x=cx, _y=cy, _w=cw, _h=ELEM_H,
            _check=check, _box=box,
            State=state, Callback=callback,
        }
        registerElemDesc(cat, elem)
        return elem
    end

    -- ── KEYBIND
    local function addKeybind(cat, labelText, defaultKey, callback)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local key = defaultKey or 0x2D
        local listening = false
        local objs = {}
        local bg  = draw(makeRect(cx, cy, cw, ELEM_H, Theme.ElementBg, baseZ+5, true))
        local lbl = draw(makeText(labelText, cx + 8, cy + ELEM_H/2 - 7, 12, Theme.TextSecondary, baseZ+6, false, true))
        local kbBg  = draw(makeRect(cx + cw - 100, cy + 4, 92, 22, Theme.InputBg, baseZ+6, true))
        local kbTxt = draw(makeText("[ " .. (KeyNames[key] or "?") .. " ]", cx + cw - 98, cy + 9, 12, Theme.TextPrimary, baseZ+7, false, true))
        table.insert(objs, bg) table.insert(objs, lbl) table.insert(objs, kbBg) table.insert(objs, kbTxt)
        registerElem(cat, objs, ELEM_H)
        local elem = {
            Type="Keybind", _bg=bg, _draws=objs,
            _x=cx+cw-100, _y=cy, _w=92, _h=ELEM_H,
            _kbTxt=kbTxt, Key=key, Listening=false,
            Callback=callback,
        }
        registerElemDesc(cat, elem)
        return elem
    end

    -- ── COLOR PICKER  (simplified: preset swatches + hex display)
    local function addColorPicker(cat, labelText, defaultColor, callback)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local h   = ELEM_H + 26
        local color = defaultColor or Color3.fromRGB(255, 100, 100)
        local objs = {}
        local bg   = draw(makeRect(cx, cy, cw, h, Theme.ElementBg, baseZ+5, true))
        local lbl  = draw(makeText(labelText, cx + 8, cy + 6, 12, Theme.TextSecondary, baseZ+6, false, true))
        -- Preview swatch
        local preview = draw(makeRect(cx + cw - 30, cy + 4, 22, 22, color, baseZ+7, true))
        -- Preset swatches
        local presets = {
            Color3.fromRGB(229,69,96),   -- red-ish accent
            Color3.fromRGB(240,165,0),   -- amber
            Color3.fromRGB(0,200,100),   -- green
            Color3.fromRGB(60,130,220),  -- blue
            Color3.fromRGB(180,60,220),  -- purple
            Color3.fromRGB(255,255,255), -- white
            Color3.fromRGB(120,120,120), -- grey
            Color3.fromRGB(0,0,0),       -- black
        }
        local swatchObjs = {}
        local swSz = 14
        for i, pc in ipairs(presets) do
            local sx = cx + 8 + (i-1) * (swSz + 4)
            local sy = cy + h - swSz - 6
            local sw = draw(makeRect(sx, sy, swSz, swSz, pc, baseZ+7, true))
            table.insert(swatchObjs, {_rect=sw, _color=pc, _x=sx, _y=sy, _sz=swSz})
            table.insert(objs, sw)
        end
        table.insert(objs, bg) table.insert(objs, lbl) table.insert(objs, preview)
        registerElem(cat, objs, h)
        local elem = {
            Type="ColorPicker", _bg=bg, _draws=objs,
            _x=cx, _y=cy, _w=cw, _h=h,
            _preview=preview, _swatches=swatchObjs,
            Color=color, Callback=callback,
        }
        registerElemDesc(cat, elem)
        return elem
    end

    -- ── VALUE LABEL
    local function addValueLabel(cat, labelText, defaultValue)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local objs = {}
        local bg   = draw(makeRect(cx, cy, cw, ELEM_H, Theme.ElementBg, baseZ+5, true))
        local lbl  = draw(makeText(labelText, cx + 8, cy + ELEM_H/2 - 7, 12, Theme.TextSecondary, baseZ+6, false, true))
        -- Reserve 100px on right for the value. A cover rect with same bg color hides overflow.
        local valW   = 100
        local valX   = cx + cw - valW - 6  -- left edge of value area
        -- Bug fix #3: stable right edge anchor computed once from layout constants.
        -- SetValue always positions text relative to this fixed point so it never drifts.
        local valRightEdge = cx + cw - 8
        local valCover = draw(makeRect(cx + cw - valW - 6, cy + 1, valW + 2, ELEM_H - 2, Theme.ElementBg, baseZ+6, true))
        local initStr = tostring(defaultValue or "")
        local initX   = valRightEdge - math.min(#initStr * 7, valW)
        local valTxt  = draw(makeText(initStr, initX, cy + ELEM_H/2 - 7, 13, Theme.AccentOn, baseZ+7, false, true))
        trackAccent(valTxt)
        table.insert(objs, bg) table.insert(objs, lbl) table.insert(objs, valCover) table.insert(objs, valTxt)
        registerElem(cat, objs, ELEM_H)
        local elem = {
            Type="ValueLabel", _bg=bg, _draws=objs,
            _x=cx, _y=cy, _w=cw, _h=ELEM_H,
            _valTxt=valTxt, _valCover=valCover, _valW=valW,
            _valRightEdge=valRightEdge,  -- stable anchor, never changes
            _labelTxt=lbl,
            Value=defaultValue or "",
            SetValue=function(self, v)
                self.Value = v
                local s = tostring(v)
                self._valTxt.Text = s
                -- Always anchor from the fixed right edge, not the current
                -- text X (which was the source of the rightward drift bug).
                local estimatedW = math.min(#s * 7, self._valW)
                self._valTxt.Position = Vector2.new(
                    self._valRightEdge - estimatedW,
                    self._valTxt.Position.Y
                )
            end,
        }
        registerElemDesc(cat, elem)
        return elem
    end

    -- ── SCROLLING FRAME
    -- visH  : visible height of the frame (px). innerH auto-grows as items are added.
    -- Scrolling is controlled exclusively by dragging the scrollbar thumb.
    -- Use elem:AddItem(text) after creation to populate rows.
    -- Each frame in the main loop re-positions item text objects to reflect _scrollY,
    -- and hides rows that fall outside the visible area (manual clip).
    local function addScrollFrame(cat, innerH, callback)
        local cx   = contentX()
        local cw   = contentW()
        local cy   = contentCursorY(cat)
        local visH = math.min(innerH, 80)
        local objs = {}
        local bg   = draw(makeRect(cx, cy, cw, visH, Theme.InputBg, baseZ+5, true))
        -- clip border
        local border = draw(makeRect(cx, cy, cw, visH, Theme.ElementBorder, baseZ+5, false))
        border.Filled = false
        border.Thickness = 1
        -- scrollbar track
        local sbX     = cx + cw - 8
        local sbTrack = draw(makeRect(sbX, cy, 6, visH, Theme.ScrollBar, baseZ+6, true))
        -- thumb (height proportional to content)
        local thumbH = math.max(20, math.floor(visH * visH / math.max(innerH, 1)))
        local thumb  = draw(makeRect(sbX, cy, 6, thumbH, Theme.ScrollThumb, baseZ+7, true))
        trackAccent(thumb)
        table.insert(objs, bg) table.insert(objs, border)
        table.insert(objs, sbTrack) table.insert(objs, thumb)
        registerElem(cat, objs, visH)

        local elem = {
            Type="ScrollFrame", _bg=bg, _draws=objs,
            _x=cx, _y=cy, _w=cw, _h=visH,
            _sbX=sbX,
            _thumb=thumb, _thumbH=thumbH,
            _innerH=innerH, _scrollY=0,
            _thumbDragging=false, _thumbDragOffY=0,
            _items={},   -- { _txt=DrawObj, _relY=number }
            _itemH=18,
            Callback=callback,
        }

        -- AddItem: add a labelled text row into the scroll frame.
        -- The main loop re-clips and repositions item labels each frame.
        function elem:AddItem(text)
            local rowIdx = #self._items
            local relY   = rowIdx * self._itemH + 4
            local absY   = self._y + relY  -- initial position (no scroll yet)
            local txt    = draw(makeText(
                text, self._x + 6, absY, 12, Theme.TextPrimary, baseZ+8, false, false
            ))
            txt.Visible = (absY >= self._y) and (absY + self._itemH <= self._y + self._h)
            table.insert(self._items, {_txt=txt, _relY=relY})
            table.insert(objs, txt)
            -- Grow innerH to fit all items
            local neededH = (#self._items) * self._itemH + 8
            if neededH > self._innerH then
                self._innerH = neededH
                local newThH = math.max(20, math.floor(self._h * self._h / self._innerH))
                self._thumbH = newThH
                self._thumb.Size = Vector2.new(6, newThH)
            end
            -- Hide immediately if category not yet active
            if win.ActiveCat ~= cat then txt.Visible = false end
            return txt
        end

        registerElemDesc(cat, elem)
        return elem
    end

    -- ── TOOLTIP (attached to element, shown on hover)
    local function addTooltip(elem, tipText)
        local ttBg  = newDraw("Square")
        ttBg.Size   = Vector2.new(#tipText * 7 + 12, 20)
        ttBg.Color  = Theme.TooltipBg
        ttBg.ZIndex = baseZ + 90
        ttBg.Filled = true
        ttBg.Transparency = 1
        ttBg.Visible = false
        local ttTxt = newDraw("Text")
        ttTxt.Text  = tipText
        ttTxt.Size  = 12
        ttTxt.Color = Theme.TextPrimary
        ttTxt.ZIndex = baseZ + 91
        ttTxt.Center = false
        ttTxt.Outline = true
        ttTxt.Font  = Drawing.Fonts.UI
        ttTxt.Transparency = 1
        ttTxt.Visible = false
        local tip = {_bg=ttBg, _txt=ttTxt, _elem=elem, Text=tipText}
        table.insert(_tooltips, tip)
        return tip
    end

    -- ─────────────────────────────
    -- Expose public API on window
    -- ─────────────────────────────
    win.AddCategory    = addCategory
    win.AddSection     = addSection
    win.AddButton      = addButton
    win.AddToggle      = addToggle
    win.AddSlider      = addSlider
    win.AddDropdown    = addDropdown
    win.AddTextInput   = addTextInput
    win.AddCheckbox    = addCheckbox
    win.AddKeybind     = addKeybind
    win.AddColorPicker = addColorPicker
    win.AddValueLabel  = addValueLabel
    win.AddScrollFrame = addScrollFrame
    win.AddTooltip     = addTooltip
    win.Reposition     = reposition
    win.SetVisible     = setWinVisible
    win.Minimize       = minimize
    win._minBtn  = minBtn
    win._minBtnX = wx + ww - 52
    win._minBtnY = wy + 6
    win._minBtnW = 18
    win._minBtnH = 16
    win._closeBtn  = closeBtn
    win._closeBtnX = wx + ww - 26
    win._closeBtnY = wy + 6
    win._closeBtnW = 18
    win._closeBtnH = 16
    win._topBarH   = TOPBAR_H
    win._activateCategory = activateCategory

    table.insert(_windows, win)
    return win
end

-- ─────────────────────────────────────────────────────────────
-- NOTIFICATION SYSTEM
-- ─────────────────────────────────────────────────────────────
local NOTIF_W     = 240
local NOTIF_H     = 50
local NOTIF_PAD   = 6
local NOTIF_DUR   = 4   -- seconds

-- Notifications spawn at top-left (50, 50) and stack downward.
local NOTIF_START_X = 50
local NOTIF_START_Y = 50

local function _layoutNotifs()
    local by = NOTIF_START_Y
    for i = 1, #_notifs do
        local n = _notifs[i]
        n._bg.Position    = Vector2.new(NOTIF_START_X, by)
        n._title.Position = Vector2.new(NOTIF_START_X + 8, by + 6)
        n._msg.Position   = Vector2.new(NOTIF_START_X + 8, by + 22)
        n._bar.Position   = Vector2.new(NOTIF_START_X, by + NOTIF_H - 4)
        by = by + NOTIF_H + NOTIF_PAD
    end
end

function MatchaUI.Notify(title, message, duration)
    local nx  = NOTIF_START_X
    local ny  = NOTIF_START_Y + #_notifs * (NOTIF_H + NOTIF_PAD)
    local dur = duration or NOTIF_DUR

    local bg   = newDraw("Square")
    bg.Position    = Vector2.new(nx, ny)
    bg.Size        = Vector2.new(NOTIF_W, NOTIF_H)
    bg.Color       = Theme.NotifBg
    bg.Filled      = true
    bg.ZIndex      = 300
    bg.Transparency = 1
    bg.Visible     = true

    -- NOTE: vertical accent bar removed; only the horizontal progress bar remains.

    local tTitle = newDraw("Text")
    tTitle.Text        = title or "Notice"
    tTitle.Position    = Vector2.new(nx+8, ny+6)
    tTitle.Size        = 13
    tTitle.Color       = Theme.AccentOn
    tTitle.ZIndex      = 302
    tTitle.Outline     = true
    tTitle.Font        = Drawing.Fonts.UI
    tTitle.Transparency = 1
    tTitle.Visible     = true

    local tMsg = newDraw("Text")
    tMsg.Text          = message or ""
    tMsg.Position      = Vector2.new(nx+8, ny+22)
    tMsg.Size          = 12
    tMsg.Color         = Theme.TextPrimary
    tMsg.ZIndex        = 302
    tMsg.Outline       = true
    tMsg.Font          = Drawing.Fonts.UI
    tMsg.Transparency  = 1
    tMsg.Visible       = true

    -- Horizontal progress bar (time remaining indicator)
    local bar = newDraw("Square")
    bar.Position   = Vector2.new(nx, ny + NOTIF_H - 4)
    bar.Size       = Vector2.new(NOTIF_W, 4)
    bar.Color      = Theme.AccentOn
    bar.Filled     = true
    bar.ZIndex     = 303
    bar.Transparency = 1
    bar.Visible    = true

    local notif = {
        _bg=bg, _title=tTitle, _msg=tMsg, _bar=bar,
        _timer=0, _duration=dur, _done=false,
    }
    table.insert(_notifs, notif)
    _layoutNotifs()
    return notif
end

-- Call this from a ColorPicker callback (or any time) to re-theme the
-- entire UI to a new accent color instantly.
-- @param color  Color3  — the new accent color
function MatchaUI.SetAccentColor(color)
    AccentColor           = color
    Theme.CategoryActive  = color
    Theme.AccentOn        = color
    Theme.SliderFill      = color
    Theme.InputBorder     = color
    Theme.NotifBorder     = color
    Theme.ScrollThumb     = color
    Theme.SectionText     = color
    -- Repaint all registered accent-colored objects
    for _, obj in ipairs(_accentObjects) do
        pcall(function() obj.Color = color end)
    end
    -- Repaint toggle tracks that are currently ON
    for _, win in ipairs(_windows) do
        for _, elem in ipairs(win._elements) do
            if elem.Type == "Toggle" and elem.State and elem._track then
                pcall(function() elem._track.Color = color end)
            end
        end
        -- Active category bg
        if win.ActiveCat and win.ActiveCat._bg then
            pcall(function() win.ActiveCat._bg.Color = color end)
        end
    end
    -- Repaint notification accent bars currently on screen
    for _, n in ipairs(_notifs) do
        pcall(function() n._bar.Color    = color end)
        pcall(function() n._title.Color  = color end)
    end
end



local VALID_CHARS = {}
do
    local s = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?-_@#%&*()[]<>:;'/\\"
    for i = 1, #s do
        VALID_CHARS[s:sub(i,i)] = true
    end
end

-- ─────────────────────────────────────────────────────────────
-- MAIN LOOP
-- ─────────────────────────────────────────────────────────────
local _sliderDrag = nil  -- currently dragged slider elem
local _cursorBlink = 0
local _prevHeldKeys   = {}  -- VK keys held last frame (for edge detection in text input)
local _keyRepeatTimer = {}  -- per-key hold timer (seconds)
local _keyRepeatFired = {}  -- whether the key generated at least one character

function MatchaUI.Run()
    while true do
        wait(0.016)
        if not isrbxactive() then
            _lastMouse1 = false
            _mouseJustDown = false
            _mouseJustUp   = false
        else
            local mouse1   = ismouse1pressed()
            local mPos     = Vector2.new(Mouse.X, Mouse.Y)
            _mouseJustDown = mouse1 and not _lastMouse1
            _mouseJustUp   = not mouse1 and _lastMouse1

            -- ── Cursor blink for focused inputs
            _cursorBlink = _cursorBlink + 0.016
            if _focusedInput and _focusedInput._cursor then
                _focusedInput._cursor.Visible = (_cursorBlink % 1) < 0.5
            end

            -- ── Notifications: tick down and shrink bar
            local i = 1
            while i <= #_notifs do
                local n = _notifs[i]
                n._timer = n._timer + 0.016
                local pct = 1 - (n._timer / n._duration)
                n._bar.Size = Vector2.new(math.max(0, NOTIF_W * pct), 4)
                if n._timer >= n._duration then
                    n._bg:Remove()
                    n._title:Remove() n._msg:Remove() n._bar:Remove()
                    table.remove(_notifs, i)
                    _layoutNotifs()
                else
                    i = i + 1
                end
            end

            -- ── Tooltip handling
            for _, tip in ipairs(_tooltips) do
                local e = tip._elem
                if e and e._x then
                    -- Bug fix #1: only show tooltip when the element's category is
                    -- the active one in its window AND the window itself is visible.
                    local catActive = false
                    if e._cat then
                        for _, w in ipairs(_windows) do
                            if w.Visible and not w.Minimized and w.ActiveCat == e._cat then
                                catActive = true
                                break
                            end
                        end
                    else
                        catActive = true  -- tooltips not attached to a category (e.g. standalone)
                    end
                    local hover = catActive and inBounds(mPos.X, mPos.Y, e._x, e._y, e._w, e._h)
                    tip._bg.Visible  = hover
                    tip._txt.Visible = hover
                    if hover then
                        tip._bg.Position  = Vector2.new(mPos.X + 12, mPos.Y - 24)
                        tip._txt.Position = Vector2.new(mPos.X + 18, mPos.Y - 20)
                    end
                end
            end

            -- ── Per-window processing
            for _, win in ipairs(_windows) do
                if not win.Visible then continue end

                -- Drag window (topbar)
                if _mouseJustDown and inBounds(mPos.X, mPos.Y,
                    win.X, win.Y, win.W, win._topBarH) then
                    -- Check it's not a button
                    local onMin = inBounds(mPos.X, mPos.Y,
                        win._minBtnX, win._minBtnY, win._minBtnW, win._minBtnH)
                    local onClose = inBounds(mPos.X, mPos.Y,
                        win._closeBtnX, win._closeBtnY, win._closeBtnW, win._closeBtnH)
                    if not onMin and not onClose then
                        win.Dragging = true
                        win.DragOffX = mPos.X - win.X
                        win.DragOffY = mPos.Y - win.Y
                    end
                end
                if _mouseJustUp then
                    win.Dragging = false
                end
                if win.Dragging and mouse1 then
                    local nx = mPos.X - win.DragOffX
                    local ny = mPos.Y - win.DragOffY
                    win.Reposition(nx, ny)
                    -- Update stored button positions
                    win._minBtnX   = nx + win.W - 52
                    win._minBtnY   = ny + 6
                    win._closeBtnX = nx + win.W - 26
                    win._closeBtnY = ny + 6
                end

                -- Minimize / Close
                if _mouseJustDown then
                    if inBounds(mPos.X, mPos.Y,
                        win._minBtnX, win._minBtnY, win._minBtnW, win._minBtnH) then
                        win.Minimize()
                    end
                    if inBounds(mPos.X, mPos.Y,
                        win._closeBtnX, win._closeBtnY, win._closeBtnW, win._closeBtnH) then
                        win.SetVisible(false)
                    end
                end

                if win.Minimized then continue end

                -- Category selection
                if _mouseJustDown then
                    for _, cat in ipairs(win.Categories) do
                        if inBounds(mPos.X, mPos.Y,
                            cat._bg.Position.X, cat._bg.Position.Y,
                            cat._bg.Size.X, cat._bg.Size.Y) then
                            win._activateCategory(cat)
                        end
                    end
                end

                -- Element interactions
                for _, elem in ipairs(win._elements) do
                    -- Only process elements belonging to the active category
                    if elem._cat ~= win.ActiveCat then continue end
                    -- Only process if element visible
                    if not elem._bg or not elem._bg.Visible then continue end

                    -- BUTTON
                    if elem.Type == "Button" and _mouseJustDown then
                        if inBounds(mPos.X, mPos.Y, elem._x, elem._y, elem._w, elem._h) then
                            if elem.Callback then pcall(elem.Callback) end
                        end
                    end

                    -- TOGGLE
                    if elem.Type == "Toggle" and _mouseJustDown then
                        if inBounds(mPos.X, mPos.Y, elem._tx, elem._ty, elem._trackW, elem._trackH) then
                            elem.State = not elem.State
                            elem._track.Color = elem.State and Theme.AccentOn or Theme.AccentOff
                            local kx = elem.State
                                and (elem._tx + elem._trackW - elem._knobSz - 2)
                                or  (elem._tx + 2)
                            elem._knob.Position = Vector2.new(kx, elem._ty + 2)
                            if elem.Callback then pcall(elem.Callback, elem.State) end
                        end
                    end

                    -- CHECKBOX
                    if elem.Type == "Checkbox" and _mouseJustDown then
                        if inBounds(mPos.X, mPos.Y, elem._x, elem._y, elem._w, elem._h) then
                            elem.State = not elem.State
                            elem._check.Visible = elem.State
                            if elem.Callback then pcall(elem.Callback, elem.State) end
                        end
                    end

                    -- SLIDER drag start
                    if elem.Type == "Slider" and _mouseJustDown and _sliderDrag == nil then
                        -- click on track or knob
                        if inBounds(mPos.X, mPos.Y, elem._trackX, elem._trackY - 6, elem._trackW, 16) then
                            _sliderDrag = elem
                        end
                    end

                    -- DROPDOWN
                    if elem.Type == "Dropdown" and _mouseJustDown then
                        if inBounds(mPos.X, mPos.Y, elem._x, elem._y, elem._w, elem._h) then
                            -- toggle open
                            elem._isOpen = not elem._isOpen
                            for _, item in ipairs(elem._itemObjs) do
                                item._bg.Visible  = elem._isOpen
                                item._txt.Visible = elem._isOpen
                            end
                            elem._arrow.Text = elem._isOpen and "^" or "v"
                        elseif elem._isOpen then
                            -- check items
                            local hit = false
                            for _, item in ipairs(elem._itemObjs) do
                                if inBounds(mPos.X, mPos.Y, item._x, item._y, elem._w, 22) then
                                    elem.Selected      = item._value
                                    elem._selTxt.Text  = item._value
                                    hit = true
                                    if elem.Callback then pcall(elem.Callback, item._value) end
                                end
                            end
                            -- close
                            elem._isOpen = false
                            elem._arrow.Text = "v"
                            for _, item in ipairs(elem._itemObjs) do
                                item._bg.Visible  = false
                                item._txt.Visible = false
                            end
                        end
                    end

                    -- KEYBIND
                    if elem.Type == "Keybind" then
                        -- Arm on mouse down; only start scanning after mouse is released
                        if _mouseJustDown and inBounds(mPos.X, mPos.Y, elem._x, elem._y, elem._w, elem._h) then
                            elem._pendingListen = true
                            elem.Listening = false
                            elem._kbTxt.Text  = "..."
                            elem._kbTxt.Color = Theme.AccentOn
                        end
                        if elem._pendingListen and _mouseJustUp then
                            elem._pendingListen = false
                            elem.Listening = true
                        end
                        if elem.Listening then
                            -- Bug fix #2: iterate only over explicitly allowed keyboard VK codes.
                            -- This prevents mouse button releases (VK 1/2/4/5/6) and any other
                            -- unmappable codes from ever being registered as a keybind.
                            for k, _ in pairs(VALID_KEYBIND_KEYS) do
                                if iskeypressed(k) then
                                    elem.Key       = k
                                    elem.Listening  = false
                                    local name = KeyNames[k] or "?"
                                    elem._kbTxt.Text  = "[ " .. name .. " ]"
                                    elem._kbTxt.Color = Theme.TextPrimary
                                    if elem.Callback then pcall(elem.Callback, k, name) end
                                    break
                                end
                            end
                        end
                    end

                    -- TEXT INPUT / SEARCH BAR: focus on click
                    if (elem.Type == "TextInput") and _mouseJustDown then
                        if inBounds(mPos.X, mPos.Y, elem._x, elem._y, elem._w, elem._h) then
                            _focusedInput = elem
                            elem.Focused   = true
                            _cursorBlink   = 0
                            if elem._inputBg then elem._inputBg.Color = Theme.InputBg end
                        else
                            if elem == _focusedInput then
                                _focusedInput = nil
                                elem.Focused  = false
                                if elem._cursor then elem._cursor.Visible = false end
                            end
                        end
                    end

                    -- COLOR PICKER swatch clicks
                    if elem.Type == "ColorPicker" and _mouseJustDown then
                        for _, sw in ipairs(elem._swatches) do
                            if inBounds(mPos.X, mPos.Y, sw._x, sw._y, sw._sz, sw._sz) then
                                elem.Color = sw._color
                                elem._preview.Color = sw._color
                                if elem.Callback then pcall(elem.Callback, sw._color) end
                            end
                        end
                    end

                    -- SCROLL FRAME: content drag (anywhere in frame) + scrollbar thumb drag
                    if elem.Type == "ScrollFrame" then
                        local sbX = elem._sbX or (elem._x + elem._w - 8)
                        local sbY = elem._y
                        local sbW = 6
                        local sbH = elem._h

                        if _mouseJustDown then
                            if inBounds(mPos.X, mPos.Y, sbX, sbY, sbW, sbH) then
                                -- Clicked on scrollbar thumb/track — start thumb drag
                                elem._thumbDragging = true
                                elem._contentDragging = false
                                -- Offset relative to thumb top so it doesn't jump
                                local thumbTopY = elem._y + (elem._thumbH < elem._h
                                    and (elem._scrollY / math.max(1, elem._innerH - elem._h)) * (elem._h - elem._thumbH)
                                    or 0)
                                elem._thumbDragOffY = mPos.Y - thumbTopY
                            elseif inBounds(mPos.X, mPos.Y, elem._x, elem._y, elem._w - sbW, elem._h) then
                                -- Clicked inside content area — start content drag
                                elem._contentDragging = true
                                elem._thumbDragging = false
                                elem._contentDragStartY = mPos.Y
                                elem._contentDragStartScroll = elem._scrollY
                            end
                        end

                        if _mouseJustUp then
                            elem._thumbDragging = false
                            elem._contentDragging = false
                        end

                        if elem._thumbDragging and mouse1 then
                            local maxScroll = math.max(1, elem._innerH - elem._h)
                            local thumbMaxY = elem._h - elem._thumbH
                            local rawY      = mPos.Y - (elem._thumbDragOffY or 0)
                            local clampedY  = math.max(0, math.min(thumbMaxY, rawY - elem._y))
                            elem._thumb.Position = Vector2.new(sbX, elem._y + clampedY)
                            local pct       = thumbMaxY > 0 and clampedY / thumbMaxY or 0
                            elem._scrollY   = pct * maxScroll
                            if elem.Callback then pcall(elem.Callback, elem._scrollY) end
                        end

                        if elem._contentDragging and mouse1 then
                            local maxScroll = math.max(0, elem._innerH - elem._h)
                            local dy = elem._contentDragStartY - mPos.Y  -- drag up = positive scroll
                            local newScroll = math.max(0, math.min(maxScroll,
                                (elem._contentDragStartScroll or 0) + dy))
                            elem._scrollY = newScroll
                            -- Sync thumb position
                            local thumbMaxY = elem._h - elem._thumbH
                            local pct = maxScroll > 0 and newScroll / maxScroll or 0
                            elem._thumb.Position = Vector2.new(sbX, elem._y + pct * thumbMaxY)
                            if elem.Callback then pcall(elem.Callback, elem._scrollY) end
                        end

                        -- Reposition and clip item text rows every frame
                        if elem._items then
                            for _, item in ipairs(elem._items) do
                                local absY = elem._y + item._relY - elem._scrollY
                                item._txt.Position = Vector2.new(elem._x + 6, absY)
                                item._txt.Visible  = (absY >= elem._y)
                                    and (absY + (elem._itemH or 18) <= elem._y + elem._h)
                            end
                        end
                    end
                end

                -- ── Slider drag update (global)
                if _sliderDrag then
                    if mouse1 then
                        local e    = _sliderDrag
                        local relX = math.max(0, math.min(mPos.X - e._trackX, e._trackW))
                        local pct  = relX / e._trackW
                        local val  = e.Min + (e.Max - e.Min) * pct
                        e.Value    = val
                        e._valLbl.Text = tostring(math.floor(val))
                        e._fillRect.Size = Vector2.new(math.max(1, relX), 4)
                        e._knob.Position = Vector2.new(e._trackX + relX - e._knobW/2, e._trackY - 5)
                        if e.Callback then pcall(e.Callback, val) end
                    else
                        _sliderDrag = nil
                    end
                end
            end

            -- ── Text input character handling (for focused input)
            -- Uses iskeypressed() polling with per-key edge detection + auto-repeat.
            -- iskeypressed() is the correct Matcha API; getpressedkeys() does not exist.
            if _focusedInput then
                local elem = _focusedInput

                -- Helper: update the displayed text and cursor position
                local function refreshInputDisplay()
                    local displayText = elem.Text == "" and elem._placeholder or elem.Text
                    elem._inputTxt.Text  = displayText
                    elem._inputTxt.Color = elem.Text == "" and Theme.TextDisabled or Theme.TextPrimary
                    if elem._cursor then
                        -- Clamp cursor so it does not overflow the input box
                        local inputLeft = elem._x + 4
                        local inputRight = elem._x + elem._w - 6
                        local cursorX = math.min(inputLeft + (#elem.Text * 7), inputRight)
                        elem._cursor.Position = Vector2.new(cursorX, elem._cursor.Position.Y)
                    end
                    if elem.Callback then pcall(elem.Callback, elem.Text) end
                end

                -- Build current held-key set via iskeypressed() on all scannable VK codes.
                -- We check: Backspace(8), Enter(13), Shift(16), Space(32), A-Z(65-90),
                -- 0-9(48-57), numpad(96-105), and common punctuation VKs.
                local SCAN_KEYS = {
                    8, 13, 16, 32,
                    48,49,50,51,52,53,54,55,56,57,
                    65,66,67,68,69,70,71,72,73,74,75,76,77,
                    78,79,80,81,82,83,84,85,86,87,88,89,90,
                    96,97,98,99,100,101,102,103,104,105,
                    107,109,110,186,187,188,189,190,191,192,219,220,221,222
                }
                local heldSet = {}
                for _, k in ipairs(SCAN_KEYS) do
                    if iskeypressed(k) then
                        heldSet[k] = true
                    end
                end

                local shift = heldSet[16]

                -- Detect newly-pressed keys (edge trigger)
                for k, _ in pairs(heldSet) do
                    if not _prevHeldKeys[k] then
                        -- Key just pressed this frame
                        _keyRepeatTimer[k] = 0
                        _keyRepeatFired[k] = false
                        local handled = false

                        if k == 8 then  -- Backspace
                            if #elem.Text > 0 then
                                elem.Text = elem.Text:sub(1, -2)
                                refreshInputDisplay()
                            end
                            handled = true
                        elseif k == 13 then  -- Enter: commit and unfocus
                            elem.Focused = false
                            if elem._cursor then elem._cursor.Visible = false end
                            _focusedInput = nil
                            if elem.Callback then pcall(elem.Callback, elem.Text) end
                            handled = true
                        else
                            -- Convert VK code to character
                            local char = nil
                            if k >= 65 and k <= 90 then
                                -- A–Z
                                char = shift and string.char(k) or string.char(k + 32)
                            elseif k >= 48 and k <= 57 then
                                -- 0–9 row (with shift symbols)
                                local digits = "0123456789"
                                local shifted = ")!@#$%^&*("
                                char = shift and shifted:sub(k-47, k-47) or digits:sub(k-47, k-47)
                            elseif k == 32 then
                                char = " "
                            elseif k == 190 or k == 110 then
                                char = shift and ">" or "."
                            elseif k == 188 then
                                char = shift and "<" or ","
                            elseif k == 189 or k == 109 then
                                char = shift and "_" or "-"
                            elseif k == 191 then
                                char = shift and "?" or "/"
                            elseif k == 186 then
                                char = shift and ":" or ";"
                            elseif k == 222 then
                                char = shift and '"' or "'"
                            elseif k == 219 then
                                char = shift and "{" or "["
                            elseif k == 221 then
                                char = shift and "}" or "]"
                            elseif k == 220 then
                                char = shift and "|" or "\\"
                            elseif k == 187 or k == 107 then
                                char = shift and "+" or "="
                            elseif k == 192 then
                                char = shift and "~" or "`"
                            elseif k >= 96 and k <= 105 then
                                -- Numpad 0–9
                                char = tostring(k - 96)
                            end
                            if char and VALID_CHARS[char] then
                                elem.Text = elem.Text .. char
                                refreshInputDisplay()
                                handled = true
                            end
                        end
                        _keyRepeatFired[k] = handled
                    else
                        -- Key held — handle auto-repeat after initial delay
                        if _keyRepeatFired[k] then
                            _keyRepeatTimer[k] = (_keyRepeatTimer[k] or 0) + 0.016
                            local delay = _keyRepeatTimer[k] < 0.5 and 0.5 or 0.05
                            if _keyRepeatTimer[k] >= delay then
                                _keyRepeatTimer[k] = _keyRepeatTimer[k] < 0.5 and 0.5 or 0
                                -- Re-fire the same key action
                                if k == 8 and #elem.Text > 0 then
                                    elem.Text = elem.Text:sub(1, -2)
                                    refreshInputDisplay()
                                end
                            end
                        end
                    end
                end

                -- Keys released since last frame
                for k, _ in pairs(_prevHeldKeys) do
                    if not heldSet[k] then
                        _keyRepeatTimer[k] = nil
                        _keyRepeatFired[k] = nil
                    end
                end

                _prevHeldKeys = heldSet
            else
                _prevHeldKeys = {}
            end

            _lastMouse1 = mouse1
        end
    end
end

-- ─────────────────────────────────────────────────────────────
-- CLEANUP
-- ─────────────────────────────────────────────────────────────
function MatchaUI.Destroy()
    for _, obj in ipairs(_objects) do
        pcall(function() obj:Remove() end)
    end
    _objects  = {}
    _windows  = {}
    _notifs   = {}
    _tooltips = {}
end

return MatchaUI
