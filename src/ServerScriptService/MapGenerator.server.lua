-- MAP GENERATOR
-- Creates the game arena dynamically based on player count

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run on game servers
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("MapGenerator: Lobby server - disabled")
	return
end

local MapGenerator = {}

-- Map size configurations based on player count
local MAP_SIZES = {
	SOLO = 400,    -- 1 player
	SMALL = 600,   -- 2-4 players
	MEDIUM = 800,  -- 5-8 players
	LARGE = 1000,  -- 9+ players
}

-- Settings
local WALL_HEIGHT = 20
local WALL_THICKNESS = 4
local PLAYER_SPAWN_PERCENT = 0.6 -- Players spawn at 60% distance from center to edge

-- Materials and colors
local GROUND_MATERIAL = Enum.Material.Grass
local GROUND_COLOR = Color3.fromRGB(85, 120, 70)
local WALL_MATERIAL = Enum.Material.Brick
local WALL_COLOR = Color3.fromRGB(80, 60, 50)

-- Get map size based on player count
local function getMapSize(playerCount)
	if playerCount <= 1 then
		return MAP_SIZES.SOLO, "SOLO"
	elseif playerCount <= 4 then
		return MAP_SIZES.SMALL, "SMALL"
	elseif playerCount <= 8 then
		return MAP_SIZES.MEDIUM, "MEDIUM"
	else
		return MAP_SIZES.LARGE, "LARGE"
	end
end

-- Create the ground plane
local function createGround(size)
	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = Vector3.new(size, 1, size)
	ground.Position = Vector3.new(0, -0.5, 0)
	ground.Anchored = true
	ground.Material = GROUND_MATERIAL
	ground.Color = GROUND_COLOR
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.BottomSurface = Enum.SurfaceType.Smooth
	ground.Parent = workspace

	return ground
end

-- Create boundary walls
local function createWalls(size)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = workspace

	local halfSize = size / 2

	-- Wall positions: {position, size, name}
	local wallConfigs = {
		{Vector3.new(0, WALL_HEIGHT/2, -halfSize - WALL_THICKNESS/2), Vector3.new(size + WALL_THICKNESS*2, WALL_HEIGHT, WALL_THICKNESS), "NorthWall"},
		{Vector3.new(0, WALL_HEIGHT/2, halfSize + WALL_THICKNESS/2), Vector3.new(size + WALL_THICKNESS*2, WALL_HEIGHT, WALL_THICKNESS), "SouthWall"},
		{Vector3.new(-halfSize - WALL_THICKNESS/2, WALL_HEIGHT/2, 0), Vector3.new(WALL_THICKNESS, WALL_HEIGHT, size), "WestWall"},
		{Vector3.new(halfSize + WALL_THICKNESS/2, WALL_HEIGHT/2, 0), Vector3.new(WALL_THICKNESS, WALL_HEIGHT, size), "EastWall"},
	}

	for _, config in ipairs(wallConfigs) do
		local wall = Instance.new("Part")
		wall.Name = config[3]
		wall.Size = config[2]
		wall.Position = config[1]
		wall.Anchored = true
		wall.Material = WALL_MATERIAL
		wall.Color = WALL_COLOR
		wall.Parent = walls
	end

	return walls
end

-- Create player spawn locations around the map (between center and edges)
local function createPlayerSpawns(playerCount, mapSize)
	local spawnLocations = Instance.new("Folder")
	spawnLocations.Name = "SpawnLocations"

	-- Calculate spawn radius based on map size
	local spawnRadius = (mapSize / 2) * PLAYER_SPAWN_PERCENT

	-- Create spawn points in a circle
	local spawnCount = math.max(playerCount, 4) -- At least 4 spawn points

	for i = 1, spawnCount do
		local angle = (i - 1) * (2 * math.pi / spawnCount)
		local x = math.cos(angle) * spawnRadius
		local z = math.sin(angle) * spawnRadius

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "PlayerSpawn" .. i
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = Vector3.new(x, 0.5, z)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Enabled = false -- We handle spawning manually
		spawn.Neutral = true
		spawn.Parent = spawnLocations
	end

	return spawnLocations
end

-- Create Kodo spawn points around the center shrine
local function createKodoSpawns(size)
	local kodoSpawns = Instance.new("Folder")
	kodoSpawns.Name = "KodoSpawns"

	local KODO_SPAWN_RADIUS = 20 -- Distance from center shrine
	local KODO_SPAWN_COUNT = 8 -- Number of spawn points in a circle

	-- Create spawns in a circle around the shrine
	for i = 1, KODO_SPAWN_COUNT do
		local angle = (i - 1) * (2 * math.pi / KODO_SPAWN_COUNT)
		local x = math.cos(angle) * KODO_SPAWN_RADIUS
		local z = math.sin(angle) * KODO_SPAWN_RADIUS

		local spawn = Instance.new("Part")
		spawn.Name = "KodoSpawn" .. i
		spawn.Size = Vector3.new(4, 1, 4)
		spawn.Position = Vector3.new(x, 0.5, z)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Parent = kodoSpawns
	end

	return kodoSpawns
end

