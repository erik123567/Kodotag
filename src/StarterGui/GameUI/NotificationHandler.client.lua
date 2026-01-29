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

-- Create prominent wave display (center-top) - ONLY FOR GAME SERVERS
local waveDisplay = Instance.new("Frame")
waveDisplay.Name = "WaveDisplay"
waveDisplay.Size = UDim2.new(0.15, 0, 0.06, 0)
waveDisplay.Position = UDim2.new(0.425, 0, 0.02, 0)
waveDisplay.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
waveDisplay.BackgroundTransparency = 0.2
waveDisplay.BorderSizePixel = 0
waveDisplay.Visible = isReservedServer
waveDisplay.Parent = screenGui

local waveCorner = Instance.new("UICorner")
waveCorner.CornerRadius = UDim.new(0, 10)
waveCorner.Parent = waveDisplay

local waveStroke = Instance.new("UIStroke")
waveStroke.Color = Color3.new(1, 0.5, 0)
waveStroke.Thickness = 2
waveStroke.Parent = waveDisplay

local waveLabel = Instance.new("TextLabel")
waveLabel.Name = "WaveLabel"
waveLabel.Size = UDim2.new(1, 0, 1, 0)
waveLabel.BackgroundTransparency = 1
waveLabel.Text = "WAVE 1"
waveLabel.TextColor3 = Color3.new(1, 0.7, 0.2)
waveLabel.Font = Enum.Font.GothamBlack
waveLabel.TextScaled = true
waveLabel.Parent = waveDisplay

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
statsTitle.Text = "KILL LEADERBOARD"
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

-- Function to update player stats list (sorted by kills as leaderboard)
local function updatePlayerStatsList(playerStats)
	-- Clear existing
	for _, child in ipairs(playerListScroll:GetChildren()) do
		child:Destroy()
	end

	-- Convert to array and sort by kills (descending)
	local sortedPlayers = {}
	for playerName, stats in pairs(playerStats) do
		table.insert(sortedPlayers, {name = playerName, stats = stats})
	end
	table.sort(sortedPlayers, function(a, b)
		return a.stats.kodoKills > b.stats.kodoKills
	end)

	local yOffset = 0
	for rank, playerData in ipairs(sortedPlayers) do
		local playerName = playerData.name
		local stats = playerData.stats

		local playerFrame = Instance.new("Frame")
		playerFrame.Size = UDim2.new(1, -10, 0, 55)
		playerFrame.Position = UDim2.new(0, 5, 0, yOffset)
		playerFrame.BackgroundColor3 = rank == 1 and Color3.new(0.3, 0.25, 0.05) or Color3.new(0.1, 0.1, 0.1)
		playerFrame.BackgroundTransparency = 0.5
		playerFrame.BorderSizePixel = 0
		playerFrame.Parent = playerListScroll

		-- Rank indicator
		local rankLabel = Instance.new("TextLabel")
		rankLabel.Size = UDim2.new(0.15, 0, 0.55, 0)
		rankLabel.Position = UDim2.new(0, 0, 0, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Text = "#" .. rank
		rankLabel.TextColor3 = rank == 1 and Color3.new(1, 0.84, 0) or Color3.new(0.7, 0.7, 0.7)
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.TextScaled = true
		rankLabel.Parent = playerFrame

		-- Player name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.5, 0, 0.55, 0)
		nameLabel.Position = UDim2.new(0.15, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = playerName
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = playerFrame

		-- Kill count (prominent)
		local killsLabel = Instance.new("TextLabel")
		killsLabel.Size = UDim2.new(0.35, 0, 0.55, 0)
		killsLabel.Position = UDim2.new(0.65, 0, 0, 0)
		killsLabel.BackgroundTransparency = 1
		killsLabel.Text = stats.kodoKills .. " kills"
		killsLabel.TextColor3 = Color3.new(1, 1, 0.5)
		killsLabel.Font = Enum.Font.GothamBold
		killsLabel.TextScaled = true
		killsLabel.TextXAlignment = Enum.TextXAlignment.Right
		killsLabel.Parent = playerFrame

		-- Deaths/Saves row
		local statsRow = Instance.new("TextLabel")
		statsRow.Size = UDim2.new(0.85, 0, 0.4, 0)
		statsRow.Position = UDim2.new(0.15, 0, 0.55, 0)
		statsRow.BackgroundTransparency = 1
		statsRow.Text = "Deaths: " .. stats.deaths .. "  |  Saves: " .. stats.saves
		statsRow.TextColor3 = Color3.new(0.6, 0.6, 0.6)
		statsRow.Font = Enum.Font.Gotham
		statsRow.TextScaled = true
		statsRow.TextXAlignment = Enum.TextXAlignment.Left
		statsRow.Parent = playerFrame

		yOffset = yOffset + 60
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

		-- Update prominent wave display
		if data.wave then
			waveLabel.Text = "WAVE " .. data.wave
		end
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