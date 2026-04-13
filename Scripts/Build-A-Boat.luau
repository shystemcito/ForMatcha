local executor = identifyexecutor()
if executor ~= "Matcha" then error("This script require Matcha LuaVM.") end
notify("Starting - By shystemmm", "Build a Boat AutoFarm", 5)

local loaderSource = game:HttpGet("https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/Loader.luau")
local fn, loaderErr = loadstring("MatchaLib = (function()\n" .. loaderSource .. "\nend)()")
if not fn then error("COMPILE ERROR (Loader): " .. tostring(loaderErr)) end
fn()
local Loader = MatchaLib

local TweenService     = Loader.load("TweenService")
local CharacterService = Loader.load("CharacterService")

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local charService = CharacterService.new(localPlayer)

local START_POS  = Vector3.new(-50, 60, 700)
local MIDDLE_POS = Vector3.new(-50, 60, 8775)

local currentToken = nil

local function newToken()
    local token = { alive = true }
    return token
end

local function cancelCurrent()
    if currentToken then
        currentToken.alive = false
    end
end

local function getEndPos()
    local boatStages   = Workspace:FindFirstChild("BoatStages")
    if not boatStages then warn("[AutoMove] BoatStages not found.") return nil end

    local normalStages = boatStages:FindFirstChild("NormalStages")
    if not normalStages then warn("[AutoMove] NormalStages not found.") return nil end

    local theEnd       = normalStages:FindFirstChild("TheEnd")
    if not theEnd then warn("[AutoMove] TheEnd not found.") return nil end

    local goldenChest  = theEnd:FindFirstChild("GoldenChest")
    if not goldenChest then warn("[AutoMove] GoldenChest not found..") return nil end

    local trigger      = goldenChest:FindFirstChild("Trigger")
    if not trigger then warn("[AutoMove] Trigger not found..") return nil end

    return trigger.Position + Vector3.new(0, 5, -5)
end

local function tweenTo(root, targetPos, speed, style, direction, token)
    speed     = speed     or 500
    style     = style     or "Sine"
    direction = direction or "Out"

    local done = false

    local tween = TweenService.new(root, {
        position      = targetPos,
        speed         = speed,
        style         = style,
        direction     = direction,
        freezePhysics = true,
        onComplete    = function()
            done = true
        end,
    })
    tween:Play()

    while not done do
        if token and not token.alive then
            tween:Stop()
            return false
        end
        task.wait(0.1)
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
    local otherData = localPlayer:FindFirstChild("OtherData")
    local stageValue = otherData and otherData:FindFirstChild("Stage" .. stageIndex)
    return stageValue and stageValue.Value ~= ""
end

local function doStages(root, token)
    local normalStages = Workspace:FindFirstChild("BoatStages") and Workspace.BoatStages:FindFirstChild("NormalStages")

    for i = 9, 0, -1 do
        if not token.alive then return end

        if not isStageComplete(i) then
            local caveIndex = i + 1
            local cave = normalStages and normalStages:FindFirstChild("CaveStage" .. caveIndex)
            local part = cave and cave:FindFirstChild("DarknessPart")

            while not isStageComplete(i) do
                if not token.alive then return end
                if part then
                    local ok = tweenTo(root, part.Position + Vector3.new(0, 0, -75), 8000, "Linear", "In", token)
                    if not ok then return end
                end
                task.wait(0.25)
            end
        end
    end
end

local function runMovementSequence(token)
    local root = charService:GetRoot()
    if not root then
        local char = charService:GetCharacter()
        if char then
            root = waitForChild(char, "HumanoidRootPart", 10)
        end
    end
    if not root then
        warn("[AutoMove] HumanoidRootPart not available after 10s. Aborting.")
        return
    end

    if not token.alive then return end
    tweenTo(root, START_POS, 1500, "Linear", "In", token)

    if not token.alive then return end
    tweenTo(root, MIDDLE_POS, 600, "Linear", "In", token)

    while not hasReachedEnd() do
        if not token.alive then return end

        local endPos = getEndPos()

        if endPos then
            local ok = tweenTo(root, endPos, 600, "Linear", "In", token)
            if not ok then return end
        else
            warn("[AutoMove] EndPos not available. Retrying in 1s...")
            task.wait(1)
            continue
        end

        if hasReachedEnd() then break end
        task.wait(0.25)
    end

    if not token.alive then return end
    tweenTo(root, MIDDLE_POS, 1500, "Linear", "In", token)

    if not token.alive then return end
    doStages(root, token)
end

charService:OnCharacterAdded(function(_character)
    cancelCurrent()
    local token = newToken()
    currentToken = token
    task.spawn(function()
        runMovementSequence(token)
    end)
end)

cancelCurrent()
local token = newToken()
currentToken = token
task.spawn(function()
    runMovementSequence(token)
end)
