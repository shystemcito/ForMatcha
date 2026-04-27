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
	RunService = game:GetService("RunService"), -- Someday I will use you... maybe
	Places = {
		Sea1 = 77747658251236, -- PlaceId
		Sea2 = 130167267952199, -- PlaceId
	},
}
cons.Player = cons.Players.LocalPlayer
cons.PlayerGui = cons.Player:WaitForChild("PlayerGui")
cons.NPCPath = cons.Workspace:WaitForChild("NPCs")
cons.CurrentPlace = game.PlaceId
cons.Mouse = cons.Player:GetMouse()

local farmCfg = {
	Tools = {},
	SelectedTool = "None",
	CachedToolNumber = nil,
	ScreenScale = 1,

	AutofarmMethod = "Nearest",
	AttackPosition = "Backward",
	SelectedQuest = "None",
	SelectedNPCs = {},
	SelectedAttacks = {},

	ExistingNPCs = {},
	NPCDistance = 10,
	TweenSpeed = 150,
	SafeTween = false,
	isTweening = false,

	CurrentSpawnpointAddress = nil,

	QuestMap = {
		None = {},
		Sea1 = {
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
			Quest17 = {"QuestNPC17", Vector3.new(-1408, 1603, 1642.2), "Quincy", {10750,11500}},
			Quest18 = {"QuestNPC18", Vector3.new(-1786.6, 7, -744.6), "Ninja", {11500,12000}},
			Quest19 = {"QuestNPC19", Vector3.new(67, -1.1, 1758.8), "ArenaFighter", {12000,12750}},
		},
		Sea2 = {
			Quest20 = {"QuestNPC20", Vector3.new(-351.78, -3.65, -189.18), "Delinquent", {12750, 13000}},
			Quest21 = {"QuestNPC21", Vector3.new(-204.35, 22.26, -375.94), "StrongFighter", {13000, 13500}},
			Quest22 = {"QuestNPC22", Vector3.new(-3091.72, 8.44, -586.49), "StrongBandit", {13500, 14500}},
			Quest23 = {"QuestNPC23", Vector3.new(-1644.26, 3.68, 1718.2), "FastNinja", {14500, 99999}},
		}
	},
	QuestsNames = {},

	QuestPieces = {
		None = {},
		Sea1 = {
			SlimePieces = {
				Piece1 = {"Slime Piece #1", Vector3.new(-852.5076, 2, -317.2415)},
				Piece2 = {"Slime Piece #2", Vector3.new(-435.9127, 24, -1188.6091)},
				Piece3 = {"Slime Piece #3", Vector3.new(66.1644, 36, -144.8689)},
				Piece4 = {"Slime Piece #4", Vector3.new(-581.1964, 58, 316.1762)},
				Piece5 = {"Slime Piece #5", Vector3.new(1749.9921, 9, 496.5012)},
				Piece6 = {"Slime Piece #6", Vector3.new(-431.0014, 23, 1401.0228)},
				Piece7 = {"Slime Piece #7", Vector3.new(790.4694, 70, -2309.6760)},
			},
			DungeonPieces = {
				Piece1 = {"Ancient Piece #1", Vector3.new(86.1230, 10.0369, -134.0189)},
				Piece2 = {"Ancient Piece #2", Vector3.new(-391.6785, 0.6315, 508.6844)},
				Piece3 = {"Ancient Piece #3", Vector3.new(-1058.0981, 6.3670, -306.4064)},
				Piece4 = {"Ancient Piece #4", Vector3.new(-314.2175, -1.1388, -1190.7639)},
				Piece5 = {"Ancient Piece #5", Vector3.new(1712.8916, 139.9440, -29.3113)},
				Piece6 = {"Ancient Piece #6", Vector3.new(-686.2745, 99.6920, 1338.5193)},
			},
			HogyokuFragments = {
				Piece1 = {"Fragment #1", Vector3.new(-424, 60, -1235)},
				Piece2 = {"Fragment #2", Vector3.new(1636, 87, 247)},
				Piece3 = {"Fragment #3", Vector3.new(-636, 27, 1206)},
				Piece4 = {"Fragment #4", Vector3.new(648, 140, -2069)},
				Piece5 = {"Fragment #5", Vector3.new(-1206, 33, 463)},
				Piece6 = {"Fragment #6", Vector3.new(-906, 18, -1260)},
			},
			FragmentPieces = {
				Piece1 = {'Spot1', Vector3.new(57, 5, -358)},
				Piece2 = {'Spot2', Vector3.new(265, 105, -292)},
				Piece3 = {'Spot3', Vector3.new(-672, 35, -522)},
				Piece4 = {'Spot4', Vector3.new(-782, 15, -296)},
				Piece5 = {'Spot5', Vector3.new(-495, 5, -1104)},
				Piece6 = {'Spot6', Vector3.new(1819, 145, -85)},
				Piece7 = {'Spot7', Vector3.new(1410, 190, 579)},
				Piece8 = {'Spot8', Vector3.new(-601, 5, 954)},
				Piece9 = {'Spot9', Vector3.new(-826, 55, 1178)},
				Piece10 = {'Spot10', Vector3.new(627, 75, -2379)},
				Piece11 = {'Spot11', Vector3.new(587, 210, -2135)},
				Piece12 = {'Spot12', Vector3.new(-1108, 15, 146)},
				Piece13 = {'Spot13', Vector3.new(-1430, 5, 397)},
				Piece14 = {'Spot14', Vector3.new(881, 40, 1286)},
				Piece15 = {'Spot15', Vector3.new(1057, 100, 1481)},
				Piece16 = {'Spot16', Vector3.new(-936, 95, -1218)},
				Piece17 = {'Spot17', Vector3.new(-1573, 40, -1418)},
				Piece18 = {'Spot18', Vector3.new(-1744, 85, -749)},
				Piece19 = {'Spot19', Vector3.new(20, 0, 2079.8999)},
				Piece20 = {'Spot20', Vector3.new(-56, 10, 1826.6602)},
			},
			TimedEasterEggs = {
				Piece1 = {"Timed Spot 1", Vector3.new(264, 100, -290)},
				Piece2 = {"Timed Spot 2", Vector3.new(-725, 80, -318)},
				Piece3 = {"Timed Spot 3", Vector3.new(-496, 3, -1136)},
				Piece4 = {"Timed Spot 4", Vector3.new(1827, 53, 200)},
				Piece5 = {"Timed Spot 5", Vector3.new(502, 18, -2435)},
				Piece6 = {"Timed Spot 6", Vector3.new(-1402, 60, -1697)},
				Piece7 = {"Timed Spot 7", Vector3.new(1162, 23, 1489)},
				Piece8 = {"Timed Spot 8", Vector3.new(-7, 0, 1796)},
			},
			HiddenEasterEggs = {
				Piece1 = {"Hidden Spot 1", Vector3.new(-415, 30, 457)},
				Piece2 = {"Hidden Spot 2", Vector3.new(-279, 55, -1264)},
				Piece3 = {"Hidden Spot 3", Vector3.new(290, 143, 956)},
			},
			BossEasterEggs = {
				Piece1 = {"Boss Spot 1", Vector3.new(13, 7, -108)},
				Piece2 = {"Boss Spot 2", Vector3.new(-210, 12, -1099)},
				Piece3 = {"Boss Spot 3", Vector3.new(-982, 7, -667)},
				Piece4 = {"Boss Spot 4", Vector3.new(605, 2, -1847)},
				Piece5 = {"Boss Spot 5", Vector3.new(1516, 30, -90)},
				Piece6 = {"Boss Spot 6", Vector3.new(414, 26, 973)},
				Piece7 = {"Boss Spot 7", Vector3.new(-1365, 18, 40)},
				Piece8 = {"Boss Spot 8", Vector3.new(-1382, 26, -1093)},
			},
		},
		Sea2 = {},
	},

	BossesMap = {
		None = {},
		Sea1 = {
			-- Timed (Normal bosses)
			Boss1 = {"JinwooBoss", Vector3.new(250, 50, 930)},
			Boss2 = {"AlucardBoss", Vector3.new(250, 50, 930)},
			Boss3 = {"GojoBoss", Vector3.new(1858, 50, 338.14)},
			Boss4 = {"YujiBoss", Vector3.new(1537, 50, 226.11)},
			Boss5 = {"SukunaBoss", Vector3.new(1571, 150, -34)},
			Boss6 = {"AizenBoss", Vector3.new(-567, 50, 1228)},
			Boss7 = {"StrongestShinobiBoss", Vector3.new(-2110.6, 50, -595)},
			Boss8 = {"YamatoBoss", Vector3.new(-1422, 50, -1383)},
			-- Spawned by players
			Boss9 = {"SaberBoss", Vector3.new(776, 50, -1091)},
			Boss10 = {"QinShiBoss", Vector3.new(776, 50, -1091)},
			Boss11 = {"IchigoBoss", Vector3.new(776, 50, -1091)},
			Boss12 = {"GilgameshBoss", Vector3.new(776, 50, -1091)},
			Boss13 = {"BlessedMaidenBoss", Vector3.new(776, 50, -1091)},
			Boss14 = {"SaberAlterBoss", Vector3.new(776, 50, -1091)},
			Boss15 = {"MoonSlayerBoss", Vector3.new(776, 50, -1091)},
			Boss16 = {"IceQueenBoss", Vector3.new(776, 50, -1091)},
			Boss17 = {"AtomicBoss_Normal", Vector3.new(56, 50, 1966)},
			Boss18 = {"RimuruBoss_Normal", Vector3.new(-1363, 50, 221)},
			Boss19 = {"GreatMageBoss_Normal", Vector3.new(2481, 50, 2053)},
			Boss20 = {"StrongestofTodayBoss_Normal", Vector3.new(136, 50, -2431)},
			Boss21 = {"StrongestinHistoryBoss_Normal", Vector3.new(611, 50, -2315)},
		},
		Sea2 = {
			Boss1 = {"CosmicBeingBoss_Normal", Vector3.new(-1825, 50, 1943)}, -- Idk more bosses in sea 2,
			-- Reminder: Add spawn bosses later
		},
	},
	bossNames = {},
	ExcludedBosses = {},
};
local currentSea = "None"
for seaName, placeId in cons.Places do
	if cons.CurrentPlace == placeId then
		currentSea = seaName
		break
	end
