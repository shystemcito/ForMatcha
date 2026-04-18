local loaderSource = game:HttpGet("https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/Loader.luau")
local fn, loaderErr = loadstring("MatchaLib = (function()\n" .. loaderSource .. "\nend)()")
if not fn then error("COMPILE ERROR (Loader): " .. tostring(loaderErr)) end
fn()
local Loader = MatchaLib

local TweenService     = Loader.load("TweenService")
local CharacterService = Loader.load("CharacterService")
local MatchaUI         = Loader.load("MatchaUI")

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local charService = CharacterService.new(localPlayer)

local BaseSpeed = 600

local START_POS  = Vector3.new(-50, 60, 700)
local MIDDLE_POS = Vector3.new(-50, 60, 8775)

local autoFarmEnabled = false
local antiAfkEnabled  = false
local currentToken    = nil

local cashAtStart = (function()
    local ok, gold = pcall(function() return localPlayer.Data.Gold.Value end)
    return ok and gold or 0
end)()
local startTime = os.clock()

local function newToken()
    return { alive = true }
end

local function cancelCurrent()
    if currentToken then
        currentToken.alive = false
        currentToken = nil
    end
end

local function getEndPos()
    local boatStages = Workspace:FindFirstChild("BoatStages")
    if not boatStages then warn("[AutoFarm] BoatStages not found.") return nil end

    local normalStages = boatStages:FindFirstChild("NormalStages")
    if not normalStages then warn("[AutoFarm] NormalStages not found.") return nil end

    local theEnd = normalStages:FindFirstChild("TheEnd")
    if not theEnd then warn("[AutoFarm] TheEnd not found.") return nil end

    local goldenChest = theEnd:FindFirstChild("GoldenChest")
    if not goldenChest then warn("[AutoFarm] GoldenChest not found.") return nil end

    local trigger = goldenChest:FindFirstChild("Trigger")
    if not trigger then warn("[AutoFarm] Trigger not found.") return nil end

    return trigger.Position + Vector3.new(0, 5, -5)
end

local function tweenTo(root, targetPos, speed, style, direction, token)
    style     = style     or "Linear"
    direction = direction or "In"

    local done = false
    local tween = TweenService.new(root, {
        position      = targetPos,
        speed         = speed,
        style         = style,
        direction     = direction,
        freezePhysics = true,
        onComplete    = function() done = true end,
    })
    tween:Play()

    while not done do
        task.wait()
        if token and not token.alive then
            tween:Stop()
            return false
        end
    end
    return true
end

local function waitForChild(instance, childName, timeout)
    timeout = timeout or 10
    local elapsed, STEP = 0, 0.05
    while elapsed < timeout do
        local child = instance:FindFirstChild(childName)
        if child then return child end
        task.wait(STEP)
        elapsed = elapsed + STEP
    end
    return nil
end

local function hasReachedEnd()
    local ok, result = pcall(function()
        return localPlayer.OtherData.End.Value
    end)
    if not ok then return false end
    return result == "EndReached"
end

local function isStageComplete(stageIndex)
    local otherData  = localPlayer:FindFirstChild("OtherData")
    local stageValue = otherData and otherData:FindFirstChild("Stage" .. stageIndex)
    return stageValue and stageValue.Value ~= ""
end

local function doStages(root, token)
    local normalStages = Workspace:FindFirstChild("BoatStages")
        and Workspace.BoatStages:FindFirstChild("NormalStages")

    for i = 9, 0, -1 do
        if not token.alive then return end

        if not isStageComplete(i) then
            local caveIndex = i + 1
            local cave = normalStages and normalStages:FindFirstChild("CaveStage" .. caveIndex)
            local part = cave and cave:FindFirstChild("DarknessPart")

            while not isStageComplete(i) do
                if not token.alive then return end
                if part then
                    local target = part.Position + Vector3.new(0, 0, -75)
                    local ok = tweenTo(root, target, BaseSpeed + 7400, "Linear", "In", token)
                    if not ok then return end
                end
                task.wait(0.1)
            end
        end
    end
end

local function runMovementSequence(token)
    local root = charService:GetRoot()
    if not root then
        local char = charService:GetCharacter()
        if char then root = waitForChild(char, "HumanoidRootPart", 10) end
    end
    if not root then
        warn("[AutoFarm] HumanoidRootPart not available. Aborting.")
        return
    end

    while token.alive and autoFarmEnabled do
        if not tweenTo(root, START_POS, BaseSpeed + 900, "Linear", "In", token) then return end
        if not tweenTo(root, MIDDLE_POS, BaseSpeed, "Linear", "In", token) then return end

        while token.alive and not hasReachedEnd() do
            local endPos = getEndPos()
            if endPos then
                local ok = tweenTo(root, endPos, BaseSpeed, "Linear", "In", token)
                if not ok then return end
            else
                warn("[AutoFarm] EndPos not available. Retrying in 1s...")
                task.wait(1)
            end
            if hasReachedEnd() then break end
            task.wait(0.25)
        end
        if not token.alive then return end

        if not tweenTo(root, MIDDLE_POS, BaseSpeed + 900, "Linear", "In", token) then return end
        doStages(root, token)
    end
end

local function startFarm()
    cancelCurrent()
    local token = newToken()
    currentToken = token
    task.spawn(function()
        runMovementSequence(token)
    end)
end

charService:OnCharacterAdded(function(_character)
    if not autoFarmEnabled then return end
    startFarm()
end)

task.spawn(function()
    while true do
        task.wait(60)
        if not antiAfkEnabled then continue end
        if not isrbxactive() then continue end
        mousemoverel(-10, 0)
        task.wait(0.1)
        mousemoverel(10, 0)
    end
end)

local Window = MatchaUI.CreateWindow({
    Title  = "Build a Boat  |  shystemmm",
    X      = 120,
    Y      = 80,
    Width  = 480,
    Height = 380,
})

local catFarm = Window.AddCategory("AutoFarm")

Window.AddSection(catFarm, "Controls")

Window.AddToggle(catFarm, "AutoFarm", false, function(state)
    autoFarmEnabled = state
    if state then
        startFarm()
    else
        cancelCurrent()
    end
end)

Window.AddToggle(catFarm, "Anti-AFK", false, function(state)
    antiAfkEnabled = state
end)

Window.AddSlider(catFarm, "Base Speed", 100, 2000, BaseSpeed, function(val)
    BaseSpeed = math.floor(val)
end)

Window.AddSection(catFarm, "Stats")

local labelCash = Window.AddValueLabel(catFarm, "Current Cash", "0")
local labelCph  = Window.AddValueLabel(catFarm, "Cash / Hour",  "0")

task.spawn(function()
    while true do
        task.wait(1)

        local ok, gold = pcall(function() return localPlayer.Data.Gold.Value end)
        local currentGold = ok and gold or 0
        labelCash:SetValue(tostring(currentGold))

        local elapsed = os.clock() - startTime
        if elapsed > 0 then
            local earned = math.max(0, currentGold - cashAtStart)
            local cph    = math.floor(earned / elapsed * 3600)
            labelCph:SetValue(tostring(cph))
        end
    end
end)

notify("Ready - By shystemmm", "Build a Boat AutoFarm", 5)

MatchaUI.Run()
