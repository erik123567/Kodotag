local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Check if this is a game server or lobby server
-- For testing: show UI in Studio as well
local RunService = game:GetService("RunService")
local isStudio = RunService:IsStudio()
local isReservedServer = isStudio or (game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0)

-- Clear existing UI except notifications and rules
for _, child in ipairs(screenGui:GetChildren()) do
	if child.Name ~= "NotificationText" and child.Name ~= "RulesScreen" and child.Name ~= "LobbyStatusPanel" and not child:IsA("LocalScript") then
		child:Destroy()
	end
end

-- Notification text (center top for alerts)
local notificationText = screenGui:FindFirstChild("NotificationText")
if not notificationText then
	notificationText = Instance.new("TextLabel")
	notificationText.Name = "NotificationText"
	notificationText.Size = UDim2.new(0.5, 0, 0.08, 0)
	notificationText.Position = UDim2.new(0.25, 0, 0.12, 0)
	notificationText.BackgroundTransparency = 0.3
	notificationText.BackgroundColor3 = Color3.new(0, 0, 0)
	notificationText.TextScaled = true
	notificationText.Text = ""
	notificationText.TextColor3 = Color3.new(1, 1, 1)
	notificationText.Font = Enum.Font.GothamBold
	notificationText.Visible = false
	notificationText.Parent = screenGui

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(0, 8)
	notifCorner.Parent = notificationText
end

-- ============================================
-- GAME INFO PANEL (Top Center)
-- Shows: Wave, Round, Timer, Alive/Dead, Kodos
-- ============================================
local gameInfoPanel = Instance.new("Frame")
gameInfoPanel.Name = "GameInfoPanel"
gameInfoPanel.Size = UDim2.new(0.25, 0, 0.1, 0)
gameInfoPanel.Position = UDim2.new(0.375, 0, 0.01, 0)
gameInfoPanel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.12)
gameInfoPanel.BackgroundTransparency = 0.2
gameInfoPanel.BorderSizePixel = 0
gameInfoPanel.Visible = isReservedServer
gameInfoPanel.Parent = screenGui

local gameInfoCorner = Instance.new("UICorner")
gameInfoCorner.CornerRadius = UDim.new(0, 10)
gameInfoCorner.Parent = gameInfoPanel

local gameInfoStroke = Instance.new("UIStroke")
gameInfoStroke.Color = Color3.new(0.4, 0.4, 0.5)
gameInfoStroke.Thickness = 2
gameInfoStroke.Parent = gameInfoPanel

-- Wave display (large, top)
local waveLabel = Instance.new("TextLabel")
waveLabel.Name = "WaveLabel"
waveLabel.Size = UDim2.new(1, 0, 0.45, 0)
waveLabel.Position = UDim2.new(0, 0, 0, 0)
waveLabel.BackgroundTransparency = 1
waveLabel.Text = "WAVE 1"
waveLabel.TextColor3 = Color3.new(1, 0.7, 0.2)
waveLabel.Font = Enum.Font.GothamBlack
waveLabel.TextScaled = true
waveLabel.Parent = gameInfoPanel

