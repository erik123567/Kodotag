-- GOLD MINE MANAGER
-- Fixed gold mines at strategic map locations
-- Higher risk/reward than passive farm income

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Only run on game servers (reserved servers)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("GoldMineManager: Lobby server - disabled")
	return
end

print("GoldMineManager: Starting...")

-- Settings for Fixed Mines
local MINE_RESOURCE = 300  -- Total gold in each mine
local MINE_RESPAWN_TIME = 45  -- Seconds before depleted mine respawns
local MINING_RANGE = 12  -- How close player must be to mine
local MINE_HEIGHT = 3  -- Height above ground

-- Settings for Random Bonus Veins
local VEIN_MIN_GOLD = 30
local VEIN_MAX_GOLD = 50
local VEIN_SPAWN_INTERVAL = 35  -- Seconds between vein spawns
local VEIN_LIFESPAN = 18  -- Seconds before vein despawns
local VEIN_SPAWN_RADIUS = 60  -- How far from center veins can spawn
local VEIN_MIN_DISTANCE_FROM_SPAWNS = 25  -- Minimum distance from player spawns

-- Fixed mine positions (strategic locations around the map)
-- These create a diamond pattern around the center, encouraging map control
local MINE_POSITIONS = {
	{name = "North Mine", offset = Vector3.new(0, 0, -70)},
	{name = "South Mine", offset = Vector3.new(0, 0, 70)},
	{name = "East Mine", offset = Vector3.new(70, 0, 0)},
	{name = "West Mine", offset = Vector3.new(-70, 0, 0)},
}

-- Wait for RoundManager
wait(2)
local RoundManager = _G.RoundManager

-- Active mines
local activeMines = {}

-- Calculate map center from spawn locations or Baseplate
local function getMapCenter()
	local center = Vector3.new(0, 0, 0)

	-- Try GameArea spawn locations first
	local gameArea = workspace:FindFirstChild("GameArea")
	if gameArea then
		local spawnLocations = gameArea:FindFirstChild("SpawnLocations")
		if spawnLocations and #spawnLocations:GetChildren() > 0 then
			local totalPos = Vector3.new(0, 0, 0)
			local count = 0
			for _, spawn in ipairs(spawnLocations:GetChildren()) do
				if spawn:IsA("BasePart") then
					totalPos = totalPos + spawn.Position
					count = count + 1
				end
			end
			if count > 0 then
				center = totalPos / count
				print("GoldMineManager: Using SpawnLocations center:", center)
				return center
			end
		end
	end

	-- Fallback: use Baseplate center
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		center = baseplate.Position
		print("GoldMineManager: Using Baseplate center:", center)
		return center
	end

	-- Fallback: use any SpawnLocation in workspace
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") then
			center = obj.Position
			print("GoldMineManager: Using SpawnLocation center:", center)
			return center
		end
	end

	print("GoldMineManager: Using default center (0,0,0)")
	return center
end

-- Create RemoteEvents
local mineGoldEvent = ReplicatedStorage:FindFirstChild("MineGold")
if not mineGoldEvent then
	mineGoldEvent = Instance.new("RemoteEvent")
	mineGoldEvent.Name = "MineGold"
	mineGoldEvent.Parent = ReplicatedStorage
end

local updateMineEvent = ReplicatedStorage:FindFirstChild("UpdateMine")
if not updateMineEvent then
	updateMineEvent = Instance.new("RemoteEvent")
	updateMineEvent.Name = "UpdateMine"
	updateMineEvent.Parent = ReplicatedStorage
end

print("GoldMineManager: Created RemoteEvents")

-- Find ground position at coordinates
local function findGroundPosition(x, z)
	local rayStart = Vector3.new(x, 200, z)
	local rayDirection = Vector3.new(0, -400, 0)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {}

	local result = workspace:Raycast(rayStart, rayDirection, rayParams)
	if result then
		local groundY = result.Position.Y + MINE_HEIGHT
		return Vector3.new(x, groundY, z)
	end

	-- Fallback: try to find Baseplate height
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		local groundY = baseplate.Position.Y + (baseplate.Size.Y / 2) + MINE_HEIGHT
		return Vector3.new(x, groundY, z)
	end

	-- Last resort fallback
	return Vector3.new(x, MINE_HEIGHT, z)
