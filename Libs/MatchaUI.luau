-- @env: Matcha LuaVM
-- MatchaUI.luau — Comprehensive UI Library for Matcha LuaVM
-- Requires only the Drawing API. No tweens, no heavy animations.
-- Layout: Topbar (title + minimize + close) | LeftBar (categories) | RightContainer (content)

--[[
    PUBLIC API SUMMARY
    ==================
    UiLib:Init(config)                         -> starts the library, returns self
    UiLib:CreateWindow(title, x, y, w, h)      -> Window
    Window:AddCategory(label)                  -> Category
    Category:AddGroup(label)                   -> Group
    Group:AddButton(label, callback)           -> Element
    Group:AddToggle(label, default, callback)  -> Toggle
    Group:AddSlider(label, min, max, default, suffix, callback) -> Slider
    Group:AddDropdown(label, options, default, callback)        -> Dropdown
    Group:AddTextInput(label, placeholder, callback)            -> TextInput
    Group:AddSearchBar(label, items, callback)                  -> SearchBar
    Group:AddColorPicker(label, default, callback)              -> ColorPicker
    Group:AddKeybind(label, default, callback)                  -> Keybind
    Group:AddCheckbox(label, default, callback)                 -> Checkbox
    Group:AddValueLabel(label, value)          -> ValueLabel (has :Set(v))
    Group:AddScrollFrame(height, items)        -> ScrollFrame
    Group:AddTooltip(targetElement, text)      -> attaches tooltip to element
    UiLib:Notify(title, body, duration)        -> shows a notification popup
    UiLib:Step()                               -> call every frame in your loop
    UiLib:Destroy()                            -> removes all drawings
]]

local MatchaUI = {}
MatchaUI.__index = MatchaUI
print("Running new version")
-- ==============================================================================
-- HELPERS
-- ==============================================================================

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function mouseInRect(mx, my, rx, ry, rw, rh)
    return mx >= rx and mx <= rx + rw and my >= ry and my <= ry + rh
end

local function getMousePos()
    local ok, lp = pcall(function() return game:GetService("Players").LocalPlayer end)
    if not ok or not lp then return 0, 0 end
    local m = lp:GetMouse()
    return m.X, m.Y
end

local function getMouse1()
    return iskeypressed and iskeypressed(0x01) or false
end

-- VK code -> display name map (no weird chars)
local VK_NAMES = {
    [0x01]="M1",[0x02]="M2",[0x08]="Back",[0x09]="Tab",[0x0D]="Enter",
    [0x10]="Shift",[0x11]="Ctrl",[0x12]="Alt",[0x1B]="Esc",[0x20]="Space",
    [0x21]="PgUp",[0x22]="PgDn",[0x23]="End",[0x24]="Home",
    [0x25]="Left",[0x26]="Up",[0x27]="Right",[0x28]="Down",
    [0x2E]="Del",
    [0x30]="0",[0x31]="1",[0x32]="2",[0x33]="3",[0x34]="4",
    [0x35]="5",[0x36]="6",[0x37]="7",[0x38]="8",[0x39]="9",
    [0x41]="A",[0x42]="B",[0x43]="C",[0x44]="D",[0x45]="E",
    [0x46]="F",[0x47]="G",[0x48]="H",[0x49]="I",[0x4A]="J",
    [0x4B]="K",[0x4C]="L",[0x4D]="M",[0x4E]="N",[0x4F]="O",
    [0x50]="P",[0x51]="Q",[0x52]="R",[0x53]="S",[0x54]="T",
    [0x55]="U",[0x56]="V",[0x57]="W",[0x58]="X",[0x59]="Y",[0x5A]="Z",
    [0x70]="F1",[0x71]="F2",[0x72]="F3",[0x73]="F4",[0x74]="F5",
    [0x75]="F6",[0x76]="F7",[0x77]="F8",[0x78]="F9",[0x79]="F10",
    [0x7A]="F11",[0x7B]="F12",
    [0xA0]="LShift",[0xA1]="RShift",[0xA2]="LCtrl",[0xA3]="RCtrl",
    [0xBA]=";",[0xBB]="+",[0xBC]=",",[0xBD]="-",[0xBE]=".",[0xBF]="/",
    [0xC0]="`",[0xDB]="[",[0xDC]="\\",[0xDD]="]",[0xDE]="'"
}

