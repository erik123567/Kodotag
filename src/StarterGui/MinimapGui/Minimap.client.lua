-- MINIMAP
-- Shows top-down view of game area with Kodos, players, and structures

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Check if game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	print("Minimap: Lobby - disabled")
	return
end

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Settings
local MAP_SIZE = 150 -- Pixels
local MAP_SCALE = 0.5 -- Studs to pixels ratio (adjust based on map size)
local UPDATE_RATE = 0.1 -- Seconds between updates
local MAP_CENTER = Vector3.new(0, 0, 0) -- Center of the game area

-- Try to find game area bounds
local gameArea = workspace:FindFirstChild("GameArea")
if gameArea then
	-- Try to calculate center from spawn locations
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
			MAP_CENTER = totalPos / count
		end
	end
end

-- Colors for different entities
local COLORS = {
	player = Color3.fromRGB(0, 255, 100),       -- Green
	otherPlayer = Color3.fromRGB(100, 200, 255), -- Light blue
	deadPlayer = Color3.fromRGB(100, 100, 100),  -- Gray
	kodo = Color3.fromRGB(255, 80, 80),          -- Red
	bossKodo = Color3.fromRGB(255, 0, 0),        -- Bright red
	miniKodo = Color3.fromRGB(255, 180, 100),    -- Orange
	turret = Color3.fromRGB(255, 255, 100),      -- Yellow
	wall = Color3.fromRGB(150, 150, 150),        -- Gray
	barricade = Color3.fromRGB(139, 90, 43),     -- Brown
	farm = Color3.fromRGB(100, 200, 100),        -- Light green
	workshop = Color3.fromRGB(200, 150, 100),    -- Tan
	powerup = Color3.fromRGB(255, 255, 255),     -- White (pulsing)
}

-- Entity sizes on minimap
local SIZES = {
	player = 6,
	kodo = 5,
	bossKodo = 10,
	miniKodo = 3,
	turret = 4,
	wall = 8,
	barricade = 3,
	farm = 5,
	workshop = 6,
	powerup = 6,
}

-- Create minimap frame
local minimapFrame = Instance.new("Frame")
minimapFrame.Name = "MinimapFrame"
minimapFrame.Size = UDim2.new(0, MAP_SIZE + 10, 0, MAP_SIZE + 30)
minimapFrame.Position = UDim2.new(0, 10, 1, -MAP_SIZE - 70)
minimapFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
minimapFrame.BackgroundTransparency = 0.2
minimapFrame.BorderSizePixel = 0
minimapFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 8)
frameCorner.Parent = minimapFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(80, 80, 100)
frameStroke.Thickness = 2
frameStroke.Parent = minimapFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 20)
titleLabel.Position = UDim2.new(0, 0, 0, 3)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MINIMAP"
titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 12
titleLabel.Parent = minimapFrame

-- Map canvas (where dots are drawn)
local mapCanvas = Instance.new("Frame")
mapCanvas.Name = "MapCanvas"
mapCanvas.Size = UDim2.new(0, MAP_SIZE, 0, MAP_SIZE)
mapCanvas.Position = UDim2.new(0, 5, 0, 25)
mapCanvas.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
mapCanvas.BorderSizePixel = 0
mapCanvas.ClipsDescendants = true
mapCanvas.Parent = minimapFrame

local canvasCorner = Instance.new("UICorner")
canvasCorner.CornerRadius = UDim.new(0, 4)
canvasCorner.Parent = mapCanvas

-- Store references to map dots
local mapDots = {}

-- Convert world position to minimap position
local function worldToMap(worldPos)
	local relativeX = (worldPos.X - MAP_CENTER.X) * MAP_SCALE
	local relativeZ = (worldPos.Z - MAP_CENTER.Z) * MAP_SCALE

	-- Center on map and clamp to bounds
	local mapX = MAP_SIZE / 2 + relativeX
	local mapY = MAP_SIZE / 2 + relativeZ

	-- Clamp to map bounds
	mapX = math.clamp(mapX, 0, MAP_SIZE)
	mapY = math.clamp(mapY, 0, MAP_SIZE)

	return mapX, mapY
end

-- Create or update a dot on the minimap
local function updateDot(id, worldPos, color, size, shape)
	local dot = mapDots[id]

	if not dot then
		-- Create new dot
		dot = Instance.new("Frame")
		dot.Name = id
		dot.BackgroundColor3 = color
		dot.BorderSizePixel = 0
		dot.Parent = mapCanvas

		if shape == "circle" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = dot
		elseif shape == "diamond" then
			dot.Rotation = 45
		end

		mapDots[id] = dot
	end

	-- Update position and appearance
	local mapX, mapY = worldToMap(worldPos)
	dot.Size = UDim2.new(0, size, 0, size)
	dot.Position = UDim2.new(0, mapX - size/2, 0, mapY - size/2)
	dot.BackgroundColor3 = color
	dot.Visible = true

	return dot
end

-- Remove a dot from the minimap
local function removeDot(id)
	local dot = mapDots[id]
	if dot then
		dot:Destroy()
		mapDots[id] = nil
	end
end

-- Hide all dots (before refresh)
local function hideAllDots()
	for _, dot in pairs(mapDots) do
		dot.Visible = false
	end
end

-- Clean up hidden dots
local function cleanupHiddenDots()
	for id, dot in pairs(mapDots) do
		if not dot.Visible then
			dot:Destroy()
			mapDots[id] = nil
		end
	end