end

-- Create a gold mine model
local function createMineModel(position, mineName)
	local mine = Instance.new("Model")
	mine.Name = "GoldMine"

	-- Store mine name for identification
	local nameValue = Instance.new("StringValue")
	nameValue.Name = "MineName"
	nameValue.Value = mineName
	nameValue.Parent = mine

	-- Main rock/ore part
	local orePart = Instance.new("Part")
	orePart.Name = "OrePart"
	orePart.Size = Vector3.new(8, 5, 8)
	orePart.Position = position
	orePart.Anchored = true
	orePart.Material = Enum.Material.Rock
	orePart.BrickColor = BrickColor.new("Bright yellow")
	orePart.Parent = mine

	-- Add some visual detail - larger rock mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://1290033"  -- Rock mesh
	mesh.Scale = Vector3.new(3, 2, 3)
	mesh.Parent = orePart

	-- Sparkle effect
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.new(1, 0.84, 0)
	sparkles.Parent = orePart

	-- Point light to make it visible
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 50)
	light.Brightness = 1
	light.Range = 15
	light.Parent = orePart

	-- Resource value
	local resource = Instance.new("IntValue")
	resource.Name = "Resource"
	resource.Value = MINE_RESOURCE
	resource.Parent = mine

	-- Max resource (for percentage calculation)
	local maxResource = Instance.new("IntValue")
	maxResource.Name = "MaxResource"
	maxResource.Value = MINE_RESOURCE
	maxResource.Parent = mine

	mine.PrimaryPart = orePart

	-- Create resource bar (BillboardGui)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ResourceBar"
	billboard.Size = UDim2.new(8, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = orePart
	billboard.Parent = orePart

	-- Mine name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = mineName
	nameLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent = billboard

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(0.8, 0, 0.3, 0)
	background.Position = UDim2.new(0.1, 0, 0.45, 0)
	background.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	background.BorderSizePixel = 2
	background.BorderColor3 = Color3.new(0, 0, 0)
	background.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = background

	local resourceBar = Instance.new("Frame")
	resourceBar.Name = "ResourceBar"
	resourceBar.Size = UDim2.new(1, 0, 1, 0)
	resourceBar.BackgroundColor3 = Color3.new(1, 0.84, 0)  -- Gold color
	resourceBar.BorderSizePixel = 0
	resourceBar.Parent = background

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = resourceBar

	local resourceText = Instance.new("TextLabel")
	resourceText.Name = "ResourceText"
	resourceText.Size = UDim2.new(1, 0, 0.25, 0)
	resourceText.Position = UDim2.new(0, 0, 0.75, 0)
	resourceText.BackgroundTransparency = 1
	resourceText.Text = MINE_RESOURCE .. " gold"
	resourceText.TextColor3 = Color3.new(1, 1, 1)
	resourceText.Font = Enum.Font.Gotham
	resourceText.TextSize = 12
	resourceText.TextStrokeTransparency = 0.5
	resourceText.Parent = billboard

	return mine
end

-- Update mine visuals
local function updateMineVisuals(mine)
	local resource = mine:FindFirstChild("Resource")
	local maxResource = mine:FindFirstChild("MaxResource")
	local orePart = mine:FindFirstChild("OrePart")

	if resource and maxResource and orePart then
		local billboard = orePart:FindFirstChild("ResourceBar")
		if billboard then
			local background = billboard:FindFirstChild("Background")
			local resourceText = billboard:FindFirstChild("ResourceText")

			if background then
				local bar = background:FindFirstChild("ResourceBar")

				if bar then
					local percent = resource.Value / maxResource.Value
					bar.Size = UDim2.new(percent, 0, 1, 0)

					-- Change color based on remaining
					if percent > 0.5 then
						bar.BackgroundColor3 = Color3.new(1, 0.84, 0)
					elseif percent > 0.25 then
						bar.BackgroundColor3 = Color3.new(1, 0.5, 0)
					else
						bar.BackgroundColor3 = Color3.new(1, 0.2, 0)
					end
				end
			end

			if resourceText then
				resourceText.Text = resource.Value .. " gold"
			end
		end

		-- Dim the mine when low on resources
		local percent = resource.Value / maxResource.Value
		if percent < 0.1 then
			orePart.Transparency = 0.5
		else
			orePart.Transparency = 0
		end
	end
end

-- Spawn a mine at a fixed position
local function spawnMine(mineData, mapCenter)
	local worldPos = mapCenter + mineData.offset
	print("GoldMineManager: Calculating position for", mineData.name)
	print("  Map center:", mapCenter)
	print("  Offset:", mineData.offset)
	print("  World pos:", worldPos)

	local groundPos = findGroundPosition(worldPos.X, worldPos.Z)
	print("  Ground pos:", groundPos)

	local mine = createMineModel(groundPos, mineData.name)
	mine.Parent = workspace

	activeMines[mineData.name] = {
		mine = mine,
		data = mineData,
		mapCenter = mapCenter
	}

	print("GoldMineManager: Spawned", mineData.name, "at", groundPos)
	return mine
end

-- Respawn depleted mine at same location
local function respawnMine(mineName)
	local mineInfo = activeMines[mineName]
	if not mineInfo then return end

	-- Visual indicator that mine is respawning
	print("GoldMineManager:", mineName, "will respawn in", MINE_RESPAWN_TIME, "seconds")

	wait(MINE_RESPAWN_TIME)

	-- Respawn at same position
	local mine = spawnMine(mineInfo.data, mineInfo.mapCenter)

	-- Spawn effect
	local orePart = mine:FindFirstChild("OrePart")
	if orePart then
		-- Grow animation
		local originalSize = orePart.Size
		orePart.Size = Vector3.new(0.1, 0.1, 0.1)
		orePart.Transparency = 1

		local growTween = TweenService:Create(orePart, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
			Size = originalSize,
			Transparency = 0
		})
		growTween:Play()

		-- Particle burst
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
		particles.Size = NumberSequence.new(1, 0)
		particles.Lifetime = NumberRange.new(0.5, 1)
		particles.Rate = 0
		particles.Speed = NumberRange.new(10, 20)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = orePart

		particles:Emit(30)
		task.delay(1, function()
			particles:Destroy()
		end)
	end

	print("GoldMineManager:", mineName, "respawned!")