end

if farmCfg.QuestMap[currentSea] then
	for questKey in farmCfg.QuestMap[currentSea] do 
		table.insert(farmCfg.QuestsNames, questKey) 
	end
end

table.sort(farmCfg.QuestsNames, function(a, b)
	local numA = tonumber(string.match(a, "%d+")) or 0
	local numB = tonumber(string.match(b, "%d+")) or 0
	return numA < numB
end)

table.clear(farmCfg.bossNames)
if farmCfg.BossesMap[currentSea] then
	for _, data in farmCfg.BossesMap[currentSea] do 
		local cleanName = string.split(data[1], "_")[1]
		
		if not table.find(farmCfg.bossNames, cleanName) then
			table.insert(farmCfg.bossNames, cleanName) 
		end
	end
	table.sort(farmCfg.bossNames)
end

local farmToggles = {
	attacking = false,
	farming = false,
	equipTools = false,
	bossPrioritize = false,
	AntiAfk = false,
	UseSpawnpoints = true,
	AutoCancelQuests = false,
}

local tokens = {
	tweenToken = 0,
	antiAfkToggle = 0,
	attackToggle = 0,
	autoEquipToolToggle = 0,
	autoCancelQuestsToggle = 0,
	autoFarmToggle = 0,
}

-- == Helpers ==========================================
local function getScreenScale()
	mousemoveabs(0, 0)
	task.wait(0.01)
	
	local startLogX = cons.Mouse.X
	local testDistance = 100
	for i = 1, 10 do
		mousemoverel(10, 0)
		task.wait(0.01)
	end
	task.wait(0.05)
	
	local endLogX = cons.Mouse.X
	local logicalMoved = math.abs(endLogX - startLogX)
	
	if logicalMoved == 0 then return 1 end
	
	local rawScale = logicalMoved / testDistance 
	local snappedScale = math.round(rawScale * 4) / 4
	local finalScale = math.clamp(snappedScale, 1, 3)
	
	for i = 1, 10 do
		mousemoverel(-10, 0)
		task.wait(0.01)
	end
	
	return finalScale
