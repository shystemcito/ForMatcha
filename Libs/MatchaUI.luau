-- @env: Matcha LuaVM
-- MatchaUI v1.0 — Modular Drawing-based UI Library
-- Designed for Matcha external executor overlay rendering
-- No tweens, no heavy animations. Pure Drawing API.

print("Color picker maybe")
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

-- Active font — changed globally via MatchaUI.SetFont()
local _currentFont = Drawing.Fonts.Monospace
-- All Text Drawing objects created by makeText, so SetFont can repaint them
local _textObjects = {}

local function makeText(text, x, y, size, color, zIndex, centered, outline)
    local t = newDraw("Text")
    t.Text         = tostring(text)
    t.Position     = Vector2.new(x, y)
    t.Size         = size or 14
    t.Color        = color or Theme.TextPrimary
    t.ZIndex       = zIndex or 11
    t.Center       = centered or false
    t.Outline      = (outline ~= false)
    t.Font         = _currentFont
    t.Transparency = 1
    t.Visible      = true
    table.insert(_textObjects, t)
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
            -- ColorPicker panel objects (shift header + all panel draw objects)
            if elem._swatches then
                for _, sw in ipairs(elem._swatches) do
                    if sw._x then sw._x = sw._x + dx end
                    if sw._y then sw._y = sw._y + dy end
                end
            end
            -- ColorPicker: update all hit-test coordinates for header and panel
            if elem.Type == "ColorPicker" then
                if elem._headerX then elem._headerX = elem._headerX + dx end
                if elem._headerY then elem._headerY = elem._headerY + dy end
                if elem._arrowX  then elem._arrowX  = elem._arrowX  + dx end
                if elem._arrowY  then elem._arrowY  = elem._arrowY  + dy end
                -- Panel floats to the right of the window; shift with the window
                if elem._panelX  then elem._panelX  = elem._panelX  + dx end
                if elem._panelY  then elem._panelY  = elem._panelY  + dy end
                -- Palette swatches hit-test coords
                for _, sw in ipairs(elem._paletteSwatch or {}) do
                    sw._x = sw._x + dx
                    sw._y = sw._y + dy
                end
                -- Stepper buttons hit-test coords
                for _, btn in ipairs(elem._btnObjs or {}) do
                    btn._x = btn._x + dx
                    btn._y = btn._y + dy
                end
            end
            -- ScrollFrame scrollbar X anchor
            if elem._sbX then elem._sbX = elem._sbX + dx end
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
                    if elem.Type == "ColorPicker" then
                        elem._cpOpen = false
                        elem._arrowTxt.Text = "v"
                        elem._panelBg.Visible = false
                        for _, r in ipairs(elem._hueRects) do r.Visible = false end
                        elem._hueCursor.Visible = false
                        for _, sv in ipairs(elem._svRects) do sv._r.Visible = false end
                        elem._svCursor.Visible = false
                        elem._rSlider._bg.Visible=false elem._rSlider._fill.Visible=false
                        elem._rSlider._lbl.Visible=false elem._rSlider._val.Visible=false
                        elem._gSlider._bg.Visible=false elem._gSlider._fill.Visible=false
                        elem._gSlider._lbl.Visible=false elem._gSlider._val.Visible=false
                        elem._bSlider._bg.Visible=false elem._bSlider._fill.Visible=false
                        elem._bSlider._lbl.Visible=false elem._bSlider._val.Visible=false
                        elem._hexLabel.Visible = false
                        for _, sw in ipairs(elem._paletteSwatch or {}) do pcall(function() sw.Visible = false end) end
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
                        if elem.Type == "ColorPicker" then
                            elem._cpOpen = false
                            elem._arrowTxt.Text = "v"
                            elem._panelBg.Visible = false
                            for _, r in ipairs(elem._hueRects) do r.Visible = false end
                            elem._hueCursor.Visible = false
                            for _, sv in ipairs(elem._svRects) do sv._r.Visible = false end
                            elem._svCursor.Visible = false
                            elem._rSlider._bg.Visible=false elem._rSlider._fill.Visible=false
                            elem._rSlider._lbl.Visible=false elem._rSlider._val.Visible=false
                            elem._gSlider._bg.Visible=false elem._gSlider._fill.Visible=false
                            elem._gSlider._lbl.Visible=false elem._gSlider._val.Visible=false
                            elem._bSlider._bg.Visible=false elem._bSlider._fill.Visible=false
                            elem._bSlider._lbl.Visible=false elem._bSlider._val.Visible=false
                            elem._hexLabel.Visible = false
                            for _, sw in ipairs(elem._paletteSwatch or {}) do pcall(function() sw.Visible = false end) end
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
            -- ColorPicker: panel always starts closed
            if elem.Type == "ColorPicker" then
                elem._cpOpen = false
                elem._arrowTxt.Text = "v"
                elem._panelBg.Visible = false
                for _, r in ipairs(elem._hueRects) do r.Visible = false end
                elem._hueCursor.Visible = false
                for _, sv in ipairs(elem._svRects) do sv._r.Visible = false end
                elem._svCursor.Visible = false
                elem._rSlider._bg.Visible = false elem._rSlider._fill.Visible = false
                elem._rSlider._lbl.Visible = false elem._rSlider._val.Visible = false
                elem._gSlider._bg.Visible = false elem._gSlider._fill.Visible = false
                elem._gSlider._lbl.Visible = false elem._gSlider._val.Visible = false
                elem._bSlider._bg.Visible = false elem._bSlider._fill.Visible = false
                elem._bSlider._lbl.Visible = false elem._bSlider._val.Visible = false
                elem._hexLabel.Visible = false
                for _, sw in ipairs(elem._paletteSwatch or {}) do pcall(function() sw.Visible = false end) end
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

    -- ── COLOR PICKER
    -- Layout:
    --   Header row : [Label]  [Preview swatch]  [> button]
    --   Panel (opens to the RIGHT of the window, floating):
    --     Left  : hex color palette (10 cols × 8 rows of swatches)
    --     Right : R/G/B +/- steppers + hex label + live preview
    local function addColorPicker(cat, labelText, defaultColor, callback)
        local cx  = contentX()
        local cw  = contentW()
        local cy  = contentCursorY(cat)
        local rowH = ELEM_H
        local color = defaultColor or Color3.fromRGB(255, 100, 100)
        local objs = {}

        -- ── Header row ──────────────────────────────────────────────────
        local bg      = draw(makeRect(cx, cy, cw, rowH, Theme.ElementBg, baseZ+5, true))
        local lbl     = draw(makeText(labelText, cx + 8, cy + 6, 12, Theme.TextSecondary, baseZ+6, false, true))
        local preview = draw(makeRect(cx + cw - 54, cy + 4, 22, 22, color, baseZ+7, true))
        local arrowBtn = draw(makeRect(cx + cw - 28, cy + 4, 22, 22, Theme.InputBg, baseZ+7, true))
        local arrowTxt = draw(makeText(">", cx + cw - 22, cy + 8, 12, Theme.AccentOn, baseZ+8, false, false))
        trackAccent(arrowTxt)
        table.insert(objs, bg) table.insert(objs, lbl) table.insert(objs, preview)
        table.insert(objs, arrowBtn) table.insert(objs, arrowTxt)

        -- ── Panel geometry: opens to the RIGHT of the whole window ───────
        -- panelX is right edge of the window + 4px gap
        local panelX  = win.X + ww + 4
        local panelY  = cy
        local swatchSz = 16   -- each palette swatch cell
        local swatchGap = 2
        local palCols = 10
        local palRows = 8
        local palW    = palCols * (swatchSz + swatchGap) - swatchGap
        local palH    = palRows * (swatchSz + swatchGap) - swatchGap
        local rsAreaX = panelX + palW + 8
        local rsAreaW = 80          -- width of the R/G/B stepper area
        local panelW  = palW + 8 + rsAreaW + 8
        local panelH  = palH + 8    -- a little padding top+bottom

        local panelBg = draw(makeRect(panelX, panelY, panelW, panelH + 4, Theme.DropdownBg, baseZ+50, true))
        panelBg.Visible = false
        table.insert(objs, panelBg)
        -- thin accent border around panel
        local panelBorder = draw(makeRect(panelX, panelY, panelW, panelH + 4, Theme.ElementBorder, baseZ+50, false))
        panelBorder.Filled = false panelBorder.Thickness = 1 panelBorder.Visible = false
        table.insert(objs, panelBorder)

        -- ── Palette colors (flat hex table, same hue-ring layout as image) ──
        local PALETTE = {
            -- row 1: warm reds/oranges
            "8B0000","B22222","CC2200","FF0000","FF4500","FF6347","FF7F50","FF8C00","FFA500","FFD700",
            -- row 2: yellows/greens
            "FFFF00","ADFF2F","7FFF00","00FF00","00FA9A","00FF7F","39FF14","00FF80","00FFAA","00FFCC",
            -- row 3: cyans/teals
            "00FFFF","00CED1","00BFFF","1E90FF","0000FF","0000CD","00008B","191970","483D8B","6A0DAD",
            -- row 4: purples/pinks
            "8B008B","9400D3","EE82EE","FF00FF","FF1493","FF69B4","FFB6C1","C71585","DB7093","FF007F",
            -- row 5: earth tones
            "A52A2A","8B4513","D2691E","CD853F","DEB887","F5DEB3","FFE4B5","FFDAB9","FAEBD7","FAF0E6",
            -- row 6: blues/indigos
            "4169E1","6495ED","87CEEB","ADD8E6","B0E0E6","5F9EA0","4682B4","708090","778899","B0C4DE",
            -- row 7: greens
            "006400","228B22","2E8B57","3CB371","66CDAA","8FBC8F","90EE90","98FB98","F0FFF0","E8F5E9",
            -- row 8: grays/blacks/whites
            "000000","1A1A1A","333333","555555","777777","999999","AAAAAA","CCCCCC","EEEEEE","FFFFFF",
        }

        local paletteSwatches = {}
        for i, hexStr in ipairs(PALETTE) do
            local row = math.floor((i-1) / palCols)
            local col = (i-1) % palCols
            local sx  = panelX + 4 + col * (swatchSz + swatchGap)
            local sy  = panelY + 4 + row * (swatchSz + swatchGap)
            local r2  = tonumber(hexStr:sub(1,2), 16) or 0
            local g2  = tonumber(hexStr:sub(3,4), 16) or 0
            local b2  = tonumber(hexStr:sub(5,6), 16) or 0
            local sw  = draw(makeRect(sx, sy, swatchSz, swatchSz, Color3.fromRGB(r2,g2,b2), baseZ+52, true))
            sw.Visible = false
            table.insert(paletteSwatches, {_r=sw, _x=sx, _y=sy, _w=swatchSz, _h=swatchSz,
                _color=Color3.fromRGB(r2,g2,b2)})
            table.insert(objs, sw)
        end

        -- ── RGB +/- steppers (right side of panel) ───────────────────────
        local function colorToHex(c)
            return string.format("#%02X%02X%02X", math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
        end

        local stepSize = 5   -- how much each +/- click changes the channel value

        local rsObjs = {}   -- all objects in the stepper area (for bulk show/hide)
        local _rSlider = {_x=0,_y=0,_w=1,_h=1, _bg=nil,_fill=nil,_lbl=nil,_val=nil}
        local _gSlider = {_x=0,_y=0,_w=1,_h=1, _bg=nil,_fill=nil,_lbl=nil,_val=nil}
        local _bSlider = {_x=0,_y=0,_w=1,_h=1, _bg=nil,_fill=nil,_lbl=nil,_val=nil}

        -- Layout for each channel row: label | value | [-] [+]
        local channels   = {"R","G","B"}
        local channelSliders = {}
        local btnObjs = {}   -- {_x,_y,_w,_h,_ch,_dir} for hit testing

        for ci, ch in ipairs(channels) do
            local rowY = panelY + 4 + (ci-1) * 22
            local lbl2 = draw(makeText(ch, rsAreaX + 4, rowY + 4, 12, Theme.TextSecondary, baseZ+52, false, false))
            lbl2.Visible = false
            table.insert(objs, lbl2)

            local initV = math.floor((ch=="R" and color.R or ch=="G" and color.G or color.B) * 255)
            local valT  = draw(makeText(tostring(initV), rsAreaX + 18, rowY + 4, 12, Theme.TextPrimary, baseZ+52, false, false))
            valT.Visible = false
            table.insert(objs, valT)

            -- [-] button
            local minBg  = draw(makeRect(rsAreaX + 50, rowY + 2, 12, 14, Theme.InputBg, baseZ+52, true))
            local minTx2 = draw(makeText("-", rsAreaX + 53, rowY + 4, 12, Theme.TextPrimary, baseZ+53, false, false))
            minBg.Visible = false minTx2.Visible = false
            table.insert(objs, minBg) table.insert(objs, minTx2)

            -- [+] button
            local plusBg  = draw(makeRect(rsAreaX + 65, rowY + 2, 12, 14, Theme.InputBg, baseZ+52, true))
            local plusTx2 = draw(makeText("+", rsAreaX + 67, rowY + 4, 12, Theme.TextPrimary, baseZ+53, false, false))
            plusBg.Visible = false plusTx2.Visible = false
            table.insert(objs, plusBg) table.insert(objs, plusTx2)

            local slDummy = {_bg=minBg,_fill=minBg,_lbl=lbl2,_val=valT,
                             _x=rsAreaX,_y=rowY,_w=rsAreaW,_h=14}
            channelSliders[ch] = {_lbl=lbl2,_val=valT,_rowY=rowY,
                _minBg=minBg,_minTx=minTx2,_plusBg=plusBg,_plusTx=plusTx2}
            table.insert(btnObjs, {_x=rsAreaX+50,_y=rowY+2,_w=12,_h=14,_ch=ch,_dir=-1,_bg=minBg})
            table.insert(btnObjs, {_x=rsAreaX+65,_y=rowY+2,_w=12,_h=14,_ch=ch,_dir=1, _bg=plusBg})

            if ch=="R" then _rSlider = slDummy
            elseif ch=="G" then _gSlider = slDummy
            else _bSlider = slDummy end
        end

        -- Hex label + small live preview patch (bottom of stepper area)
        local hexLblY  = panelY + 4 + 3*22 + 4
        local hexLabel = draw(makeText(colorToHex(color), rsAreaX + 2, hexLblY, 10, Theme.TextSecondary, baseZ+52, false, false))
        hexLabel.Visible = false
        table.insert(objs, hexLabel)

        local prevPatch = draw(makeRect(rsAreaX + 2, hexLblY + 14, rsAreaW - 4, 16, color, baseZ+52, true))
        prevPatch.Visible = false
        table.insert(objs, prevPatch)

        registerElem(cat, objs, rowH)

        -- refreshAll: sync all UI to current color
        local function refreshAll()
            preview.Color    = color
            prevPatch.Color  = color
            hexLabel.Text    = colorToHex(color)
            local rv = math.floor(color.R*255)
            local gv = math.floor(color.G*255)
            local bv = math.floor(color.B*255)
            if channelSliders["R"] then channelSliders["R"]._val.Text = tostring(rv) end
            if channelSliders["G"] then channelSliders["G"]._val.Text = tostring(gv) end
            if channelSliders["B"] then channelSliders["B"]._val.Text = tostring(bv) end
            if callback then pcall(callback, color) end
        end

        local elem = {
            Type="ColorPicker", _bg=bg, _draws=objs,
            _x=cx+cw-54, _y=cy, _w=54, _h=rowH,
            _arrowX=cx+cw-28, _arrowY=cy+4, _arrowW=22, _arrowH=22,
            _headerX=cx, _headerY=cy, _headerW=cw, _headerH=rowH,
            _panelBg=panelBg, _panelBorder=panelBorder,
            _panelX=panelX, _panelY=panelY, _panelW=panelW, _panelH=panelH+4,
            _hueRects={}, _hueCursor=panelBorder,   -- stubs so closeCP helper works
            _svRects={}, _svCursor=panelBorder,
            _rSlider=_rSlider, _gSlider=_gSlider, _bSlider=_bSlider,
            _hexLabel=hexLabel,
            _preview=preview, _arrowTxt=arrowTxt,
            _paletteSwatch=paletteSwatches,
            _channelSliders=channelSliders,
            _btnObjs=btnObjs,
            _prevPatch=prevPatch,
            _swatches={},
            _cpOpen=false,
            _cpDragHue=false, _cpDragR=false, _cpDragG=false, _cpDragB=false, _cpDragSV=false,
            Color=color,
            _cpHue=0, _cpSat=1, _cpVal=1,
            _refreshSV=function() end, _refreshAll=refreshAll,
            _rsW=rsAreaW, _rsH=14, _rsX=rsAreaX,
            Callback=callback,
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
    -- visH  : visible height of the frame (px). innerH auto-grows as widgets are added.
    -- Supports both text rows (AddItem) and full UI elements (AddWidget).
    -- Scrolling is controlled by dragging the scrollbar thumb or content drag.
    -- Each frame in the main loop re-positions and clips all child objects.
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
            _contentDragging=false, _contentDragStartY=0, _contentDragStartScroll=0,
            _items={},   -- { _txt=DrawObj, _relY=number }  (text rows)
            _widgets={}, -- { _objs={DrawObj,...}, _relY=number, _h=number }  (UI widgets)
            _itemH=18,
            Callback=callback,
        }

        -- AddItem: add a labelled text row into the scroll frame (legacy API).
        function elem:AddItem(text)
            local rowIdx = #self._items
            local relY   = rowIdx * self._itemH + 4
            local absY   = self._y + relY
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
            if win.ActiveCat ~= cat then txt.Visible = false end
            return txt
        end

        -- AddWidget: embed a full UI element (Button, Toggle, Checkbox, Slider, Dropdown…)
        -- inside the scroll frame. The element is built normally via the cat builders, but
        -- its draw objects are detached from the category layout and owned by the frame.
        -- @param builder   function()  — a zero-argument closure that calls the add* function
        --                                and returns the element descriptor.
        -- @returns the element descriptor (same as calling the builder directly).
        --
        -- Usage:
        --   scrollFrame:AddWidget(function()
        --       return Window.AddButton(catFoo, "My Button", callback)
        --   end)
        --
        -- The widget is positioned relative to the scroll frame's content area and will
        -- scroll with the frame. Its height is taken from elem._h on the descriptor.
        function elem:AddWidget(builder)
            -- Temporarily adjust the category cursor so the element lands inside us.
            -- We compute the desired relY (distance from top of scroll frame content).
            local neededInnerH = 0
            for _, w in ipairs(self._widgets) do
                neededInnerH = neededInnerH + w._h + 2
            end
            for _, it in ipairs(self._items) do
                neededInnerH = neededInnerH + self._itemH
            end
            local relY = neededInnerH + 4

            -- Build the element. It will be placed at the current cat cursor,
            -- which is (cy + relY - scrollY). We must compensate for the cursor offset.
            local builtElem = builder()
            if not builtElem then return nil end

            local wh = builtElem._h or ELEM_H
            -- Move all of this element's draw objects into the frame's ownership
            -- and shift them to relY inside the frame.
            local absY = self._y + relY - self._scrollY
            local dyFix = absY - (builtElem._y or absY)

            -- Collect the draw objects from the last cat._elemObjs entry (the one just added)
            local lastObjs = cat._elemObjs[#cat._elemObjs]
            local widgetObjs = {}
            if lastObjs then
                for _, o in ipairs(lastObjs) do
                    table.insert(widgetObjs, o)
                    table.insert(objs, o)
                    -- shift vertically to align inside the scroll frame
                    pcall(function() o.Position = o.Position + Vector2.new(0, dyFix) end)
                    -- start clipped
                    local oAbsY = o.Position.Y
                    o.Visible = (oAbsY >= self._y) and (oAbsY < self._y + self._h)
                end
                -- Remove from cat layout management (we own it now)
                table.remove(cat._elemObjs, #cat._elemObjs)
            end

            -- Patch element descriptor Y coordinates to match actual position
            if builtElem._y then builtElem._y = builtElem._y + dyFix end
            if builtElem._ty then builtElem._ty = builtElem._ty + dyFix end
            if builtElem._trackY then builtElem._trackY = builtElem._trackY + dyFix end

            table.insert(self._widgets, {_objs=widgetObjs, _relY=relY, _h=wh, _elem=builtElem})

            -- Grow scroll content height
            local totalH = relY + wh + 8
            if totalH > self._innerH then
                self._innerH = totalH
                local newThH = math.max(20, math.floor(self._h * self._h / self._innerH))
                self._thumbH = newThH
                self._thumb.Size = Vector2.new(6, newThH)
            end

            if win.ActiveCat ~= cat then
                for _, o in ipairs(widgetObjs) do pcall(function() o.Visible = false end) end
            end
            return builtElem
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
        ttTxt.Font  = Drawing.Fonts.Monospace
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
    tTitle.Font        = Drawing.Fonts.Monospace
    tTitle.Transparency = 1
    tTitle.Visible     = true

    local tMsg = newDraw("Text")
    tMsg.Text          = message or ""
    tMsg.Position      = Vector2.new(nx+8, ny+22)
    tMsg.Size          = 12
    tMsg.Color         = Theme.TextPrimary
    tMsg.ZIndex        = 302
    tMsg.Outline       = true
    tMsg.Font          = Drawing.Fonts.Monospace
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

-- ─────────────────────────────────────────────────────────────
-- SET THEME COLOR
-- ─────────────────────────────────────────────────────────────
-- Change any Theme key (Background, TopBar, LeftBar, TextPrimary, etc.)
-- and repaint all currently-visible Drawing objects that use that color.
-- For accent-linked keys (AccentOn, SliderFill, etc.) prefer SetAccentColor.
-- @param key    string   — Theme table key (e.g. "Background", "TopBar")
-- @param color  Color3   — new color value
function MatchaUI.SetThemeColor(key, color)
    if Theme[key] == nil then
        warn("MatchaUI.SetThemeColor: unknown theme key '" .. tostring(key) .. "'")
        return
    end
    local old = Theme[key]
    Theme[key] = color
    -- Walk all tracked Drawing objects and repaint those whose color matches the old value.
    -- This is a best-effort repaint; objects painted with a derived or hardcoded color
    -- (e.g. CloseBtn red) are not automatically updated.
    for _, obj in ipairs(_objects) do
        pcall(function()
            if obj.Color == old then
                obj.Color = color
            end
        end)
    end
end

-- ─────────────────────────────────────────────────────────────
-- SET FONT
-- ─────────────────────────────────────────────────────────────
-- Change the global font for all text Drawing objects immediately.
-- Available font names: UI, System, SystemBold, Minecraft, Monospace, Pixel, Fortnite
-- @param fontName  string  — one of the names listed above (case-sensitive)
function MatchaUI.SetFont(fontName)
    local fontMap = {
        UI          = Drawing.Fonts.UI,
        System      = Drawing.Fonts.System,
        SystemBold  = Drawing.Fonts.SystemBold,
        Minecraft   = Drawing.Fonts.Minecraft,
        Monospace   = Drawing.Fonts.Monospace,
        Pixel       = Drawing.Fonts.Pixel,
        Fortnite    = Drawing.Fonts.Fortnite,
    }
    local font = fontMap[fontName]
    if not font then
        warn("MatchaUI.SetFont: unknown font '" .. tostring(fontName) ..
             "'. Valid options: UI, System, SystemBold, Minecraft, Monospace, Pixel, Fortnite")
        return
    end
    _currentFont = font
    -- Repaint all tracked Text Drawing objects
    for _, obj in ipairs(_textObjects) do
        pcall(function() obj.Font = font end)
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

                    -- COLOR PICKER: header click toggles panel, palette swatch click, +/- steppers
                    if elem.Type == "ColorPicker" then
                        local function setPanelVis(state)
                            elem._panelBg.Visible     = state
                            elem._panelBorder.Visible = state
                            for _, sw in ipairs(elem._paletteSwatch or {}) do
                                pcall(function() sw._r.Visible = state end)
                            end
                            local cs = elem._channelSliders or {}
                            for _, ch in ipairs({"R","G","B"}) do
                                local s = cs[ch]
                                if s then
                                    s._lbl.Visible=state s._val.Visible=state
                                    s._minBg.Visible=state s._minTx.Visible=state
                                    s._plusBg.Visible=state s._plusTx.Visible=state
                                end
                            end
                            elem._hexLabel.Visible  = state
                            elem._prevPatch.Visible = state
                        end

                        -- Toggle open/close on header click
                        if _mouseJustDown and inBounds(mPos.X, mPos.Y, elem._headerX, elem._headerY, elem._headerW, elem._headerH) then
                            elem._cpOpen = not elem._cpOpen
                            elem._arrowTxt.Text = elem._cpOpen and "<" or ">"
                            setPanelVis(elem._cpOpen)
                        end

                        if elem._cpOpen then
                            -- Close panel if click is outside both header and panel
                            if _mouseJustDown then
                                local inHeader = inBounds(mPos.X, mPos.Y, elem._headerX, elem._headerY, elem._headerW, elem._headerH)
                                local inPanel  = inBounds(mPos.X, mPos.Y, elem._panelX, elem._panelY, elem._panelW, elem._panelH)
                                if not inHeader and not inPanel then
                                    elem._cpOpen = false
                                    elem._arrowTxt.Text = ">"
                                    setPanelVis(false)
                                end
                            end

                            -- Palette swatch click
                            if _mouseJustDown then
                                for _, sw in ipairs(elem._paletteSwatch or {}) do
                                    if inBounds(mPos.X, mPos.Y, sw._x, sw._y, sw._w, sw._h) then
                                        elem.Color = sw._color
                                        elem._refreshAll()
                                        break
                                    end
                                end
                            end

                            -- +/- stepper buttons
                            if _mouseJustDown then
                                for _, btn in ipairs(elem._btnObjs or {}) do
                                    if inBounds(mPos.X, mPos.Y, btn._x, btn._y, btn._w, btn._h) then
                                        local c  = elem.Color
                                        local rv = math.floor(c.R*255)
                                        local gv = math.floor(c.G*255)
                                        local bv = math.floor(c.B*255)
                                        local step = 5
                                        if btn._ch == "R" then rv = math.max(0, math.min(255, rv + btn._dir * step))
                                        elseif btn._ch == "G" then gv = math.max(0, math.min(255, gv + btn._dir * step))
                                        else bv = math.max(0, math.min(255, bv + btn._dir * step)) end
                                        elem.Color = Color3.fromRGB(rv, gv, bv)
                                        elem._refreshAll()
                                        break
                                    end
                                end
                            end
                        end
                    end

                    -- SCROLL FRAME: content drag (anywhere in frame) + scrollbar thumb drag
                    if elem.Type == "ScrollFrame" then
                        -- Always derive sbX from elem._sbX (kept in sync by reposition)
                        local sbX = elem._sbX
                        local sbW = 8   -- wider hit zone for the scrollbar (matches the track visual)

                        if _mouseJustDown then
                            if inBounds(mPos.X, mPos.Y, sbX, elem._y, sbW, elem._h) then
                                -- Clicked scrollbar track/thumb — thumb drag
                                elem._thumbDragging    = true
                                elem._contentDragging  = false
                                -- Record offset from thumb top so thumb doesn't jump on first frame
                                local maxScroll  = math.max(1, elem._innerH - elem._h)
                                local thumbMaxY  = math.max(1, elem._h - elem._thumbH)
                                local thumbTopY  = elem._y + (elem._scrollY / maxScroll) * thumbMaxY
                                elem._thumbDragOffY = mPos.Y - thumbTopY
                            elseif inBounds(mPos.X, mPos.Y, elem._x, elem._y, elem._w - sbW, elem._h) then
                                -- Clicked content area — content drag
                                elem._contentDragging       = true
                                elem._thumbDragging         = false
                                elem._contentDragStartY     = mPos.Y
                                elem._contentDragStartScroll = elem._scrollY
                            end
                        end

                        if _mouseJustUp then
                            elem._thumbDragging   = false
                            elem._contentDragging = false
                        end

                        if elem._thumbDragging and mouse1 then
                            local maxScroll = math.max(1, elem._innerH - elem._h)
                            local thumbMaxY = math.max(1, elem._h - elem._thumbH)
                            -- rawY is the desired thumb top in screen space
                            local rawY     = mPos.Y - elem._thumbDragOffY
                            -- clamp to [elem._y, elem._y + thumbMaxY]
                            local clampedY = math.max(elem._y, math.min(elem._y + thumbMaxY, rawY))
                            -- position thumb at correct X (sbX) and clamped Y
                            elem._thumb.Position = Vector2.new(sbX, clampedY)
                            local pct      = (clampedY - elem._y) / thumbMaxY
                            elem._scrollY  = pct * maxScroll
                            if elem.Callback then pcall(elem.Callback, elem._scrollY) end
                        end

                        if elem._contentDragging and mouse1 then
                            local maxScroll = math.max(0, elem._innerH - elem._h)
                            -- Drag DOWN  → mPos.Y increases → dy positive → scroll DOWN (higher _scrollY)
                            local dy = mPos.Y - elem._contentDragStartY
                            -- Content moves with finger: dragging down reveals items above (scroll up)
                            -- so invert: dragging down = negative scroll delta
                            local newScroll = math.max(0, math.min(maxScroll,
                                elem._contentDragStartScroll - dy))
                            elem._scrollY = newScroll
                            -- Sync thumb
                            local thumbMaxY = math.max(1, elem._h - elem._thumbH)
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
                        -- Reposition and clip widget draw objects every frame
                        if elem._widgets then
                            for _, widget in ipairs(elem._widgets) do
                                local baseAbsY = elem._y + widget._relY - elem._scrollY
                                local wElem    = widget._elem
                                local dy = baseAbsY - (wElem._y or baseAbsY)
                                -- Shift element descriptor Y fields
                                if wElem._y then wElem._y = wElem._y + dy end
                                if wElem._ty then wElem._ty = wElem._ty + dy end
                                if wElem._trackY then wElem._trackY = wElem._trackY + dy end
                                for _, obj in ipairs(widget._objs) do
                                    pcall(function()
                                        obj.Position = obj.Position + Vector2.new(0, dy)
                                        local oY = obj.Position.Y
                                        obj.Visible = (oY >= elem._y) and (oY < elem._y + elem._h)
                                    end)
                                end
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
