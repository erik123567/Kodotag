-- BuildingTemplateGenerator.server.lua
-- Generates all building templates programmatically on server start
-- Ensures consistency between preview and placement

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run on game servers (not lobby)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("BuildingTemplateGenerator: Lobby - skipped")
	return
end

print("BuildingTemplateGenerator: Starting...")

-- Create BuildableItems folder structure
local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local buildableItems = ensureFolder(ServerStorage, "BuildableItems")
local turretsFolder = ensureFolder(buildableItems, "Turrets")
local defenseFolder = ensureFolder(buildableItems, "Defense")
local economyFolder = ensureFolder(buildableItems, "Farms")
local utilityFolder = ensureFolder(buildableItems, "Utility")

-- Also create in ReplicatedStorage for client preview
local repBuildableItems = ensureFolder(ReplicatedStorage, "BuildableItems")
local repTurretsFolder = ensureFolder(repBuildableItems, "Turrets")
local repDefenseFolder = ensureFolder(repBuildableItems, "Defense")
local repEconomyFolder = ensureFolder(repBuildableItems, "Farms")
local repUtilityFolder = ensureFolder(repBuildableItems, "Utility")

-- Helper: Add cost value to model
local function addCost(model, cost)
	local costValue = Instance.new("IntValue")
	costValue.Name = "Cost"
	costValue.Value = cost
	costValue.Parent = model
end

-- Helper: Add display name
local function addDisplayName(model, name)
	local nameValue = Instance.new("StringValue")
	nameValue.Name = "DisplayName"
	nameValue.Value = name
	nameValue.Parent = model
end

--==========================================
-- TURRET TEMPLATES
--==========================================

-- TURRETS ARE TALL (5-6 studs) so they shoot OVER walls/barricades (4 studs)
-- All turrets use same footprint for consistent gameplay
local TURRET_BASE_SIZE = Vector3.new(4, 3, 4)  -- Taller base (3 studs)
local TURRET_HEAD_HEIGHT = 2  -- Head is 2 studs tall
local STANDARD_BARREL_SIZE = Vector3.new(1, 1, 3.5)

local TURRET_CONFIGS = {
	Turret = {
		displayName = "Basic Turret",
		cost = 50,
		baseColor = Color3.fromRGB(100, 100, 100),
		barrelColor = Color3.fromRGB(60, 60, 60),
		barrelSize = STANDARD_BARREL_SIZE,
	},
	FastTurret = {
		displayName = "Fast Turret",
		cost = 75,
		baseColor = Color3.fromRGB(200, 200, 100),
		barrelColor = Color3.fromRGB(150, 150, 50),
		barrelSize = Vector3.new(0.6, 0.6, 3),
		dualBarrel = true,
	},
	SlowTurret = {
		displayName = "Heavy Turret",
		cost = 30,
		baseColor = Color3.fromRGB(80, 80, 80),
		barrelColor = Color3.fromRGB(40, 40, 40),
		barrelSize = Vector3.new(1.5, 1.5, 4),
	},
	FrostTurret = {
		displayName = "Frost Turret",
		cost = 100,
		baseColor = Color3.fromRGB(150, 200, 255),
		barrelColor = Color3.fromRGB(100, 180, 255),
		barrelSize = STANDARD_BARREL_SIZE,
		glowColor = Color3.fromRGB(150, 220, 255),
	},
	PoisonTurret = {
		displayName = "Poison Turret",
		cost = 90,
		baseColor = Color3.fromRGB(80, 150, 80),
		barrelColor = Color3.fromRGB(50, 200, 50),
		barrelSize = STANDARD_BARREL_SIZE,
		glowColor = Color3.fromRGB(100, 255, 100),
	},
	MultiShotTurret = {
		displayName = "Multi-Shot Turret",
		cost = 120,
		baseColor = Color3.fromRGB(150, 100, 50),
		barrelColor = Color3.fromRGB(100, 70, 30),
		barrelSize = Vector3.new(0.7, 0.7, 3),
		tripleBarrel = true,
	},
	CannonTurret = {
		displayName = "Cannon Turret",
		cost = 150,
		baseColor = Color3.fromRGB(60, 60, 70),
		barrelColor = Color3.fromRGB(40, 40, 50),
		barrelSize = Vector3.new(1.8, 1.8, 3.5),
	},
}