end
farmCfg.ScreenScale = getScreenScale()

local function walkMouseTo(targetX, targetY, stepSize, tolX, tolY, scale)
	local failsafe = 0 
	while true do
		task.wait(0.01)
		failsafe = failsafe + 1
		
		if failsafe > 150 then 
			break 
		end
		
		local currentX = cons.Mouse.X
		local currentY = cons.Mouse.Y
		
		local diffX = targetX - currentX
		local diffY = targetY - currentY
		
		if math.abs(diffX) <= tolX and math.abs(diffY) <= tolY then 
			break 
		end
		
		local distance = math.sqrt((diffX * diffX) + (diffY * diffY))
		local moveX = (diffX / distance) * stepSize
		local moveY = (diffY / distance) * stepSize
		
		local finalPhysicalMoveX = moveX / scale
		local finalPhysicalMoveY = moveY / scale
		
		mousemoverel(finalPhysicalMoveX, finalPhysicalMoveY)
	end
end

local function ClickGui(btn)
	if isrbxactive() then
		local startX = cons.Mouse.X
		local startY = cons.Mouse.Y

		local logicX = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
		local logicY = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2)
		local viewport = cons.Workspace.CurrentCamera.ViewportSize

		if logicX < 0 or logicY < 0 or logicX > viewport.X or logicY > viewport.Y then
			return false 
		end

		local btnTargetX = logicX * farmCfg.ScreenScale
		local btnTargetY = logicY * farmCfg.ScreenScale
		
		local btnTolX = math.max(1, ((btn.AbsoluteSize.X * farmCfg.ScreenScale) / 2) - 5)
		local btnTolY = math.max(1, ((btn.AbsoluteSize.Y * farmCfg.ScreenScale) / 2) - 5)

		walkMouseTo(btnTargetX, btnTargetY, 15, btnTolX, btnTolY, farmCfg.ScreenScale)
		mousemoverel(math.random(-2, 2), math.random(-2, 2))
		task.wait(0.01)
		mouse1click()
		task.wait(0.05)
		walkMouseTo(startX, startY, 15, 10, 10, farmCfg.ScreenScale)
	end