end

-- Handle mining request
mineGoldEvent.OnServerEvent:Connect(function(player, mine, mineAmount)
	if not mine or not mine.Parent then return end

	-- Verify player is close enough
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local orePart = mine:FindFirstChild("OrePart")
	if not orePart then return end

	local distance = (humanoidRootPart.Position - orePart.Position).Magnitude
	if distance > MINING_RANGE then
		return
	end

	-- Get mine resource
	local resource = mine:FindFirstChild("Resource")
	if not resource or resource.Value <= 0 then return end

	-- Calculate actual amount to mine
	local actualAmount = math.min(mineAmount, resource.Value)

	-- Deduct from mine
	resource.Value = resource.Value - actualAmount

	-- Update visuals
	updateMineVisuals(mine)

	-- Give gold to player
	if RoundManager and RoundManager.playerStats then
		local stats = RoundManager.playerStats[player.Name]
		if stats then
			stats.gold = stats.gold + actualAmount
			stats.goldEarned = (stats.goldEarned or 0) + actualAmount
			RoundManager.broadcastPlayerStats()
		end
	end

	-- Broadcast update to all clients
	updateMineEvent:FireAllClients(mine, resource.Value)

	-- Check if depleted
	if resource.Value <= 0 then
		local isBonusVein = mine:FindFirstChild("IsBonusVein")

		if isBonusVein and isBonusVein.Value then
			-- Bonus vein - just destroy, no respawn
			print("GoldMineManager: Bonus vein collected by", player.Name)

			-- Remove from tracking
			for i, v in ipairs(activeVeins) do
				if v == mine then
					table.remove(activeVeins, i)
					break
				end
			end

			mine:Destroy()
		else
			-- Fixed mine - respawn at same location
			local mineName = mine:FindFirstChild("MineName")
			local name = mineName and mineName.Value or "Unknown"

			print("GoldMineManager:", name, "depleted by", player.Name)

			-- Store info before destroying
			local mineInfo = nil
			for n, info in pairs(activeMines) do
				if info.mine == mine then
					mineInfo = info
					break
				end
			end

			-- Destroy old mine
			mine:Destroy()

			-- Schedule respawn at same location
			if mineInfo then
				task.spawn(function()
					respawnMine(name)
				end)
			end
		end
	end
end)

