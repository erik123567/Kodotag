local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Check if this is a game server or lobby server
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

-- Clear existing UI except notifications and rules
for _, child in ipairs(screenGui:GetChildren()) do
	if child.Name ~= "NotificationText" and child.Name ~= "RulesScreen" and child.Name ~= "LobbyStatusPanel" and not child:IsA("LocalScript") then
		child:Destroy()
	end
end

-- Notification text
local notificationText = screenGui:FindFirstChild("NotificationText")
if not notificationText then
	notificationText = Instance.new("TextLabel")
	notificationText.Name = "NotificationText"
	notificationText.Size = UDim2.new(0.5, 0, 0.1, 0)
	notificationText.Position = UDim2.new(0.25, 0, 0.05, 0)
	notificationText.BackgroundTransparency = 0.5
	notificationText.BackgroundColor3 = Color3.new(0, 0, 0)
	notificationText.TextScaled = true
	notificationText.Text = ""
	notificationText.TextColor3 = Color3.new(1, 1, 1)
	notificationText.Font = Enum.Font.GothamBold
	notificationText.Visible = false
	notificationText.Parent = screenGui
end

-- Create main stats panel (top left) - ONLY FOR GAME SERVERS
local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsFrame"
statsFrame.Size = UDim2.new(0.25, 0, 0.2, 0)
statsFrame.Position = UDim2.new(0.02, 0, 0.02, 0)
statsFrame.BackgroundColor3 = Color3.new(0, 0, 0)
statsFrame.BackgroundTransparency = 0.3
statsFrame.BorderSizePixel = 0
statsFrame.Visible = isReservedServer -- Hide in lobby, show in game
statsFrame.Parent = screenGui

-- Round display
local roundLabel = Instance.new("TextLabel")
roundLabel.Name = "RoundLabel"
roundLabel.Size = UDim2.new(1, 0, 0.25, 0)
roundLabel.Position = UDim2.new(0, 0, 0, 0)
roundLabel.BackgroundTransparency = 1
roundLabel.Text = "Round: 1"
roundLabel.TextColor3 = Color3.new(1, 1, 1)
roundLabel.Font = Enum.Font.GothamBold
roundLabel.TextScaled = true
roundLabel.Parent = statsFrame

-- Alive count
local aliveLabel = Instance.new("TextLabel")
aliveLabel.Name = "AliveLabel"
aliveLabel.Size = UDim2.new(1, 0, 0.25, 0)
aliveLabel.Position = UDim2.new(0, 0, 0.25, 0)
aliveLabel.BackgroundTransparency = 1
aliveLabel.Text = "Alive: 0"
aliveLabel.TextColor3 = Color3.new(0, 1, 0)
aliveLabel.Font = Enum.Font.GothamBold
aliveLabel.TextScaled = true
aliveLabel.Parent = statsFrame

-- Dead count
local deadLabel = Instance.new("TextLabel")
deadLabel.Name = "DeadLabel"
deadLabel.Size = UDim2.new(1, 0, 0.25, 0)
deadLabel.Position = UDim2.new(0, 0, 0.5, 0)
deadLabel.BackgroundTransparency = 1
deadLabel.Text = "Dead: 0"
deadLabel.TextColor3 = Color3.new(1, 0, 0)
deadLabel.Font = Enum.Font.GothamBold
deadLabel.TextScaled = true
deadLabel.Parent = statsFrame

