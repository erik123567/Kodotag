-- REPAIR SYSTEM
-- Hold F near your damaged structures to repair them (costs gold)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Check if game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Settings
local REPAIR_RANGE = 15 -- Studs
local REPAIR_KEY = Enum.KeyCode.F

-- State
local isHoldingRepair = false
local currentTarget = nil
local activeIndicators = {} -- Track BillboardGuis on structures
local activeHighlight = nil

-- Remote event for repair
local repairStructure = ReplicatedStorage:WaitForChild("RepairStructure", 10)
if not repairStructure then
	warn("RepairSystem: RepairStructure event not found")
	return
end

-- Helper: Get structure's adornee part
local function getStructurePart(structure)
	if structure:IsA("Model") and structure.PrimaryPart then
		return structure.PrimaryPart
	elseif structure:IsA("BasePart") then
		return structure
	end
	return nil
end

-- Helper: Create or update indicator on a structure
local function createIndicator(structure, isRepairing)
	local part = getStructurePart(structure)
	if not part then return nil end

	local health = structure:FindFirstChild("Health")
	local maxHealth = structure:FindFirstChild("MaxHealth")
	if not health or not maxHealth then return nil end

	local healthPercent = math.floor((health.Value / maxHealth.Value) * 100)

	-- Check if indicator already exists
	local indicator = activeIndicators[structure]
	if not indicator or not indicator.Parent then
		indicator = Instance.new("BillboardGui")
		indicator.Name = "RepairIndicator"
		indicator.Size = UDim2.new(0, 120, 0, 50)
		indicator.StudsOffset = Vector3.new(0, 5, 0)
		indicator.AlwaysOnTop = true
		indicator.Adornee = part
		indicator.Parent = playerGui

		-- Background
		local bg = Instance.new("Frame")
		bg.Name = "Background"
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		bg.BackgroundTransparency = 0.2
		bg.BorderSizePixel = 0
		bg.Parent = indicator

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = bg

		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Thickness = 2
		stroke.Parent = bg

		-- Prompt text (top line)
		local promptText = Instance.new("TextLabel")
		promptText.Name = "PromptText"
		promptText.Size = UDim2.new(1, 0, 0, 18)
		promptText.Position = UDim2.new(0, 0, 0, 4)
		promptText.BackgroundTransparency = 1
		promptText.Font = Enum.Font.GothamBold
		promptText.TextSize = 12
		promptText.Parent = bg

		-- Health bar background
		local healthBarBg = Instance.new("Frame")
		healthBarBg.Name = "HealthBarBg"
		healthBarBg.Size = UDim2.new(0.9, 0, 0, 8)
		healthBarBg.Position = UDim2.new(0.05, 0, 0, 24)
		healthBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		healthBarBg.BorderSizePixel = 0
		healthBarBg.Parent = bg

		local healthBarCorner = Instance.new("UICorner")
		healthBarCorner.CornerRadius = UDim.new(0, 4)
		healthBarCorner.Parent = healthBarBg

		-- Health bar fill
		local healthBarFill = Instance.new("Frame")
		healthBarFill.Name = "HealthBarFill"
		healthBarFill.Size = UDim2.new(0.5, 0, 1, 0)
		healthBarFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
		healthBarFill.BorderSizePixel = 0
		healthBarFill.Parent = healthBarBg

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 4)
		fillCorner.Parent = healthBarFill

		-- Health text
		local healthText = Instance.new("TextLabel")
		healthText.Name = "HealthText"
		healthText.Size = UDim2.new(1, 0, 0, 14)
		healthText.Position = UDim2.new(0, 0, 0, 34)
		healthText.BackgroundTransparency = 1
		healthText.Font = Enum.Font.Gotham
		healthText.TextSize = 10
		healthText.TextColor3 = Color3.fromRGB(180, 180, 180)
		healthText.Parent = bg

		activeIndicators[structure] = indicator
	end

	-- Update indicator content
	local bg = indicator:FindFirstChild("Background")
	if bg then
		local promptText = bg:FindFirstChild("PromptText")
		local healthBarFill = bg.HealthBarBg:FindFirstChild("HealthBarFill")
		local healthText = bg:FindFirstChild("HealthText")
		local stroke = bg:FindFirstChild("Stroke")

		if isRepairing then
			-- Repairing state
			promptText.Text = "REPAIRING..."
			promptText.TextColor3 = Color3.fromRGB(100, 255, 100)
			stroke.Color = Color3.fromRGB(100, 255, 100)
			indicator.Size = UDim2.new(0, 140, 0, 55)
		else
			-- Prompt state
			promptText.Text = "[F] Repair"
			promptText.TextColor3 = Color3.fromRGB(255, 220, 100)
			stroke.Color = Color3.fromRGB(255, 180, 50)
			indicator.Size = UDim2.new(0, 120, 0, 50)
		end

		-- Update health bar
		local healthFraction = health.Value / maxHealth.Value
		healthBarFill.Size = UDim2.new(healthFraction, 0, 1, 0)

		-- Color based on health
		if healthFraction > 0.6 then
			healthBarFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
		elseif healthFraction > 0.3 then
			healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		else
			healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
		end

		healthText.Text = health.Value .. " / " .. maxHealth.Value .. " HP (" .. healthPercent .. "%)"
	end

	return indicator