-- All scannable VK codes for keybind capture
local ALL_VK = {}
for vk in pairs(VK_NAMES) do
    ALL_VK[#ALL_VK+1] = vk
end

-- ==============================================================================
-- DRAWING WRAPPER
-- ==============================================================================

local DrawPool = {}

local function newSquare(x, y, w, h, color, filled, zindex, transparency, corner)
    local s = Drawing.new("Square")
    s.Position     = Vector2.new(x, y)
    s.Size         = Vector2.new(w, h)
    s.Color        = color or Color3.fromRGB(255,255,255)
    s.Filled       = filled ~= false
    s.ZIndex       = zindex or 1
    s.Transparency = transparency or 0
    s.Visible      = true
    if corner then s.Corner = corner end
    DrawPool[#DrawPool+1] = s
    return s
end

local function newText(x, y, text, size, color, zindex, outline, center)
    local t = Drawing.new("Text")
    t.Position     = Vector2.new(x, y)
    t.Text         = tostring(text)
    t.Size         = size or 13
    t.Color        = color or Color3.fromRGB(255,255,255)
    t.ZIndex       = zindex or 1
    t.Outline      = outline ~= false
    t.Center       = center or false
    t.Font         = Drawing.Fonts.UI
    t.Visible      = true
    DrawPool[#DrawPool+1] = t
    return t
end

local function newLine(x1,y1,x2,y2,color,thickness,zindex)
    local l = Drawing.new("Line")
    l.From         = Vector2.new(x1,y1)
    l.To           = Vector2.new(x2,y2)
    l.Color        = color or Color3.fromRGB(255,255,255)
    l.Thickness    = thickness or 1
    l.ZIndex       = zindex or 1
    l.Transparency = 0
    l.Visible      = true
    DrawPool[#DrawPool+1] = l
    return l
end

local function removeDrawing(d)
    if d then
        for i,v in ipairs(DrawPool) do
            if v == d then table.remove(DrawPool, i) break end
        end
        pcall(function() d:Remove() end)
    end
end

local function removeList(list)
    for _,d in ipairs(list) do removeDrawing(d) end
end

-- ==============================================================================
-- THEME
-- ==============================================================================

local T = {
    bg        = Color3.fromRGB(18, 18, 22),
    topbar    = Color3.fromRGB(12, 12, 16),
    leftbar   = Color3.fromRGB(14, 14, 18),
    panel     = Color3.fromRGB(22, 22, 28),
    group     = Color3.fromRGB(28, 28, 36),
    border    = Color3.fromRGB(45, 45, 58),
    accent    = Color3.fromRGB(100, 140, 255),
    accentDim = Color3.fromRGB(55, 80, 160),
    text      = Color3.fromRGB(220, 220, 230),
    subtext   = Color3.fromRGB(120, 120, 135),
    danger    = Color3.fromRGB(220, 70, 70),
    success   = Color3.fromRGB(70, 200, 110),
    warn      = Color3.fromRGB(230, 180, 50),
    input_bg  = Color3.fromRGB(12, 12, 16),
    slider_bg = Color3.fromRGB(12, 12, 16),
    check_on  = Color3.fromRGB(100, 140, 255),
    check_off = Color3.fromRGB(40, 40, 50),
}

-- ==============================================================================
-- CONSTANTS
-- ==============================================================================

local TOPBAR_H   = 28
local LEFTBAR_W  = 90
local PADDING    = 7
local ELEM_H     = 22
local FONT_SIZE  = 13
local CAT_H      = 26
local GROUP_PAD  = 6
local NOTIF_W    = 220
local NOTIF_H    = 52
local NOTIF_PAD  = 6

-- ==============================================================================
-- GLOBAL STATE
-- ==============================================================================

local _state = {
    windows          = {},
    notifications    = {},
    notif_counter    = 0,
    active_dropdown  = nil,    -- ref to dropdown currently open
    active_colorpick = nil,    -- ref to colorpicker currently open
    active_keybind   = nil,    -- ref to keybind waiting for input
    active_textinput = nil,    -- ref to text input being edited
    tooltip_elem     = nil,
    tooltip_timer    = 0,
    mouse_prev_x     = 0,
    mouse_prev_y     = 0,
    drag_window      = nil,
    drag_ox          = 0,
    drag_oy          = 0,
    m1_prev          = false,
    m1_curr          = false,
    mx               = 0,
    my               = 0,
}

-- Key input edge detection
local _keyPrev = {}
local function keyJustPressed(vk)
    local now = iskeypressed and iskeypressed(vk) or false
    local prev = _keyPrev[vk] or false
    _keyPrev[vk] = now
    return now and not prev
end

-- Char-level key capture for text inputs
local CHAR_KEYS = {}
do
    -- a-z
    for i = 0x41, 0x5A do CHAR_KEYS[i] = string.char(i+32) end
    -- 0-9 (top row)
    for i = 0x30, 0x39 do CHAR_KEYS[i] = string.char(i) end
    CHAR_KEYS[0x20] = " "
    CHAR_KEYS[0xBD] = "-"
    CHAR_KEYS[0xBB] = "="
    CHAR_KEYS[0xBE] = "."
    CHAR_KEYS[0xBC] = ","
    CHAR_KEYS[0xBF] = "/"
    CHAR_KEYS[0xBA] = ";"
    CHAR_KEYS[0xDE] = "'"
    CHAR_KEYS[0xDB] = "["
    CHAR_KEYS[0xDD] = "]"
    CHAR_KEYS[0xDC] = "\\"
    CHAR_KEYS[0xC0] = "`"
end
local SHIFT_MAP = {
    ["1"]="!",["2"]="@",["3"]="#",["4"]="$",["5"]="%",
    ["6"]="^",["7"]="&",["8"]="*",["9"]="(",["0"]=")",
    ["-"]="_",["="]="+",["["]="{"]=["]"]="}",[";"]=":"
    ,["'"]='"',[","]="<",["."]=">",["/"]="?",["\\"]="|",
    ["`"]="~"
}

-- ==============================================================================
-- WINDOW
-- ==============================================================================

local Window = {}
Window.__index = Window

function Window:_build()
    local x, y, w, h = self.x, self.y, self.w, self.h

    -- Main background
    self._bg = newSquare(x, y, w, h, T.bg, true, 10, 0, 2)

    -- Top border
    self._topborder = newSquare(x, y, w, TOPBAR_H, T.topbar, true, 11, 0, 2)
    self._topline   = newSquare(x, y+TOPBAR_H-1, w, 1, T.accent, true, 12, 0)

    -- Title
    self._title_d = newText(x + PADDING, y + 7, self.title, FONT_SIZE, T.text, 13, true)

    -- Minimize button  [_]
    self._min_bg = newSquare(x + w - 44, y + 5, 18, 18, T.group, true, 12, 0, 2)
    self._min_t  = newText(x + w - 44 + 4, y + 6, "_", FONT_SIZE, T.subtext, 13, false)

    -- Close button  [x]
    self._cls_bg = newSquare(x + w - 23, y + 5, 18, 18, T.danger, true, 12, 0, 2)
    self._cls_t  = newText(x + w - 23 + 4, y + 6, "x", FONT_SIZE, T.text, 13, false)

    -- Left bar background
    self._leftbar = newSquare(x, y+TOPBAR_H, LEFTBAR_W, h-TOPBAR_H, T.leftbar, true, 11, 0)
    self._leftborder = newSquare(x+LEFTBAR_W-1, y+TOPBAR_H, 1, h-TOPBAR_H, T.border, true, 12, 0)

    -- Right content area
    self._rightbg = newSquare(x+LEFTBAR_W, y+TOPBAR_H, w-LEFTBAR_W, h-TOPBAR_H, T.panel, true, 10, 0)

    self._minimized = false
    self._visible   = true

    -- Outer border
    self._border = newSquare(x, y, w, h, T.border, false, 13, 0, 2)
end

function Window:_rebuildLayout()
    -- repositions all drawings when x/y/w/h changes (drag)
    local x, y, w, h = self.x, self.y, self.w, self.h

    self._bg.Position       = Vector2.new(x,y)
    self._bg.Size           = Vector2.new(w,h)
    self._topborder.Position= Vector2.new(x,y)
    self._topborder.Size    = Vector2.new(w,TOPBAR_H)
    self._topline.Position  = Vector2.new(x,y+TOPBAR_H-1)
    self._topline.Size      = Vector2.new(w,1)
    self._title_d.Position  = Vector2.new(x+PADDING, y+7)
    self._min_bg.Position   = Vector2.new(x+w-44, y+5)
    self._min_t.Position    = Vector2.new(x+w-44+4, y+6)
    self._cls_bg.Position   = Vector2.new(x+w-23, y+5)
    self._cls_t.Position    = Vector2.new(x+w-23+4, y+6)
    self._leftbar.Position  = Vector2.new(x, y+TOPBAR_H)
    self._leftbar.Size      = Vector2.new(LEFTBAR_W, h-TOPBAR_H)
    self._leftborder.Position = Vector2.new(x+LEFTBAR_W-1, y+TOPBAR_H)
    self._leftborder.Size   = Vector2.new(1, h-TOPBAR_H)
    self._rightbg.Position  = Vector2.new(x+LEFTBAR_W, y+TOPBAR_H)
    self._rightbg.Size      = Vector2.new(w-LEFTBAR_W, h-TOPBAR_H)
    self._border.Position   = Vector2.new(x,y)
    self._border.Size       = Vector2.new(w,h)

    -- Rebuild categories
    for _,cat in ipairs(self._categories) do
        cat:_rebuildLayout()
    end
end

function Window:_setVisible(v)
    self._visible = v
    local function sv(d) if d then d.Visible = v end end
    sv(self._bg) sv(self._topborder) sv(self._topline) sv(self._title_d)
    sv(self._min_bg) sv(self._min_t) sv(self._cls_bg) sv(self._cls_t)
    sv(self._leftbar) sv(self._leftborder) sv(self._rightbg) sv(self._border)

    for _,cat in ipairs(self._categories) do
        cat:_setVisible(v)
    end
end

function Window:_setContentVisible(v)
    -- Only show/hide content area (minimize hides content but keeps topbar)
    self._leftbar.Visible     = v
    self._leftborder.Visible  = v
    self._rightbg.Visible     = v
    for _,cat in ipairs(self._categories) do
        cat:_setVisible(v)
    end
    if v then
        self._bg.Size = Vector2.new(self.w, self.h)
        self._border.Size = Vector2.new(self.w, self.h)
    else
        self._bg.Size = Vector2.new(self.w, TOPBAR_H)
        self._border.Size = Vector2.new(self.w, TOPBAR_H)
    end
end

function Window:AddCategory(label)
    local cat = setmetatable({}, {__index = require and nil or nil})
    cat._label      = label
    cat._groups     = {}
    cat._window     = self
    cat._active     = (#self._categories == 0)  -- first cat is default active
    cat._drawings   = {}

    self._categories[#self._categories+1] = cat

    -- build tab button in leftbar
    local idx = #self._categories
    local tx = self.x + 4
    local ty = self.y + TOPBAR_H + (idx-1)*CAT_H + 4

    cat._tab_bg = newSquare(tx, ty, LEFTBAR_W-8, CAT_H-4,
        cat._active and T.accent or T.group, true, 14, 0, 2)
    cat._tab_t  = newText(tx+6, ty+5, label, 12,
        cat._active and T.text or T.subtext, 15, true)

    cat._tab_idx = idx

    -- content area dimensions
    cat._cx = self.x + LEFTBAR_W + PADDING
    cat._cy = self.y + TOPBAR_H + PADDING
    cat._cw = self.w - LEFTBAR_W - PADDING*2
    cat._ch = self.h - TOPBAR_H - PADDING*2

    -- Category methods
    local Category = {}
    Category.__index = Category

    function cat:_rebuildLayout()
        local win = self._window
        local idx2 = self._tab_idx
        local tx2 = win.x + 4
        local ty2 = win.y + TOPBAR_H + (idx2-1)*CAT_H + 4
        self._tab_bg.Position = Vector2.new(tx2, ty2)
        self._tab_t.Position  = Vector2.new(tx2+6, ty2+5)
        self._cx = win.x + LEFTBAR_W + PADDING
        self._cy = win.y + TOPBAR_H + PADDING
        self._cw = win.w - LEFTBAR_W - PADDING*2
        self._ch = win.h - TOPBAR_H - PADDING*2
        for _,grp in ipairs(self._groups) do
            grp:_rebuildLayout()
        end
    end

    function cat:_setVisible(v)
        self._tab_bg.Visible = v
        self._tab_t.Visible  = v
        if not self._active then
            -- non-active tab only shows its tab button
        end
        for _,grp in ipairs(self._groups) do
            grp:_setVisible(v and self._active)
        end
    end

    function cat:_activate()
        -- deactivate siblings
        for _,c in ipairs(self._window._categories) do
            if c ~= self then
                c._active = false
                c._tab_bg.Color = T.group
                c._tab_t.Color  = T.subtext
                for _,g in ipairs(c._groups) do g:_setVisible(false) end
            end
        end
        self._active = true
        self._tab_bg.Color = T.accent
        self._tab_t.Color  = T.text
        for _,g in ipairs(self._groups) do g:_setVisible(true) end
    end

    function cat:AddGroup(label)
        -- Groups stack vertically in the content area
        local grpIdx = #self._groups
        local gx = self._cx
        -- calculate gy based on previous groups
        local gy = self._cy
        for _,g in ipairs(self._groups) do
            gy = gy + g._totalH + GROUP_PAD
        end

        local grp = {}
        grp._label    = label
        grp._cat      = self
        grp._elements = {}
        grp._drawings = {}
        grp._gx       = gx
        grp._gy       = gy
        grp._gw       = self._cw
        grp._innerH   = 0      -- grows as elements are added
        grp._totalH   = 0      -- including header

        local HEADER_H = 18

        grp._hdr_bg  = newSquare(gx, gy, self._cw, HEADER_H, T.group, true, 15, 0, 2)
        grp._hdr_t   = newText(gx+6, gy+3, label, 12, T.accent, 16, true)
        grp._hdr_line= newSquare(gx, gy+HEADER_H-1, self._cw, 1, T.border, true, 16, 0)
        grp._body_bg = newSquare(gx, gy+HEADER_H, self._cw, ELEM_H, T.group, true, 14, 0, 2)
        grp._border  = newSquare(gx, gy, self._cw, HEADER_H+ELEM_H, T.border, false, 17, 0, 2)

        grp._hdr_h    = HEADER_H
        grp._totalH   = HEADER_H + ELEM_H

        -- hide if category not active
        if not self._active then
            grp._hdr_bg.Visible  = false
            grp._hdr_t.Visible   = false
            grp._hdr_line.Visible= false
            grp._body_bg.Visible = false
            grp._border.Visible  = false
        end

        function grp:_getNextElemY()
            return self._gy + self._hdr_h + PADDING + self._innerH
        end

        function grp:_updateBody()
            local bh = math.max(self._innerH + PADDING, ELEM_H)
            self._body_bg.Size  = Vector2.new(self._gw, bh)
            self._border.Size   = Vector2.new(self._gw, self._hdr_h + bh)
            self._totalH = self._hdr_h + bh
        end

        function grp:_rebuildLayout()
            local newGx = self._cat._cx
            local newGy = self._cat._cy
            for _,g in ipairs(self._cat._groups) do
                if g == self then break end
                newGy = newGy + g._totalH + GROUP_PAD
            end
            local newGw = self._cat._cw
            local dx = newGx - self._gx
            local dy = newGy - self._gy

            self._gx = newGx
            self._gy = newGy
            self._gw = newGw

            self._hdr_bg.Position   = Vector2.new(newGx, newGy)
            self._hdr_bg.Size       = Vector2.new(newGw, self._hdr_h)
            self._hdr_t.Position    = Vector2.new(newGx+6, newGy+3)
            self._hdr_line.Position = Vector2.new(newGx, newGy+self._hdr_h-1)
            self._hdr_line.Size     = Vector2.new(newGw, 1)
            self._body_bg.Position  = Vector2.new(newGx, newGy+self._hdr_h)
            self._body_bg.Size      = Vector2.new(newGw, self._body_bg.Size.Y)
            self._border.Position   = Vector2.new(newGx, newGy)
            self._border.Size       = Vector2.new(newGw, self._border.Size.Y)

            for _,el in ipairs(self._elements) do
                if el._rebuildLayout then el:_rebuildLayout(dx, dy) end
            end
        end

        function grp:_setVisible(v)
            self._hdr_bg.Visible   = v
            self._hdr_t.Visible    = v
            self._hdr_line.Visible = v
            self._body_bg.Visible  = v
            self._border.Visible   = v
            for _,el in ipairs(self._elements) do
                if el._setVisible then el:_setVisible(v) end
            end
        end

        -- == BUTTON ==========================================================
        function grp:AddButton(label2, callback)
            local ey = self:_getNextElemY()
            local ex = self._gx + PADDING
            local ew = self._gw - PADDING*2
            local vis = self._cat._active

            local el = {}
            el._type      = "button"
            el._grp       = self
            el._callback  = callback
            el._tooltip   = nil

            el._bg   = newSquare(ex, ey, ew, ELEM_H, T.accentDim, true, 18, 0, 2)
            el._text = newText(ex + ew/2, ey+4, label2, FONT_SIZE, T.text, 19, true, true)
            el._bg.Visible   = vis
            el._text.Visible = vis

            function el:_setVisible(v)
                self._bg.Visible   = v
                self._text.Visible = v
            end

            function el:_rebuildLayout(dx, dy)
                self._bg.Position   = self._bg.Position   + Vector2.new(dx,dy)
                self._text.Position = self._text.Position + Vector2.new(dx,dy)
            end

            function el:_step(mx, my, m1click)
                if not self._bg.Visible then return end
                local p = self._bg.Position
                local s = self._bg.Size
                local hover = mouseInRect(mx,my,p.X,p.Y,s.X,s.Y)
                self._bg.Color = hover and T.accent or T.accentDim
                if hover and m1click and self._callback then
                    self._callback()
                end
            end

            self._innerH = self._innerH + ELEM_H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == TOGGLE ==========================================================
        function grp:AddToggle(label2, default, callback)
            local ey  = self:_getNextElemY()
            local ex  = self._gx + PADDING
            local ew  = self._gw - PADDING*2
            local vis = self._cat._active

            local el = {}
            el._type     = "toggle"
            el._value    = default or false
            el._callback = callback
            el._tooltip  = nil

            local BOX = 14
            el._bg      = newSquare(ex, ey, ew, ELEM_H, T.input_bg, true, 18, 0, 2)
            el._label_d = newText(ex+4, ey+4, label2, FONT_SIZE, T.text, 19, true)
            el._box     = newSquare(ex+ew-BOX-4, ey+(ELEM_H-BOX)/2, BOX, BOX,
                              el._value and T.check_on or T.check_off, true, 19, 0, 2)
            el._check   = newText(ex+ew-BOX-4+2, ey+(ELEM_H-BOX)/2, el._value and "v" or " ", 11, T.text, 20, false)

            el._bg.Visible     = vis
            el._label_d.Visible= vis
            el._box.Visible    = vis
            el._check.Visible  = vis

            function el:_setVisible(v)
                self._bg.Visible     = v
                self._label_d.Visible= v
                self._box.Visible    = v
                self._check.Visible  = v
            end

            function el:_rebuildLayout(dx, dy)
                self._bg.Position     = self._bg.Position     + Vector2.new(dx,dy)
                self._label_d.Position= self._label_d.Position+ Vector2.new(dx,dy)
                self._box.Position    = self._box.Position    + Vector2.new(dx,dy)
                self._check.Position  = self._check.Position  + Vector2.new(dx,dy)
            end

            function el:Set(v)
                self._value = v
                self._box.Color  = v and T.check_on or T.check_off
                self._check.Text = v and "v" or " "
                if self._callback then self._callback(v) end
            end

            function el:Get() return self._value end

            function el:_step(mx, my, m1click)
                if not self._bg.Visible then return end
                local p = self._bg.Position
                local s = self._bg.Size
                if mouseInRect(mx,my,p.X,p.Y,s.X,s.Y) and m1click then
                    self:Set(not self._value)
                end
            end

            self._innerH = self._innerH + ELEM_H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == CHECKBOX ========================================================
        function grp:AddCheckbox(label2, default, callback)
            -- Same as toggle but visually a square checkbox on the left
            local ey  = self:_getNextElemY()
            local ex  = self._gx + PADDING
            local ew  = self._gw - PADDING*2
            local vis = self._cat._active
            local BOX = 14

            local el = {}
            el._type     = "checkbox"
            el._value    = default or false
            el._callback = callback
            el._tooltip  = nil

            el._bg    = newSquare(ex, ey, ew, ELEM_H, T.input_bg, true, 18, 0, 2)
            el._box   = newSquare(ex+4, ey+(ELEM_H-BOX)/2, BOX, BOX,
                            el._value and T.check_on or T.check_off, true, 19, 0, 2)
            el._check = newText(ex+6, ey+(ELEM_H-BOX)/2, el._value and "v" or " ", 11, T.text, 20, false)
            el._lbl   = newText(ex+BOX+10, ey+4, label2, FONT_SIZE, T.text, 19, true)

            el._bg.Visible    = vis
            el._box.Visible   = vis
            el._check.Visible = vis
            el._lbl.Visible   = vis

            function el:_setVisible(v)
                self._bg.Visible    = v
                self._box.Visible   = v
                self._check.Visible = v
                self._lbl.Visible   = v
            end

            function el:_rebuildLayout(dx, dy)
                local d = Vector2.new(dx, dy)
                self._bg.Position    = self._bg.Position    + d
                self._box.Position   = self._box.Position   + d
                self._check.Position = self._check.Position + d
                self._lbl.Position   = self._lbl.Position   + d
            end

            function el:Set(v)
                self._value = v
                self._box.Color  = v and T.check_on or T.check_off
                self._check.Text = v and "v" or " "
                if self._callback then self._callback(v) end
            end

            function el:Get() return self._value end

            function el:_step(mx, my, m1click)
                if not self._bg.Visible then return end
                local p = self._bg.Position
                local s = self._bg.Size
                if mouseInRect(mx,my,p.X,p.Y,s.X,s.Y) and m1click then
                    self:Set(not self._value)
                end
            end

            self._innerH = self._innerH + ELEM_H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == SLIDER ==========================================================
        function grp:AddSlider(label2, min, max, default, suffix, callback)
            local ey   = self:_getNextElemY()
            local ex   = self._gx + PADDING
            local ew   = self._gw - PADDING*2
            local vis  = self._cat._active
            local H    = ELEM_H + 10   -- taller for slider

            local el = {}
            el._type     = "slider"
            el._min      = min or 0
            el._max      = max or 100
            el._value    = clamp(default or min or 0, min or 0, max or 100)
            el._suffix   = suffix or ""
            el._callback = callback
            el._dragging = false
            el._tooltip  = nil

            local TRACK_Y = H - 8
            local TRACK_H = 4

            el._bg      = newSquare(ex, ey, ew, H, T.input_bg, true, 18, 0, 2)
            el._lbl     = newText(ex+4, ey+3, label2, FONT_SIZE, T.text, 19, true)
            el._track   = newSquare(ex+4, ey+TRACK_Y, ew-8, TRACK_H, T.border, true, 19, 0, 2)
            el._fill    = newSquare(ex+4, ey+TRACK_Y, 1, TRACK_H, T.accent, true, 20, 0, 2)
            el._val_t   = newText(ex+ew-4, ey+3, tostring(el._value)..el._suffix, FONT_SIZE, T.accent, 19, false)
            el._val_t.Position = Vector2.new(ex+ew-4 - #(tostring(el._value)..el._suffix)*7, ey+3)

            el._bg.Visible    = vis
            el._lbl.Visible   = vis
            el._track.Visible = vis
            el._fill.Visible  = vis
            el._val_t.Visible = vis

            local function updateFill(self2)
                local pct = (self2._value - self2._min) / (self2._max - self2._min)
                local tw = self2._track.Size.X
                self2._fill.Size = Vector2.new(math.max(1, tw * pct), TRACK_H)
                self2._val_t.Text = tostring(self2._value) .. self2._suffix
                self2._val_t.Position = Vector2.new(
                    self2._track.Position.X + tw - #self2._val_t.Text * 6,
                    self2._lbl.Position.Y)
            end
            updateFill(el)

            function el:_setVisible(v)
                self._bg.Visible    = v
                self._lbl.Visible   = v
                self._track.Visible = v
                self._fill.Visible  = v
                self._val_t.Visible = v
            end

            function el:_rebuildLayout(dx, dy)
                local d = Vector2.new(dx, dy)
                self._bg.Position    = self._bg.Position    + d
                self._lbl.Position   = self._lbl.Position   + d
                self._track.Position = self._track.Position + d
                self._fill.Position  = self._fill.Position  + d
                self._val_t.Position = self._val_t.Position + d
            end

            function el:Set(v)
                self._value = clamp(math.floor(v), self._min, self._max)
                updateFill(self)
                if self._callback then self._callback(self._value) end
            end

            function el:Get() return self._value end

            function el:_step(mx, my, m1down, m1click, m1release)
                if not self._bg.Visible then return end
                local tp = self._track.Position
                local ts = self._track.Size
                if mouseInRect(mx,my,self._bg.Position.X,self._bg.Position.Y,
                               self._bg.Size.X,self._bg.Size.Y) and m1click then
                    self._dragging = true
                end
                if self._dragging and m1down then
                    local pct = clamp((mx - tp.X) / ts.X, 0, 1)
                    local newVal = math.floor(self._min + pct*(self._max - self._min))
                    if newVal ~= self._value then
                        self._value = newVal
                        updateFill(self)
                        if self._callback then self._callback(self._value) end
                    end
                end
                if m1release then self._dragging = false end
            end

            self._innerH = self._innerH + H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == DROPDOWN ========================================================
        function grp:AddDropdown(label2, options, default, callback)
            local ey  = self:_getNextElemY()
            local ex  = self._gx + PADDING
            local ew  = self._gw - PADDING*2
            local vis = self._cat._active

            local el = {}
            el._type     = "dropdown"
            el._options  = options or {}
            el._value    = default or (options and options[1]) or ""
            el._callback = callback
            el._open     = false
            el._tooltip  = nil
            el._drawings = {}

            el._bg    = newSquare(ex, ey, ew, ELEM_H, T.input_bg, true, 18, 0, 2)
            el._lbl   = newText(ex+4, ey+4, label2, FONT_SIZE, T.subtext, 19, true)
            el._val   = newText(ex+4+#label2*7+6, ey+4, tostring(el._value), FONT_SIZE, T.text, 19, true)
            el._arrow = newText(ex+ew-12, ey+4, "v", FONT_SIZE, T.subtext, 19, false)
            el._border= newSquare(ex, ey, ew, ELEM_H, T.border, false, 19, 0, 2)

            el._bg.Visible    = vis
            el._lbl.Visible   = vis
            el._val.Visible   = vis
            el._arrow.Visible = vis
            el._border.Visible= vis

            function el:_closeMenu()
                for _,d in ipairs(self._drawings) do pcall(function() d:Remove() end) end
                self._drawings = {}
                self._open = false
                if _state.active_dropdown == self then _state.active_dropdown = nil end
            end

            function el:_openMenu(mx2, my2)
                self:_closeMenu()
                self._open = true
                _state.active_dropdown = self
                local ox = self._bg.Position.X
                local oy = self._bg.Position.Y + ELEM_H
                local ow = self._bg.Size.X
                local oh = math.min(#self._options, 6) * ELEM_H + 2
                local menubg = newSquare(ox, oy, ow, oh, T.group, true, 30, 0, 2)
                local menubrd= newSquare(ox, oy, ow, oh, T.border, false, 31, 0, 2)
                self._drawings[1] = menubg
                self._drawings[2] = menubrd
                for i, opt in ipairs(self._options) do
                    if i <= 6 then
                        local ity = oy + (i-1)*ELEM_H + 1
                        local ibg = newSquare(ox+1, ity, ow-2, ELEM_H-1, T.group, true, 31, 0)
                        local itx = newText(ox+6, ity+4, tostring(opt), FONT_SIZE, T.text, 32, true)
                        self._drawings[#self._drawings+1] = ibg
                        self._drawings[#self._drawings+1] = itx
                        ibg._opt    = opt
                        ibg._itx    = itx
                        ibg._owner  = self
                    end
                end
            end

            function el:_setVisible(v)
                self._bg.Visible    = v
                self._lbl.Visible   = v
                self._val.Visible   = v
                self._arrow.Visible = v
                self._border.Visible= v
                if not v then self:_closeMenu() end
            end

            function el:_rebuildLayout(dx, dy)
                local d = Vector2.new(dx,dy)
                self._bg.Position    = self._bg.Position    + d
                self._lbl.Position   = self._lbl.Position   + d
                self._val.Position   = self._val.Position   + d
                self._arrow.Position = self._arrow.Position + d
                self._border.Position= self._border.Position+ d
            end

            function el:Set(v)
                self._value = v
                self._val.Text = tostring(v)
                if self._callback then self._callback(v) end
            end

            function el:Get() return self._value end

            function el:_step(mx, my, m1click)
                if not self._bg.Visible then return end
                local p = self._bg.Position
                local s = self._bg.Size
                local hover = mouseInRect(mx,my,p.X,p.Y,s.X,s.Y)
                self._bg.Color = hover and T.group or T.input_bg

                if hover and m1click then
                    if self._open then self:_closeMenu()
                    else self:_openMenu(mx,my) end
                end

                -- Step dropdown items
                if self._open then
                    for i = 3, #self._drawings, 2 do
                        local ibg = self._drawings[i]
                        local itx = self._drawings[i+1]
                        if ibg and ibg._opt then
                            local ip = ibg.Position
                            local is_ = ibg.Size
                            local ihov = mouseInRect(mx,my,ip.X,ip.Y,is_.X,is_.Y)
                            ibg.Color = ihov and T.accent or T.group
                            if itx then itx.Color = ihov and T.text or T.subtext end
                            if ihov and m1click then
                                self:Set(ibg._opt)
                                self:_closeMenu()
                            end
                        end
                    end
                end
            end

            self._innerH = self._innerH + ELEM_H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == TEXT INPUT ======================================================
        function grp:AddTextInput(label2, placeholder, callback)
            local ey  = self:_getNextElemY()
            local ex  = self._gx + PADDING
            local ew  = self._gw - PADDING*2
            local vis = self._cat._active

            local el = {}
            el._type        = "textinput"
            el._value       = ""
            el._placeholder = placeholder or "Type here..."
            el._callback    = callback
            el._focused     = false
            el._tooltip     = nil

            el._bg    = newSquare(ex, ey, ew, ELEM_H, T.input_bg, true, 18, 0, 2)
            el._lbl   = newText(ex+4, ey+4, label2, FONT_SIZE, T.subtext, 19, true)
            el._txt   = newText(ex+#label2*7+10, ey+4, placeholder or "", FONT_SIZE, T.subtext, 19, true)
            el._cur   = newSquare(ex+#label2*7+10, ey+4, 1, FONT_SIZE, T.text, true, 20, 0)
            el._border= newSquare(ex, ey, ew, ELEM_H, T.border, false, 19, 0, 2)
            el._cur.Visible = false

            el._bg.Visible    = vis
            el._lbl.Visible   = vis
            el._txt.Visible   = vis
            el._border.Visible= vis

            function el:_setVisible(v)
                self._bg.Visible    = v
                self._lbl.Visible   = v
                self._txt.Visible   = v
                self._border.Visible= v
                self._cur.Visible   = false
                if not v and self._focused then
                    self._focused = false
                    if _state.active_textinput == self then _state.active_textinput = nil end
                end
            end

            function el:_rebuildLayout(dx, dy)
                local d = Vector2.new(dx,dy)
                self._bg.Position    = self._bg.Position    + d
                self._lbl.Position   = self._lbl.Position   + d
                self._txt.Position   = self._txt.Position   + d
                self._cur.Position   = self._cur.Position   + d
                self._border.Position= self._border.Position+ d
            end

            function el:Set(v)
                self._value = v
                self._txt.Text  = #v > 0 and v or self._placeholder
                self._txt.Color = #v > 0 and T.text or T.subtext
                if self._callback then self._callback(v) end
            end

            function el:Get() return self._value end

            function el:_updateDisplay()
                local disp = self._value
                -- truncate to fit
                local maxChars = math.floor((self._bg.Size.X - #self._lbl.Text*7 - 20) / 7)
                if #disp > maxChars then disp = "..." .. disp:sub(-maxChars+3) end
                self._txt.Text  = #self._value > 0 and disp or self._placeholder
                self._txt.Color = #self._value > 0 and T.text or T.subtext
                -- cursor
                local cx = self._txt.Position.X + #(#self._value > 0 and disp or "")*7
                self._cur.Position = Vector2.new(cx, self._cur.Position.Y)
            end

            function el:_step(mx, my, m1click)
                if not self._bg.Visible then return end
                local p = self._bg.Position
                local s = self._bg.Size
                local hover = mouseInRect(mx,my,p.X,p.Y,s.X,s.Y)
                self._bg.Color     = (hover or self._focused) and T.group or T.input_bg
                self._border.Color = self._focused and T.accent or T.border

                if m1click then
                    if hover then
                        self._focused = true
                        _state.active_textinput = self
                        self._cur.Visible = true
                    else
                        self._focused = false
                        self._cur.Visible = false
                        if _state.active_textinput == self then _state.active_textinput = nil end
                    end
                end
            end

            self._innerH = self._innerH + ELEM_H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == SEARCH BAR ======================================================
        function grp:AddSearchBar(label2, items, callback)
            local ey  = self:_getNextElemY()
            local ex  = self._gx + PADDING
            local ew  = self._gw - PADDING*2
            local vis = self._cat._active
            local TOTAL_H = ELEM_H + 4

            local el = {}
            el._type     = "searchbar"
            el._value    = ""
            el._items    = items or {}
            el._results  = {}
            el._callback = callback
            el._focused  = false
            el._drawings = {}
            el._tooltip  = nil

            el._bg     = newSquare(ex, ey, ew, ELEM_H, T.input_bg, true, 18, 0, 2)
            el._icon   = newText(ex+4, ey+4, "[S]", FONT_SIZE, T.subtext, 19, false)
            el._txt    = newText(ex+28, ey+4, label2, FONT_SIZE, T.subtext, 19, true)
            el._border = newSquare(ex, ey, ew, ELEM_H, T.border, false, 19, 0, 2)

            el._bg.Visible    = vis
            el._icon.Visible  = vis
            el._txt.Visible   = vis
            el._border.Visible= vis

            function el:_closeResults()
                for _,d in ipairs(self._drawings) do pcall(function() d:Remove() end) end
                self._drawings = {}
            end

            function el:_openResults()
                self:_closeResults()
                local ox = self._bg.Position.X
                local oy = self._bg.Position.Y + ELEM_H
                local ow = self._bg.Size.X
                local filtered = {}
                for _,item in ipairs(self._items) do
                    local s2 = tostring(item):lower()
                    if self._value == "" or s2:find(self._value:lower(), 1, true) then
                        filtered[#filtered+1] = item
                    end
                end
                self._results = filtered
                if #filtered == 0 then return end
                local oh = math.min(#filtered, 5) * ELEM_H
                local mbg = newSquare(ox, oy, ow, oh, T.group, true, 30, 0, 2)
                local mbrd= newSquare(ox, oy, ow, oh, T.border, false, 31, 0, 2)
                self._drawings[1] = mbg
                self._drawings[2] = mbrd
                for i, item in ipairs(filtered) do
                    if i <= 5 then
                        local ity = oy + (i-1)*ELEM_H
                        local ibg = newSquare(ox+1, ity, ow-2, ELEM_H, T.group, true, 31, 0)
                        local itx = newText(ox+6, ity+4, tostring(item), FONT_SIZE, T.text, 32, true)
                        ibg._item = item
                        ibg._itx  = itx
                        self._drawings[#self._drawings+1] = ibg
                        self._drawings[#self._drawings+1] = itx
                    end
                end
            end

            function el:_setVisible(v)
                self._bg.Visible    = v
                self._icon.Visible  = v
                self._txt.Visible   = v
                self._border.Visible= v
                if not v then self:_closeResults() end
            end

            function el:_rebuildLayout(dx, dy)
                local d = Vector2.new(dx,dy)
                self._bg.Position    = self._bg.Position    + d
                self._icon.Position  = self._icon.Position  + d
                self._txt.Position   = self._txt.Position   + d
                self._border.Position= self._border.Position+ d
            end

            function el:Get() return self._value end

            function el:_step(mx, my, m1click)
                if not self._bg.Visible then return end
                local p = self._bg.Position
                local s = self._bg.Size
                local hover = mouseInRect(mx,my,p.X,p.Y,s.X,s.Y)
                self._bg.Color     = (hover or self._focused) and T.group or T.input_bg
                self._border.Color = self._focused and T.accent or T.border

                if m1click then
                    if hover then
                        self._focused = true
                        _state.active_textinput = self
                        self:_openResults()
                    else
                        -- check result items
                        local clicked = false
                        for i = 3, #self._drawings, 2 do
                            local ibg = self._drawings[i]
                            if ibg and ibg._item then
                                local ip = ibg.Position
                                local is_ = ibg.Size
                                if mouseInRect(mx,my,ip.X,ip.Y,is_.X,is_.Y) then
                                    self._value = tostring(ibg._item)
                                    self._txt.Text  = self._value
                                    self._txt.Color = T.text
                                    if self._callback then self._callback(ibg._item) end
                                    clicked = true
                                    break
                                end
                            end
                        end
                        if not clicked then
                            self._focused = false
                            if _state.active_textinput == self then _state.active_textinput = nil end
                        end
                        self:_closeResults()
                    end
                end

                -- update search on typing
                if self._focused and _state.active_textinput == self then
                    -- text is handled by global input step
                    if self._value ~= self._txt.Text then
                        self._txt.Text  = self._value
                        self._txt.Color = #self._value > 0 and T.text or T.subtext
                        self:_openResults()
                    end
                end
            end

            self._innerH = self._innerH + ELEM_H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == COLOR PICKER ====================================================
        function grp:AddColorPicker(label2, default, callback)
            local ey  = self:_getNextElemY()
            local ex  = self._gx + PADDING
            local ew  = self._gw - PADDING*2
            local vis = self._cat._active

            local el = {}
            el._type     = "colorpicker"
            el._value    = default or Color3.fromRGB(255,255,255)
            el._callback = callback
            el._open     = false
            el._drawings = {}
            el._tooltip  = nil
            -- HSV state
            local r,g,b = el._value.R, el._value.G, el._value.B

            local function toHSV(col)
                local rv,gv,bv = col.R, col.G, col.B
                local max = math.max(rv,gv,bv)
                local min = math.min(rv,gv,bv)
                local h,s,v2 = 0,0,max
                local d = max-min
                if max~=0 then s=d/max end
                if d~=0 then
                    if max==rv then h=(gv-bv)/d+(gv<bv and 6 or 0)
                    elseif max==gv then h=(bv-rv)/d+2
                    else h=(rv-gv)/d+4 end
                    h=h/6
                end
                return h,s,v2
            end

            local ih,is_,iv = toHSV(el._value)
            el._h = ih; el._s = is_; el._v = iv

            el._bg      = newSquare(ex, ey, ew, ELEM_H, T.input_bg, true, 18, 0, 2)
            el._lbl     = newText(ex+4, ey+4, label2, FONT_SIZE, T.subtext, 19, true)
            el._swatch  = newSquare(ex+ew-22, ey+3, 18, 16, el._value, true, 19, 0, 2)
            el._swbrd   = newSquare(ex+ew-22, ey+3, 18, 16, T.border, false, 20, 0, 2)
            el._border  = newSquare(ex, ey, ew, ELEM_H, T.border, false, 19, 0, 2)

            el._bg.Visible     = vis
            el._lbl.Visible    = vis
            el._swatch.Visible = vis
            el._swbrd.Visible  = vis
            el._border.Visible = vis

            function el:_applyColor()
                self._value = Color3.fromHSV(self._h, self._s, self._v)
                self._swatch.Color = self._value
                if self._callback then self._callback(self._value) end
            end

            function el:_closePanel()
                for _,d in ipairs(self._drawings) do pcall(function() d:Remove() end) end
                self._drawings = {}
                self._open = false
                if _state.active_colorpick == self then _state.active_colorpick = nil end
            end

            function el:_openPanel()
                self:_closePanel()
                self._open = true
                _state.active_colorpick = self
                local ox = self._bg.Position.X
                local oy = self._bg.Position.Y + ELEM_H + 2
                local PW = self._bg.Size.X
                local PH = 90

                -- Panel bg
                local pbg = newSquare(ox, oy, PW, PH, T.group, true, 28, 0, 2)
                local pbrd= newSquare(ox, oy, PW, PH, T.border, false, 29, 0, 2)
                self._drawings[1] = pbg
                self._drawings[2] = pbrd

                -- Hue bar (horizontal gradient via multiple squares)
                local HUE_Y = oy + 6
                local HUE_W = PW - 12
                local HUE_H = 10
                local HUE_X = ox + 6
                local HUE_STEPS = 12
                for i = 0, HUE_STEPS-1 do
                    local hw = HUE_W / HUE_STEPS
                    local hc = Color3.fromHSV(i/HUE_STEPS, 1, 1)
                    local hbar = newSquare(HUE_X + i*hw, HUE_Y, hw+1, HUE_H, hc, true, 30, 0)
                    self._drawings[#self._drawings+1] = hbar
                end
                -- Hue cursor
                local hcur = newSquare(HUE_X + self._h*HUE_W - 2, HUE_Y-1, 4, HUE_H+2, T.text, false, 31, 0)
                self._drawings[#self._drawings+1] = hcur
                self._hue_cursor = hcur
                self._hue_x = HUE_X; self._hue_w = HUE_W; self._hue_y = HUE_Y; self._hue_h = HUE_H

                -- Saturation bar
                local SAT_Y = HUE_Y + HUE_H + 6
                local satbg = newSquare(ox+6, SAT_Y, HUE_W, HUE_H, T.border, true, 30, 0)
                local satfg = newSquare(ox+6, SAT_Y, HUE_W, HUE_H, Color3.fromHSV(self._h,1,self._v), true, 30, 0.5)
                local scur  = newSquare(ox+6 + self._s*HUE_W-2, SAT_Y-1, 4, HUE_H+2, T.text, false, 31, 0)
                self._drawings[#self._drawings+1] = satbg
                self._drawings[#self._drawings+1] = satfg
                self._drawings[#self._drawings+1] = scur
                self._sat_bg = satbg; self._sat_cur = scur
                self._sat_x = ox+6; self._sat_w = HUE_W; self._sat_y = SAT_Y

                -- Value bar
                local VAL_Y = SAT_Y + HUE_H + 6
                local valbg = newSquare(ox+6, VAL_Y, HUE_W, HUE_H, T.border, true, 30, 0)
                local valfg = newSquare(ox+6, VAL_Y, HUE_W, HUE_H, Color3.fromHSV(self._h,self._s,1), true, 30, 0.5)
                local vcur  = newSquare(ox+6 + self._v*HUE_W-2, VAL_Y-1, 4, HUE_H+2, T.text, false, 31, 0)
                self._drawings[#self._drawings+1] = valbg
                self._drawings[#self._drawings+1] = valfg
                self._drawings[#self._drawings+1] = vcur
                self._val_bg = valbg; self._val_cur = vcur
                self._val_x = ox+6; self._val_w = HUE_W; self._val_y = VAL_Y

                -- Preview swatch
                local prev = newSquare(ox+6, VAL_Y+HUE_H+6, HUE_W, 16, self._value, true, 30, 0, 2)
                self._drawings[#self._drawings+1] = prev
                self._preview = prev

                -- Hex label
                local function hexStr(c)
                    local function b(v2) return string.format("%02X", math.floor(v2*255)) end
                    return "#"..b(c.R)..b(c.G)..b(c.B)
                end
                local hext = newText(ox+6, VAL_Y+HUE_H+22, hexStr(self._value), 12, T.subtext, 31, false)
                self._drawings[#self._drawings+1] = hext
                self._hex_text = hext
                self._hexStr = hexStr

                self._drag_hue = false; self._drag_sat = false; self._drag_val = false
            end

            function el:_setVisible(v)
                self._bg.Visible    = v
                self._lbl.Visible   = v
                self._swatch.Visible= v
                self._swbrd.Visible = v
                self._border.Visible= v
                if not v then self:_closePanel() end
            end

            function el:_rebuildLayout(dx, dy)
                local d = Vector2.new(dx,dy)
                self._bg.Position     = self._bg.Position     + d
                self._lbl.Position    = self._lbl.Position    + d
                self._swatch.Position = self._swatch.Position + d
                self._swbrd.Position  = self._swbrd.Position  + d
                self._border.Position = self._border.Position + d
            end

            function el:Set(c)
                self._value = c
                local hh,hs,hv = toHSV(c)
                self._h = hh; self._s = hs; self._v = hv
                self._swatch.Color = c
                if self._callback then self._callback(c) end
            end

            function el:Get() return self._value end

            function el:_step(mx, my, m1down, m1click, m1release)
                if not self._bg.Visible then return end
                local p = self._bg.Position
                local s = self._bg.Size

                if mouseInRect(mx,my,p.X,p.Y,s.X,s.Y) and m1click then
                    if self._open then self:_closePanel()
                    else self:_openPanel() end
                end

                if self._open then
                    -- Hue drag
                    if mouseInRect(mx,my,self._hue_x, self._hue_y, self._hue_w, self._hue_h) and m1click then
                        self._drag_hue = true
                    end
                    if self._drag_hue and m1down then
                        self._h = clamp((mx - self._hue_x)/self._hue_w, 0, 1)
                        self._hue_cursor.Position = Vector2.new(self._hue_x + self._h*self._hue_w - 2, self._hue_y - 1)
                        self:_applyColor()
                        if self._preview then self._preview.Color = self._value end
                        if self._hex_text then self._hex_text.Text = self._hexStr(self._value) end
                    end
                    if m1release then self._drag_hue = false end

                    -- Sat drag
                    if mouseInRect(mx,my,self._sat_x, self._sat_y, self._sat_w, 10) and m1click then
                        self._drag_sat = true
                    end
                    if self._drag_sat and m1down then
                        self._s = clamp((mx - self._sat_x)/self._sat_w, 0, 1)
                        self._sat_cur.Position = Vector2.new(self._sat_x + self._s*self._sat_w - 2, self._sat_y - 1)
                        self:_applyColor()
                        if self._preview then self._preview.Color = self._value end
                        if self._hex_text then self._hex_text.Text = self._hexStr(self._value) end
                    end
                    if m1release then self._drag_sat = false end

                    -- Val drag
                    if mouseInRect(mx,my,self._val_x, self._val_y, self._val_w, 10) and m1click then
                        self._drag_val = true
                    end
                    if self._drag_val and m1down then
                        self._v = clamp((mx - self._val_x)/self._val_w, 0, 1)
                        self._val_cur.Position = Vector2.new(self._val_x + self._v*self._val_w - 2, self._val_y - 1)
                        self:_applyColor()
                        if self._preview then self._preview.Color = self._value end
                        if self._hex_text then self._hex_text.Text = self._hexStr(self._value) end
                    end
                    if m1release then self._drag_val = false end
                end
            end

            self._innerH = self._innerH + ELEM_H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == KEYBIND =========================================================
        function grp:AddKeybind(label2, default, callback)
            local ey  = self:_getNextElemY()
            local ex  = self._gx + PADDING
            local ew  = self._gw - PADDING*2
            local vis = self._cat._active

            local el = {}
            el._type     = "keybind"
            el._value    = default  -- VK code or nil
            el._callback = callback
            el._listening= false
            el._tooltip  = nil

            el._bg     = newSquare(ex, ey, ew, ELEM_H, T.input_bg, true, 18, 0, 2)
            el._lbl    = newText(ex+4, ey+4, label2, FONT_SIZE, T.subtext, 19, true)
            el._key    = newText(ex+ew-60, ey+4, el._value and ("["..(VK_NAMES[el._value] or "?").."]") or "[None]", FONT_SIZE, T.text, 19, true)
            el._border = newSquare(ex, ey, ew, ELEM_H, T.border, false, 19, 0, 2)

            el._bg.Visible    = vis
            el._lbl.Visible   = vis
            el._key.Visible   = vis
            el._border.Visible= vis

            function el:_setVisible(v)
                self._bg.Visible    = v
                self._lbl.Visible   = v
                self._key.Visible   = v
                self._border.Visible= v
            end

            function el:_rebuildLayout(dx, dy)
                local d = Vector2.new(dx,dy)
                self._bg.Position    = self._bg.Position    + d
                self._lbl.Position   = self._lbl.Position   + d
                self._key.Position   = self._key.Position   + d
                self._border.Position= self._border.Position+ d
            end

            function el:Set(vk)
                self._value = vk
                self._key.Text = vk and ("["..(VK_NAMES[vk] or "?").."]") or "[None]"
                self._listening = false
                self._border.Color = T.border
                if _state.active_keybind == self then _state.active_keybind = nil end
                if self._callback then self._callback(vk) end
            end

            function el:Get() return self._value end

            function el:_step(mx, my, m1click)
                if not self._bg.Visible then return end
                local p = self._bg.Position
                local s = self._bg.Size
                local hover = mouseInRect(mx,my,p.X,p.Y,s.X,s.Y)

                if hover and m1click then
                    self._listening = true
                    _state.active_keybind = self
                    self._key.Text = "[...]"
                    self._border.Color = T.accent
                end

                if self._listening then
                    -- Scan all VKs for first press
                    for _,vk in ipairs(ALL_VK) do
                        if vk ~= 0x01 then  -- skip left click itself
                            if iskeypressed and iskeypressed(vk) then
                                self:Set(vk)
                                break
                            end
                        end
                    end
                    -- Escape = unbind
                    if iskeypressed and iskeypressed(0x1B) then
                        self:Set(nil)
                    end
                end
            end

            self._innerH = self._innerH + ELEM_H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == VALUE LABEL =====================================================
        function grp:AddValueLabel(label2, value)
            local ey  = self:_getNextElemY()
            local ex  = self._gx + PADDING
            local ew  = self._gw - PADDING*2
            local vis = self._cat._active

            local el = {}
            el._type    = "valuelabel"
            el._tooltip = nil

            el._bg   = newSquare(ex, ey, ew, ELEM_H, T.input_bg, true, 18, 0, 2)
            el._lbl  = newText(ex+4, ey+4, label2..":", FONT_SIZE, T.subtext, 19, true)
            el._val  = newText(ex+ew-6, ey+4, tostring(value), FONT_SIZE, T.accent, 19, false)
            el._val.Position = Vector2.new(ex+ew - #tostring(value)*7 - 6, ey+4)

            el._bg.Visible  = vis
            el._lbl.Visible = vis
            el._val.Visible = vis

            function el:_setVisible(v)
                self._bg.Visible  = v
                self._lbl.Visible = v
                self._val.Visible = v
            end

            function el:_rebuildLayout(dx, dy)
                local d = Vector2.new(dx,dy)
                self._bg.Position  = self._bg.Position  + d
                self._lbl.Position = self._lbl.Position + d
                self._val.Position = self._val.Position + d
            end

            function el:Set(v)
                self._val.Text = tostring(v)
                self._val.Position = Vector2.new(
                    self._bg.Position.X + self._bg.Size.X - #tostring(v)*7 - 6,
                    self._val.Position.Y)
            end

            function el:Get() return self._val.Text end

            function el:_step() end  -- no interaction

            self._innerH = self._innerH + ELEM_H + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == SCROLL FRAME ====================================================
        function grp:AddScrollFrame(frameHeight, items)
            local ey  = self:_getNextElemY()
            local ex  = self._gx + PADDING
            local ew  = self._gw - PADDING*2
            local vis = self._cat._active
            local FH  = frameHeight or 60

            local el = {}
            el._type     = "scrollframe"
            el._items    = items or {}
            el._scroll   = 0
            el._drawings = {}
            el._tooltip  = nil

            el._bg     = newSquare(ex, ey, ew, FH, T.input_bg, true, 18, 0, 2)
            el._border = newSquare(ex, ey, ew, FH, T.border, false, 19, 0, 2)

            el._bg.Visible    = vis
            el._border.Visible= vis

            -- Item drawings
            local ITEM_H = ELEM_H
            local function buildItems(self2)
                for _,d in ipairs(self2._drawings) do pcall(function() d:Remove() end) end
                self2._drawings = {}
                local maxVisible = math.floor(FH / ITEM_H)
                local startI = self2._scroll + 1
                for i = 0, maxVisible-1 do
                    local idx2 = startI + i
                    if idx2 <= #self2._items then
                        local ity = ey + i*ITEM_H + 1
                        local itbg = newSquare(ex+1, ity, ew-2, ITEM_H-1, (i%2==0) and T.input_bg or T.group, true, 19, 0)
                        local ittx = newText(ex+6, ity+4, tostring(self2._items[idx2]), FONT_SIZE, T.text, 20, true)
                        itbg.Visible = vis
                        ittx.Visible = vis
                        self2._drawings[#self2._drawings+1] = itbg
                        self2._drawings[#self2._drawings+1] = ittx
                    end
                end
                -- Scrollbar
                if #self2._items > maxVisible then
                    local sbH = FH * maxVisible / #self2._items
                    local sbY = ey + (self2._scroll / #self2._items) * FH
                    local sb = newSquare(ex+ew-4, sbY, 3, sbH, T.border, true, 20, 0, 2)
                    sb.Visible = vis
                    self2._drawings[#self2._drawings+1] = sb
                    self2._scrollbar = sb
                end
            end
            buildItems(el)

            function el:_setVisible(v)
                self._bg.Visible    = v
                self._border.Visible= v
                for _,d in ipairs(self._drawings) do d.Visible = v end
            end

            function el:_rebuildLayout(dx, dy)
                local d = Vector2.new(dx,dy)
                self._bg.Position    = self._bg.Position    + d
                self._border.Position= self._border.Position+ d
                for _,dr in ipairs(self._drawings) do
                    dr.Position = dr.Position + d
                end
            end

            function el:_step(mx, my, m1click)
                if not self._bg.Visible then return end
                local p = self._bg.Position
                local s = self._bg.Size
                -- mouse wheel scroll simulation via up/down keys
                if mouseInRect(mx,my,p.X,p.Y,s.X,s.Y) then
                    if keyJustPressed(0x26) then  -- UP arrow
                        self._scroll = math.max(0, self._scroll-1)
                        buildItems(self)
                    elseif keyJustPressed(0x28) then  -- DOWN arrow
                        self._scroll = math.min(math.max(0, #self._items - math.floor(FH/ELEM_H)), self._scroll+1)
                        buildItems(self)
                    end
                end
            end

            self._innerH = self._innerH + FH + PADDING
            self:_updateBody()
            self._elements[#self._elements+1] = el
            return el
        end

        -- == TOOLTIP =========================================================
        function grp:AddTooltip(targetElement, text)
            if targetElement then
                targetElement._tooltip_text = text
                targetElement._has_tooltip  = true
            end
        end

        self._groups[#self._groups+1] = grp
        return grp
    end

    self._categories[#self._categories+1] = cat
    return cat
end

-- ==============================================================================
-- TOOLTIP OVERLAY (global, reused single instance)
-- ==============================================================================

local _tooltip_bg   = newSquare(0,0,100,ELEM_H, T.group, true, 50, 0, 2)
local _tooltip_brd  = newSquare(0,0,100,ELEM_H, T.accent, false, 51, 0, 2)
local _tooltip_txt  = newText(0,0,"", FONT_SIZE, T.text, 52, true)
_tooltip_bg.Visible  = false
_tooltip_brd.Visible = false
_tooltip_txt.Visible = false

local function showTooltip(mx, my, text)
    local tw = #text * 7 + 10
    _tooltip_bg.Position  = Vector2.new(mx+12, my-20)
    _tooltip_bg.Size      = Vector2.new(tw, ELEM_H)
    _tooltip_brd.Position = Vector2.new(mx+12, my-20)
    _tooltip_brd.Size     = Vector2.new(tw, ELEM_H)
    _tooltip_txt.Position = Vector2.new(mx+16, my-16)
    _tooltip_txt.Text     = text
    _tooltip_bg.Visible   = true
    _tooltip_brd.Visible  = true
    _tooltip_txt.Visible  = true
end

local function hideTooltip()
    _tooltip_bg.Visible  = false
    _tooltip_brd.Visible = false
    _tooltip_txt.Visible = false
end

-- ==============================================================================
-- NOTIFICATION SYSTEM
-- ==============================================================================

local function stepNotifications(mx, my, m1click)
    local screenW = 1920
    local ok, cam = pcall(function() return workspace.CurrentCamera end)
    if ok and cam and cam.ViewportSize then screenW = cam.ViewportSize.X end

    local nx = screenW - NOTIF_W - 10
    local baseY = 10

    local toRemove = {}
    for i, n in ipairs(_state.notifications) do
        local elapsed = os.clock() - n.startTime
        if elapsed >= n.duration then
            toRemove[#toRemove+1] = i
        else
            -- Stack from top
            local ny = baseY + (i-1)*(NOTIF_H + NOTIF_PAD)
            if n._bg then
                n._bg.Position    = Vector2.new(nx, ny)
                n._title.Position = Vector2.new(nx+8, ny+6)
                n._body.Position  = Vector2.new(nx+8, ny+18)
                n._bar.Position   = Vector2.new(nx, ny+NOTIF_H-3)
                local remaining = 1 - elapsed/n.duration
                n._bar.Size = Vector2.new(math.max(1, NOTIF_W * remaining), 3)
                -- Close button
                n._close.Position = Vector2.new(nx+NOTIF_W-16, ny+4)
                if m1click and mouseInRect(mx,my, nx+NOTIF_W-16, ny+4, 12, 12) then
                    toRemove[#toRemove+1] = i
                end
            end
        end
    end
    -- Remove expired (reverse order)
    for i = #toRemove, 1, -1 do
        local n = _state.notifications[toRemove[i]]
        if n then
            pcall(function() n._bg:Remove() end)
            pcall(function() n._title:Remove() end)
            pcall(function() n._body:Remove() end)
            pcall(function() n._bar:Remove() end)
            pcall(function() n._close:Remove() end)
            pcall(function() n._border:Remove() end)
        end
        table.remove(_state.notifications, toRemove[i])
    end
end

-- ==============================================================================
-- PUBLIC API
-- ==============================================================================

function MatchaUI:Init()
    return self
end

function MatchaUI:CreateWindow(title, x, y, w, h)
    local win = setmetatable({}, Window)
    win.title        = title or "MatchaUI"
    win.x            = x or 100
    win.y            = y or 100
    win.w            = w or 420
    win.h            = h or 460
    win._categories  = {}
    win._visible     = true
    win._minimized   = false

    win:_build()
    _state.windows[#_state.windows+1] = win
    return win
end

function MatchaUI:Notify(title, body, duration)
    local screenW = 1920
    local ok, cam = pcall(function() return workspace.CurrentCamera end)
    if ok and cam and cam.ViewportSize then screenW = cam.ViewportSize.X end

    local nx = screenW - NOTIF_W - 10
    local idx = #_state.notifications
    local ny = 10 + idx*(NOTIF_H+NOTIF_PAD)

    local n = {}
    n.startTime = os.clock()
    n.duration  = duration or 5

    n._bg     = newSquare(nx, ny, NOTIF_W, NOTIF_H, T.group, true, 60, 0, 2)
    n._border = newSquare(nx, ny, NOTIF_W, NOTIF_H, T.accent, false, 61, 0, 2)
    n._title  = newText(nx+8, ny+6, tostring(title), FONT_SIZE, T.accent, 62, true)
    n._body   = newText(nx+8, ny+18, tostring(body), 12, T.text, 62, false)
    n._bar    = newSquare(nx, ny+NOTIF_H-3, NOTIF_W, 3, T.accent, true, 62, 0, 2)
    n._close  = newText(nx+NOTIF_W-14, ny+4, "x", 12, T.danger, 63, false)

    _state.notifications[#_state.notifications+1] = n
end

function MatchaUI:Step()
    local mx, my = getMousePos()
    local m1now  = ismouse1pressed and ismouse1pressed() or false
    local m1click  = m1now and not _state.m1_prev
    local m1release= not m1now and _state.m1_prev

    -- == TEXT INPUT GLOBAL KEY HANDLING ======================================
    if _state.active_textinput then
        local ti = _state.active_textinput
        local shift = (iskeypressed and iskeypressed(0xA0)) or (iskeypressed and iskeypressed(0xA1)) or false

        if keyJustPressed(0x08) then  -- Backspace
            ti._value = ti._value:sub(1, -2)
        elseif keyJustPressed(0x0D) then  -- Enter
            _state.active_textinput = nil
            if ti._focused ~= nil then ti._focused = false end
            if ti._cur then ti._cur.Visible = false end
        else
            for vk, ch in pairs(CHAR_KEYS) do
                if keyJustPressed(vk) then
                    local c = ch
                    if shift then
                        if c:match("%a") then c = c:upper()
                        elseif SHIFT_MAP[c] then c = SHIFT_MAP[c] end
                    end
                    ti._value = ti._value .. c
                    break
                end
            end
        end
        -- sync display
        if ti._updateDisplay then ti:_updateDisplay() end
    end

    -- == DRAG WINDOW =========================================================
    if _state.drag_window then
        if m1now then
            _state.drag_window.x = mx - _state.drag_ox
            _state.drag_window.y = my - _state.drag_oy
            _state.drag_window:_rebuildLayout()
        else
            _state.drag_window = nil
        end
    end

    -- == PER-WINDOW ==========================================================
    local tooltipElem = nil
    for _, win in ipairs(_state.windows) do
        if not win._visible then goto continue_win end

        -- Topbar drag initiation
        if m1click and not _state.drag_window then
            local tx = win.x
            local ty = win.y
            local tw = win.w - 48  -- exclude buttons area
            if mouseInRect(mx,my, tx, ty, tw, TOPBAR_H) then
                _state.drag_window = win
                _state.drag_ox = mx - win.x
                _state.drag_oy = my - win.y
            end
        end

        -- Minimize button
        if m1click and mouseInRect(mx,my, win.x+win.w-44, win.y+5, 18, 18) then
            win._minimized = not win._minimized
            win:_setContentVisible(not win._minimized)
        end

        -- Close button
        if m1click and mouseInRect(mx,my, win.x+win.w-23, win.y+5, 18, 18) then
            win:_setVisible(false)
        end

        if win._minimized then goto continue_win end

        -- Category tab clicks
        for _,cat in ipairs(win._categories) do
            local idx2 = cat._tab_idx
            local tx2 = win.x + 4
            local ty2 = win.y + TOPBAR_H + (idx2-1)*CAT_H + 4
            if m1click and mouseInRect(mx,my, tx2, ty2, LEFTBAR_W-8, CAT_H-4) then
                cat:_activate()
            end
            -- reposition tab drawings on drag
            cat._tab_bg.Position = Vector2.new(win.x+4, win.y+TOPBAR_H+(cat._tab_idx-1)*CAT_H+4)
            cat._tab_t.Position  = Vector2.new(win.x+10, win.y+TOPBAR_H+(cat._tab_idx-1)*CAT_H+9)
        end

        -- Step all elements in active category
        for _, cat in ipairs(win._categories) do
            if cat._active then
                for _, grp in ipairs(cat._groups) do
                    for _, el in ipairs(grp._elements) do
                        if el._step then
                            el:_step(mx, my, m1now, m1click, m1release)
                        end
                        -- Tooltip detection
                        if el._has_tooltip and el._bg then
                            local p = el._bg.Position
                            local s = el._bg.Size
                            if mouseInRect(mx,my,p.X,p.Y,s.X,s.Y) then
                                tooltipElem = el
                            end
                        end
                    end
                end
            end
        end

        ::continue_win::
    end

    -- == TOOLTIP =============================================================
    if tooltipElem then
        local moved = math.abs(mx - _state.mouse_prev_x) > 2 or math.abs(my - _state.mouse_prev_y) > 2
        if moved then
            _state.tooltip_timer = os.clock()
        end
        if os.clock() - _state.tooltip_timer > 0.6 then
            showTooltip(mx, my, tooltipElem._tooltip_text or "")
        else
            hideTooltip()
        end
    else
        _state.tooltip_timer = os.clock()
        hideTooltip()
    end

    -- == NOTIFICATIONS =======================================================
    stepNotifications(mx, my, m1click)

    -- Update state
    _state.m1_prev       = m1now
    _state.mouse_prev_x  = mx
    _state.mouse_prev_y  = my
end

function MatchaUI:Destroy()
    for _, d in ipairs(DrawPool) do
        pcall(function() d:Remove() end)
    end
    DrawPool = {}
    pcall(function() _tooltip_bg:Remove() end)
    pcall(function() _tooltip_brd:Remove() end)
    pcall(function() _tooltip_txt:Remove() end)
end

return MatchaUI