end

local function getRoot(Model)
	if Model.ClassName ~= "Model" then return nil end
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
	for _, tool in cons.Player.Backpack:GetChildren() do
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
		if toolEquipped and toolEquipped.ClassName == "Tool" then return end
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
			if table.find(farmCfg.ExcludedBosses, npc.Name) then continue end
			
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
				if table.find(farmCfg.ExcludedBosses, exactName) then continue end
				
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

local function findNearestBoss(filterNamesExclusion)
	local character = cons.Player.Character
	local root = getRoot(character)

	if not root then return nil, nil end

	local nearestBoss = nil
	local nearestPos = nil
	local bestDist = math.huge

	local function isExcluded(npcName)
		if not filterNamesExclusion then return false end
		local cleanName = string.split(npcName, "_")[1]
		return table.find(filterNamesExclusion, cleanName) ~= nil
	end

	for _, npc in cons.NPCPath:GetChildren() do
		if npc.ClassName == "Model" and (npc:GetAttribute("_IsTimedBoss")) then
			if not isExcluded(npc.Name) then
				local humanoid = getHumanoid(npc)
				if humanoid and humanoid.Health > 0 then
					local npcRoot = getRoot(npc)
					if npcRoot then
						local dist = (npcRoot.Position - root.Position).Magnitude
						if dist < bestDist then
							bestDist = dist
							nearestBoss = npc
							nearestPos = npcRoot.Position
						end
					end
				end
			end
		end
	end	

	if not nearestBoss then
		if farmCfg.BossesMap[currentSea] then
			local difficulties = {"_Normal", "_Medium", "_Hard", "_Extreme"}

			for _, bossData in farmCfg.BossesMap[currentSea] do
				local cleanDataName = string.split(bossData[1], "_")[1]
				local spawnPos = bossData[2]

				if not isExcluded(cleanDataName) then
					local npc = nil
					local possibleNames = {cleanDataName}
					for _, diff in difficulties do
						table.insert(possibleNames, cleanDataName .. diff)
					end

					for _, exactName in possibleNames do
						local child = cons.NPCPath:FindFirstChild(exactName)
						if child and child.ClassName == "Model" then
							npc = child
							break 
						end
					end

					if npc then
						local humanoid = getHumanoid(npc)
						if humanoid and humanoid.Health > 0 then
							local npcRoot = getRoot(npc)
							local targetPos = npcRoot and (npcRoot.Position + Vector3.new(0, 20, 0)) or spawnPos
							
							local dist = (targetPos - root.Position).Magnitude
							if dist < bestDist then
								bestDist = dist
								nearestBoss = npc
								nearestPos = targetPos
							end
						end
					end
				end
			end
		end
	end
	
	return nearestBoss, nearestPos
end

-- == Farm Utilities ==========================================
local function TweenTo(targetPos, lift, targetInstance, isManual) 
	tokens.tweenToken += 1
	local myToken = tokens.tweenToken

	local character = cons.Player.Character
	if not character then return end
	local root = getRoot(character)
	local humanoid = getHumanoid(character)
	
	if not root or not humanoid or humanoid.Health <= 0 then return end
	if not isManual and not farmToggles.farming then return end 

	farmToggles.isTweening = true

	local startPos = root.Position
	local distance = (targetPos - startPos).Magnitude
	local duration = distance / farmCfg.TweenSpeed

	local steps = math.max(1, math.floor(duration / 0.03))
	local stepTime = duration / steps

	for i = 1, steps do
		if tokens.tweenToken ~= myToken then return end

		character = cons.Player.Character
		root = getRoot(character)
		humanoid = getHumanoid(character)
		
		if not isManual and not farmToggles.farming then
			if root then root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
			if tokens.tweenToken == myToken then farmToggles.isTweening = false end
			return
		end

		if not character or not root or not humanoid or humanoid.Health <= 0 then 
			if tokens.tweenToken == myToken then farmToggles.isTweening = false end
			return
		end
		
		if targetInstance then
			local targetHum = getHumanoid(targetInstance)
			if not targetInstance.Parent or not targetHum or targetHum.Health <= 0 then
				if root then root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
				if tokens.tweenToken == myToken then farmToggles.isTweening = false end
				return 
			end
		end

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

	if tokens.tweenToken == myToken then
		character = cons.Player.Character
		root = getRoot(character)
		humanoid = getHumanoid(character)
		
		if root and humanoid and humanoid.Health > 0 and (isManual or farmToggles.farming) then
			for i = 1, 10 do
				if tokens.tweenToken ~= myToken then return end
				root.Position = targetPos
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				task.wait()
			end
		end
		
		farmToggles.isTweening = false
	end
