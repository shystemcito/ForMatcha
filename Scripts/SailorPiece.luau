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
			DemoniteFragments = {
				Piece1 = {"Demonite Fragment #1", Vector3.new(1006, 12, 1130)},
				Piece2 = {"Demonite Fragment #2", Vector3.new(920, 70, 1478)},
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
			Boss22 = {"TrueAizenBoss_Normal", Vector3.new(-1199, 1650, 1775)},
			Boss23 = {"AnosBoss_Normal", Vector3.new(950, 50, 1378)}
		},
		Sea2 = {
			Boss1 = {"CosmicBeingBoss_Normal", Vector3.new(-1825, 50, 1943)}, -- Idk more bosses in sea 2,
			Boss2 = {"TheWorldBoss_Normal", Vector3.new(-3354, 9, -955)},
			-- Reminder: Add spawn bosses later
		},
	},
	bossNames = {},
	ExcludedBosses = {},
	NPCsMap = {
		Sea1 = {
			Npc1 = {"Thief", Vector3.new(177, 50, -157)},
			Npc2 = {"ThiefBoss", Vector3.new(-66, 50, -162)},
			Npc3 = {"DesertBandit", Vector3.new(-793, 50, -433)},
			Npc4 = {"FrostRogue", Vector3.new(-410, 50, -990)},
			Npc5 = {"SnowBoss", Vector3.new(-594, 80, -1060)},
			Npc6 = {"Sorcerer", Vector3.new(1398, 50, 488)},
			Npc7 = {"PandaMiniBoss", Vector3.new(1688, 60, 513)},
			Npc8 = {"Hollow", Vector3.new(-365, 50, 1097)},
			Npc9 = {"Monkey", Vector3.new(-567, 50, 399)},
			Npc10 = {"MonkeyBoss", Vector3.new(-494, 100, 496)},
			Npc11 = {"StrongSorcerer", Vector3.new(666, 50, -1695)},
			Npc12 = {"Curse", Vector3.new(-18, 50, -1845)},
			Npc13 = {"Slime", Vector3.new(-1124, 60, 371)},
			Npc14 = {"AcademyTeacher", Vector3.new(1072, 50, 1275)},
			Npc15 = {"Swordsman", Vector3.new(-1274, 50, -1191)},
			Npc16 = {"Quincy", Vector3.new(-1339, 1650, 1617)},
			Npc17 = {"Ninja", Vector3.new(-1876, 60, -738)},
			Npc18 = {"ArenaFighter", Vector3.new(59, 50, 1816)},
			Npc19 = {"Bunny", Vector3.new(2306, 60, 2224)},
		},
		Sea2 = {
			Npc1 = {"Delinquent", Vector3.new(-325, 50, -119)},
			Npc2 = {"StrongFighter", Vector3.new(-194, 70, -450)},
			Npc3 = {"StrongBandit", Vector3.new(-3075, 60, -667)},
			Npc4 = {"FastNinja", Vector3.new(-1579, 50, 1846)},
		},
	},
	NPCsNames = {},
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

if farmCfg.BossesMap[currentSea] then
	for _, data in farmCfg.BossesMap[currentSea] do 
		local cleanName = string.split(data[1], "_")[1]
		
		if not table.find(farmCfg.bossNames, cleanName) then
			table.insert(farmCfg.bossNames, cleanName) 
		end
	end
	table.sort(farmCfg.bossNames)
end

if farmCfg.NPCsMap[currentSea] then
	for _, npcData in farmCfg.NPCsMap[currentSea] do
		local npcName = npcData[1]
		if not table.find(farmCfg.ExistingNPCs, npcName) then
			table.insert(farmCfg.ExistingNPCs, npcName)
		end
	end
	table.sort(farmCfg.ExistingNPCs)
end

