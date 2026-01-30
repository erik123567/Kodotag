local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run on game servers (reserved servers)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("GoldMineManager: Lobby server - disabled")
	return
end

print("GoldMineManager: Starting...")

-- Settings
local MINE_COUNT = 5
local MINE_RESOURCE = 200  -- Total gold in each mine
local MINE_RESPAWN_TIME = 60  -- Seconds before depleted mine respawns
local SPAWN_AREA_SIZE = 200  -- How far from center mines can spawn
local SPAWN_HEIGHT = 3  -- Height above ground

-- Wait for RoundManager
wait(2)
local RoundManager = _G.RoundManager

-- Active mines
local activeMines = {}

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

-- Create a gold mine model
local function createMineModel(position)
	local mine = Instance.new("Model")
	mine.Name = "GoldMine"

	-- Main rock/ore part
	local orePart = Instance.new("Part")
	orePart.Name = "OrePart"
	orePart.Size = Vector3.new(6, 4, 6)
	orePart.Position = position
	orePart.Anchored = true
	orePart.Material = Enum.Material.Rock
	orePart.BrickColor = BrickColor.new("Bright yellow")
	orePart.Parent = mine

	-- Add some visual detail
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://1290033"  -- Rock mesh
	mesh.Scale = Vector3.new(2, 1.5, 2)
	mesh.Parent = orePart

	-- Sparkle effect
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.new(1, 0.84, 0)
	sparkles.Parent = orePart

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
	billboard.Size = UDim2.new(6, 0, 1, 0)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = orePart
	billboard.Parent = orePart

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	background.BorderSizePixel = 2
	background.BorderColor3 = Color3.new(0, 0, 0)
	background.Parent = billboard

	local resourceBar = Instance.new("Frame")
	resourceBar.Name = "ResourceBar"
	resourceBar.Size = UDim2.new(1, 0, 1, 0)
	resourceBar.BackgroundColor3 = Color3.new(1, 0.84, 0)  -- Gold color
	resourceBar.BorderSizePixel = 0
	resourceBar.Parent = background

	local resourceText = Instance.new("TextLabel")
	resourceText.Name = "ResourceText"
	resourceText.Size = UDim2.new(1, 0, 1, 0)
	resourceText.BackgroundTransparency = 1
	resourceText.Text = "Gold Mine"
	resourceText.TextColor3 = Color3.new(1, 1, 1)
	resourceText.TextScaled = true
	resourceText.Font = Enum.Font.GothamBold
	resourceText.TextStrokeTransparency = 0.5
	resourceText.Parent = background

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
			if background then
				local bar = background:FindFirstChild("ResourceBar")
				local text = background:FindFirstChild("ResourceText")

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

				if text then
					text.Text = resource.Value .. " / " .. maxResource.Value
				end
			end
		end
	end
end

-- Find valid spawn position
local function findSpawnPosition()
	local attempts = 0
	local maxAttempts = 20

	while attempts < maxAttempts do
		local x = math.random(-SPAWN_AREA_SIZE, SPAWN_AREA_SIZE)
		local z = math.random(-SPAWN_AREA_SIZE, SPAWN_AREA_SIZE)

		-- Raycast down to find ground
		local rayStart = Vector3.new(x, 100, z)
		local rayDirection = Vector3.new(0, -200, 0)

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {}

		local result = workspace:Raycast(rayStart, rayDirection, rayParams)

		if result then
			local position = result.Position + Vector3.new(0, SPAWN_HEIGHT, 0)

			-- Check if too close to other mines
			local tooClose = false
			for _, mine in ipairs(activeMines) do
				if mine and mine.Parent then
					local minePart = mine:FindFirstChild("OrePart")
					if minePart then
						local distance = (minePart.Position - position).Magnitude
						if distance < 30 then
							tooClose = true
							break
						end
					end
				end
			end

			if not tooClose then
				return position
			end
		end

		attempts = attempts + 1
	end

	-- Fallback position
	return Vector3.new(math.random(-50, 50), SPAWN_HEIGHT, math.random(-50, 50))
end

-- Spawn a mine
local function spawnMine()
	local position = findSpawnPosition()
	local mine = createMineModel(position)
	mine.Parent = workspace

	table.insert(activeMines, mine)
	print("GoldMineManager: Spawned mine at", position)

	return mine
end

-- Respawn depleted mine
local function respawnMine(index)
	wait(MINE_RESPAWN_TIME)

	local position = findSpawnPosition()
	local mine = createMineModel(position)
	mine.Parent = workspace

	activeMines[index] = mine
	print("GoldMineManager: Respawned mine at", position)
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
	if distance > 15 then
		print("GoldMineManager:", player.Name, "too far from mine")
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
			RoundManager.broadcastPlayerStats()
			print("GoldMineManager:", player.Name, "mined", actualAmount, "gold. Mine has", resource.Value, "left")
		end
	end

	-- Broadcast update to all clients
	updateMineEvent:FireAllClients(mine, resource.Value)

	-- Check if depleted
	if resource.Value <= 0 then
		print("GoldMineManager: Mine depleted!")

		-- Find index and schedule respawn
		for i, activeMine in ipairs(activeMines) do
			if activeMine == mine then
				-- Destroy old mine
				mine:Destroy()
				activeMines[i] = nil

				-- Schedule respawn
				task.spawn(function()
					respawnMine(i)
				end)

				break
			end
		end
	end
end)

-- Initial spawn
print("GoldMineManager: Spawning initial mines...")
for i = 1, MINE_COUNT do
	spawnMine()
end

print("GoldMineManager: Loaded with", MINE_COUNT, "mines")
