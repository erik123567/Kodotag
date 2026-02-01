local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Check if this is a game server (set by GameInitializer)
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	print("GoldDisplayUpdater: Lobby - disabled")
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("GoldDisplayUpdater: Starting...")

-- Create UI elements
local screenGui = script.Parent

local goldDisplay = screenGui:FindFirstChild("GoldDisplay")
if not goldDisplay then
	goldDisplay = Instance.new("Frame")
	goldDisplay.Name = "GoldDisplay"
	goldDisplay.Size = UDim2.new(0, 150, 0, 50)
	goldDisplay.Position = UDim2.new(1, -160, 0, 10)
	goldDisplay.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	goldDisplay.BackgroundTransparency = 0.3
	goldDisplay.BorderSizePixel = 0
	goldDisplay.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = goldDisplay

	print("GoldDisplayUpdater: Created GoldDisplay frame")
end

local goldText = goldDisplay:FindFirstChild("GoldText")
if not goldText then
	goldText = Instance.new("TextLabel")
	goldText.Name = "GoldText"
	goldText.Size = UDim2.new(1, 0, 1, 0)
	goldText.Position = UDim2.new(0, 0, 0, 0)
	goldText.BackgroundTransparency = 1
	goldText.Text = "Gold: 0"
	goldText.TextColor3 = Color3.new(1, 0.84, 0) -- Gold color
	goldText.TextScaled = true
	goldText.Font = Enum.Font.GothamBold
	goldText.Parent = goldDisplay

	print("GoldDisplayUpdater: Created GoldText label")
end

print("GoldDisplayUpdater: UI ready")

-- Hide the standalone gold display (gold is now shown in main game info panel)
goldDisplay.Visible = false

-- Set initial text
goldText.Text = "Gold: 50"

-- Wait for UpdatePlayerStats event
local updatePlayerStats = ReplicatedStorage:WaitForChild("UpdatePlayerStats", 10)

if updatePlayerStats then
	print("GoldDisplayUpdater: Found UpdatePlayerStats event")

	-- Listen for player stats updates
	updatePlayerStats.OnClientEvent:Connect(function(playerStats)
		-- Get this player's stats
		if playerStats[player.Name] then
			local stats = playerStats[player.Name]
			local goldAmount = stats.gold or 0
			goldText.Text = "Gold: " .. goldAmount
		end
	end)

	print("GoldDisplayUpdater: Listening for updates")
else
	warn("GoldDisplayUpdater: UpdatePlayerStats event not found!")
end

-- Farm income floating text
local TweenService = game:GetService("TweenService")

local function showFarmIncomeText(farm, amount)
	-- Get farm position
	local farmPos
	if farm:IsA("Model") and farm.PrimaryPart then
		farmPos = farm.PrimaryPart.Position
	elseif farm:IsA("BasePart") then
		farmPos = farm.Position
	else
		return
	end

	-- Create BillboardGui for floating text
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FarmIncomeText"
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = farm:IsA("Model") and farm.PrimaryPart or farm
	billboard.Parent = playerGui

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "+" .. math.floor(amount) .. " gold"
	textLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold color
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.TextStrokeTransparency = 0.3
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = 18
	textLabel.Parent = billboard

	-- Animate: float up and fade out
	task.spawn(function()
		local startOffset = Vector3.new(0, 5, 0)
		local endOffset = Vector3.new(0, 10, 0)

		for i = 0, 1, 0.05 do
			billboard.StudsOffset = startOffset:Lerp(endOffset, i)
			textLabel.TextTransparency = i * 0.8
			textLabel.TextStrokeTransparency = 0.3 + (i * 0.7)
			task.wait(0.03)
		end

		billboard:Destroy()
	end)
end

-- Listen for farm income events
local showFarmIncome = ReplicatedStorage:WaitForChild("ShowFarmIncome", 10)
if showFarmIncome then
	showFarmIncome.OnClientEvent:Connect(function(farm, amount)
		if farm and farm.Parent then
			showFarmIncomeText(farm, amount)
		end
	end)
	print("GoldDisplayUpdater: Listening for farm income")
end