local function createTurret(name, config)
	local turret = Instance.new("Model")
	turret.Name = name

	local baseHeight = TURRET_BASE_SIZE.Y
	local headHeight = TURRET_HEAD_HEIGHT

	-- Base platform (center at Y = baseHeight/2, so bottom at Y=0)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = TURRET_BASE_SIZE
	base.CFrame = CFrame.new(0, baseHeight / 2, 0)
	base.Color = config.baseColor
	base.Material = Enum.Material.Metal
	base.Anchored = true
	base.CanCollide = true
	base.Parent = turret

	-- Turret head on top of base
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(TURRET_BASE_SIZE.X * 0.7, headHeight, TURRET_BASE_SIZE.Z * 0.7)
	head.CFrame = CFrame.new(0, baseHeight + headHeight / 2, 0)
	head.Color = config.baseColor
	head.Material = Enum.Material.Metal
	head.Anchored = true
	head.CanCollide = false
	head.Parent = turret

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = base
	headWeld.Part1 = head
	headWeld.Parent = head

	-- Barrel(s) - positioned at head height
	local barrelY = baseHeight + headHeight / 2
	local function createBarrel(xOffset)
		local barrel = Instance.new("Part")
		barrel.Name = "Barrel"
		barrel.Size = config.barrelSize
		barrel.CFrame = CFrame.new(xOffset, barrelY, -config.barrelSize.Z / 2 - head.Size.Z / 4)
		barrel.Color = config.barrelColor
		barrel.Material = Enum.Material.Metal
		barrel.Anchored = true
		barrel.CanCollide = false
		barrel.Parent = turret

		local barrelWeld = Instance.new("WeldConstraint")
		barrelWeld.Part0 = head
		barrelWeld.Part1 = barrel
		barrelWeld.Parent = barrel

		return barrel
	end

	if config.tripleBarrel then
		createBarrel(-1)
		createBarrel(0)
		createBarrel(1)
	elseif config.dualBarrel then
		createBarrel(-0.6)
		createBarrel(0.6)
	else
		createBarrel(0)
	end

	-- Glow effect for elemental turrets
	if config.glowColor then
		local glow = Instance.new("PointLight")
		glow.Color = config.glowColor
		glow.Brightness = 1
		glow.Range = 8
		glow.Parent = head
	end

	-- PrimaryPart is Base (center at Y = baseHeight/2)
	turret.PrimaryPart = base
	addCost(turret, config.cost)
	addDisplayName(turret, config.displayName)

	return turret
end

--==========================================
-- DEFENSE TEMPLATES
-- Walls are SHORT (4 studs) so turrets (5+ studs) can shoot OVER them
--==========================================

local function createBarricade()
	-- Short wooden pillar for maze building - players can kite around these
	local barricade = Instance.new("Part")
	barricade.Name = "Barricade"
	barricade.Size = Vector3.new(4, 4, 4)  -- Short cube, 4 studs tall
	barricade.CFrame = CFrame.new(0, 2, 0)  -- Center at Y=2, bottom at Y=0
	barricade.Material = Enum.Material.Wood
	barricade.BrickColor = BrickColor.new("Brown")
	barricade.Anchored = true
	barricade.CanCollide = true

	addCost(barricade, 15)
	addDisplayName(barricade, "Barricade")

	return barricade
end

local function createWall()
	-- Low concrete wall - turrets shoot over it
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Size = Vector3.new(10, 4, 2)  -- 4 studs tall, wide
	wall.CFrame = CFrame.new(0, 2, 0)  -- Center at Y=2, bottom at Y=0
	wall.Material = Enum.Material.Concrete
	wall.BrickColor = BrickColor.new("Medium stone grey")
	wall.Anchored = true
	wall.CanCollide = true

	addCost(wall, 60)
	addDisplayName(wall, "Wall")

	return wall
end

local function createStrongWall()
	-- Bunker-style fortification: thick base with sandbags and metal plating
	local model = Instance.new("Model")
	model.Name = "StrongWall"

	-- Thick concrete base
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(10, 3, 4)  -- Wider/thicker than regular wall
	base.CFrame = CFrame.new(0, 1.5, 0)  -- Center at Y=1.5, bottom at Y=0
	base.Material = Enum.Material.Concrete
	base.BrickColor = BrickColor.new("Dark stone grey")
	base.Anchored = true
	base.CanCollide = true
	base.Parent = model

	-- Top plate (angled for deflection look)
	local topPlate = Instance.new("Part")
	topPlate.Name = "TopPlate"
	topPlate.Size = Vector3.new(10, 1.5, 4.5)
	topPlate.CFrame = CFrame.new(0, 3.75, 0)  -- On top of base
	topPlate.Material = Enum.Material.DiamondPlate
	topPlate.Color = Color3.fromRGB(70, 70, 80)
	topPlate.Anchored = true
	topPlate.CanCollide = true
	topPlate.Parent = model

	local topWeld = Instance.new("WeldConstraint")
	topWeld.Part0 = base
	topWeld.Part1 = topPlate
	topWeld.Parent = topPlate

	-- Corner reinforcements
	for i = -1, 1, 2 do
		local corner = Instance.new("Part")
		corner.Name = "Corner"
		corner.Size = Vector3.new(1, 4.5, 4.5)
		corner.CFrame = CFrame.new(i * 4.5, 2.25, 0)
		corner.Material = Enum.Material.DiamondPlate
		corner.Color = Color3.fromRGB(50, 50, 60)
		corner.Anchored = true
		corner.CanCollide = false
		corner.Parent = model

		local cornerWeld = Instance.new("WeldConstraint")
		cornerWeld.Part0 = base
		cornerWeld.Part1 = corner
		cornerWeld.Parent = corner
	end

	model.PrimaryPart = base
	addCost(model, 120)
	addDisplayName(model, "Bunker Wall")

	return model