-- Bottom row with Round, Timer, Players, Kodos
local infoRow = Instance.new("Frame")
infoRow.Name = "InfoRow"
infoRow.Size = UDim2.new(1, -10, 0.45, 0)
infoRow.Position = UDim2.new(0, 5, 0.5, 0)
infoRow.BackgroundTransparency = 1
infoRow.Parent = gameInfoPanel

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(0.25, 0, 1, 0)
timerLabel.Position = UDim2.new(0, 0, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "0:00"
timerLabel.TextColor3 = Color3.new(1, 1, 0)
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextScaled = true
timerLabel.Parent = infoRow

local playersLabel = Instance.new("TextLabel")
playersLabel.Name = "PlayersLabel"
playersLabel.Size = UDim2.new(0.25, 0, 1, 0)
playersLabel.Position = UDim2.new(0.25, 0, 0, 0)
playersLabel.BackgroundTransparency = 1
playersLabel.Text = "0/0"
playersLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
playersLabel.Font = Enum.Font.GothamBold
playersLabel.TextScaled = true
playersLabel.Parent = infoRow

local kodosLabel = Instance.new("TextLabel")
kodosLabel.Name = "KodosLabel"
kodosLabel.Size = UDim2.new(0.25, 0, 1, 0)
kodosLabel.Position = UDim2.new(0.5, 0, 0, 0)
kodosLabel.BackgroundTransparency = 1
kodosLabel.Text = "K:0"
kodosLabel.TextColor3 = Color3.new(1, 0.4, 0.4)
kodosLabel.Font = Enum.Font.GothamBold
kodosLabel.TextScaled = true
kodosLabel.Parent = infoRow

local goldLabel = Instance.new("TextLabel")
goldLabel.Name = "GoldLabel"
goldLabel.Size = UDim2.new(0.25, 0, 1, 0)
goldLabel.Position = UDim2.new(0.75, 0, 0, 0)
goldLabel.BackgroundTransparency = 1
goldLabel.Text = "0g"
goldLabel.TextColor3 = Color3.new(1, 0.84, 0)
goldLabel.Font = Enum.Font.GothamBold
goldLabel.TextScaled = true
goldLabel.Parent = infoRow

-- ============================================
-- PLAYER STATS PANEL (Right Side)
-- Shows each player: Name, Kills, Deaths, Saves
-- ============================================
local playerStatsFrame = Instance.new("Frame")
playerStatsFrame.Name = "PlayerStatsFrame"
playerStatsFrame.Size = UDim2.new(0.22, 0, 0.5, 0)
playerStatsFrame.Position = UDim2.new(0.77, 0, 0.12, 0)
playerStatsFrame.BackgroundColor3 = Color3.new(0.08, 0.08, 0.1)
playerStatsFrame.BackgroundTransparency = 0.2
playerStatsFrame.BorderSizePixel = 0
playerStatsFrame.Visible = isReservedServer
playerStatsFrame.Parent = screenGui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 10)
statsCorner.Parent = playerStatsFrame

local statsStroke = Instance.new("UIStroke")
statsStroke.Color = Color3.new(0.3, 0.3, 0.4)
statsStroke.Thickness = 2
statsStroke.Parent = playerStatsFrame

-- Title
local statsTitle = Instance.new("TextLabel")
statsTitle.Name = "StatsTitle"
statsTitle.Size = UDim2.new(1, 0, 0.08, 0)
statsTitle.Position = UDim2.new(0, 0, 0.01, 0)
statsTitle.BackgroundTransparency = 1
statsTitle.Text = "PLAYER STATS"
statsTitle.TextColor3 = Color3.new(1, 1, 1)
statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextScaled = true
statsTitle.Parent = playerStatsFrame

-- Column headers
local headerFrame = Instance.new("Frame")
headerFrame.Name = "HeaderFrame"
headerFrame.Size = UDim2.new(1, -10, 0.07, 0)
headerFrame.Position = UDim2.new(0, 5, 0.1, 0)
headerFrame.BackgroundTransparency = 1
headerFrame.Parent = playerStatsFrame

local headerName = Instance.new("TextLabel")
headerName.Size = UDim2.new(0.4, 0, 1, 0)
headerName.Position = UDim2.new(0, 0, 0, 0)
headerName.BackgroundTransparency = 1
headerName.Text = "Player"
headerName.TextColor3 = Color3.new(0.7, 0.7, 0.7)
headerName.Font = Enum.Font.Gotham
headerName.TextScaled = true
headerName.TextXAlignment = Enum.TextXAlignment.Left
headerName.Parent = headerFrame

local headerKills = Instance.new("TextLabel")
headerKills.Size = UDim2.new(0.2, 0, 1, 0)
headerKills.Position = UDim2.new(0.4, 0, 0, 0)
headerKills.BackgroundTransparency = 1
headerKills.Text = "Kills"
headerKills.TextColor3 = Color3.new(0.7, 0.7, 0.7)
headerKills.Font = Enum.Font.Gotham
headerKills.TextScaled = true
headerKills.Parent = headerFrame

local headerDeaths = Instance.new("TextLabel")
headerDeaths.Size = UDim2.new(0.2, 0, 1, 0)
headerDeaths.Position = UDim2.new(0.6, 0, 0, 0)
headerDeaths.BackgroundTransparency = 1
headerDeaths.Text = "Deaths"
headerDeaths.TextColor3 = Color3.new(0.7, 0.7, 0.7)
headerDeaths.Font = Enum.Font.Gotham
headerDeaths.TextScaled = true
headerDeaths.Parent = headerFrame

