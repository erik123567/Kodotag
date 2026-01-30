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