end

local function selectQuestForLevel()
	local level = 0
	pcall(function()
		level = cons.Player.Data.Level.Value
	end)

	local bestKey = nil
	local bestMin = -1

	if farmCfg.QuestMap[currentSea] then
		for key, data in farmCfg.QuestMap[currentSea] do
			local levelRange = data[4]
			if level >= levelRange[1] and level <= levelRange[2] then
				if levelRange[1] > bestMin then
					bestMin = levelRange[1]
					bestKey = key
				end
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

local function getQuestStatus(text)
	local current, max = string.match(text, "(%d+)/(%d+)")
	if current and max then
		return tonumber(current), tonumber(max)
	else
		return nil, nil
	end
end

local function readQuestStatus()
	local ok, text = pcall(function()
		return cons.PlayerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestRequirement.Text
	end)
	if not ok then return nil, nil end
	return getQuestStatus(text)
end

local function WaitForNewCharacter(oldAddress)
	while farmToggles.farming do
		local newCharacter = cons.Player.Character
		
		if newCharacter then
			local currentAddress = tostring(newCharacter.Address)

			if currentAddress ~= oldAddress then
				local root = getRoot(newCharacter)
				local humanoid = getHumanoid(newCharacter)
				
				if root and humanoid and humanoid.Health > 0 then
					task.wait(0.1)
					return newCharacter
				end
			end
		end
		task.wait(0.5)
	end
	return nil
end

-- == Auto Farm Logic ==========================================
local function getSpawnpointAddress(spawnpoint)
	if not spawnpoint then return nil end
	return tostring(spawnpoint.Address)
end

local function handleSpawnpoint()
	if not farmToggles.UseSpawnpoints then return false end

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
	for i = 1,60 do
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		root.Position = spawnRoot.Position + Vector3.new(0, 5, 0)
		task.wait(0.05)
	end
	keyrelease(keyMap.E)

	farmCfg.CurrentSpawnpointAddress = address
	return true
end

-- == Farm Utilities ==========================================
local function attackNPC(npc, myToken)
	if not farmToggles.farming then return end

	local npcRoot = getRoot(npc)
	if not npcRoot then return end
	
	local lastPosUpdate = 0 
	local updateInterval = 3
	local targetPosition = npcRoot.Position

	while farmToggles.farming do
		if tokens.autoFarmToggle ~= myToken then break end
		
		local character = cons.Player.Character
		if not character then break end

		local playerHumanoid = getHumanoid(character)
		local npcHumanoid = getHumanoid(npc)

		if not playerHumanoid or playerHumanoid.Health <= 0 then 
			local oldCharAddress = tostring(character.Address)
			WaitForNewCharacter(oldCharAddress)
			break 
		end
		
		if not npcHumanoid or npcHumanoid.Health <= 0 then break end
		if not npcRoot then break end

		if farmCfg.AttackPosition == "Backward" or farmCfg.AttackPosition == "Front" or os.clock() - lastPosUpdate >= updateInterval then
			local dist = farmCfg.NPCDistance
			
			if farmCfg.AttackPosition == "Bottom" then
				targetPosition = (npcRoot.CFrame * CFrame.new(0, -dist, 0)).Position
			elseif farmCfg.AttackPosition == "Backward" then
				targetPosition = (npcRoot.CFrame * CFrame.new(0, 0, dist)).Position
			elseif farmCfg.AttackPosition == "Front" then
				targetPosition = (npcRoot.CFrame * CFrame.new(0, 0, -dist)).Position
			else
				targetPosition = (npcRoot.CFrame * CFrame.new(0, dist, 0)).Position
			end
			
			lastPosUpdate = os.clock()
		end

		local root = getRoot(character)

		if root then
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			root.CFrame = CFrame.lookAt(targetPosition, npcRoot.Position)
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		end

		task.wait()
	end
end