-- Create the resurrection shrine in the center
local function createShrine()
	local shrine = Instance.new("Model")
	shrine.Name = "ResurrectionShrine"

	-- Base platform
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(12, 1, 12)
	base.Position = Vector3.new(0, 0.5, 0)
	base.Anchored = true
	base.Material = Enum.Material.Marble
	base.Color = Color3.fromRGB(200, 200, 220)
	base.Parent = shrine

	-- Center pillar
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Size = Vector3.new(3, 8, 3)
	pillar.Position = Vector3.new(0, 5, 0)
	pillar.Anchored = true
	pillar.Material = Enum.Material.Marble
	pillar.Color = Color3.fromRGB(220, 220, 240)
	pillar.Parent = shrine

	-- Glowing orb on top
	local orb = Instance.new("Part")
	orb.Name = "Orb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(4, 4, 4)
	orb.Position = Vector3.new(0, 11, 0)
	orb.Anchored = true
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(100, 200, 255)
	orb.CanCollide = false
	orb.Parent = shrine

	-- Point light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(100, 200, 255)
	light.Brightness = 2
	light.Range = 30
	light.Parent = orb

	shrine.PrimaryPart = base
	shrine.Parent = workspace

	return shrine
end

-- Create corner decorations/towers
local function createCornerTowers(size)
	local towers = Instance.new("Folder")
	towers.Name = "CornerTowers"
	towers.Parent = workspace

	local halfSize = size / 2 - 5
	local corners = {
		Vector3.new(-halfSize, 0, -halfSize),
		Vector3.new(halfSize, 0, -halfSize),
		Vector3.new(-halfSize, 0, halfSize),
		Vector3.new(halfSize, 0, halfSize),
	}

	for i, pos in ipairs(corners) do
		local tower = Instance.new("Part")
		tower.Name = "Tower" .. i
		tower.Size = Vector3.new(8, 15, 8)
		tower.Position = pos + Vector3.new(0, 7.5, 0)
		tower.Anchored = true
		tower.Material = Enum.Material.Brick
		tower.Color = Color3.fromRGB(100, 75, 60)
		tower.Parent = towers

		-- Tower top
		local top = Instance.new("Part")
		top.Name = "Top"
		top.Size = Vector3.new(10, 2, 10)
		top.Position = pos + Vector3.new(0, 16, 0)
		top.Anchored = true
		top.Material = Enum.Material.Brick
		top.Color = Color3.fromRGB(70, 50, 40)
		top.Parent = towers

		-- Torch light
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 50)
		light.Brightness = 1
		light.Range = 25
		light.Parent = top
	end

	return towers
end

-- Main generation function
function MapGenerator.generateMap(playerCount)
	print("MapGenerator: Generating map for", playerCount, "players...")

	-- Clean up any existing map elements
	local oldGround = workspace:FindFirstChild("Ground")
	if oldGround then oldGround:Destroy() end

	local oldWalls = workspace:FindFirstChild("Walls")
	if oldWalls then oldWalls:Destroy() end

	local oldGameArea = workspace:FindFirstChild("GameArea")
	if oldGameArea then oldGameArea:Destroy() end

	local oldShrine = workspace:FindFirstChild("ResurrectionShrine")
	if oldShrine then oldShrine:Destroy() end

	local oldTowers = workspace:FindFirstChild("CornerTowers")
	if oldTowers then oldTowers:Destroy() end

	local oldBaseplate = workspace:FindFirstChild("Baseplate")
	if oldBaseplate then oldBaseplate:Destroy() end

	-- Get map size
	local mapSize, sizeCategory = getMapSize(playerCount)
	print("MapGenerator: Map size:", mapSize, "(" .. sizeCategory .. ")")

	-- Create GameArea folder
	local gameArea = Instance.new("Folder")
	gameArea.Name = "GameArea"
	gameArea.Parent = workspace

	-- Create map elements
	local ground = createGround(mapSize)
	local walls = createWalls(mapSize)
	local spawnLocations = createPlayerSpawns(playerCount, mapSize)
	local kodoSpawns = createKodoSpawns(mapSize)
	local shrine = createShrine()
	local towers = createCornerTowers(mapSize)

	-- Parent spawn folders to GameArea
	spawnLocations.Parent = gameArea
	kodoSpawns.Parent = gameArea

	-- Move shrine into GameArea
	shrine.Parent = gameArea

	-- Store map info globally
	_G.MapInfo = {
		size = mapSize,
		sizeCategory = sizeCategory,
		center = Vector3.new(0, 0, 0),
		halfSize = mapSize / 2
	}

	print("MapGenerator: Map generation complete!")
	print("  - Ground: " .. mapSize .. "x" .. mapSize)
	print("  - Player spawns: " .. #spawnLocations:GetChildren())
	print("  - Kodo spawns: " .. #kodoSpawns:GetChildren())

	return gameArea
end

-- Wait for game config, then generate map
task.spawn(function()
	print("MapGenerator: Waiting for game configuration...")

	-- Wait for GameConfig to be set
	while not _G.GameConfig do
		task.wait(0.1)
	end

	-- Wait a moment for player count to be determined
	task.wait(1)

	local playerCount = _G.GameConfig.expectedPlayers or #Players:GetPlayers()
	playerCount = math.max(playerCount, 1)

	MapGenerator.generateMap(playerCount)
end)

_G.MapGenerator = MapGenerator
print("MapGenerator: Loaded!")

return MapGenerator