local farmToggles = {
	attacking = false,
	autoClicking = false,
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
	autoClickToggle = 0,
	autoEquipToolToggle = 0,
	autoCancelQuestsToggle = 0,
	autoFarmToggle = 0,
	bypassTeleport = false,
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
local function findNearestNPC(filterNames)
	local character = cons.Player.Character
	local root = getRoot(character)

	if not root then return nil, nil end

	local nearestNPC = nil
	local bestDist = math.huge

	local function isExcluded(nameToCheck)
		if not farmCfg.ExcludedBosses or #farmCfg.ExcludedBosses == 0 then return false end
		
		local clean = string.split(nameToCheck, "_")[1]
		local superClean = clean:gsub("%s*%d+$", "")
		
		if table.find(farmCfg.ExcludedBosses, clean) then return true end
		if table.find(farmCfg.ExcludedBosses, superClean) then return true end
		if table.find(farmCfg.ExcludedBosses, nameToCheck) then return true end
		
		return false
	end

	for _, npc in cons.NPCPath:GetChildren() do
		if npc.ClassName == "Model" and npc:FindFirstChild("HumanoidRootPart") and npc.Name ~= "TrainingDummy" then
			if isExcluded(npc.Name) then continue end
			
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

	if nearestNPC then 
		return nearestNPC, getRoot(nearestNPC).Position 
	end

	local bestZoneDist = math.huge
	local fallbackPos = nil

	if farmCfg.NPCsMap[currentSea] then
		for _, npcData in farmCfg.NPCsMap[currentSea] do
			local npcName = npcData[1]
			local zonePos = npcData[2]
			
			if isExcluded(npcName) then continue end
			
			local allowed = (not filterNames or #filterNames == 0) or table.find(filterNames, npcName)
			if allowed then
				local distToZone = (zonePos - root.Position).Magnitude
				if distToZone < bestZoneDist then
					local exists = false
					
					local possibleNames = {npcName}
					for i = 1, 10 do 
						table.insert(possibleNames, npcName .. " " .. tostring(i))
						table.insert(possibleNames, npcName .. tostring(i))
					end
					
					for _, exactName in possibleNames do
						if isExcluded(exactName) then continue end
						
						local foundChild = cons.NPCPath:FindFirstChild(exactName)
						if foundChild and foundChild.ClassName == "Model" then
							exists = true
							break
						end
					end
					
					if exists then
						bestZoneDist = distToZone
						fallbackPos = zonePos
					end
				end
			end
		end
	end

	return nil, fallbackPos
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

	if farmToggles.bypassTeleport and distance > 500 then
		task.wait(0.25)
		for i = 1,100 do
			if tokens.tweenToken ~= myToken then return end
			game.Players.LocalPlayer.Character.HumanoidRootPart.Position = targetPos
			task.wait(0.01)
			keypress(keyMap.Q)
			keyrelease(keyMap.Q)
		end
	else
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
	local selectedIndex = 1

	while farmToggles.farming do
		if tokens.autoFarmToggle ~= myToken then break end
		
		local targetNPC = nil
		local targetPos = nil
		
		if farmToggles.bossPrioritize then
			targetNPC, targetPos = findNearestBoss(farmCfg.ExcludedBosses)
		end
		
		if not targetNPC and not targetPos then
			if filtered and #farmCfg.SelectedNPCs > 0 then
				if selectedIndex > #farmCfg.SelectedNPCs then
					selectedIndex = 1
				end
				
				local currentTargetName = farmCfg.SelectedNPCs[selectedIndex]
				local fNpc, fPos = findNearestNPC({currentTargetName})
				
				targetNPC = fNpc
				targetPos = fPos
				
				if not targetNPC and targetPos then
					local character = cons.Player.Character
					local root = getRoot(character)
					if root then
						local distToZone = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
						
						if distToZone < 100 then 
							selectedIndex = selectedIndex + 1 
							task.wait(0.1)
							continue
						end
					end
				end
			else
				local fNpc, fPos = findNearestNPC(nil)
				targetNPC = fNpc
				targetPos = fPos
			end
		end

		if not targetPos then
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

		if targetNPC then
			attackNPC(targetNPC, myToken)
		end
		
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

		local npc, fallbackPos = findNearestNPC({enemyName})
		local finalPos = nil

		if npc then
			local npcRoot = getRoot(npc)
			if npcRoot then finalPos = npcRoot.Position end
		elseif fallbackPos then
			finalPos = fallbackPos
		end

		if not finalPos then
			task.wait(1)
			continue
		end

		TweenTo(finalPos + Vector3.new(0, 50, 0), true, npc)
		if tokens.autoFarmToggle ~= myToken or not farmToggles.farming then break end

		local progressBeforeKill = currentProgress or 0

		if npc then
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
local catToolSetup = Window.AddCategory("Tool setup")
local catMovement  = Window.AddCategory("Movement")
local catAutoFarm  = Window.AddCategory("Auto Farm")
local catQuests    = Window.AddCategory("Quests")
local catMisc      = Window.AddCategory("Misc")

-- == Tool setup Category =================================
Window.AddSection(catToolSetup, "Tools & Weapons")
local toolsDd = Window.AddDropdown(catToolSetup, "Tool select", farmCfg.Tools, "None", function(sel)
	task.spawn(function()
		farmCfg.SelectedTool = sel
	end)
end)
Window.AddTooltip(toolsDd, "Choose the weapon or tool you want the autofarm to use.")

local toolUpdtateBtn = Window.AddButton(catToolSetup, "Refresh tools", function()
	refreshTools()
	farmCfg.SelectedTool = "None"
	toolsDd:SetOptions(farmCfg.Tools, "None")
	UiLib.Notify("Tool update", "List of tools updated", 2)
end)
Window.AddTooltip(toolUpdtateBtn, "Click to refresh your inventory if a new tool isn't showing up.")

local attackLabel = Window.AddValueLabel(catToolSetup, "Selected attacks", "None")
local attacksDd = Window.AddDropdown(catToolSetup, "Select attacks", {"Z", "X", "C", "V", "F", "J"}, "None", function(sel)
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
Window.AddTooltip(attacksDd, "Pick which skills or hotkeys to spam while attacking.")

local attackTgl = Window.AddToggle(catToolSetup, "Auto Attack", farmToggles.attacking, function(state)
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
Window.AddTooltip(attackTgl, "Enable to start using selected skills.")

local autoClickTgl = Window.AddToggle(catToolSetup, "Auto Click", farmToggles.autoClicking, function(state)
	farmToggles.autoClicking = state
	if state then
		tokens.autoClickToggle += 1
		local myToken = tokens.autoClickToggle
		task.spawn(function()
			while farmToggles.autoClicking do
				if tokens.autoClickToggle ~= myToken or not farmToggles.autoClicking then break end
				if isrbxactive() and not farmToggles.isTweening then
					mouse1click()
				end
				task.wait(0.1)
			end
		end)
	else
		tokens.autoClickToggle += 1
	end
end)
Window.AddTooltip(autoClickTgl, "Enable to start auto-clicking with your mouse.")

local AutoEquipTgl = Window.AddToggle(catToolSetup, "Auto equip tools", farmToggles.equipTools, function(state)
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
Window.AddTooltip(AutoEquipTgl, "Automatically re-equips your chosen tool if you drop it or die.")

-- == Movement Category ===================================
Window.AddSection(catMovement, "Positioning & Tweening")
local safeTweenTgl = Window.AddToggle(catMovement, "Safe tween", farmCfg.SafeTween, function(state)
	farmCfg.SafeTween = state
end)
Window.AddTooltip(safeTweenTgl, "Uses dash logic while flying to targets to avoid anti-cheat kicks.")

local tweenSpeedSld = Window.AddSlider(catMovement, "Tween Speed", 16, 200, farmCfg.TweenSpeed, function(val)
	farmCfg.TweenSpeed = math.floor(val)
end)
Window.AddTooltip(tweenSpeedSld, "Set how fast your character flies towards enemies.")

local npcDistSld = Window.AddSlider(catMovement, "NPC Distance", 1, 20, farmCfg.NPCDistance, function(val)
	farmCfg.NPCDistance = math.floor(val)
end)
Window.AddTooltip(npcDistSld, "Set how far away you want to stand from the enemy while fighting.")

Window.AddSection(catMovement, "Teleport")
local bypassTpTgl = Window.AddToggle(catMovement, "Bypass Teleport", farmToggles.bypassTeleport, function(state)
	farmToggles.bypassTeleport = state
end)
Window.AddTooltip(bypassTpTgl, "Instantly teleports to targets further than 500 studs (Risky!).")

-- == Auto Farm Category ==================================
Window.AddSection(catAutoFarm, "Farm config")
local farmMethodDd = Window.AddDropdown(catAutoFarm, "Farm method", {"Nearest", "Selected", "Quest", "LevelUp"}, farmCfg.AutofarmMethod, function(sel)
	task.spawn(function()
		farmCfg.AutofarmMethod = sel
		if farmToggles.farming then
			startAutoFarm(true)
		end
	end)
end)
Window.AddTooltip(farmMethodDd, "Choose how you want to farm: nearest enemy, specific NPCs, or by quests.")

local selectQuestDd = Window.AddDropdown(catAutoFarm, "Quest (for Quest method)", farmCfg.QuestsNames, "None", function(sel)
	task.spawn(function()
		farmCfg.SelectedQuest = sel
	end)
end)
Window.AddTooltip(selectQuestDd, "Pick the exact quest you want to loop when using 'Quest' method.")

Window.AddSection(catAutoFarm, "Target Settings")
local NPCsLabel = Window.AddValueLabel(catAutoFarm, "Selected NPCs", "None")
local NPCsDd = Window.AddDropdown(catAutoFarm, "Select NPCs", farmCfg.ExistingNPCs, "None", function(sel)
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
Window.AddTooltip(NPCsDd, "Choose specific enemies to hunt when using the 'Selected' farm method.")

local PrioBossCbx = Window.AddCheckbox(catAutoFarm, "Prioritize bosses", farmToggles.bossPrioritize, function(state)
	farmToggles.bossPrioritize = state
end)
Window.AddTooltip(PrioBossCbx, "Forces the bot to drop everything and target a boss if one spawns.")

local excludedBossesLabel = Window.AddValueLabel(catAutoFarm, "Excluded Bosses", "None")
local excludeBossDd = Window.AddDropdown(catAutoFarm, "Exclude / Include Boss", farmCfg.bossNames, "None", function(sel)
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
Window.AddTooltip(excludeBossDd, "Pick bosses you want the autofarm to completely ignore.")

local attackPosDd = Window.AddDropdown(catAutoFarm, "Attack Position", {"Upward", "Bottom", "Backward", "Front"}, farmCfg.AttackPosition, function(sel)
	task.spawn(function()
		farmCfg.AttackPosition = sel
	end)
end)
Window.AddTooltip(attackPosDd, "Where to stand while attacking. Note: Turn on Noclip in Matcha if using 'Bottom'.")

Window.AddSection(catAutoFarm, "Main Toggles")
local autoFarmTgl = Window.AddToggle(catAutoFarm, "Auto Farm", farmToggles.farming, function(state)
	task.spawn(function()
		startAutoFarm(state)
	end)
end)
Window.AddTooltip(autoFarmTgl, "Turn this on to start the main autofarm loop.")

task.spawn(function()
	while true do
		task.wait(1200)
		if farmToggles.farming then
			startAutoFarm(true)
		end
	end
end)

local useSpawnpointsTgl = Window.AddToggle(catAutoFarm, "Use spawnpoints", farmToggles.UseSpawnpoints, function(state)
	task.spawn(function()
		farmToggles.UseSpawnpoints = state
	end)
end)
Window.AddTooltip(useSpawnpointsTgl, "Automatically claims the nearest crystal spawnpoint while farming.")

-- == Quests Category =====================================
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
		
		local pieceDd = Window.AddDropdown(catQuests, "Go to " .. groupName, pieceNames, "None", function(sel)
			task.spawn(function()
				if sel ~= "None" and pieceDataMap[sel] then
					TweenTo(pieceDataMap[sel], true, nil, true) 
				end
			end)
		end)
		Window.AddTooltip(pieceDd, "Instantly fly to this specific hidden piece or location.")
	end
else
	Window.AddSection(catQuests, "No quest pieces available in this sea")
end

-- == Misc Category =======================================
Window.AddSection(catMisc, "Utility")
local antiAfkTgl = Window.AddToggle(catMisc, "Anti-AFK", farmToggles.AntiAfk, function(state)
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
Window.AddTooltip(antiAfkTgl, "Prevents Roblox from kicking you for idling. Keep the game window open!")

local autoCancelQuestTgl = Window.AddToggle(catMisc, "Auto cancel quest", farmToggles.AutoCancelQuests, function(state)
	farmToggles.AutoCancelQuests = state
	if state then
		tokens.autoCancelQuestsToggle += 1
		local myToken = tokens.autoCancelQuestsToggle
		
		task.spawn(function()
			while farmToggles.AutoCancelQuests do
				task.wait(900)
				if tokens.autoCancelQuestsToggle ~= myToken or not farmToggles.AutoCancelQuests then break end
				qqq(function()
					local CloseButton = cons.Player.PlayerGui.QuestUI.Quest.Quest.Holder.Content.Exit.CloseButton
					ClickGui(CloseButton)
				end)
			end
		end)
	else
		tokens.autoCancelQuestsToggle += 1
	end
end)
Window.AddTooltip(autoCancelQuestTgl, "Cancels a bugged quest every 15 mins to keep the farm running smoothly.")

Window.AddSection(catMisc, "UI Data")
local scaleLabel = Window.AddValueLabel(catMisc, "Scale Info", "Screen scale: " .. tostring(farmCfg.ScreenScale))
local recalcScaleBtn = Window.AddButton(catMisc, "Re-Calculate Scale (Fix AutoCancel)", function()
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
Window.AddTooltip(recalcScaleBtn, "Fixes mouse clicking issues for UI buttons. Do NOT touch your mouse while calculating!")

Window.AddConfigPreset({})
UiLib.Run()