-- Initial spawn of all fixed mines
local function initializeMines()
	local mapCenter = getMapCenter()
	print("GoldMineManager: Map center at", mapCenter)

	for _, mineData in ipairs(MINE_POSITIONS) do
		spawnMine(mineData, mapCenter)
	end
end

-- =====================
-- RANDOM BONUS VEINS
-- =====================

-- Remote event for vein spawn notification
local veinSpawnedEvent = ReplicatedStorage:FindFirstChild("VeinSpawned")
if not veinSpawnedEvent then
	veinSpawnedEvent = Instance.new("RemoteEvent")
	veinSpawnedEvent.Name = "VeinSpawned"
	veinSpawnedEvent.Parent = ReplicatedStorage
end

-- Track active veins
local activeVeins = {}

-- Get spawn locations to avoid
local function getSpawnLocations()
	local spawns = {}
	local gameArea = workspace:FindFirstChild("GameArea")
	if gameArea then
		local spawnLocations = gameArea:FindFirstChild("SpawnLocations")
		if spawnLocations then
			for _, spawn in ipairs(spawnLocations:GetChildren()) do
				if spawn:IsA("BasePart") then
					table.insert(spawns, spawn.Position)
				end
			end
		end
	end
	return spawns
end

-- Find valid random position for vein
local function findVeinSpawnPosition(mapCenter)
	local spawnLocations = getSpawnLocations()

	for attempt = 1, 20 do
		local angle = math.random() * math.pi * 2
		local distance = math.random(20, VEIN_SPAWN_RADIUS)
		local x = mapCenter.X + math.cos(angle) * distance
		local z = mapCenter.Z + math.sin(angle) * distance

		-- Check distance from player spawns
		local tooClose = false
		for _, spawnPos in ipairs(spawnLocations) do
			local dist = (Vector3.new(x, 0, z) - Vector3.new(spawnPos.X, 0, spawnPos.Z)).Magnitude
			if dist < VEIN_MIN_DISTANCE_FROM_SPAWNS then
				tooClose = true
				break
			end
		end

		if not tooClose then
			return findGroundPosition(x, z)
		end
	end

	-- Fallback
	return findGroundPosition(mapCenter.X + math.random(-30, 30), mapCenter.Z + math.random(-30, 30))
end