end

-- Helper: Remove indicator from structure
local function removeIndicator(structure)
	local indicator = activeIndicators[structure]
	if indicator and indicator.Parent then
		indicator:Destroy()
	end
	activeIndicators[structure] = nil
end

-- Helper: Clear all indicators
local function clearAllIndicators()
	for structure, indicator in pairs(activeIndicators) do
		if indicator and indicator.Parent then
			indicator:Destroy()
		end
	end
	activeIndicators = {}
end

-- Helper: Add highlight to structure being repaired
local function setRepairHighlight(structure)
	-- Remove old highlight
	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end

	if structure then
		activeHighlight = Instance.new("Highlight")
		activeHighlight.Name = "RepairHighlight"
		activeHighlight.FillColor = Color3.fromRGB(100, 255, 100)
		activeHighlight.FillTransparency = 0.7
		activeHighlight.OutlineColor = Color3.fromRGB(150, 255, 150)
		activeHighlight.OutlineTransparency = 0
		activeHighlight.Parent = structure
	end
end

-- Find all repairable structures in range
local function findRepairableStructures()
	local character = player.Character
	if not character then return {} end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return {} end

	local structures = {}

	for _, obj in ipairs(workspace:GetChildren()) do
		local owner = obj:FindFirstChild("Owner")
		local health = obj:FindFirstChild("Health")
		local maxHealth = obj:FindFirstChild("MaxHealth")
		local underConstruction = obj:FindFirstChild("UnderConstruction")

		-- Skip buildings under construction (they use the assist system instead)
		if underConstruction and underConstruction.Value == true then
			continue
		end

		if owner and owner.Value == player.Name and health and maxHealth then
			if health.Value < maxHealth.Value then
				local part = getStructurePart(obj)
				if part then
					local dist = (hrp.Position - part.Position).Magnitude
					if dist < REPAIR_RANGE then
						table.insert(structures, {structure = obj, distance = dist})
					end
				end
			end
		end
	end

	-- Sort by distance
	table.sort(structures, function(a, b)
		return a.distance < b.distance
	end)

	return structures
end

-- Update loop
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	-- Throttle updates
	local now = tick()
	if now - lastUpdate < 0.1 then return end
	lastUpdate = now

	local repairableStructures = findRepairableStructures()
	local nearestTarget = repairableStructures[1] and repairableStructures[1].structure or nil

	-- Track which structures should have indicators
	local structuresToShow = {}
	for _, data in ipairs(repairableStructures) do
		structuresToShow[data.structure] = true
	end

	-- Remove indicators for structures no longer in range
	for structure, _ in pairs(activeIndicators) do
		if not structuresToShow[structure] then
			removeIndicator(structure)
		end
	end

	-- Update or create indicators for structures in range
	for _, data in ipairs(repairableStructures) do
		local structure = data.structure
		local isBeingRepaired = isHoldingRepair and structure == nearestTarget
		createIndicator(structure, isBeingRepaired)
	end

	-- Handle repair action
	if isHoldingRepair and nearestTarget then
		currentTarget = nearestTarget
		setRepairHighlight(nearestTarget)
		repairStructure:FireServer(nearestTarget)
	else
		currentTarget = nil
		setRepairHighlight(nil)
	end
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == REPAIR_KEY then
		isHoldingRepair = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == REPAIR_KEY then
		isHoldingRepair = false
		setRepairHighlight(nil)
	end
end)

print("RepairSystem: Loaded - Hold F near damaged structures to repair")
