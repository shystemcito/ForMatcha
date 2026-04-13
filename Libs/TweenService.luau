-- @env: Matcha LuaVM
-- ============================================================
-- TweenService — v1.0.0
-- Position animation library for Matcha LuaVM.
-- Animates BasePart instances by interpolating their Position
-- property using multiple easing styles and directions.
-- ============================================================

--[[
    MODULE: TweenService
    Exports a single constructor function: TweenService.new()

    EASING STYLES (config.style : string)
        "Linear" | "Quad" | "Cubic" | "Sine" | "Bounce" | "Back" | "Elastic" | "Expo"

    EASING DIRECTIONS (config.direction : string)
        "In" | "Out" | "InOut"

    ──────────────────────────────────────────────────────────
    TweenService.new(instance: BasePart, config: table) → Tween
    ──────────────────────────────────────────────────────────
        instance    : BasePart  — The instance whose Position will be animated.
        config      : table     — Configuration table with the following fields:

            position      : Vector3   — Target position. Default: instance.Position.
            duration      : number    — Duration in seconds (ignored if speed is set). Default: 1.
            speed         : number    — Speed in studs/second. Overrides duration if > 0.
            style         : string    — Easing style name. Default: "Sine".
            direction     : string    — Easing direction. Default: "Out".
            repeat_       : number    — Number of additional repetitions. -1 = infinite. Default: 0.
            reverse       : boolean   — If true, even cycles play in reverse. Default: false.
            delay         : number    — Initial delay in seconds before playback starts. Default: 0.
            freezePhysics : boolean   — If true, forces Velocity to zero during animation. Default: true when position is defined.
            onComplete    : function  — Callback invoked when the tween finishes. No arguments.
            onUpdate      : function  — Callback invoked every frame. Receives (easedValue: number).

    ──────────────────────────────────────────────────────────
    Tween:Play() → nil
    ──────────────────────────────────────────────────────────
        Starts the animation. Does nothing if already playing.

    ──────────────────────────────────────────────────────────
    Tween:Stop() → nil
    ──────────────────────────────────────────────────────────
        Stops the animation at its current position and cleans up the physics thread.
        Does not invoke onComplete.

    ──────────────────────────────────────────────────────────
    Tween:Cancel() → nil
    ──────────────────────────────────────────────────────────
        Alias for Stop(). Stops and marks the tween as cancelled without calling onComplete.

    ──────────────────────────────────────────────────────────
    Tween:Pause() → nil
    ──────────────────────────────────────────────────────────
        Pauses the animation while preserving current progress.

    ──────────────────────────────────────────────────────────
    Tween:Resume() → nil
    ──────────────────────────────────────────────────────────
        Resumes the animation from where it was paused.

    ──────────────────────────────────────────────────────────
    Tween:IsPlaying() → boolean
    ──────────────────────────────────────────────────────────
        Returns true if the animation is currently running and not paused.

    ──────────────────────────────────────────────────────────
    Tween:GetProgress() → number
    ──────────────────────────────────────────────────────────
        Returns the current normalized progress [0, 1] of the active cycle.
]]

-- ============================================================
-- Easing styles
-- ============================================================

local EasingStyles = {
    Linear  = function(t: number): number return t end,
    Quad    = function(t: number): number return t * t end,
    Cubic   = function(t: number): number return t * t * t end,
    Sine    = function(t: number): number return 1 - math.cos(t * math.pi / 2) end,
    Bounce  = function(t: number): number
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
    Back    = function(t: number): number
        local s = 1.70158
        return t * t * ((s + 1) * t - s)
    end,
    Elastic = function(t: number): number
        if t == 0 or t == 1 then return t end
        return -math.pow(2, 10 * (t - 1)) * math.sin((t - 1.1) * 5 * math.pi)
    end,
    Expo    = function(t: number): number
        return t == 0 and 0 or math.pow(2, 10 * (t - 1))
    end,
}

-- ============================================================
-- Easing directions
-- ============================================================

local EasingDirections = {
    In    = function(s, t: number): number return s(t) end,
    Out   = function(s, t: number): number return 1 - s(1 - t) end,
    InOut = function(s, t: number): number
        if t < 0.5 then
            return s(t * 2) / 2
        else
            return 1 - s((1 - t) * 2) / 2
        end
    end,
}

-- ============================================================
-- Internal utilities
-- ============================================================

local function lerpV3(a: Vector3, b: Vector3, t: number): Vector3
    return Vector3.new(
        a.X + (b.X - a.X) * t,
        a.Y + (b.Y - a.Y) * t,
        a.Z + (b.Z - a.Z) * t
    )