end

--==========================================
-- ECONOMY TEMPLATES
--==========================================

local function createFarm()
	local farm = Instance.new("Model")
	farm.Name = "Farm"

	-- Base plot
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(8, 1, 10)
	base.CFrame = CFrame.new(0, 0.5, 0)
	base.Material = Enum.Material.Grass
	base.BrickColor = BrickColor.new("Bright green")
	base.Anchored = true
	base.CanCollide = true
	base.Parent = farm

	-- Dirt rows
	for z = -3, 3, 2 do
		local row = Instance.new("Part")
		row.Name = "DirtRow"
		row.Size = Vector3.new(6, 0.3, 1)
		row.CFrame = CFrame.new(0, 1.15, z)
		row.Material = Enum.Material.Ground
		row.BrickColor = BrickColor.new("Reddish brown")
		row.Anchored = true
		row.CanCollide = false
		row.Parent = farm

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = row
		weld.Parent = row
	end

	-- Fence posts
	local function createPost(x, z)
		local post = Instance.new("Part")
		post.Name = "FencePost"
		post.Size = Vector3.new(0.4, 3, 0.4)
		post.CFrame = CFrame.new(x, 2.5, z)
		post.Material = Enum.Material.Wood
		post.BrickColor = BrickColor.new("Brown")
		post.Anchored = true
		post.CanCollide = false
		post.Parent = farm

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = post
		weld.Parent = post
	end

	createPost(-4, -5)
	createPost(-4, 5)
	createPost(4, -5)
	createPost(4, 5)

	farm.PrimaryPart = base
	addCost(farm, 40)
	addDisplayName(farm, "Farm")

	return farm
end

local function createWorkshop()
	local workshop = Instance.new("Model")
	workshop.Name = "Workshop"

	-- Floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(10, 1, 10)
	floor.CFrame = CFrame.new(0, 0.5, 0)
	floor.Material = Enum.Material.WoodPlanks
	floor.BrickColor = BrickColor.new("Brown")
	floor.Anchored = true
	floor.CanCollide = true
	floor.Parent = workshop

	-- Walls
	local function createWallPart(size, position, rotation)
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Size = size
		wall.CFrame = CFrame.new(position) * (rotation or CFrame.new())
		wall.Material = Enum.Material.Wood
		wall.BrickColor = BrickColor.new("Reddish brown")
		wall.Anchored = true
		wall.CanCollide = true
		wall.Parent = workshop

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = floor
		weld.Part1 = wall
		weld.Parent = wall

		return wall
	end

	-- Back wall
	createWallPart(Vector3.new(10, 6, 0.5), Vector3.new(0, 4, 5))
	-- Side walls
	createWallPart(Vector3.new(0.5, 6, 10), Vector3.new(-5, 4, 0))
	createWallPart(Vector3.new(0.5, 6, 10), Vector3.new(5, 4, 0))
	-- Front wall (with door gap)
	createWallPart(Vector3.new(3, 6, 0.5), Vector3.new(-3.5, 4, -5))
	createWallPart(Vector3.new(3, 6, 0.5), Vector3.new(3.5, 4, -5))
	createWallPart(Vector3.new(4, 2, 0.5), Vector3.new(0, 6, -5))

	-- Roof
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(12, 1, 12)
	roof.CFrame = CFrame.new(0, 7.5, 0)
	roof.Material = Enum.Material.Slate
	roof.BrickColor = BrickColor.new("Dark stone grey")
	roof.Anchored = true
	roof.CanCollide = true
	roof.Parent = workshop

	local roofWeld = Instance.new("WeldConstraint")
	roofWeld.Part0 = floor
	roofWeld.Part1 = roof
	roofWeld.Parent = roof

	-- Anvil inside
	local anvil = Instance.new("Part")
	anvil.Name = "Anvil"
	anvil.Size = Vector3.new(2, 2, 3)
	anvil.CFrame = CFrame.new(2, 2, 2)
	anvil.Material = Enum.Material.Metal
	anvil.Color = Color3.fromRGB(50, 50, 50)
	anvil.Anchored = true
	anvil.CanCollide = false
	anvil.Parent = workshop

	local anvilWeld = Instance.new("WeldConstraint")
	anvilWeld.Part0 = floor
	anvilWeld.Part1 = anvil
	anvilWeld.Parent = anvil

	workshop.PrimaryPart = floor
	addCost(workshop, 200)
	addDisplayName(workshop, "Workshop")

	return workshop
