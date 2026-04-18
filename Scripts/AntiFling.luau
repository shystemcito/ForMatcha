local loaderSource = game:HttpGet("https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/Loader.luau")
local fn, loaderErr = loadstring("MatchaLib = (function()\n" .. loaderSource .. "\nend)()")
if not fn then error("COMPILE ERROR (Loader): " .. tostring(loaderErr)) end
fn()
local Loader = MatchaLib

local MatchaUI = Loader.load("MatchaUI")

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")

local steppedConnection = nil

local function antiFlingLoop()
    for _, player in pairs(Players:GetPlayers()) do
        if player.Name ~= Players.LocalPlayer.Name and player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end

local function setAntiFling(state)
    if state then
        if not steppedConnection then
            steppedConnection = RunService.Stepped:Connect(antiFlingLoop)
        end
        MatchaUI.Notify("AntiFling", "Anti-Fling turned on", 3)
    else
        if steppedConnection then
            steppedConnection:Disconnect()
            steppedConnection = nil
        end
        MatchaUI.Notify("AntiFling", "Anti-Fling turned off", 3)
    end
end

local win = MatchaUI.CreateWindow({Title  = "AntiFling by shystemmm",
    X      = 80,
    Y      = 80,
    Width  = 400,
    Height = 100,
})

local cat = win.AddCategory("Antifling")

win.AddSection(cat, "Protection")

win.AddToggle(cat, "Anti-Fling", false, function(state)
    setAntiFling(state)
end)

MatchaUI.Run()
