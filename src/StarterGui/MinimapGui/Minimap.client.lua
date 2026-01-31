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

-- FULL MAP OVERLAY
local FULL_MAP_SIZE = 500
local fullMapVisible = false

-- Dimmed background
local dimBackground = Instance.new("Frame")
dimBackground.Name = "DimBackground"
dimBackground.Size = UDim2.new(1, 0, 1, 0)
dimBackground.Position = UDim2.new(0, 0, 0, 0)
dimBackground.BackgroundColor3 = Color3.new(0, 0, 0)
dimBackground.BackgroundTransparency = 0.5
dimBackground.BorderSizePixel = 0
dimBackground.Visible = false
dimBackground.ZIndex = 10
dimBackground.Parent = screenGui

-- Full map frame
local fullMapFrame = Instance.new("Frame")
fullMapFrame.Name = "FullMapFrame"
fullMapFrame.Size = UDim2.new(0, FULL_MAP_SIZE + 20, 0, FULL_MAP_SIZE + 60)
fullMapFrame.Position = UDim2.new(0.5, -(FULL_MAP_SIZE + 20) / 2, 0.5, -(FULL_MAP_SIZE + 60) / 2)
fullMapFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
fullMapFrame.BackgroundTransparency = 0.1
fullMapFrame.BorderSizePixel = 0
fullMapFrame.Visible = false
fullMapFrame.ZIndex = 11
fullMapFrame.Parent = screenGui

local fullFrameCorner = Instance.new("UICorner")
fullFrameCorner.CornerRadius = UDim.new(0, 12)
fullFrameCorner.Parent = fullMapFrame

local fullFrameStroke = Instance.new("UIStroke")
fullFrameStroke.Color = Color3.fromRGB(100, 100, 120)
fullFrameStroke.Thickness = 3
fullFrameStroke.Parent = fullMapFrame

-- Full map title
local fullMapTitle = Instance.new("TextLabel")
fullMapTitle.Name = "Title"
fullMapTitle.Size = UDim2.new(1, 0, 0, 30)
fullMapTitle.Position = UDim2.new(0, 0, 0, 5)
fullMapTitle.BackgroundTransparency = 1
fullMapTitle.Text = "MAP (Press M to close)"
fullMapTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
fullMapTitle.Font = Enum.Font.GothamBold
fullMapTitle.TextSize = 18
fullMapTitle.ZIndex = 12
fullMapTitle.Parent = fullMapFrame

-- Full map canvas
local fullMapCanvas = Instance.new("Frame")
fullMapCanvas.Name = "FullMapCanvas"
fullMapCanvas.Size = UDim2.new(0, FULL_MAP_SIZE, 0, FULL_MAP_SIZE)
fullMapCanvas.Position = UDim2.new(0, 10, 0, 40)
fullMapCanvas.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
fullMapCanvas.BorderSizePixel = 0
fullMapCanvas.ClipsDescendants = true
fullMapCanvas.ZIndex = 12
fullMapCanvas.Parent = fullMapFrame

local fullCanvasCorner = Instance.new("UICorner")
fullCanvasCorner.CornerRadius = UDim.new(0, 6)
fullCanvasCorner.Parent = fullMapCanvas

-- Store full map dots separately
local fullMapDots = {}

-- Full map scale (larger view = smaller scale value to fit more area)
local FULL_MAP_SCALE = 1.5

-- Convert world position to full map position
local function worldToFullMap(worldPos)
	local relativeX = (worldPos.X - MAP_CENTER.X) * FULL_MAP_SCALE
	local relativeZ = (worldPos.Z - MAP_CENTER.Z) * FULL_MAP_SCALE

	local mapX = FULL_MAP_SIZE / 2 + relativeX
	local mapY = FULL_MAP_SIZE / 2 + relativeZ

	mapX = math.clamp(mapX, 0, FULL_MAP_SIZE)
	mapY = math.clamp(mapY, 0, FULL_MAP_SIZE)

	return mapX, mapY
end

-- Create or update a dot on the full map
local function updateFullMapDot(id, worldPos, color, size, shape, label)
	local dot = fullMapDots[id]

	if not dot then
		dot = Instance.new("Frame")
		dot.Name = id
		dot.BackgroundColor3 = color
		dot.BorderSizePixel = 0
		dot.ZIndex = 13
		dot.Parent = fullMapCanvas

		if shape == "circle" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = dot
		elseif shape == "diamond" then
			dot.Rotation = 45
		end

		-- Add label for players
		if label then
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "Label"
			nameLabel.Size = UDim2.new(0, 80, 0, 14)
			nameLabel.Position = UDim2.new(0.5, -40, 1, 2)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = label
			nameLabel.TextColor3 = color
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 10
			nameLabel.TextStrokeTransparency = 0.5
			nameLabel.ZIndex = 14
			nameLabel.Parent = dot
		end

		fullMapDots[id] = dot
	end

	-- Update position
	local mapX, mapY = worldToFullMap(worldPos)
	dot.Size = UDim2.new(0, size, 0, size)
	dot.Position = UDim2.new(0, mapX - size/2, 0, mapY - size/2)
	dot.BackgroundColor3 = color
	dot.Visible = true

	-- Update label if exists
	local nameLabel = dot:FindFirstChild("Label")
	if nameLabel and label then
		nameLabel.Text = label
		nameLabel.TextColor3 = color
	end

	return dot