end

--==========================================
-- AURA TEMPLATES
--==========================================

local AURA_CONFIGS = {
	SpeedAura = { color = Color3.fromRGB(255, 200, 50), cost = 150, displayName = "Speed Aura" },
	DamageAura = { color = Color3.fromRGB(255, 80, 80), cost = 200, displayName = "Damage Aura" },
	FortifyAura = { color = Color3.fromRGB(100, 200, 255), cost = 175, displayName = "Fortify Aura" },
	RangeAura = { color = Color3.fromRGB(150, 255, 150), cost = 225, displayName = "Range Aura" },
	RegenAura = { color = Color3.fromRGB(100, 255, 200), cost = 250, displayName = "Regen Aura" },
}

local function createAura(name, config)
	local aura = Instance.new("Model")
	aura.Name = name

	-- Base pillar
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4, 6, 4)
	base.CFrame = CFrame.new(0, 3, 0)
	base.Material = Enum.Material.SmoothPlastic
	base.Color = config.color
	base.Anchored = true
	base.CanCollide = true
	base.Parent = aura

	-- Crystal on top
	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Size = Vector3.new(2, 3, 2)
	crystal.CFrame = CFrame.new(0, 7.5, 0)
	crystal.Material = Enum.Material.Neon
	crystal.Color = config.color
	crystal.Transparency = 0.3
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.Parent = aura

	local crystalWeld = Instance.new("WeldConstraint")
	crystalWeld.Part0 = base
	crystalWeld.Part1 = crystal
	crystalWeld.Parent = crystal

	-- Glow
	local light = Instance.new("PointLight")
	light.Color = config.color
	light.Brightness = 2
	light.Range = 15
	light.Parent = crystal

	aura.PrimaryPart = base
	addCost(aura, config.cost)
	addDisplayName(aura, config.displayName)

	return aura
end

--==========================================
-- GENERATE ALL TEMPLATES
--==========================================

local function clearFolder(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			child:Destroy()
		end
	end
end

local function generateTemplates()
	local count = 0

	-- Clear existing templates
	clearFolder(turretsFolder)
	clearFolder(defenseFolder)
	clearFolder(economyFolder)
	clearFolder(utilityFolder)
	clearFolder(repTurretsFolder)
	clearFolder(repDefenseFolder)
	clearFolder(repEconomyFolder)
	clearFolder(repUtilityFolder)

	-- Generate turrets
	for name, config in pairs(TURRET_CONFIGS) do
		local turret = createTurret(name, config)
		turret.Parent = turretsFolder
		turret:Clone().Parent = repTurretsFolder
		count = count + 1
		print("  Created:", name)
	end

	-- Generate defense structures
	local barricade = createBarricade()
	barricade.Parent = defenseFolder
	barricade:Clone().Parent = repDefenseFolder
	count = count + 1
	print("  Created: Barricade")

	local wall = createWall()
	wall.Parent = defenseFolder
	wall:Clone().Parent = repDefenseFolder
	count = count + 1
	print("  Created: Wall")

	local strongWall = createStrongWall()
	strongWall.Parent = defenseFolder
	strongWall:Clone().Parent = repDefenseFolder
	count = count + 1
	print("  Created: StrongWall")

	-- Generate economy structures
	local farm = createFarm()
	farm.Parent = economyFolder
	farm:Clone().Parent = repEconomyFolder
	count = count + 1
	print("  Created: Farm")

	local workshop = createWorkshop()
	workshop.Parent = economyFolder
	workshop:Clone().Parent = repEconomyFolder
	count = count + 1
	print("  Created: Workshop")

	-- Generate auras
	for name, config in pairs(AURA_CONFIGS) do
		local aura = createAura(name, config)
		aura.Parent = utilityFolder
		aura:Clone().Parent = repUtilityFolder
		count = count + 1
		print("  Created:", name)
	end

	return count
end

-- Generate all templates
local count = generateTemplates()
print("BuildingTemplateGenerator: Created", count, "building templates")
print("BuildingTemplateGenerator: Ready!")
