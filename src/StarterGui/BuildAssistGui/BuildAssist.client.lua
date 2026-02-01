-- BUILD ASSIST SYSTEM
-- Hold F near your structures under construction to speed up building

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

-- Settings
local ASSIST_RANGE = 15 -- Studs
local ASSIST_KEY = Enum.KeyCode.F

-- State
local isHoldingAssist = false
local currentTarget = nil
local activeIndicators = {} -- Track BillboardGuis on structures
local activeHighlight = nil

-- Remote event for assist
local assistConstruction = ReplicatedStorage:WaitForChild("AssistConstruction", 10)
if not assistConstruction then
	warn("BuildAssist: AssistConstruction event not found")
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
local function createIndicator(structure, isAssisting)
	local part = getStructurePart(structure)
	if not part then return nil end

	-- Check if indicator already exists
	local indicator = activeIndicators[structure]
	if not indicator or not indicator.Parent then
		indicator = Instance.new("BillboardGui")
		indicator.Name = "AssistIndicator"
		indicator.Size = UDim2.new(0, 140, 0, 35)
		indicator.StudsOffset = Vector3.new(0, 8, 0) -- Above the construction progress bar
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

		-- Prompt text
		local promptText = Instance.new("TextLabel")
		promptText.Name = "PromptText"
		promptText.Size = UDim2.new(1, 0, 1, 0)
		promptText.BackgroundTransparency = 1
		promptText.Font = Enum.Font.GothamBold
		promptText.TextSize = 14
		promptText.Parent = bg

		activeIndicators[structure] = indicator
	end

	-- Update indicator content
	local bg = indicator:FindFirstChild("Background")
	if bg then
		local promptText = bg:FindFirstChild("PromptText")
		local stroke = bg:FindFirstChild("Stroke")

		if isAssisting then
			-- Assisting state
			promptText.Text = "ASSISTING..."
			promptText.TextColor3 = Color3.fromRGB(100, 255, 200)
			stroke.Color = Color3.fromRGB(100, 255, 200)
			indicator.Size = UDim2.new(0, 140, 0, 35)
		else
			-- Prompt state
			promptText.Text = "[F] Assist Build"
			promptText.TextColor3 = Color3.fromRGB(100, 200, 255)
			stroke.Color = Color3.fromRGB(50, 150, 255)
			indicator.Size = UDim2.new(0, 140, 0, 35)
		end
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

-- Helper: Add highlight to structure being assisted
local function setAssistHighlight(structure)
	-- Remove old highlight
	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end

	if structure then
		activeHighlight = Instance.new("Highlight")
		activeHighlight.Name = "AssistHighlight"
		activeHighlight.FillColor = Color3.fromRGB(100, 255, 200)
		activeHighlight.FillTransparency = 0.7
		activeHighlight.OutlineColor = Color3.fromRGB(150, 255, 220)
		activeHighlight.OutlineTransparency = 0
		activeHighlight.Parent = structure
	end
end

-- Find all structures under construction in range
local function findConstructionSites()
	local character = player.Character
	if not character then return {} end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return {} end

	local structures = {}

	for _, obj in ipairs(workspace:GetChildren()) do
		local owner = obj:FindFirstChild("Owner")
		local underConstruction = obj:FindFirstChild("UnderConstruction")

		-- Only show for buildings under construction that we own
		if owner and owner.Value == player.Name and underConstruction and underConstruction.Value == true then
			local part = getStructurePart(obj)
			if part then
				local dist = (hrp.Position - part.Position).Magnitude
				if dist < ASSIST_RANGE then
					table.insert(structures, {structure = obj, distance = dist})
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

	local constructionSites = findConstructionSites()
	local nearestTarget = constructionSites[1] and constructionSites[1].structure or nil

	-- Track which structures should have indicators
	local structuresToShow = {}
	for _, data in ipairs(constructionSites) do
		structuresToShow[data.structure] = true
	end

	-- Remove indicators for structures no longer in range or completed
	for structure, _ in pairs(activeIndicators) do
		if not structuresToShow[structure] then
			removeIndicator(structure)
		end
	end

	-- Update or create indicators for structures in range
	for _, data in ipairs(constructionSites) do
		local structure = data.structure
		local isBeingAssisted = isHoldingAssist and structure == nearestTarget
		createIndicator(structure, isBeingAssisted)
	end

	-- Handle assist action
	if isHoldingAssist and nearestTarget then
		currentTarget = nearestTarget
		setAssistHighlight(nearestTarget)
		assistConstruction:FireServer(nearestTarget)
	else
		currentTarget = nil
		setAssistHighlight(nil)
	end
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == ASSIST_KEY then
		isHoldingAssist = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == ASSIST_KEY then
		isHoldingAssist = false
		setAssistHighlight(nil)
	end
end)

print("BuildAssist: Loaded - Hold F near buildings under construction to assist")