local function runFarmNearest(filtered, myToken)
	while farmToggles.farming do
		if tokens.autoFarmToggle ~= myToken then break end
		
		local targetNPC = nil
		local targetPos = nil
		
		if farmToggles.bossPrioritize then
			targetNPC, targetPos = findNearestBoss(farmCfg.ExcludedBosses)
		end
		
		if not targetNPC then
			local filter = (filtered and #farmCfg.SelectedNPCs > 0) and farmCfg.SelectedNPCs or nil
			targetNPC = findNearestNPC(filter)
			
			if targetNPC then
				local npcRoot = getRoot(targetNPC)
				if npcRoot then
					targetPos = npcRoot.Position
				end
			end
		end

		if not targetNPC or not targetPos then
			task.wait(1)
			continue
		end

		TweenTo(targetPos + Vector3.new(0, 50, 0), true, targetNPC)
		if tokens.autoFarmToggle ~= myToken or not farmToggles.farming then break end

		local spawnChanged = handleSpawnpoint()
		if tokens.autoFarmToggle ~= myToken or not farmToggles.farming then break end

		if spawnChanged then
			TweenTo(targetPos + Vector3.new(0, 50, 0), true, targetNPC)
		end
		if tokens.autoFarmToggle ~= myToken or not farmToggles.farming then break end

		attackNPC(targetNPC, myToken)
		task.wait(0.1)
	end
end

local function runFarmQuest(autoLevel, myToken)
	local forceGoToNPC = true 

	while farmToggles.farming do
		if tokens.autoFarmToggle ~= myToken then break end
		
		local targetBoss = nil
		local targetPos = nil
		
		if farmToggles.bossPrioritize then
			targetBoss, targetPos = findNearestBoss(farmCfg.ExcludedBosses)
		end

		if targetBoss and targetPos then
			TweenTo(targetPos + Vector3.new(0, 50, 0), true, targetBoss)
			if tokens.autoFarmToggle ~= myToken or not farmToggles.farming then break end

			local spawnChanged = handleSpawnpoint()
			if spawnChanged then
				TweenTo(targetPos + Vector3.new(0, 50, 0), true, targetBoss)
			end

			local bossRoot = getRoot(targetBoss)
			if bossRoot then
				attackNPC(targetBoss, myToken)
			end
			
			forceGoToNPC = true
			task.wait(0.1)
			continue
		end

		local questKey = autoLevel and selectQuestForLevel() or farmCfg.SelectedQuest

		if not questKey or not farmCfg.QuestMap[currentSea] or not farmCfg.QuestMap[currentSea][questKey] then
			task.wait(1)
			continue
		end

		local questData = farmCfg.QuestMap[currentSea][questKey]
		local questPos = questData[2]
		local enemyName = questData[3]

		local currentProgress, maxProgress = readQuestStatus()

		if forceGoToNPC or currentProgress == nil then
			TweenTo(questPos, true)
			if tokens.autoFarmToggle ~= myToken or not farmToggles.farming then break end

			local spawnChanged = handleSpawnpoint()
			if tokens.autoFarmToggle ~= myToken or not farmToggles.farming then break end

			if spawnChanged then
				TweenTo(questPos, true)
				if tokens.autoFarmToggle ~= myToken or not farmToggles.farming then break end
			end

			for i = 1, 5 do
				keypress(keyMap.E)
				keyrelease(keyMap.E)
				task.wait(0.1)
			end

			task.wait(0.5) 
			currentProgress, maxProgress = readQuestStatus()

			forceGoToNPC = false 
		end

		local npc = findNearestNPC({enemyName})
		if not npc then
			task.wait(1)
			continue
		end

		local npcRoot = getRoot(npc)
		if npcRoot then
			TweenTo(npcRoot.Position + Vector3.new(0, 50, 0), true, npc)
		end
		if tokens.autoFarmToggle ~= myToken or not farmToggles.farming then break end

		local progressBeforeKill = currentProgress or 0

		attackNPC(npc, myToken)

		local npcHumanoid = getHumanoid(npc)
		if npcHumanoid and npcHumanoid.Health <= 0 then
			task.wait(0.3) 

			local newProgress, newMax = readQuestStatus()

			if newProgress == progressBeforeKill then
				forceGoToNPC = true
			else
				forceGoToNPC = false
				currentProgress = newProgress
			end
		end

		task.wait(0.1)
	end
end

local function startAutoFarm(state)
	farmToggles.farming = state
	
	if state then
		tokens.autoFarmToggle += 1
		local myToken = tokens.autoFarmToggle
		
		task.spawn(function()
			local method = farmCfg.AutofarmMethod

			if method == "Nearest" then
				runFarmNearest(false, myToken)
			elseif method == "Selected" then
				runFarmNearest(true, myToken)
			elseif method == "Quest" then
				runFarmQuest(false, myToken)
			elseif method == "LevelUp" then
				runFarmQuest(true, myToken)
			end
		end)
	else
		tokens.autoFarmToggle += 1
	end
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
local catQuests = Window.AddCategory("Quests")

-- == Setup Category ==========================================
-- == Tools section ==========================================
Window.AddSection(catSetup, "Tools")
local toolsDd = Window.AddDropdown(catSetup, "Tool select", farmCfg.Tools, "None", function(sel)
	task.spawn(function()
		farmCfg.SelectedTool = sel
	end)
end)
Window.AddTooltip(toolsDd, "Select a tool for autofarming")


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
Window.AddTooltip(attacksDd, "Select auto-attacks for the autofarm")

local toolUpdtateBtn = Window.AddButton(catSetup, "Refresh tools", function()
	refreshTools()
	farmCfg.SelectedTool = "None"
	toolsDd:SetOptions(farmCfg.Tools, "None")
	UiLib.Notify("Tool update", "List of tools updated", 2)
end)
Window.AddTooltip(toolUpdtateBtn, "Update the list of tools")

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
Window.AddTooltip(NPCsUpdateBtn, "Update the list of NPCs")

local safeTweenTgl = Window.AddToggle(catSetup, "Safe tween", farmCfg.SafeTween, function(state)
	farmCfg.SafeTween = state
end)
Window.AddTooltip(safeTweenTgl, "This Tween will use dash movement")

Window.AddSlider(catSetup, "Tween Speed", 16, 200, farmCfg.TweenSpeed, function(val)
	farmCfg.TweenSpeed = math.floor(val)
end)

local attackPosDd = Window.AddDropdown(catSetup, "Attack Position", {"Upward", "Bottom", "Backward", "Front"}, farmCfg.AttackPosition, function(sel)
	task.spawn(function()
		farmCfg.AttackPosition = sel
	end)
end)
Window.AddTooltip(attackPosDd, "Select attack position | Note: If using Bottom, enable Noclip in the Matcha menu")

Window.AddSlider(catSetup, "NPC Distance", 1, 20, farmCfg.NPCDistance, function(val)
	farmCfg.NPCDistance = math.floor(val)
end)
-- == Misc section ==================================
Window.AddSection(catSetup, "Misc")
local antiAfkTgl = Window.AddToggle(catSetup, "Anti-AFK", farmToggles.AntiAfk, function(state)
	farmToggles.AntiAfk = state
	
	if state then
		tokens.antiAfkToggle += 1
		local myToken = tokens.antiAfkToggle
		
		task.spawn(function()
			while farmToggles.AntiAfk do
				task.wait(600)
				if tokens.antiAfkToggle ~= myToken or not farmToggles.AntiAfk then break end
				
				if not isrbxactive() then continue end
				mousemoverel(-10, 0)
				task.wait(0.1)
				mousemoverel(10, 0)
			end
		end)
	else
		tokens.antiAfkToggle += 1
	end
end)
Window.AddTooltip(antiAfkTgl, "This will avoid getting you disconnected after 20 minutes (ROBLOX WINDOWS MUST BE ACTIVE)")

-- == Farm Category ==========================================
-- == FarmConfig Section ==========================================
Window.AddSection(catFarm, "Farm config")

local farmMethodDd = Window.AddDropdown(catFarm, "Farm method", {"Nearest", "Selected", "Quest", "LevelUp"}, farmCfg.AutofarmMethod, function(sel)
	task.spawn(function()
		farmCfg.AutofarmMethod = sel
		if farmToggles.farming then
			startAutoFarm(true)
		end
	end)
end)
Window.AddTooltip(farmMethodDd, "Select the auto farm method")

local selectQuestDd = Window.AddDropdown(catFarm, "Quest (for Quest method)", farmCfg.QuestsNames, "None", function(sel)
	task.spawn(function()
		farmCfg.SelectedQuest = sel
		--TweenTo(farmCfg.QuestMap[currentSea][sel][2], true)
	end)
end)

-- == Auto Farm Section ==========================================
Window.AddSection(catFarm, "Auto Farming")
Window.AddToggle(catFarm, "Auto Farm", farmToggles.farming, function(state)
	task.spawn(function()
		startAutoFarm(state)
	end)
end)
task.spawn(function()
	while true do
		task.wait(1200)
		if farmToggles.farming then
			startAutoFarm(true)
		end
	end
end)

Window.AddToggle(catFarm, "Attack", farmToggles.attacking, function(state)
	farmToggles.attacking = state
	if state then
		tokens.attackToggle += 1
		local myToken = tokens.attackToggle
		task.spawn(function()
			while farmToggles.attacking do
				if tokens.attackToggle ~= myToken or not farmToggles.attacking then break end
				if not farmToggles.isTweening then
					attack()
				end
				task.wait(0.15)
			end
		end)
	else
		tokens.attackToggle += 1
	end
end)

local AutoEquipTgl = Window.AddToggle(catFarm, "Auto equip tools", farmToggles.equipTools, function(state)
	farmToggles.equipTools = state
	if state then
		tokens.autoEquipToolToggle += 1
		local myToken = tokens.autoEquipToolToggle
		task.spawn(function()
			while farmToggles.equipTools do
				if tokens.autoEquipToolToggle ~= myToken or not farmToggles.equipTools then break end
				
				if farmCfg.SelectedTool == "None" then
					UiLib.Notify("Auto equip tool", "Please select a tool in Setup!", 3)
					task.wait(5)
				else
					equipTool(farmCfg.SelectedTool)
					task.wait(0.5)
				end
			end
		end)
	else
		tokens.autoEquipToolToggle += 1
	end
end)
Window.AddTooltip(AutoEquipTgl, "Auto-Equip choosen tool in Farm Setup")


-- == Bosses Section ==========================================
Window.AddSection(catFarm, "Bosses")

local PrioBossCbx = Window.AddCheckbox(catFarm, "Prioritize bosses", farmToggles.bossPrioritize, function(state)
	farmToggles.bossPrioritize = state
end)
Window.AddTooltip(PrioBossCbx, "Check if there are bosses to kill")

local excludedBossesLabel = Window.AddValueLabel(catFarm, "Excluded Bosses", "None")
local excludeBossDd = Window.AddDropdown(catFarm, "Exclude / Include Boss", farmCfg.bossNames, "None", function(sel)
	task.spawn(function()
		if sel == "None" then return end 
		local index = table.find(farmCfg.ExcludedBosses, sel)
		if index then
			table.remove(farmCfg.ExcludedBosses, index)
		else
			table.insert(farmCfg.ExcludedBosses, sel)
		end

		if #farmCfg.ExcludedBosses > 0 then
			excludedBossesLabel:SetValue(table.concat(farmCfg.ExcludedBosses, ", "))
		else
			excludedBossesLabel:SetValue("None")
		end
	end)
end)
Window.AddTooltip(excludeBossDd, "Select bosses you want to ignore")

-- == Extras Section ==========================================
Window.AddSection(catFarm, "Extras")
local useSpawnpointsTgl = Window.AddToggle(catFarm, "Use spawnpoints", farmToggles.UseSpawnpoints, function(state)
	task.spawn(function()
		farmToggles.UseSpawnpoints = state
	end)
end)
Window.AddTooltip(useSpawnpointsTgl, "Use map spawnpoints while autofarming")

local autoCancelQuestTgl = Window.AddToggle(catFarm, "Auto cancel quest", farmToggles.AutoCancelQuests, function(state)
	farmToggles.AutoCancelQuests = state
	if state then
		tokens.autoCancelQuestsToggle += 1
		local myToken = tokens.autoCancelQuestsToggle
		
		task.spawn(function()
			while farmToggles.AutoCancelQuests do
				task.wait(900)
				if tokens.autoCancelQuestsToggle ~= myToken or not farmToggles.AutoCancelQuests then break end
				pcall(function()
					local CloseButton = cons.Player.PlayerGui.QuestUI.Quest.Quest.Holder.Content.Exit.CloseButton
					ClickGui(CloseButton)
				end)
			end
		end)
	else
		tokens.autoCancelQuestsToggle += 1
	end
end)
Window.AddTooltip(autoCancelQuestTgl, "Auto cancel current quest every 15 minutes.")

local scaleLabel = Window.AddValueLabel(catFarm, "Scale Info", "Screen scale: " .. tostring(farmCfg.ScreenScale))
local recalcScaleBtn = Window.AddButton(catFarm, "Re-Calculate Scale (Fix AutoCancel)", function()
	task.spawn(function()
		for i = 3, 1, -1 do
			scaleLabel:SetValue("Calculating in " .. i .. "s, don't move your mouse...")
			task.wait(1)
		end
		scaleLabel:SetValue("Calculating...")
		farmCfg.ScreenScale = getScreenScale()
		scaleLabel:SetValue("Screen scale: " .. tostring(farmCfg.ScreenScale))
	end)
end)
Window.AddTooltip(recalcScaleBtn, "Click this if the script misses the cancel button on quests")

-- == Quests Category ==========================================
local hasQuestPieces = false
if farmCfg.QuestPieces[currentSea] and next(farmCfg.QuestPieces[currentSea]) then
	hasQuestPieces = true
end

if hasQuestPieces then
	for groupName, piecesList in farmCfg.QuestPieces[currentSea] do
		Window.AddSection(catQuests, groupName)
		
		local pieceNames = {}
		local pieceDataMap = {}
		
		for key, data in piecesList do
			table.insert(pieceNames, data[1])
			pieceDataMap[data[1]] = data[2]
		end
		
		table.sort(pieceNames, function(a, b)
			local numA = tonumber(string.match(a, "%d+")) or 0
			local numB = tonumber(string.match(b, "%d+")) or 0
			return numA < numB
		end)
		
		table.insert(pieceNames, 1, "None")
		
		Window.AddDropdown(catQuests, "Go to " .. groupName, pieceNames, "None", function(sel)
			task.spawn(function()
				if sel ~= "None" and pieceDataMap[sel] then
					TweenTo(pieceDataMap[sel], true, nil, true) 
				end
			end)
		end)
	end
else
	Window.AddSection(catQuests, "No quest pieces available in this sea")
end

Window.AddConfigPreset({})
UiLib.Run()
