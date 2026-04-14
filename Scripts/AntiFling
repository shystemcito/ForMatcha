local executor, version = identifyexecutor()
if executor ~= "Matcha" then error("[NoCollide] Ejecutor no soportado: " .. tostring(executor)) end

notify("AntiFling", "Anti-Fling Enabled - By shystemmm", 5)
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

RunService.Stepped:Connect(function()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)