-- Create a small bonus vein
local function createVeinModel(position, goldAmount)
	local vein = Instance.new("Model")
	vein.Name = "GoldVein"

	-- Mark as bonus vein
	local isVein = Instance.new("BoolValue")
	isVein.Name = "IsBonusVein"
	isVein.Value = true
	isVein.Parent = vein

	-- Smaller ore part
	local orePart = Instance.new("Part")
	orePart.Name = "OrePart"
	orePart.Size = Vector3.new(4, 3, 4)
	orePart.Position = position
	orePart.Anchored = true
	orePart.Material = Enum.Material.Rock
	orePart.BrickColor = BrickColor.new("Bright yellow")
	orePart.Parent = vein

	-- Smaller mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://1290033"
	mesh.Scale = Vector3.new(1.5, 1, 1.5)
	mesh.Parent = orePart

	-- Brighter sparkle to draw attention
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.new(1, 0.9, 0.3)
	sparkles.Parent = orePart

	-- Brighter light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 100)
	light.Brightness = 2
	light.Range = 20
	light.Parent = orePart

	-- Resource value
	local resource = Instance.new("IntValue")
	resource.Name = "Resource"
	resource.Value = goldAmount
	resource.Parent = vein

	local maxResource = Instance.new("IntValue")
	maxResource.Name = "MaxResource"
	maxResource.Value = goldAmount
	maxResource.Parent = vein

	vein.PrimaryPart = orePart

	-- Billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ResourceBar"
	billboard.Size = UDim2.new(5, 0, 1.5, 0)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = orePart
	billboard.Parent = orePart

	-- "BONUS" label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "BONUS VEIN"
	nameLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent = billboard

	-- Gold amount
	local goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.Size = UDim2.new(1, 0, 0.5, 0)
	goldLabel.Position = UDim2.new(0, 0, 0.5, 0)
	goldLabel.BackgroundTransparency = 1
	goldLabel.Text = goldAmount .. " gold"
	goldLabel.TextColor3 = Color3.new(1, 1, 1)
	goldLabel.Font = Enum.Font.Gotham
	goldLabel.TextSize = 12
	goldLabel.TextStrokeTransparency = 0.5
	goldLabel.Parent = billboard

	return vein
end

-- Spawn a random bonus vein
local function spawnBonusVein()
	local mapCenter = getMapCenter()
	local position = findVeinSpawnPosition(mapCenter)
	local goldAmount = math.random(VEIN_MIN_GOLD, VEIN_MAX_GOLD)

	local vein = createVeinModel(position, goldAmount)
	vein.Parent = workspace

	-- Spawn animation
	local orePart = vein:FindFirstChild("OrePart")
	if orePart then
		local originalSize = orePart.Size
		orePart.Size = Vector3.new(0.1, 0.1, 0.1)
		orePart.Transparency = 1

		local growTween = TweenService:Create(orePart, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
			Size = originalSize,
			Transparency = 0
		})
		growTween:Play()

		-- Particle burst
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 100))
		particles.Size = NumberSequence.new(0.8, 0)
		particles.Lifetime = NumberRange.new(0.3, 0.6)
		particles.Rate = 0
		particles.Speed = NumberRange.new(8, 15)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = orePart

		particles:Emit(20)
		task.delay(0.8, function()
			if particles.Parent then
				particles:Destroy()
			end
		end)
	end

	-- Track vein
	table.insert(activeVeins, vein)

	-- Notify clients
	veinSpawnedEvent:FireAllClients(position, goldAmount)

	print("GoldMineManager: Bonus vein spawned with", goldAmount, "gold at", position)

	-- Auto-despawn after lifespan
	task.delay(VEIN_LIFESPAN, function()
		if vein.Parent then
			-- Fade out animation
			local orePart = vein:FindFirstChild("OrePart")
			if orePart then
				local fadeTween = TweenService:Create(orePart, TweenInfo.new(0.5), {
					Transparency = 1,
					Size = Vector3.new(0.1, 0.1, 0.1)
				})
				fadeTween:Play()
				fadeTween.Completed:Wait()
			end

			-- Remove from tracking
			for i, v in ipairs(activeVeins) do
				if v == vein then
					table.remove(activeVeins, i)
					break
				end
			end

			vein:Destroy()
			print("GoldMineManager: Bonus vein despawned (uncollected)")
		end
	end)

	return vein
end

-- Handle vein collection (uses same MineGold event)
-- The existing handler works for veins too, but veins don't respawn

-- Vein spawn loop
local function startVeinSpawning()
	while true do
		task.wait(VEIN_SPAWN_INTERVAL)
		spawnBonusVein()
	end
end

-- Wait a moment for map to load, then spawn mines and start vein spawning
task.delay(3, function()
	initializeMines()
	print("GoldMineManager: Loaded with", #MINE_POSITIONS, "fixed mines")

	-- Start bonus vein spawning after a short delay
	task.delay(10, function()
		print("GoldMineManager: Starting bonus vein spawns every", VEIN_SPAWN_INTERVAL, "seconds")
		startVeinSpawning()
	end)
end)

print("GoldMineManager: Initialized")
