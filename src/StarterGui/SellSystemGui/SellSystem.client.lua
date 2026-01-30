local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Check if this is a game server (set by GameInitializer)
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	print("SellSystem: Lobby - disabled")
	return
end

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- Settings
local HOLD_DURATION = 1
local SELL_PERCENTAGE = 0.5
local MAX_SELL_DISTANCE = 50

-- Item costs (must match build menu)
local ITEM_COSTS = {
	Turret = 50,
	FastTurret = 75,
	SlowTurret = 30,
	FrostTurret = 100,
	PoisonTurret = 90,
	MultiShotTurret = 120,
	CannonTurret = 150,
	Wall = 25,
	Farm = 75,
	Workshop = 150
}

-- State
local isHoldingSellKey = false
local currentTarget = nil
local holdStartTime = 0

-- Remote event
local sellBuildingEvent = ReplicatedStorage:WaitForChild("SellBuilding", 10)
if not sellBuildingEvent then
	sellBuildingEvent = Instance.new("RemoteEvent")
	sellBuildingEvent.Name = "SellBuilding"
	sellBuildingEvent.Parent = ReplicatedStorage
end

-- UI Setup
local screenGui = script.Parent
local sellProgressFrame = Instance.new("Frame")
sellProgressFrame.Name = "SellProgressFrame"
sellProgressFrame.Size = UDim2.new(0, 200, 0, 40)
sellProgressFrame.Position = UDim2.new(0.5, -100, 0.7, 0)
sellProgressFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
sellProgressFrame.BorderSizePixel = 2
sellProgressFrame.BorderColor3 = Color3.new(1, 1, 1)
sellProgressFrame.Visible = false
sellProgressFrame.Parent = screenGui

local progressBar = Instance.new("Frame")
progressBar.Name = "ProgressBar"
progressBar.Size = UDim2.new(0, 0, 1, 0)
progressBar.BackgroundColor3 = Color3.new(1, 0.5, 0)
progressBar.BorderSizePixel = 0
progressBar.Parent = sellProgressFrame

local sellText = Instance.new("TextLabel")
sellText.Name = "SellText"
sellText.Size = UDim2.new(1, 0, 1, 0)
sellText.BackgroundTransparency = 1
sellText.Text = "Selling... +0 Gold"
sellText.TextColor3 = Color3.new(1, 1, 1)
sellText.TextScaled = true
sellText.Font = Enum.Font.GothamBold
sellText.TextStrokeTransparency = 0.5
sellText.Parent = sellProgressFrame

-- Helper: Get building under mouse
local function getBuildingUnderMouse()
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {player.Character}

	local result = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * MAX_SELL_DISTANCE, raycastParams)

	if result then
		local hit = result.Instance
		local building = hit.Parent

		-- Check if it's a valid building
		local validNames = {
			Wall = true, Turret = true, FastTurret = true, SlowTurret = true,
			FrostTurret = true, PoisonTurret = true, MultiShotTurret = true, CannonTurret = true,
			Farm = true, Workshop = true
		}
		if validNames[building.Name] then
			return building
		elseif validNames[hit.Name] then
			return hit
		end
	end

	return nil
end

-- Helper: Calculate sell value
local function getSellValue(building)
	local buildingName = building.Name
	local originalCost = ITEM_COSTS[buildingName] or 0
	return math.floor(originalCost * SELL_PERCENTAGE)
end

-- Helper: Update progress bar
local function updateProgressBar(progress, building)
	if not sellProgressFrame.Visible then
		sellProgressFrame.Visible = true
	end

	local sellValue = getSellValue(building)
	progressBar.Size = UDim2.new(progress, 0, 1, 0)
	sellText.Text = "Selling... +" .. sellValue .. " Gold"
end

-- Helper: Hide progress bar
local function hideProgressBar()
	sellProgressFrame.Visible = false
	progressBar.Size = UDim2.new(0, 0, 1, 0)
end

-- Main update loop
RunService.RenderStepped:Connect(function()
	if isHoldingSellKey then
		local building = getBuildingUnderMouse()

		if building and building == currentTarget then
			-- Still holding on same building
			local holdDuration = tick() - holdStartTime
			local progress = math.min(holdDuration / HOLD_DURATION, 1)

			updateProgressBar(progress, building)

			-- Completed hold
			if progress >= 1 then
				print("SellSystem: Selling", building.Name)
				sellBuildingEvent:FireServer(building)

				-- Reset
				isHoldingSellKey = false
				currentTarget = nil
				hideProgressBar()
			end
		else
			-- Changed target or no target
			if building ~= currentTarget then
				-- Reset if changed target
				currentTarget = building
				holdStartTime = tick()

				if building then
					updateProgressBar(0, building)
				else
					hideProgressBar()
				end
			end
		end
	else
		-- Not holding key
		hideProgressBar()
		currentTarget = nil
	end
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.E then
		local building = getBuildingUnderMouse()

		if building then
			isHoldingSellKey = true
			currentTarget = building
			holdStartTime = tick()
			print("SellSystem: Started holding E on", building.Name)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.E then
		isHoldingSellKey = false
		hideProgressBar()
		print("SellSystem: Released E")
	end
end)

print("SellSystem: Loaded - Hold E to sell buildings for 50% value")
