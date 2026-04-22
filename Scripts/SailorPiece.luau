-- ==============================================================
-- Sailor Piece / shystemmm
-- ==============================================================
-- == Loader ====================================================
local loaderSource = game:HttpGet("https://raw.githubusercontent.com/shystemcito/ForMatcha/refs/heads/main/Libs/Loader.luau")
local fn, loaderErr = loadstring("MatchaLib = (function()\n" .. loaderSource .. "\nend)()")
if not fn then error("COMPILE ERROR (Loader): " .. tostring(loaderErr)) end
fn()
local Loader = MatchaLib
local UiLib = Loader.load("MatchaUI")

-- == Keycodes ==================================================
local keyMap = {
	A = 65, B = 66, C = 67, D = 68, E = 69, F = 70,
	G = 71, H = 72, I = 73, J = 74, K = 75, L = 76,
	M = 77, N = 78, O = 79, P = 80, Q = 81, R = 82,
	S = 83, T = 84, U = 85, V = 86, W = 87, X = 88,
	Y = 89, Z = 90,

	N0 = 48, N1 = 49, N2 = 50, N3 = 51, N4 = 52,
	N5 = 53, N6 = 54, N7 = 55, N8 = 56, N9 = 57,

	Space = 32,
}

local cons = {
	Workspace = game:GetService("Workspace"),
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService")
}
cons.Player = cons.Players.LocalPlayer
cons.Backpack = cons.Player:WaitForChild("Backpack")
cons.NPCPath = cons.Workspace:WaitForChild("NPCs")

local farmCfg = {
	Tools = {},
	SelectedTool = "None",
	CachedToolNumber = nil,

	AutofarmMethod = "Nearest",
	SelectedQuest = "",
	SelectedNPCs = {},
	SelectedAttacks = {},

	ExistingNPCs = {},
	NPCDistance = 10,
	TweenSpeed = 120,
	SafeTween = false,

	CurrentSpawnpointAddress = nil,

	QuestMap = {
		Quest1 = {"QuestNPC1", Vector3.new(171, 16, -214), "Thief", {0,99}},
		Quest2 = {"QuestNPC2", Vector3.new(-7, -2.5, -202), "ThiefBoss", {100,249}},
		Quest3 = {"QuestNPC3", Vector3.new(-519, -1.6, 434), "Monkey", {250,499}},
		Quest4 = {"QuestNPC4", Vector3.new(-467, 18.8, 480), "MonkeyBoss", {500,749}},
		Quest5 = {"QuestNPC5", Vector3.new(-688, -2.4, -460), "DesertBandit", {750,999}},
		Quest6 = {"QuestNPC6", Vector3.new(-863, -4.2, -385.5), "DesertBoss", {1000,1499}},
		Quest7 = {"QuestNPC7", Vector3.new(-388.6, -1.7, -945), "FrostRogue", {1500,1999}},
		Quest8 = {"QuestNPC8", Vector3.new(-550.7, 22.4, -1025.7), "SnowBoss", {2000,2999}},
		Quest9 = {"QuestNPC9", Vector3.new(1419, 9, 372), "Sorcerer", {3000,3999}},
		Quest10 = {"QuestNPC10", Vector3.new(1604, 9, 429), "PandaMiniBoss", {4000,5000}},
		Quest11 = {"QuestNPC11", Vector3.new(-285.6, -3.3, 1038.7), "Hollow", {5000,6250}},
		Quest12 = {"QuestNPC12", Vector3.new(626.4, 1.8, -1609.5), "StrongSorcerer", {6250,7000}},
		Quest13 = {"QuestNPC13", Vector3.new(-19.7, 1.9, -1985.2), "Curse", {7000,8000}},
		Quest14 = {"QuestNPC14", Vector3.new(-1187.4, 17.9, 338.5), "Slime", {8000,9000}},
		Quest15 = {"QuestNPC15", Vector3.new(1028, 1.4, 1241), "AcademyTeacher", {9000,10000}},
		Quest16 = {"QuestNPC16", Vector3.new(-1165, 2.5, -1189.8), "Swordsman", {10000,10750}},
		Quest17 = {"QuestNPC17", Vector3.new(0, 0, 0), "Unknown", {10750,11500}},
		Quest18 = {"QuestNPC18", Vector3.new(-1786.6, 7, -744.6), "Ninja", {11500,12000}},
		Quest19 = {"QuestNPC19", Vector3.new(67, -1.1, 1758.8), "ArenaFighter", {12000,12750}},
	},
	QuestsNames = {}
}; for i = 1, 19 do table.insert(farmCfg.QuestsNames, "Quest" .. i) end

