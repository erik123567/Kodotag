local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

print("MiningSystem: Starting...")

-- Settings
local MINE_RATE = 10  -- Gold per second while mining
local MAX_MINE_DISTANCE = 12

-- State
local isHoldingMineKey = false
local currentMine = nil
local miningStartTime = 0

-- Remote events
local mineGoldEvent = ReplicatedStorage:WaitForChild("MineGold", 10)
local updateMineEvent = ReplicatedStorage:WaitForChild("UpdateMine", 10)

if not mineGoldEvent then
	warn("MiningSystem: MineGold event not found!")
	return
end

-- UI Setup
local screenGui = script.Parent

local miningProgressFrame = Instance.new("Frame")
miningProgressFrame.Name = "MiningProgressFrame"
miningProgressFrame.Size = UDim2.new(0, 200, 0, 40)
miningProgressFrame.Position = UDim2.new(0.5, -100, 0.6, 0)
miningProgressFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
miningProgressFrame.BorderSizePixel = 2
miningProgressFrame.BorderColor3 = Color3.new(1, 0.84, 0)
miningProgressFrame.Visible = false
miningProgressFrame.Parent = screenGui

local progressBar = Instance.new("Frame")
progressBar.Name = "ProgressBar"
progressBar.Size = UDim2.new(1, 0, 1, 0)
progressBar.BackgroundColor3 = Color3.new(1, 0.84, 0)
progressBar.BorderSizePixel = 0
progressBar.Parent = miningProgressFrame

local miningText = Instance.new("TextLabel")
miningText.Name = "MiningText"
miningText.Size = UDim2.new(1, 0, 1, 0)
miningText.BackgroundTransparency = 1
miningText.Text = "Mining... +0 Gold"
miningText.TextColor3 = Color3.new(1, 1, 1)
miningText.TextScaled = true
miningText.Font = Enum.Font.GothamBold
miningText.TextStrokeTransparency = 0.5
miningText.Parent = miningProgressFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = miningProgressFrame

-- Hint text (shows when near mine but not mining)
local hintFrame = Instance.new("Frame")
hintFrame.Name = "MiningHint"
hintFrame.Size = UDim2.new(0, 200, 0, 30)
hintFrame.Position = UDim2.new(0.5, -100, 0.65, 0)
hintFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
hintFrame.BackgroundTransparency = 0.3
hintFrame.BorderSizePixel = 0
hintFrame.Visible = false
hintFrame.Parent = screenGui

local hintText = Instance.new("TextLabel")
hintText.Size = UDim2.new(1, 0, 1, 0)
hintText.BackgroundTransparency = 1
hintText.Text = "Hold E to mine"
hintText.TextColor3 = Color3.new(1, 0.84, 0)
hintText.TextScaled = true
hintText.Font = Enum.Font.GothamBold
hintText.Parent = hintFrame

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 6)
hintCorner.Parent = hintFrame

print("MiningSystem: Created UI")

-- Helper: Get mine under mouse or nearby
local function getMineNearby()
	local character = player.Character
	if not character then return nil end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return nil end

	-- First check what's under the mouse
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character}

	local result = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * MAX_MINE_DISTANCE * 2, raycastParams)

	if result then
		local hit = result.Instance
		-- Check if we hit a mine or part of a mine
		if hit.Parent and hit.Parent.Name == "GoldMine" then
			local mine = hit.Parent
			local orePart = mine:FindFirstChild("OrePart")
			if orePart then
				local distance = (humanoidRootPart.Position - orePart.Position).Magnitude
				if distance <= MAX_MINE_DISTANCE then
					return mine
				end
			end
		end
	end

	-- Also check for nearby mines (in case not looking directly at it)
	local nearestMine = nil
	local nearestDistance = MAX_MINE_DISTANCE

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "GoldMine" then
			local orePart = obj:FindFirstChild("OrePart")
			if orePart then
				local distance = (humanoidRootPart.Position - orePart.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestMine = obj
				end
			end
		end
	end

	return nearestMine
end

-- Helper: Update progress bar
local function updateProgressBar(goldMined)
	if not miningProgressFrame.Visible then
		miningProgressFrame.Visible = true
		hintFrame.Visible = false
	end

	-- Pulse the progress bar
	local pulse = (math.sin(tick() * 5) + 1) / 2 * 0.3 + 0.7
	progressBar.BackgroundTransparency = 1 - pulse

	miningText.Text = "Mining... +" .. math.floor(goldMined) .. " Gold"
end

-- Helper: Hide progress bar
local function hideProgressBar()
	miningProgressFrame.Visible = false
	progressBar.BackgroundTransparency = 0
end

-- Track total gold mined this session
local sessionGoldMined = 0
local lastMineTime = 0

-- Main update loop
RunService.RenderStepped:Connect(function(dt)
	local nearbyMine = getMineNearby()

	if isHoldingMineKey and nearbyMine then
		currentMine = nearbyMine
		hintFrame.Visible = false

		-- Check if mine has resources
		local resource = nearbyMine:FindFirstChild("Resource")
		if resource and resource.Value > 0 then
			-- Calculate gold to mine this frame
			local goldThisFrame = MINE_RATE * dt

			-- Update UI
			sessionGoldMined = sessionGoldMined + goldThisFrame
			updateProgressBar(sessionGoldMined)

			-- Send to server periodically (every 0.5 seconds)
			if tick() - lastMineTime >= 0.5 then
				local goldToSend = math.floor(MINE_RATE * 0.5)
				if goldToSend > 0 then
					mineGoldEvent:FireServer(nearbyMine, goldToSend)
					lastMineTime = tick()
				end
			end
		else
			-- Mine is depleted
			hideProgressBar()
			hintFrame.Visible = false
		end

	elseif nearbyMine then
		-- Near a mine but not mining - show hint
		local resource = nearbyMine:FindFirstChild("Resource")
		if resource and resource.Value > 0 then
			hintFrame.Visible = true
		else
			hintFrame.Visible = false
		end
		hideProgressBar()
		sessionGoldMined = 0

	else
		-- Not near any mine
		hintFrame.Visible = false
		hideProgressBar()
		currentMine = nil
		sessionGoldMined = 0
	end
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.E then
		local mine = getMineNearby()
		if mine then
			local resource = mine:FindFirstChild("Resource")
			if resource and resource.Value > 0 then
				isHoldingMineKey = true
				currentMine = mine
				miningStartTime = tick()
				sessionGoldMined = 0
				lastMineTime = tick()
				print("MiningSystem: Started mining")
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.E then
		if isHoldingMineKey and sessionGoldMined > 0 then
			-- Send any remaining gold
			local remainingGold = math.floor(sessionGoldMined) - math.floor((tick() - miningStartTime) / 0.5) * math.floor(MINE_RATE * 0.5)
			if remainingGold > 0 and currentMine then
				mineGoldEvent:FireServer(currentMine, remainingGold)
			end
		end

		isHoldingMineKey = false
		hideProgressBar()
		sessionGoldMined = 0
		print("MiningSystem: Stopped mining")
	end
end)

print("MiningSystem: Loaded - Hold E near gold mines to collect gold")
