-- @env: Matcha LuaVM
-- ============================================================
-- TweenService — v2.0.0
-- Property animation library for Matcha LuaVM.
-- Animates BasePart instances AND Drawing overlay objects by
-- interpolating arbitrary properties using multiple easing
-- styles and directions.
--
-- CHANGES FROM v1.0.1:
--   - _origin now captured at Play() time, not at Tween.new().
--     Re-playing a tween or playing after a delay now starts
--     from the correct current position.
--   - Duration from speed mode also recalculated at Play() for
--     the same reason.
--   - finalEased now uses the actual completed cycle count
--     (local `repeated`) instead of self.repeatCount, fixing
--     incorrect final position with reverse=true and infinite
--     repeat (-1).
--   - Pause busy-wait replaced with a slower poll (0.1s) that
--     does not starve the Matcha scheduler when many tweens
--     are paused simultaneously.
--   - Generalized property interpolation: accepts a `props`
--     table with multiple properties instead of only `position`.
--     Supports number, Vector3, Vector2, and Color3 per-property.
--     This makes TweenService usable for Drawing overlay objects
--     (fade, slide, color transitions) not just BaseParts.
--   - Legacy `position` config key still works as a convenience
--     alias for `props = { Position = value }`.
-- ============================================================

--[[
    MODULE: TweenService
    Exports: TweenService.new(target, config) -> Tween

    ==========================================================
    TweenService.new(target: any, config: table) -> Tween
    ==========================================================
        target  : any   — Object whose properties will be animated.
                          Can be a BasePart, Drawing object, or any
                          table/userdata with settable properties.

        config  : table — Fields:
            props         : table     — Map of { propertyName = targetValue }.
                                        Supported value types: number, Vector3,
                                        Vector2, Color3.
                                        Example: { Transparency = 0, Position = Vector2.new(50,50) }
            position      : Vector3   — Legacy alias. Equivalent to props = { Position = value }.
                                        Ignored if props is provided.
            duration      : number    — Duration in seconds. Default: 1.
            speed         : number    — Speed in studs/s (for Vector3 Position only).
                                        Overrides duration if > 0.
            style         : string    — Easing style. Default: "Sine".
                                        "Linear"|"Quad"|"Cubic"|"Sine"|"Bounce"|"Back"|"Elastic"|"Expo"
            direction     : string    — Easing direction. Default: "Out".
                                        "In"|"Out"|"InOut"
            repeat_       : number    — Extra repetitions. -1 = infinite. Default: 0.
            reverse       : boolean   — Even cycles play in reverse. Default: false.
            delay         : number    — Initial delay in seconds. Default: 0.
            freezePhysics : boolean   — Zero out Velocity during animation (BasePart only).
                                        Default: true when a Position prop is present.
            onComplete    : function  — Called when tween finishes (not on Stop/Cancel).
            onUpdate      : function  — Called every frame with (easedT: number).

    ==========================================================
    Tween API
    ==========================================================
        Tween:Play()        -> nil      Start. No-op if already playing.
        Tween:Stop()        -> nil      Stop without calling onComplete.
        Tween:Cancel()      -> nil      Alias for Stop().
        Tween:Pause()       -> nil      Pause, preserving progress.
        Tween:Resume()      -> nil      Resume from paused state.
        Tween:IsPlaying()   -> boolean  True if running and not paused.
        Tween:GetProgress() -> number   Normalized progress [0,1] of active cycle.
]]

-- ============================================================
-- Type interpolators
-- ============================================================

-- Each interpolator: (a, b, t) -> value
-- t is always in [0, 1] after easing is applied.

local Interpolators = {}

function Interpolators.number(a, b, t)
    return a + (b - a) * t
end

function Interpolators.Vector3(a, b, t)
    return Vector3.new(
        a.X + (b.X - a.X) * t,
        a.Y + (b.Y - a.Y) * t,
        a.Z + (b.Z - a.Z) * t
    )
end

function Interpolators.Vector2(a, b, t)
    return Vector2.new(
        a.X + (b.X - a.X) * t,
        a.Y + (b.Y - a.Y) * t
    )