end

-- Hide all full map dots
local function hideAllFullMapDots()
	for _, dot in pairs(fullMapDots) do
		dot.Visible = false
	end
end

-- Clean up hidden full map dots
local function cleanupHiddenFullMapDots()
	for id, dot in pairs(fullMapDots) do
		if not dot.Visible then
			dot:Destroy()
			fullMapDots[id] = nil
		end
	end
end

-- Update full map
local function updateFullMap()
	if not fullMapVisible then return end

	hideAllFullMapDots()

	-- Update players (with names)
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

				local displayName = p.DisplayName or p.Name
				if isLocalPlayer then
					displayName = "You"
				end
				if isDead then
					displayName = displayName .. " (Dead)"
				end

				local dot = updateFullMapDot("player_" .. p.Name, rootPart.Position, color, 10, "circle", displayName)

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
				local size = 8

				if isBoss then
					color = COLORS.bossKodo
					size = 16
				elseif kodoType == "Mini" then
					color = COLORS.miniKodo
					size = 5
				end

				updateFullMapDot("kodo_" .. tostring(obj), rootPart.Position, color, size, "circle")
			end
		end
	end

	-- Update structures
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
				updateFullMapDot("structure_" .. tostring(obj), pos, structureColor, structureSize * 1.5, structureShape)
			end
		end
	end

	-- Update power-ups
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name:find("PowerUp_") and obj:IsA("BasePart") then
			local powerUpType = obj:FindFirstChild("PowerUpType")
			local label = powerUpType and powerUpType.Value or "Power-Up"
			local dot = updateFullMapDot("powerup_" .. tostring(obj), obj.Position, COLORS.powerup, 10, "circle", label)
			dot.BackgroundTransparency = 0.2 + 0.3 * math.sin(tick() * 5)
		end
	end

	cleanupHiddenFullMapDots()
end

-- Full map legend
local fullLegendFrame = Instance.new("Frame")
fullLegendFrame.Name = "Legend"
fullLegendFrame.Size = UDim2.new(1, -20, 0, 20)
fullLegendFrame.Position = UDim2.new(0, 10, 1, -25)
fullLegendFrame.BackgroundTransparency = 1
fullLegendFrame.ZIndex = 12
fullLegendFrame.Parent = fullMapFrame

local fullLegendLayout = Instance.new("UIListLayout")
fullLegendLayout.FillDirection = Enum.FillDirection.Horizontal
fullLegendLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
fullLegendLayout.Padding = UDim.new(0, 20)
fullLegendLayout.Parent = fullLegendFrame

local fullLegendItems = {
	{color = COLORS.player, text = "You"},
	{color = COLORS.otherPlayer, text = "Allies"},
	{color = COLORS.kodo, text = "Kodos"},
	{color = COLORS.turret, text = "Turrets"},
	{color = COLORS.wall, text = "Walls"},
	{color = COLORS.powerup, text = "Power-Ups"},
}

for _, item in ipairs(fullLegendItems) do
	local legendItem = Instance.new("Frame")
	legendItem.Size = UDim2.new(0, 70, 0, 16)
	legendItem.BackgroundTransparency = 1
	legendItem.ZIndex = 12
	legendItem.Parent = fullLegendFrame

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 10, 0, 10)
	dot.Position = UDim2.new(0, 0, 0.5, -5)
	dot.BackgroundColor3 = item.color
	dot.BorderSizePixel = 0
	dot.ZIndex = 12
	dot.Parent = legendItem

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -14, 1, 0)
	label.Position = UDim2.new(0, 14, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = item.text
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.Font = Enum.Font.Gotham
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 12
	label.Parent = legendItem
end

-- Toggle full map with M key
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.M then
		fullMapVisible = not fullMapVisible
		fullMapFrame.Visible = fullMapVisible
		dimBackground.Visible = fullMapVisible
	end
end)

-- Update loop
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastUpdate >= UPDATE_RATE then
		lastUpdate = now
		updateMinimap()
		if fullMapVisible then
			updateFullMap()
		end
	end
end)

-- Initial update
updateMinimap()

print("Minimap: Loaded! Press M to open full map")