end

-- Get structure color and size
local function getStructureInfo(name)
	if name == "Turret" or name == "FastTurret" or name == "SlowTurret"
		or name == "FrostTurret" or name == "PoisonTurret"
		or name == "MultiShotTurret" or name == "CannonTurret" then
		return COLORS.turret, SIZES.turret, "diamond"
	elseif name == "Wall" then
		return COLORS.wall, SIZES.wall, "square"
	elseif name == "Barricade" then
		return COLORS.barricade, SIZES.barricade, "square"
	elseif name == "Farm" then
		return COLORS.farm, SIZES.farm, "square"
	elseif name == "Workshop" then
		return COLORS.workshop, SIZES.workshop, "square"
	end
	return nil, nil, nil
end

-- Update minimap
local function updateMinimap()
	hideAllDots()

	-- Update players
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = p.Character:FindFirstChild("Humanoid")

			if rootPart then
				local isDead = not humanoid or humanoid.Health <= 0
				local isLocalPlayer = (p == player)

				local color
				if isDead then
					color = COLORS.deadPlayer
				elseif isLocalPlayer then
					color = COLORS.player
				else
					color = COLORS.otherPlayer
				end

				local dot = updateDot("player_" .. p.Name, rootPart.Position, color, SIZES.player, "circle")

				-- Add pulsing effect for local player
				if isLocalPlayer and not isDead then
					dot.BackgroundTransparency = 0.3 + 0.2 * math.sin(tick() * 4)
				else
					dot.BackgroundTransparency = 0
				end
			end
		end
	end

	-- Update Kodos
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:FindFirstChild("Humanoid") and obj:FindFirstChild("KodoType") then
			local rootPart = obj:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local kodoType = obj.KodoType.Value
				local isBoss = obj:FindFirstChild("IsBoss") and obj.IsBoss.Value

				local color = COLORS.kodo
				local size = SIZES.kodo

				if isBoss then
					color = COLORS.bossKodo
					size = SIZES.bossKodo
				elseif kodoType == "Mini" then
					color = COLORS.miniKodo
					size = SIZES.miniKodo
				end

				updateDot("kodo_" .. tostring(obj), rootPart.Position, color, size, "circle")
			end
		end
	end

	-- Update structures
	local structureNames = {
		"Turret", "FastTurret", "SlowTurret", "FrostTurret", "PoisonTurret",
		"MultiShotTurret", "CannonTurret", "Wall", "Barricade", "Farm", "Workshop"
	}

	for _, obj in ipairs(workspace:GetChildren()) do
		local structureColor, structureSize, structureShape = getStructureInfo(obj.Name)
		if structureColor then
			local pos
			if obj:IsA("Model") and obj.PrimaryPart then
				pos = obj.PrimaryPart.Position
			elseif obj:IsA("BasePart") then
				pos = obj.Position
			end

			if pos then
				updateDot("structure_" .. tostring(obj), pos, structureColor, structureSize, structureShape)
			end
		end
	end

	-- Update power-ups (pulsing effect)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name:find("PowerUp_") and obj:IsA("BasePart") then
			local dot = updateDot("powerup_" .. tostring(obj), obj.Position, COLORS.powerup, SIZES.powerup, "circle")
			-- Pulsing effect
			dot.BackgroundTransparency = 0.2 + 0.3 * math.sin(tick() * 5)
		end
	end

	-- Clean up dots for removed entities
	cleanupHiddenDots()
end

-- Legend (small indicators of what colors mean)
local legendFrame = Instance.new("Frame")
legendFrame.Name = "Legend"
legendFrame.Size = UDim2.new(0, MAP_SIZE, 0, 40)
legendFrame.Position = UDim2.new(0, 5, 1, -45)
legendFrame.BackgroundTransparency = 1
legendFrame.Parent = minimapFrame

local legendLayout = Instance.new("UIGridLayout")
legendLayout.CellSize = UDim2.new(0, 50, 0, 12)
legendLayout.CellPadding = UDim2.new(0, 2, 0, 2)
legendLayout.FillDirection = Enum.FillDirection.Horizontal
legendLayout.Parent = legendFrame

local legendItems = {
	{color = COLORS.player, text = "You"},
	{color = COLORS.kodo, text = "Kodo"},
	{color = COLORS.powerup, text = "Pickup"},
}

for _, item in ipairs(legendItems) do
	local legendItem = Instance.new("Frame")
	legendItem.BackgroundTransparency = 1
	legendItem.Parent = legendFrame

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.Position = UDim2.new(0, 0, 0.5, -4)
	dot.BackgroundColor3 = item.color
	dot.BorderSizePixel = 0
	dot.Parent = legendItem

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = item.text
	label.TextColor3 = Color3.fromRGB(180, 180, 180)
	label.Font = Enum.Font.Gotham
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = legendItem
end

-- Toggle minimap with M key
local minimapVisible = true
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.M then
		minimapVisible = not minimapVisible
		minimapFrame.Visible = minimapVisible
	end
end)

-- Update loop
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	if not minimapVisible then return end

	local now = tick()
	if now - lastUpdate >= UPDATE_RATE then
		lastUpdate = now
		updateMinimap()
	end
end)

-- Initial update
updateMinimap()

print("Minimap: Loaded! Press M to toggle")