end

function Interpolators.Color3(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

-- Resolves the correct interpolator for a given value.
-- Returns nil if the type is unsupported.
local function resolveInterpolator(value)
    -- type: (value: any) -> function | nil
    local t = type(value)
    if t == "number" then
        return Interpolators.number
    end
    -- Userdata types: check by constructor name via tostring heuristic
    -- or by checking known properties unique to each type.
    if t == "userdata" then
        if typeof then
            -- typeof is available in some Luau environments
            local tn = typeof(value)
            if Interpolators[tn] then
                return Interpolators[tn]
            end
        end
        -- Fallback: structural check for known types.
        if value.X ~= nil and value.Y ~= nil and value.Z ~= nil then
            return Interpolators.Vector3
        end
        if value.X ~= nil and value.Y ~= nil then
            return Interpolators.Vector2
        end
        if value.R ~= nil and value.G ~= nil and value.B ~= nil then
            return Interpolators.Color3
        end
    end
    return nil
end

-- ============================================================
-- Easing styles
-- ============================================================

local EasingStyles = {
    Linear = function(t) return t end,

    Quad   = function(t) return t * t end,

    Cubic  = function(t) return t * t * t end,

    Sine   = function(t) return 1 - math.cos(t * math.pi / 2) end,

    Bounce = function(t)
        if t < 1 / 2.75 then
            return 7.5625 * t * t
        elseif t < 2 / 2.75 then
            t = t - 1.5 / 2.75
            return 7.5625 * t * t + 0.75
        elseif t < 2.5 / 2.75 then
            t = t - 2.25 / 2.75
            return 7.5625 * t * t + 0.9375
        else
            t = t - 2.625 / 2.75
            return 7.5625 * t * t + 0.984375
        end
    end,

    Back = function(t)
        local s = 1.70158
        return t * t * ((s + 1) * t - s)
    end,

    Elastic = function(t)
        if t == 0 or t == 1 then return t end
        return -((2 ^ (10 * (t - 1))) * math.sin((t - 1.1) * 5 * math.pi))
    end,

    Expo = function(t)
        return t == 0 and 0 or (2 ^ (10 * (t - 1)))
    end,
}

-- ============================================================
-- Easing directions
-- ============================================================

local EasingDirections = {
    In    = function(s, t) return s(t) end,

    Out   = function(s, t) return 1 - s(1 - t) end,

    InOut = function(s, t)
        if t < 0.5 then
            return s(t * 2) / 2
        else
            return 1 - s((1 - t) * 2) / 2
        end
    end,
}

-- ============================================================
-- Internal validation
-- ============================================================

local function assertType(value, expected, field)
    if value ~= nil and type(value) ~= expected then
        error(
            ("TweenService: config.%s must be of type %s, got %s")
                :format(field, expected, type(value)),
            2
        )
    end
end

-- ============================================================
-- Property snapshot — captures current values of all animated
-- properties from the target. Called at Play() time.
-- ============================================================

local function snapshotOrigins(target, props)
    -- type: (target: any, props: { [string]: any }) -> { [string]: any }
    local origins = {}
    for propName in pairs(props) do
        local ok, val = pcall(function() return target[propName] end)
        if ok and val ~= nil then
            origins[propName] = val
        else
            warn(("TweenService: cannot read property '%s' from target — skipping."):format(propName))
        end
    end
    return origins
end

-- Applies all interpolated property values to the target for a given t.
local function applyProps(target, props, origins, interps, easedT)
    -- type: (target, props, origins, interps, easedT: number) -> void
    for propName, targetVal in pairs(props) do
        local origin = origins[propName]
        local interp = interps[propName]
        if origin ~= nil and interp ~= nil then
            local ok, err = pcall(function()
                target[propName] = interp(origin, targetVal, easedT)
            end)
            if not ok then
                warn(("TweenService: failed to set '%s': %s"):format(propName, tostring(err)))
            end
        end
    end
end

-- ============================================================
-- Tween class
-- ============================================================

local Tween = {}
Tween.__index = Tween

function Tween.new(target, config)
    assert(target ~= nil,              "TweenService: 'target' cannot be nil.")
    assert(type(config) == "table",    "TweenService: 'config' must be a table.")

    assertType(config.duration,      "number",   "duration")
    assertType(config.speed,         "number",   "speed")
    assertType(config.repeat_,       "number",   "repeat_")
    assertType(config.reverse,       "boolean",  "reverse")
    assertType(config.delay,         "number",   "delay")
    assertType(config.freezePhysics, "boolean",  "freezePhysics")
    assertType(config.onComplete,    "function", "onComplete")
    assertType(config.onUpdate,      "function", "onUpdate")
    assertType(config.style,         "string",   "style")
    assertType(config.direction,     "string",   "direction")

    -- Resolve props table: new multi-prop API or legacy position alias.
    local props
    if type(config.props) == "table" then
        props = config.props
    elseif config.position ~= nil then
        props = { Position = config.position }
    else
        error("TweenService: config must include 'props' or 'position'.", 2)
    end

    -- Pre-resolve interpolators for each property at construction time.
    -- This validates types early and avoids repeated resolution per-frame.
    local interps = {}
    for propName, targetVal in pairs(props) do
        local interp = resolveInterpolator(targetVal)
        if interp == nil then
            error(
                ("TweenService: unsupported type for property '%s': %s")
                    :format(propName, type(targetVal)),
                2
            )
        end
        interps[propName] = interp
    end

    -- Determine if freezePhysics should apply.
    -- Only meaningful when animating Position on a BasePart.
    local hasPosition = (props.Position ~= nil)
    local freeze = hasPosition and (config.freezePhysics ~= false)
    if config.freezePhysics == true and not hasPosition then
        warn("TweenService: freezePhysics has no effect without a Position property.")
        freeze = false
    end

    -- Easing style resolution with fallback.
    local sName = config.style     or "Sine"
    local dName = config.direction or "Out"

    if not EasingStyles[sName] then
        warn(("TweenService: unknown style '%s', falling back to 'Sine'."):format(sName))
        sName = "Sine"
    end
    if not EasingDirections[dName] then
        warn(("TweenService: unknown direction '%s', falling back to 'Out'."):format(dName))
        dName = "Out"
    end

    local self = setmetatable({}, Tween)

    self._target       = target
    self._props        = props        -- { propName = targetValue }
    self._interps      = interps      -- { propName = interpolatorFn }
    self._origins      = {}           -- populated at Play() time

    self._repeatCount  = config.repeat_    or 0
    self._reverse      = config.reverse    or false
    self._delay        = config.delay      or 0
    self._onComplete   = config.onComplete or nil
    self._onUpdate     = config.onUpdate   or nil
    self._freeze       = freeze

    -- Speed mode: store raw speed, recalculate duration at Play().
    self._rawSpeed     = (config.speed and config.speed > 0) and config.speed or nil
    self._duration     = config.duration or 1

    self._style        = EasingStyles[sName]
    self._direction    = EasingDirections[dName]

    self._playing        = false
    self._cancelled      = false
    self._paused         = false
    self._progress       = 0
    self._velocityThread = nil

    return self
end

-- == Physics freeze (BasePart only) ============================

function Tween:_startVelocityReset()
    if not self._freeze then return end

    self._velocityThread = task.spawn(function()
        while self._playing and not self._cancelled do
            pcall(function()
                self._target.Velocity               = Vector3.new(0, 0, 0)
                self._target.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
            task.wait(0.05)
        end
    end)
end

function Tween:_stopVelocityReset()
    if self._velocityThread then
        pcall(task.cancel, self._velocityThread)
        self._velocityThread = nil
    end
end

-- == Public API ================================================

function Tween:Play()
    if self._playing then return end

    -- == Capture origins at Play() time, not at construction. ==
    -- This ensures re-playing a tween or playing after a delay
    -- always starts from the target's current actual state.
    self._origins = snapshotOrigins(self._target, self._props)

    -- == Recalculate speed-based duration at Play() time. ==
    -- If the target moved since construction, the distance (and
    -- thus duration) would be wrong if calculated earlier.
    if self._rawSpeed ~= nil then
        local originPos = self._origins["Position"]
        local targetPos = self._props["Position"]
        if originPos ~= nil and targetPos ~= nil then
            local dist = (originPos - targetPos).Magnitude
            self._duration = dist > 0 and (dist / self._rawSpeed) or 0
        else
            -- Speed mode without a Position prop: fall back to stored duration.
            warn("TweenService: speed mode requires a 'Position' property.")
        end
    end

    self._playing   = true
    self._cancelled = false
    self._paused    = false
    self._progress  = 0

    -- Zero-duration case: snap to target immediately.
    if self._duration == 0 then
        applyProps(self._target, self._props, self._origins, self._interps, 1)
        self._playing  = false
        self._progress = 1
        if self._onComplete then self._onComplete() end
        return
    end

    self:_startVelocityReset()

    local self_ = self

    task.spawn(function()
        -- Initial delay.
        if self_._delay > 0 then
            task.wait(self_._delay)
        end
        if self_._cancelled then
            self_:_stopVelocityReset()
            self_._playing = false
            return
        end

        local repeated = 0  -- actual completed cycle count

        repeat
            local cycleStart  = tick()
            local pauseOffset = 0

            while not self_._cancelled do
                task.wait(0.016) -- target ~60fps; Matcha may clamp this

                -- == Pause handling ================================
                -- Use a slower poll (0.1s) while paused so we don't
                -- waste scheduler slots spinning on a tight wait.
                if self_._paused then
                    local pauseBegin = tick()
                    while self_._paused and not self_._cancelled do
                        task.wait(0.1)
                    end
                    pauseOffset = pauseOffset + (tick() - pauseBegin)
                end

                if self_._cancelled then break end

                local elapsed = tick() - cycleStart - pauseOffset
                local t       = math.clamp(elapsed / self_._duration, 0, 1)
                local eased   = self_._direction(self_._style, t)

                -- Reverse on odd cycles.
                if self_._reverse and (repeated % 2 == 1) then
                    eased = 1 - eased
                end

                self_._progress = t
                applyProps(self_._target, self_._props, self_._origins, self_._interps, eased)

                if self_._onUpdate then
                    pcall(self_._onUpdate, eased)
                end

                if elapsed >= self_._duration then break end
            end

            repeated = repeated + 1

        until self_._cancelled
              or (self_._repeatCount ~= -1 and repeated > self_._repeatCount)

        -- == Snap to correct final value ========================
        -- Use the actual completed cycle count (`repeated`) to
        -- determine whether the last cycle ended at origin or target.
        -- self._repeatCount is NOT used here — it may be -1 (infinite)
        -- or simply not reflect the real number of cycles run.
        if not self_._cancelled then
            local finalT
            if self_._reverse then
                -- Odd number of completed cycles ends at origin (easedT = 0).
                finalT = (repeated % 2 == 1) and 0 or 1
            else
                finalT = 1
            end
            applyProps(self_._target, self_._props, self_._origins, self_._interps, finalT)
            self_._progress = 1
        end

        self_:_stopVelocityReset()
        self_._playing = false

        if not self_._cancelled and self_._onComplete then
            pcall(self_._onComplete)
        end
    end)
end

function Tween:Stop()
    self._cancelled = true
    self._paused    = false
    self:_stopVelocityReset()
    self._playing = false
end

function Tween:Cancel()
    self:Stop()
end

function Tween:Pause()
    if self._playing and not self._paused then
        self._paused = true
    end
end

function Tween:Resume()
    if self._playing and self._paused then
        self._paused = false
    end
end

function Tween:IsPlaying()
    -- type: () -> boolean
    return self._playing and not self._paused
end

function Tween:GetProgress()
    -- type: () -> number  [0, 1]
    return self._progress
end

-- ============================================================
-- TweenService module
-- ============================================================

local TweenService = {}

function TweenService.new(target, config)
    -- type: (target: any, config: table) -> Tween
    return Tween.new(target, config)
end

return TweenService