local farmToggles = {
	attacking = false,
	farming = false,
	equipTools = false,
}

-- == Helpers ==========================================
local function getRoot(Model)
	if not Model.ClassName == "Model" then return "Class missmatch" end
	local Root = Model:FindFirstChild("HumanoidRootPart")
		or Model.PrimaryPart
		or Model:FindFirstChild("Torso")
		or Model:FindFirstChildWhichIsA("BasePart")
	if Root then return Root end
	return nil
end

local function getHumanoid(Model)
	if Model.ClassName ~= "Model" then return nil end
	local Humanoid = Model:FindFirstChild("Humanoid") or Model:FindFirstChildWhichIsA("Humanoid")
	return Humanoid
end

-- == Tool Utilities ==========================================
local function refreshTools()
	table.clear(farmCfg.Tools)
	table.insert(farmCfg.Tools, "None")
	for _, tool in cons.Backpack:GetChildren() do
		if tool.ClassName == "Tool" then
			table.insert(farmCfg.Tools, tool.Name)
		end
	end

	local Character = cons.Player.Character
	if Character then
		for _, tool in Character:GetChildren() do
			if tool.ClassName == "Tool" then
				table.insert(farmCfg.Tools, tool.Name)
			end
		end
	end
end
refreshTools()

local function equipTool(toolName)
	if not toolName or toolName == "None" then return end
	if not cons.Player.Character then return end

	local toolEquipped = cons.Player.Character:FindFirstChild(toolName)
	if toolEquipped and toolEquipped.ClassName == "Tool" then return end

	local inventorySlots = {
		keyMap.N1, keyMap.N2, keyMap.N3, keyMap.N4, keyMap.N5,
		keyMap.N6, keyMap.N7, keyMap.N8, keyMap.N9, keyMap.N0,
	}

	if farmCfg.CachedToolNumber then
		local KeyCode = inventorySlots[farmCfg.CachedToolNumber]
		keypress(KeyCode)
		keyrelease(KeyCode)
		task.wait(0.1)
		toolEquipped = cons.Player.Character:FindFirstChild(toolName)
		if toolEquipped and toolEquipped.ClassName == "Tool" then
			return
		end
	end

	for slot, keyCode in inventorySlots do
		keypress(keyCode)
		keyrelease(keyCode)
		task.wait(0.1)
		toolEquipped = cons.Player.Character:FindFirstChild(toolName)
		if toolEquipped and toolEquipped.ClassName == "Tool" then
			farmCfg.CachedToolNumber = slot
			return
		end
	end
	return "Tool not found"
end

-- == NPCs Utilities ==========================================
local function refreshNPCs()
	table.clear(farmCfg.SelectedNPCs)
	table.clear(farmCfg.ExistingNPCs)

	local character = cons.Player.Character
	local root = getRoot(character)
	local tempNPCs = {}

	for _, npc in cons.NPCPath:GetChildren() do
		if npc.ClassName == "Model" and getHumanoid(npc) then
			local npcRoot = getRoot(npc)
			local npcFormattedName = npc.Name:gsub("%s*%d+$", "")
			local distance, hasRoot = 9999, false

			if npcRoot and root then
				hasRoot = true
				distance = (npcRoot.Position - root.Position).Magnitude
				table.insert(tempNPCs, {Name = npcFormattedName, Distance = distance, HasRoot = hasRoot})
			end
		end
	end

	table.sort(tempNPCs, function(a, b)
		if a.HasRoot ~= b.HasRoot then
			return a.HasRoot
		elseif a.HasRoot then
			return a.Distance < b.Distance
		end
		return false
	end)

	for _, data in tempNPCs do
		if not table.find(farmCfg.ExistingNPCs, data.Name) then
			table.insert(farmCfg.ExistingNPCs, data.Name)
		end
	end
end
refreshNPCs()