-- Timer
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, 0, 0.25, 0)
timerLabel.Position = UDim2.new(0, 0, 0.75, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "Time: 0:00"
timerLabel.TextColor3 = Color3.new(1, 1, 0)
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextScaled = true
timerLabel.Parent = statsFrame

-- Create player stats panel (right side) - ONLY FOR GAME SERVERS
local playerStatsFrame = Instance.new("Frame")
playerStatsFrame.Name = "PlayerStatsFrame"
playerStatsFrame.Size = UDim2.new(0.25, 0, 0.6, 0)
playerStatsFrame.Position = UDim2.new(0.73, 0, 0.02, 0)
playerStatsFrame.BackgroundColor3 = Color3.new(0, 0, 0)
playerStatsFrame.BackgroundTransparency = 0.3
playerStatsFrame.BorderSizePixel = 0
playerStatsFrame.Visible = isReservedServer -- Hide in lobby, show in game
playerStatsFrame.Parent = screenGui

-- Player stats title
local statsTitle = Instance.new("TextLabel")
statsTitle.Name = "StatsTitle"
statsTitle.Size = UDim2.new(1, 0, 0.1, 0)
statsTitle.Position = UDim2.new(0, 0, 0, 0)
statsTitle.BackgroundTransparency = 1
statsTitle.Text = "PLAYER STATS"
statsTitle.TextColor3 = Color3.new(1, 1, 1)
statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextScaled = true
statsTitle.Parent = playerStatsFrame

-- ScrollingFrame for player list
local playerListScroll = Instance.new("ScrollingFrame")
playerListScroll.Name = "PlayerListScroll"
playerListScroll.Size = UDim2.new(1, 0, 0.9, 0)
playerListScroll.Position = UDim2.new(0, 0, 0.1, 0)
playerListScroll.BackgroundTransparency = 1
playerListScroll.BorderSizePixel = 0
playerListScroll.ScrollBarThickness = 6
playerListScroll.Parent = playerStatsFrame

-- Function to format time
local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", minutes, secs)
end

-- Function to update player stats list
local function updatePlayerStatsList(playerStats)
	-- Clear existing
	for _, child in ipairs(playerListScroll:GetChildren()) do
		child:Destroy()
	end

	local yOffset = 0
	for playerName, stats in pairs(playerStats) do
		local playerFrame = Instance.new("Frame")
		playerFrame.Size = UDim2.new(1, -10, 0, 60)
		playerFrame.Position = UDim2.new(0, 5, 0, yOffset)
		playerFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
		playerFrame.BackgroundTransparency = 0.5
		playerFrame.BorderSizePixel = 0
		playerFrame.Parent = playerListScroll

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = playerName
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = playerFrame

		local deathsLabel = Instance.new("TextLabel")
		deathsLabel.Size = UDim2.new(1, 0, 0.23, 0)
		deathsLabel.Position = UDim2.new(0, 0, 0.33, 0)
		deathsLabel.BackgroundTransparency = 1
		deathsLabel.Text = "Deaths: " .. stats.deaths
		deathsLabel.TextColor3 = Color3.new(1, 0.5, 0.5)
		deathsLabel.Font = Enum.Font.Gotham
		deathsLabel.TextScaled = true
		deathsLabel.TextXAlignment = Enum.TextXAlignment.Left
		deathsLabel.Parent = playerFrame

		local savesLabel = Instance.new("TextLabel")
		savesLabel.Size = UDim2.new(0.5, 0, 0.23, 0)
		savesLabel.Position = UDim2.new(0, 0, 0.56, 0)
		savesLabel.BackgroundTransparency = 1
		savesLabel.Text = "Saves: " .. stats.saves
		savesLabel.TextColor3 = Color3.new(0.5, 1, 0.5)
		savesLabel.Font = Enum.Font.Gotham
		savesLabel.TextScaled = true
		savesLabel.TextXAlignment = Enum.TextXAlignment.Left
		savesLabel.Parent = playerFrame

		local killsLabel = Instance.new("TextLabel")
		killsLabel.Size = UDim2.new(0.5, 0, 0.23, 0)
		killsLabel.Position = UDim2.new(0.5, 0, 0.56, 0)
		killsLabel.BackgroundTransparency = 1
		killsLabel.Text = "Kills: " .. stats.kodoKills
		killsLabel.TextColor3 = Color3.new(1, 1, 0.5)
		killsLabel.Font = Enum.Font.Gotham
		killsLabel.TextScaled = true
		killsLabel.TextXAlignment = Enum.TextXAlignment.Left
		killsLabel.Parent = playerFrame

		yOffset = yOffset + 65
	end

	playerListScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

-- Only set up RemoteEvent listeners in game servers
if isReservedServer then
	print("Game server - Waiting for RemoteEvents...")

	-- Wait for RemoteEvents to be created
	local updateGameState = ReplicatedStorage:WaitForChild("UpdateGameState", 10)
	local updatePlayerStats = ReplicatedStorage:WaitForChild("UpdatePlayerStats", 10)
	local showNotification = ReplicatedStorage:WaitForChild("ShowNotification", 10)

	if not updateGameState or not updatePlayerStats or not showNotification then
		warn("HUD: Failed to find RemoteEvents!")
		return
	end

	print("HUD: Found all RemoteEvents")

	-- Listen for game state updates
	updateGameState.OnClientEvent:Connect(function(data)
		roundLabel.Text = "Round: " .. data.round
		aliveLabel.Text = "Alive: " .. data.alive
		deadLabel.Text = "Dead: " .. data.dead
		timerLabel.Text = "Time: " .. formatTime(data.time)
	end)

	-- Listen for player stats updates
	updatePlayerStats.OnClientEvent:Connect(function(playerStats)
		updatePlayerStatsList(playerStats)
	end)

	-- Listen for notification events
	showNotification.OnClientEvent:Connect(function(message, color)
		notificationText.Text = message
		notificationText.TextColor3 = color or Color3.new(1, 1, 1)
		notificationText.Visible = true

		wait(3)
		notificationText.Visible = false
	end)

	print("HUD loaded successfully!")
else
	print("Lobby server - Game UI hidden")
end