local headerSaves = Instance.new("TextLabel")
headerSaves.Size = UDim2.new(0.2, 0, 1, 0)
headerSaves.Position = UDim2.new(0.8, 0, 0, 0)
headerSaves.BackgroundTransparency = 1
headerSaves.Text = "Saves"
headerSaves.TextColor3 = Color3.new(0.7, 0.7, 0.7)
headerSaves.Font = Enum.Font.Gotham
headerSaves.TextScaled = true
headerSaves.Parent = headerFrame

-- ScrollingFrame for player list
local playerListScroll = Instance.new("ScrollingFrame")
playerListScroll.Name = "PlayerListScroll"
playerListScroll.Size = UDim2.new(1, -10, 0.8, 0)
playerListScroll.Position = UDim2.new(0, 5, 0.18, 0)
playerListScroll.BackgroundTransparency = 1
playerListScroll.BorderSizePixel = 0
playerListScroll.ScrollBarThickness = 4
playerListScroll.ScrollBarImageColor3 = Color3.new(0.5, 0.5, 0.5)
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

	-- Convert to array and sort by kills (descending)
	local sortedPlayers = {}
	for playerName, stats in pairs(playerStats) do
		table.insert(sortedPlayers, {name = playerName, stats = stats})
	end
	table.sort(sortedPlayers, function(a, b)
		return a.stats.kodoKills > b.stats.kodoKills
	end)

	local yOffset = 0
	for _, playerData in ipairs(sortedPlayers) do
		local playerName = playerData.name
		local stats = playerData.stats
		local isLocalPlayer = (playerName == player.Name)

		local playerRow = Instance.new("Frame")
		playerRow.Size = UDim2.new(1, 0, 0, 28)
		playerRow.Position = UDim2.new(0, 0, 0, yOffset)
		playerRow.BackgroundColor3 = isLocalPlayer and Color3.new(0.2, 0.25, 0.15) or Color3.new(0.12, 0.12, 0.14)
		playerRow.BackgroundTransparency = 0.3
		playerRow.BorderSizePixel = 0
		playerRow.Parent = playerListScroll

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 4)
		rowCorner.Parent = playerRow

		-- Player name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 5, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = playerName
		nameLabel.TextColor3 = isLocalPlayer and Color3.new(0.5, 1, 0.5) or Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = playerRow

		-- Kills
		local killsLabel = Instance.new("TextLabel")
		killsLabel.Size = UDim2.new(0.2, 0, 1, 0)
		killsLabel.Position = UDim2.new(0.4, 0, 0, 0)
		killsLabel.BackgroundTransparency = 1
		killsLabel.Text = tostring(stats.kodoKills)
		killsLabel.TextColor3 = Color3.new(1, 1, 0.4)
		killsLabel.Font = Enum.Font.GothamBold
		killsLabel.TextScaled = true
		killsLabel.Parent = playerRow

		-- Deaths
		local deathsLabel = Instance.new("TextLabel")
		deathsLabel.Size = UDim2.new(0.2, 0, 1, 0)
		deathsLabel.Position = UDim2.new(0.6, 0, 0, 0)
		deathsLabel.BackgroundTransparency = 1
		deathsLabel.Text = tostring(stats.deaths)
		deathsLabel.TextColor3 = Color3.new(1, 0.4, 0.4)
		deathsLabel.Font = Enum.Font.GothamBold
		deathsLabel.TextScaled = true
		deathsLabel.Parent = playerRow

		-- Saves
		local savesLabel = Instance.new("TextLabel")
		savesLabel.Size = UDim2.new(0.2, 0, 1, 0)
		savesLabel.Position = UDim2.new(0.8, 0, 0, 0)
		savesLabel.BackgroundTransparency = 1
		savesLabel.Text = tostring(stats.saves)
		savesLabel.TextColor3 = Color3.new(0.4, 1, 0.8)
		savesLabel.Font = Enum.Font.GothamBold
		savesLabel.TextScaled = true
		savesLabel.Parent = playerRow

		yOffset = yOffset + 32
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
		-- Update wave display
		if data.wave then
			waveLabel.Text = "WAVE " .. data.wave
		end

		-- Update info row
		timerLabel.Text = formatTime(data.time)
		playersLabel.Text = data.alive .. "/" .. (data.alive + data.dead)

		if data.kodosRemaining then
			kodosLabel.Text = "K:" .. data.kodosRemaining
		end
	end)

	-- Listen for player stats updates
	updatePlayerStats.OnClientEvent:Connect(function(playerStats)
		updatePlayerStatsList(playerStats)

		-- Update gold display
		if playerStats[player.Name] then
			goldLabel.Text = playerStats[player.Name].gold .. "g"
		end
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