local function findNearestNPC(filterNames)
	local character = cons.Player.Character
	local root = getRoot(character)

	if not root then return nil end

	local nearestNPC = nil
	local bestDist = math.huge

	for _, npc in cons.NPCPath:GetChildren() do
		if npc.ClassName == "Model" and npc:FindFirstChild("HumanoidRootPart") and npc.Name ~= "TrainingDummy" then
			local humanoid = getHumanoid(npc)
			if humanoid and humanoid.Health > 0 then
				local nameFormatted = npc.Name:gsub("%s*%d+$", "")
				local allowed = (not filterNames or #filterNames == 0) or table.find(filterNames, nameFormatted)
				if allowed then
					local npcRoot = getRoot(npc)
					if npcRoot then
						local distance = (npcRoot.Position - root.Position).Magnitude
						if distance < bestDist then
							bestDist = distance
							nearestNPC = npc
						end
					end
				end
			end
		end
	end

	if filterNames and nearestNPC == nil then
		for _, filterName in filterNames do
			local possibleNames = {filterName}

			for i = 1, 10 do 
				table.insert(possibleNames, filterName .. " " .. tostring(i))
				table.insert(possibleNames, filterName .. tostring(i))
			end

			for _, exactName in possibleNames do
				local directNpc = cons.NPCPath:FindFirstChild(exactName)
				if directNpc and directNpc.ClassName == "Model" and directNpc:FindFirstChild("HumanoidRootPart") then
					local humanoid = getHumanoid(directNpc)
					if humanoid and humanoid.Health > 0 then
						local npcRoot = getRoot(directNpc)
						if npcRoot then
							nearestNPC = directNpc
							break
						end
					end
				end
			end
			if nearestNPC then break end
		end
	end
	return nearestNPC
end

-- == Farm Utilities ==========================================
local tweenToken = 0
local function TweenTo(targetPos, lift)
	tweenToken += 1
	local myToken = tweenToken

	local character = cons.Player.Character
	if not character then return end
	local root = getRoot(character)
	if not root then return end

	if farmCfg.SafeTween and lift then
		root.Velocity = Vector3.new(0, 300, 0)
		root.Velocity = Vector3.new(0, 300, 0)
		root.Velocity = Vector3.new(0, 300, 0)
		root.Velocity = Vector3.new(0, 300, 0)
		task.wait(0.75)
		if tweenToken ~= myToken then return end
	end

	local startPos = root.Position
	local distance = (targetPos - startPos).Magnitude
	local duration = distance / farmCfg.TweenSpeed

	local steps = math.max(1, math.floor(duration / 0.03))
	local stepTime = duration / steps

	for i = 1, steps do
		if tweenToken ~= myToken then return end

		character = cons.Player.Character
		if not character then break end
		root = getRoot(character)
		if not root then break end

		local alpha = i / steps
		local newPos = startPos:Lerp(targetPos, alpha)
		root.Position = newPos

		if farmCfg.SafeTween then
			local direction = (targetPos - root.Position)
			if direction.Magnitude > 0.1 then
				local lookCF = CFrame.lookAt(
					root.Position,
					root.Position + Vector3.new(direction.X, 0, direction.Z)
				)
				root.CFrame = lookCF
			end

			local currentDist = (targetPos - root.Position).Magnitude
			if currentDist > 30 then
				keypress(keyMap.Q)
				keyrelease(keyMap.Q)
			end
		end

		task.wait(stepTime)
	end

	if root and tweenToken == myToken then
		for i = 1, 10 do
			if tweenToken ~= myToken then return end
			root.Position = targetPos
			root.Velocity = Vector3.new(0, 0, 0)
			task.wait()
		end
	end
end

local function selectQuestForLevel()
	local level = 0
	pcall(function()
		level = cons.Player.Data.Level.Value
	end)

	local bestKey = nil
	local bestMin = -1

	for key, data in farmCfg.QuestMap do
		local levelRange = data[4]
		if level >= levelRange[1] and level <= levelRange[2] then
			if levelRange[1] > bestMin then
				bestMin = levelRange[1]
				bestKey = key
			end
		end
	end
	return bestKey
end

local function attack()
	if isrbxactive() then
		mouse1click()
		for _, attackKey in farmCfg.SelectedAttacks do
			local keyCode = keyMap[attackKey]
			if keyCode then
				keypress(keyCode)
				keyrelease(keyCode)
			end
		end
	end
end

local function getNearestSpawnpoint()
	local character = cons.Player.Character
	local root = getRoot(character)

	if not root then return nil end

	local nearestSpawnpoint = nil
	local bestDist = math.huge

	for _, spawnpoint in cons.Workspace:GetDescendants() do
		if string.match(spawnpoint.Name, "^SpawnPointCrystal_") and spawnpoint:FindFirstChild("Crystal") then
			local dist = (root.Position - spawnpoint:FindFirstChild("Crystal").Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				nearestSpawnpoint = spawnpoint
			end
		end
	end

	return nearestSpawnpoint
end

-- == Auto Farm Logic ==========================================
local function getSpawnpointAddress(spawnpoint)
	if not spawnpoint then return nil end
	return tostring(spawnpoint.Address)
end

local function handleSpawnpoint()
	local spawnpoint = getNearestSpawnpoint()
	if not spawnpoint then return false end

	local character = cons.Player.Character
	local root = getRoot(character)

	local address = getSpawnpointAddress(spawnpoint)
	if address == farmCfg.CurrentSpawnpointAddress then return false end

	local spawnRoot = spawnpoint:FindFirstChild("Crystal")
		or spawnpoint.PrimaryPart
		or spawnpoint:FindFirstChildWhichIsA("BasePart")
	if not spawnRoot then return false end

	TweenTo(spawnRoot.Position + Vector3.new(0,5,0), true)

	keypress(keyMap.E)
	for i = 1,30 do
		root.Position = spawnRoot.Position
		task.wait(0.1)
	end
	keyrelease(keyMap.E)

	farmCfg.CurrentSpawnpointAddress = address
	return true
end

-- == Farm Utilities ==========================================
local function attackNPC(npc)
	if not farmToggles.farming then return end

	while farmToggles.farming do
		local character = cons.Player.Character
		if not character then break end

		local playerHumanoid = getHumanoid(character)
		local npcHumanoid = getHumanoid(npc)

		if not playerHumanoid or playerHumanoid.Health <= 0 then break end
		if not npcHumanoid or npcHumanoid.Health <= 0 then break end

		local npcRoot = getRoot(npc)
		if not npcRoot then break end

		local root = getRoot(character)
		local overPos = npcRoot.Position + Vector3.new(0, farmCfg.NPCDistance, 0)

		if root then
			root.CFrame = CFrame.new(
				overPos.X, overPos.Y, overPos.Z,
				1, 0, 0,
				0, 0, 1,
				0, -1, 0
			)
			root.Velocity = Vector3.new(0, 0, 0)
		end

		task.wait()
	end
end

local function runFarmNearest(filtered)
	while farmToggles.farming do
		local filter = (filtered and #farmCfg.SelectedNPCs > 0) and farmCfg.SelectedNPCs or nil
		local npc = findNearestNPC(filter)

		if not npc then
			task.wait(1)
			continue
		end

		local npcRoot = getRoot(npc)
		if npcRoot then
			TweenTo(npcRoot.Position + Vector3.new(0, 50, 0), true)
		end
		if not farmToggles.farming then break end

		local spawnChanged = handleSpawnpoint()
		if not farmToggles.farming then break end

		if spawnChanged and npcRoot then
			TweenTo(npcRoot.Position + Vector3.new(0, 50, 0), true)
		end
		if not farmToggles.farming then break end

		attackNPC(npc)
		task.wait(0.1)
	end
end

local function runFarmQuest(autoLevel)
	while farmToggles.farming do
		local questKey
		if autoLevel then
			questKey = selectQuestForLevel()
		else
			questKey = farmCfg.SelectedQuest
		end

		if not questKey or not farmCfg.QuestMap[questKey] then
			task.wait(1)
			continue
		end

		local questData = farmCfg.QuestMap[questKey]
		local questPos = questData[2]
		local enemyName = questData[3]

		TweenTo(questPos, true)
		if not farmToggles.farming then break end

		local spawnChanged = handleSpawnpoint()
		if not farmToggles.farming then break end

		if spawnChanged then
			TweenTo(questPos, true)
			if not farmToggles.farming then break end
		end

		for i = 1, 5 do
			keypress(keyMap.E)
			keyrelease(keyMap.E)
		end
		task.wait(0.2)

		local npc = findNearestNPC({enemyName})
		if not npc then
			task.wait(1)
			continue
		end

		local npcRoot = getRoot(npc)
		if npcRoot then
			TweenTo(npcRoot.Position + Vector3.new(0, 50, 0), true)
		end
		if not farmToggles.farming then break end

		attackNPC(npc)
		task.wait(0.1)
	end
end

local function startAutoFarm(state)
	farmToggles.farming = state
	if not state then return end

	task.spawn(function()
		while farmToggles.farming do
			local method = farmCfg.AutofarmMethod

			if method == "Nearest" then
				runFarmNearest(false)
			elseif method == "Selected" then
				runFarmNearest(true)
			elseif method == "Quest" then
				runFarmQuest(false)
			elseif method == "LevelUp" then
				runFarmQuest(true)
			end

			task.wait(0.1)
		end
	end)
end

-- == UI INIT ==========================================
local Window = UiLib.CreateWindow({
	Title  = "Sailor piece - shystemmm",
	X      = 500,
	Y      = 100,
	Width  = 600,
	Height = 600,
	ZIndex = 100,
})

-- == Categories ==========================================
local catSetup = Window.AddCategory("Farm Setup")
local catFarm = Window.AddCategory("Auto Farm")

-- == Setup Category ==========================================
-- == Tools section ==========================================
Window.AddSection(catSetup, "Tools")
local toolsDd = Window.AddDropdown(catSetup, "Tool select", farmCfg.Tools, "None", function(sel)
	task.spawn(function()
		farmCfg.SelectedTool = sel
	end)
end)
Window.AddTooltip(toolsDd, "Select tool for autofarming")

local attackLabel = Window.AddValueLabel(catSetup, "Selected attacks", "None")
local attacksDd = Window.AddDropdown(catSetup, "Select attacks", {"Z", "X", "C", "V", "F"}, "None", function(sel)
	task.spawn(function()
		local index = table.find(farmCfg.SelectedAttacks, sel)
		if index then
			table.remove(farmCfg.SelectedAttacks, index)
		else
			table.insert(farmCfg.SelectedAttacks, sel)
		end
		attackLabel:SetValue(table.concat(farmCfg.SelectedAttacks, ", "))
	end)
end)
Window.AddTooltip(attacksDd, "Select auto-attacks for autofarm")

local toolUpdtateBtn = Window.AddButton(catSetup, "Refresh tools", function()
	refreshTools()
	farmCfg.SelectedTool = "None"
	toolsDd:SetOptions(farmCfg.Tools, "None")
	UiLib.Notify("Tool update", "List of tools updated", 2)
end)
Window.AddTooltip(toolUpdtateBtn, "Update the list of tools.")

-- == NPCs Section ==========================================
Window.AddSection(catSetup, "NPCs")
local NPCsLabel = Window.AddValueLabel(catSetup, "Selected NPCs", "None")
local NPCsDd = Window.AddDropdown(catSetup, "Select NPCs", farmCfg.ExistingNPCs, "None", function(sel)
	task.spawn(function()
		local index = table.find(farmCfg.SelectedNPCs, sel)
		if index then
			table.remove(farmCfg.SelectedNPCs, index)
		else
			table.insert(farmCfg.SelectedNPCs, sel)
		end
		NPCsLabel:SetValue(table.concat(farmCfg.SelectedNPCs, ", "))
	end)
end)
Window.AddTooltip(NPCsDd, "Select NPCs for autofarm")

local NPCsUpdateBtn = Window.AddButton(catSetup, "Refresh NPCs", function()
	refreshNPCs()
	NPCsDd:SetOptions(farmCfg.ExistingNPCs, "None")
	NPCsLabel:SetValue(table.concat(farmCfg.SelectedNPCs, ", "))
end)
Window.AddTooltip(NPCsUpdateBtn, "Update the list of NPCs.")

Window.AddToggle(catSetup, "Safe tween", farmCfg.SafeTween, function(state)
	farmCfg.SafeTween = state
end)
Window.AddSlider(catSetup, "Tween Speed", 16, 200, farmCfg.TweenSpeed, function(val)
	farmCfg.TweenSpeed = math.floor(val)
end)
Window.AddSlider(catSetup, "NPC Distance", 1, 20, farmCfg.NPCDistance, function(val)
	farmCfg.NPCDistance = math.floor(val)
end)

-- == Farm Section ==========================================
Window.AddSection(catSetup, "Farm")

local farmMethodDd = Window.AddDropdown(catSetup, "Farm method", {"Nearest", "Selected", "Quest", "LevelUp"}, farmCfg.AutofarmMethod, function(sel)
	task.spawn(function()
		farmCfg.AutofarmMethod = sel
	end)
end)
Window.AddTooltip(farmMethodDd, "Select the auto farm method")

local selectQuestDd = Window.AddDropdown(catSetup, "Quest (for Quest method)", farmCfg.QuestsNames, "None", function(sel)
	task.spawn(function()
		farmCfg.SelectedQuest = sel
		TweenTo(farmCfg.QuestMap[sel][2], true)
	end)
end)

-- == Farm Category ==========================================
Window.AddToggle(catFarm, "Auto Farm", farmToggles.farming, function(state)
	task.spawn(function()
		startAutoFarm(state)
	end)
end)

Window.AddToggle(catFarm, "Attack", farmToggles.attacking, function(state)
	task.spawn(function()
		farmToggles.attacking = state
		while farmToggles.attacking do
			attack()
			task.wait(0.15)
		end
	end)
end)

Window.AddToggle(catFarm, "Auto equip tools", farmToggles.equipTools, function(state)
	task.spawn(function()
		farmToggles.equipTools = state
		while farmToggles.equipTools do
			if farmCfg.SelectedTool == "None" then
				UiLib.Notify("Auto equip tool", "Please select a tool in Setup!", 3)
				task.wait(5)
			else
				equipTool(farmCfg.SelectedTool)
				task.wait(0.5)
			end
		end
	end)
end)

Window.AddConfigPreset({})
UiLib.Run()