end

local function assertType(value: any, expected: string, field: string)
    if value ~= nil and type(value) ~= expected then
        error(("TweenService: config.%s must be of type %s, got %s"):format(field, expected, type(value)), 2)
    end
end

-- ============================================================
-- Tween class
-- ============================================================

local Tween = {}
Tween.__index = Tween

function Tween.new(instance: BasePart, config: table)
    assert(instance, "TweenService: 'instance' cannot be nil.")
    assert(type(config) == "table", "TweenService: 'config' must be a table.")

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

    local self = setmetatable({}, Tween)

    self.instance      = instance
    self.target        = config.position   or instance.Position
    self.repeatCount   = config.repeat_    or 0
    self.reverse       = config.reverse    or false
    self.delay         = config.delay      or 0
    self.onComplete    = config.onComplete or nil
    self.onUpdate      = config.onUpdate   or nil
    self.freezePhysics = config.position ~= nil and (config.freezePhysics ~= false)

    local origin   = instance.Position
    local distance = (origin - self.target).Magnitude

    if config.speed and config.speed > 0 then
        self.duration = distance > 0 and (distance / config.speed) or 0
    else
        self.duration = config.duration or 1
    end

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

    self._style         = EasingStyles[sName]
    self._direction     = EasingDirections[dName]

    self._playing        = false
    self._cancelled      = false
    self._paused         = false
    self._progress       = 0
    self._velocityThread = nil
    self._origin         = origin

    return self
end

-- ── Physics freeze ────────────────────────────────────────────

function Tween:_startVelocityReset()
    if not self.freezePhysics then return end

    self._velocityThread = task.spawn(function()
        while self._playing and not self._cancelled do
            pcall(function()
                self.instance.Velocity               = Vector3.new(0, 0, 0)
                self.instance.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
            task.wait(0.05)
        end
    end)
end

function Tween:_stopVelocityReset()
    if self._velocityThread then
        task.cancel(self._velocityThread)
        self._velocityThread = nil
    end
end

-- ── Public API ────────────────────────────────────────────────

function Tween:Play()
    if self._playing then return end

    self._playing   = true
    self._cancelled = false
    self._paused    = false
    self._progress  = 0

    local origin = self._origin

    if self.duration == 0 then
        self.instance.Position = self.target
        self._playing  = false
        self._progress = 1
        if self.onComplete then self.onComplete() end
        return
    end

    self:_startVelocityReset()

    task.spawn(function()
        if self.delay > 0 then
            task.wait(self.delay)
        end
        if self._cancelled then
            self:_stopVelocityReset()
            self._playing = false
            return
        end

        local repeated = 0

        repeat
            local cycleStart  = tick()
            local pauseOffset = 0

            while not self._cancelled do
                task.wait()

                if self._paused then
                    local pauseBegin = tick()
                    repeat task.wait() until not self._paused or self._cancelled
                    pauseOffset = pauseOffset + (tick() - pauseBegin)
                end

                if self._cancelled then break end

                local elapsed = tick() - cycleStart - pauseOffset
                local t       = math.clamp(elapsed / self.duration, 0, 1)
                local eased   = self._direction(self._style, t)

                if self.reverse and (repeated % 2 == 1) then
                    eased = 1 - eased
                end

                self._progress         = t
                self.instance.Position = lerpV3(origin, self.target, eased)

                if self.onUpdate then self.onUpdate(eased) end
                if elapsed >= self.duration then break end
            end

            repeated = repeated + 1

        until self._cancelled or (self.repeatCount ~= -1 and repeated > self.repeatCount)

        if not self._cancelled then
            local finalEased = self.reverse and (self.repeatCount % 2 == 1) and 0 or 1
            self.instance.Position = lerpV3(origin, self.target, finalEased)
            self._progress = 1
        end

        self:_stopVelocityReset()
        self._playing = false

        if not self._cancelled and self.onComplete then
            self.onComplete()
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

function Tween:IsPlaying(): boolean
    return self._playing and not self._paused
end

function Tween:GetProgress(): number
    return self._progress
end

-- ============================================================
-- TweenService module
-- ============================================================

local TweenService = {}
TweenService.__index = TweenService

--[[
    TweenService.new(instance: BasePart, config: table) → Tween
    Creates and returns a Tween object ready to be played.
    See the module documentation at the top of this file
    for all available config fields.
]]
function TweenService.new(instance: BasePart, config: table)
    return Tween.new(instance, config)
end

return TweenService
