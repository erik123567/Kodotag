local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Check if this is a game server (set by GameInitializer)
local isStudio = RunService:IsStudio()
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
local isReservedServer = isStudio or (isGameServerValue and isGameServerValue.Value)

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
-- GAME INFO PANEL (Top Right, above player stats)
-- Shows: Wave, Timer, Alive/Dead, Kodos, Gold
-- ============================================
local gameInfoPanel = Instance.new("Frame")
gameInfoPanel.Name = "GameInfoPanel"
gameInfoPanel.Size = UDim2.new(0.22, 0, 0.1, 0)
gameInfoPanel.Position = UDim2.new(0.77, 0, 0.01, 0)
gameInfoPanel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.12)
gameInfoPanel.BackgroundTransparency = 0.2
gameInfoPanel.BorderSizePixel = 0
gameInfoPanel.Visible = false -- Hidden until round starts
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
-- PLAYER STATS PANEL (Right Side, below game info)
-- Shows each player: Name, Kills, Deaths, Saves
-- ============================================
local playerStatsFrame = Instance.new("Frame")
playerStatsFrame.Name = "PlayerStatsFrame"
playerStatsFrame.Size = UDim2.new(0.22, 0, 0.45, 0)
playerStatsFrame.Position = UDim2.new(0.77, 0, 0.12, 0)
playerStatsFrame.BackgroundColor3 = Color3.new(0.08, 0.08, 0.1)
playerStatsFrame.BackgroundTransparency = 0.2
playerStatsFrame.BorderSizePixel = 0
playerStatsFrame.Visible = false -- Hidden until round starts
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
		-- Show UI only when round is active (players are in game)
		local roundActive = (data.alive + data.dead) > 0
		gameInfoPanel.Visible = roundActive
		playerStatsFrame.Visible = roundActive

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

	-- ============================================
	-- WAVE PREVIEW UI (Compact, top-left corner)
	-- Shows incoming wave composition before spawn
	-- ============================================
	local wavePreviewFrame = Instance.new("Frame")
	wavePreviewFrame.Name = "WavePreviewFrame"
	wavePreviewFrame.Size = UDim2.new(0, 280, 0, 140)
	wavePreviewFrame.Position = UDim2.new(0, 10, 0, 80)
	wavePreviewFrame.BackgroundColor3 = Color3.new(0.08, 0.08, 0.12)
	wavePreviewFrame.BackgroundTransparency = 0.15
	wavePreviewFrame.BorderSizePixel = 0
	wavePreviewFrame.Visible = false
	wavePreviewFrame.Parent = screenGui

	local previewCorner = Instance.new("UICorner")
	previewCorner.CornerRadius = UDim.new(0, 8)
	previewCorner.Parent = wavePreviewFrame

	local previewStroke = Instance.new("UIStroke")
	previewStroke.Color = Color3.new(1, 0.5, 0)
	previewStroke.Thickness = 2
	previewStroke.Parent = wavePreviewFrame

	-- Wave title (compact)
	local waveTitle = Instance.new("TextLabel")
	waveTitle.Name = "WaveTitle"
	waveTitle.Size = UDim2.new(1, -10, 0, 24)
	waveTitle.Position = UDim2.new(0, 5, 0, 5)
	waveTitle.BackgroundTransparency = 1
	waveTitle.Text = "WAVE 1 INCOMING"
	waveTitle.TextColor3 = Color3.new(1, 0.7, 0.3)
	waveTitle.Font = Enum.Font.GothamBold
	waveTitle.TextSize = 16
	waveTitle.TextXAlignment = Enum.TextXAlignment.Left
	waveTitle.Parent = wavePreviewFrame

	-- Countdown on same line as title (right side)
	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownLabel"
	countdownLabel.Size = UDim2.new(0, 60, 0, 24)
	countdownLabel.Position = UDim2.new(1, -65, 0, 5)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = "5s"
	countdownLabel.TextColor3 = Color3.new(1, 1, 0)
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.TextSize = 16
	countdownLabel.TextXAlignment = Enum.TextXAlignment.Right
	countdownLabel.Parent = wavePreviewFrame

	-- Kodo composition container (scrollable if needed)
	local compositionFrame = Instance.new("ScrollingFrame")
	compositionFrame.Name = "CompositionFrame"
	compositionFrame.Size = UDim2.new(1, -10, 0, 100)
	compositionFrame.Position = UDim2.new(0, 5, 0, 32)
	compositionFrame.BackgroundTransparency = 1
	compositionFrame.BorderSizePixel = 0
	compositionFrame.ScrollBarThickness = 3
	compositionFrame.ScrollBarImageColor3 = Color3.new(0.5, 0.5, 0.5)
	compositionFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	compositionFrame.Parent = wavePreviewFrame

	local compositionLayout = Instance.new("UIListLayout")
	compositionLayout.FillDirection = Enum.FillDirection.Vertical
	compositionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	compositionLayout.Padding = UDim.new(0, 2)
	compositionLayout.Parent = compositionFrame

	-- Kodo type colors
	local KODO_TYPE_COLORS = {
		Normal = Color3.fromRGB(180, 140, 100),
		Armored = Color3.fromRGB(140, 140, 160),
		Swift = Color3.fromRGB(220, 220, 240),
		Frostborn = Color3.fromRGB(100, 180, 255),
		Venomous = Color3.fromRGB(80, 200, 80),
		Horde = Color3.fromRGB(200, 80, 80),
		Mini = Color3.fromRGB(255, 180, 100)  -- Orange
	}

	-- Kodo type weaknesses for tips
	local KODO_TYPE_TIPS = {
		Normal = "No special resistances",
		Armored = "Weak to: Poison, AOE",
		Swift = "Weak to: Frost (slows)",
		Frostborn = "Weak to: Physical damage",
		Venomous = "Weak to: Frost",
		Horde = "Weak to: AOE, Multishot",
		Mini = "Fits through gaps! Use AOE"
	}

	-- Listen for wave preview event
	local showWavePreview = ReplicatedStorage:WaitForChild("ShowWavePreview", 10)
	if showWavePreview then
		showWavePreview.OnClientEvent:Connect(function(data)
			print("Wave preview received - Wave", data.wave)

			-- Clear previous composition entries
			for _, child in ipairs(compositionFrame:GetChildren()) do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end

			-- Update title (compact format)
			local titleText = "Wave " .. data.wave
			if data.waveType then
				titleText = data.waveType .. " - " .. titleText
				if data.waveType == "BOSS" then
					previewStroke.Color = Color3.new(1, 0, 0)
					waveTitle.TextColor3 = Color3.new(1, 0.3, 0.3)
				elseif data.waveType == "SWARM" then
					previewStroke.Color = Color3.new(1, 1, 0)
					waveTitle.TextColor3 = Color3.new(1, 1, 0.5)
				elseif data.waveType == "ELITE" then
					previewStroke.Color = Color3.new(0.8, 0.3, 1)
					waveTitle.TextColor3 = Color3.new(0.9, 0.5, 1)
				elseif data.waveType == "MINI" then
					previewStroke.Color = Color3.new(1, 0.7, 0.3)
					waveTitle.TextColor3 = Color3.new(1, 0.8, 0.4)
				end
			else
				previewStroke.Color = Color3.new(1, 0.5, 0)
				waveTitle.TextColor3 = Color3.new(1, 0.7, 0.3)
			end
			waveTitle.Text = titleText

			-- Track total height for canvas size
			local totalHeight = 0

			-- Create compact composition entries
			for _, entry in ipairs(data.composition) do
				local entryFrame = Instance.new("Frame")
				entryFrame.Name = entry.type .. "Entry"
				entryFrame.Size = UDim2.new(1, -6, 0, 20)
				entryFrame.BackgroundColor3 = KODO_TYPE_COLORS[entry.type] or Color3.new(0.5, 0.5, 0.5)
				entryFrame.BackgroundTransparency = 0.75
				entryFrame.Parent = compositionFrame

				local entryCorner = Instance.new("UICorner")
				entryCorner.CornerRadius = UDim.new(0, 4)
				entryCorner.Parent = entryFrame

				-- Kodo type name and count (compact)
				local typeLabel = Instance.new("TextLabel")
				typeLabel.Size = UDim2.new(0.45, 0, 1, 0)
				typeLabel.Position = UDim2.new(0, 5, 0, 0)
				typeLabel.BackgroundTransparency = 1
				typeLabel.Text = entry.count .. "x " .. entry.type
				typeLabel.TextColor3 = KODO_TYPE_COLORS[entry.type] or Color3.new(1, 1, 1)
				typeLabel.Font = Enum.Font.GothamBold
				typeLabel.TextSize = 12
				typeLabel.TextXAlignment = Enum.TextXAlignment.Left
				typeLabel.Parent = entryFrame

				-- Weakness tip (compact)
				local tipLabel = Instance.new("TextLabel")
				tipLabel.Size = UDim2.new(0.52, 0, 1, 0)
				tipLabel.Position = UDim2.new(0.45, 0, 0, 0)
				tipLabel.BackgroundTransparency = 1
				tipLabel.Text = KODO_TYPE_TIPS[entry.type] or ""
				tipLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
				tipLabel.Font = Enum.Font.Gotham
				tipLabel.TextSize = 10
				tipLabel.TextXAlignment = Enum.TextXAlignment.Right
				tipLabel.Parent = entryFrame

				totalHeight = totalHeight + 22
			end

			-- Add boss indicator if boss wave (compact)
			if data.isBossWave then
				local bossEntry = Instance.new("Frame")
				bossEntry.Name = "BossEntry"
				bossEntry.Size = UDim2.new(1, -6, 0, 20)
				bossEntry.BackgroundColor3 = Color3.new(0.6, 0, 0)
				bossEntry.BackgroundTransparency = 0.6
				bossEntry.Parent = compositionFrame

				local bossCorner = Instance.new("UICorner")
				bossCorner.CornerRadius = UDim.new(0, 4)
				bossCorner.Parent = bossEntry

				local bossLabel = Instance.new("TextLabel")
				bossLabel.Size = UDim2.new(1, -10, 1, 0)
				bossLabel.Position = UDim2.new(0, 5, 0, 0)
				bossLabel.BackgroundTransparency = 1
				bossLabel.Text = "+ BOSS (5x HP)"
				bossLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
				bossLabel.Font = Enum.Font.GothamBold
				bossLabel.TextSize = 12
				bossLabel.TextXAlignment = Enum.TextXAlignment.Left
				bossLabel.Parent = bossEntry

				totalHeight = totalHeight + 22
			end

			-- Update canvas size
			compositionFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

			-- Show preview
			wavePreviewFrame.Visible = true

			-- Countdown (compact format)
			local previewTime = data.previewTime or 5
			for i = previewTime, 1, -1 do
				countdownLabel.Text = i .. "s"
				task.wait(1)
			end
			countdownLabel.Text = "GO!"
			task.wait(0.5)

			-- Hide preview
			wavePreviewFrame.Visible = false
		end)
	end

	-- Listen for game over event
	local showGameOver = ReplicatedStorage:WaitForChild("ShowGameOver", 10)
	if showGameOver then
		showGameOver.OnClientEvent:Connect(function(data)
			print("Game Over received - showing results screen")

			-- Fetch global leaderboard
			local globalTop10 = {}
			local getHighScore = ReplicatedStorage:FindFirstChild("GetHighScore")
			if getHighScore then
				local success, result = pcall(function()
					return getHighScore:InvokeServer("global")
				end)
				if success and result then
					globalTop10 = result
				end
			end

			-- Hide game UI
			gameInfoPanel.Visible = false
			playerStatsFrame.Visible = false

			-- Create game over screen
			local gameOverScreen = Instance.new("Frame")
			gameOverScreen.Name = "GameOverScreen"
			gameOverScreen.Size = UDim2.new(0.55, 0, 0.7, 0)
			gameOverScreen.Position = UDim2.new(0.225, 0, 0.15, 0)
			gameOverScreen.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
			gameOverScreen.BackgroundTransparency = 0.1
			gameOverScreen.BorderSizePixel = 0
			gameOverScreen.Parent = screenGui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = gameOverScreen

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(1, 0.3, 0.3)
			stroke.Thickness = 3
			stroke.Parent = gameOverScreen

			-- Title
			local titleLabel = Instance.new("TextLabel")
			titleLabel.Size = UDim2.new(1, 0, 0, 40)
			titleLabel.Position = UDim2.new(0, 0, 0, 10)
			titleLabel.BackgroundTransparency = 1
			titleLabel.Text = "GAME OVER"
			titleLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
			titleLabel.Font = Enum.Font.GothamBlack
			titleLabel.TextSize = 32
			titleLabel.Parent = gameOverScreen

			-- Check for new record
			local myHighScore = data.highScores and data.highScores[player.Name]
			local isNewRecord = myHighScore and myHighScore.isNewRecord
			local bestWave = myHighScore and myHighScore.bestWave or (data.wavesReached or 1)

			-- Waves reached
			local wavesLabel = Instance.new("TextLabel")
			wavesLabel.Size = UDim2.new(0.6, 0, 0, 30)
			wavesLabel.Position = UDim2.new(0, 10, 0, 55)
			wavesLabel.BackgroundTransparency = 1
			wavesLabel.Text = "Survived " .. (data.wavesReached or 1) .. " Waves"
			wavesLabel.TextColor3 = Color3.new(1, 1, 0.5)
			wavesLabel.Font = Enum.Font.GothamBold
			wavesLabel.TextSize = 24
			wavesLabel.TextXAlignment = Enum.TextXAlignment.Left
			wavesLabel.Parent = gameOverScreen

			-- Personal best display
			local bestLabel = Instance.new("TextLabel")
			bestLabel.Size = UDim2.new(0.35, 0, 0, 20)
			bestLabel.Position = UDim2.new(0.63, 0, 0, 55)
			bestLabel.BackgroundTransparency = 1
			bestLabel.Text = "Personal Best: Wave " .. bestWave
			bestLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
			bestLabel.Font = Enum.Font.Gotham
			bestLabel.TextSize = 14
			bestLabel.TextXAlignment = Enum.TextXAlignment.Right
			bestLabel.Parent = gameOverScreen

			-- NEW RECORD indicator
			if isNewRecord then
				local recordLabel = Instance.new("TextLabel")
				recordLabel.Size = UDim2.new(0.35, 0, 0, 18)
				recordLabel.Position = UDim2.new(0.63, 0, 0, 72)
				recordLabel.BackgroundTransparency = 1
				recordLabel.Text = "NEW RECORD!"
				recordLabel.TextColor3 = Color3.new(1, 0.85, 0)
				recordLabel.Font = Enum.Font.GothamBlack
				recordLabel.TextSize = 16
				recordLabel.TextXAlignment = Enum.TextXAlignment.Right
				recordLabel.Parent = gameOverScreen

				-- Animate the new record text
				task.spawn(function()
					while recordLabel and recordLabel.Parent do
						for i = 0, 1, 0.05 do
							if not recordLabel or not recordLabel.Parent then break end
							recordLabel.TextColor3 = Color3.new(1, 0.85 + 0.15 * math.sin(i * math.pi * 2), 0)
							task.wait(0.05)
						end
					end
				end)
			end

			-- Leaderboard section
			local leaderboardFrame = Instance.new("Frame")
			leaderboardFrame.Name = "LeaderboardFrame"
			leaderboardFrame.Size = UDim2.new(1, -20, 1, -140)
			leaderboardFrame.Position = UDim2.new(0, 10, 0, 95)
			leaderboardFrame.BackgroundColor3 = Color3.new(0.08, 0.08, 0.1)
			leaderboardFrame.BackgroundTransparency = 0.3
			leaderboardFrame.BorderSizePixel = 0
			leaderboardFrame.Parent = gameOverScreen

			local lbCorner = Instance.new("UICorner")
			lbCorner.CornerRadius = UDim.new(0, 8)
			lbCorner.Parent = leaderboardFrame

			-- Leaderboard title
			local lbTitle = Instance.new("TextLabel")
			lbTitle.Size = UDim2.new(1, 0, 0, 25)
			lbTitle.Position = UDim2.new(0, 0, 0, 5)
			lbTitle.BackgroundTransparency = 1
			lbTitle.Text = "LEADERBOARD"
			lbTitle.TextColor3 = Color3.new(1, 0.85, 0.3)
			lbTitle.Font = Enum.Font.GothamBold
			lbTitle.TextSize = 18
			lbTitle.Parent = leaderboardFrame

			-- Column headers
			local headerFrame = Instance.new("Frame")
			headerFrame.Size = UDim2.new(1, -20, 0, 22)
			headerFrame.Position = UDim2.new(0, 10, 0, 32)
			headerFrame.BackgroundTransparency = 1
			headerFrame.Parent = leaderboardFrame

			local headers = {"#", "Player", "Kills", "Deaths", "Saves", "Gold"}
			local headerWidths = {0.08, 0.32, 0.15, 0.15, 0.15, 0.15}
			local xPos = 0
			for i, headerText in ipairs(headers) do
				local header = Instance.new("TextLabel")
				header.Size = UDim2.new(headerWidths[i], 0, 1, 0)
				header.Position = UDim2.new(xPos, 0, 0, 0)
				header.BackgroundTransparency = 1
				header.Text = headerText
				header.TextColor3 = Color3.new(0.6, 0.6, 0.6)
				header.Font = Enum.Font.GothamBold
				header.TextSize = 12
				header.TextXAlignment = i == 2 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
				header.Parent = headerFrame
				xPos = xPos + headerWidths[i]
			end

			-- Player rows (scrollable)
			local playerList = Instance.new("ScrollingFrame")
			playerList.Name = "PlayerList"
			playerList.Size = UDim2.new(1, -20, 1, -62)
			playerList.Position = UDim2.new(0, 10, 0, 56)
			playerList.BackgroundTransparency = 1
			playerList.BorderSizePixel = 0
			playerList.ScrollBarThickness = 4
			playerList.ScrollBarImageColor3 = Color3.new(0.5, 0.5, 0.5)
			playerList.Parent = leaderboardFrame

			local listLayout = Instance.new("UIListLayout")
			listLayout.Padding = UDim.new(0, 4)
			listLayout.Parent = playerList

			-- Sort players by kills (descending)
			local sortedPlayers = {}
			if data.playerStats then
				for playerName, stats in pairs(data.playerStats) do
					table.insert(sortedPlayers, {name = playerName, stats = stats})
				end
				table.sort(sortedPlayers, function(a, b)
					return (a.stats.kodoKills or 0) > (b.stats.kodoKills or 0)
				end)
			end

			-- Create player rows
			for rank, playerData in ipairs(sortedPlayers) do
				local isLocalPlayer = (playerData.name == player.Name)
				local stats = playerData.stats
				local playerHighScore = data.highScores and data.highScores[playerData.name]
				local playerGotRecord = playerHighScore and playerHighScore.isNewRecord

				local row = Instance.new("Frame")
				row.Name = playerData.name
				row.Size = UDim2.new(1, 0, 0, 32)
				row.BackgroundColor3 = isLocalPlayer and Color3.new(0.2, 0.3, 0.15) or Color3.new(0.12, 0.12, 0.15)
				row.BackgroundTransparency = 0.3
				row.Parent = playerList

				local rowCorner = Instance.new("UICorner")
				rowCorner.CornerRadius = UDim.new(0, 6)
				rowCorner.Parent = row

				-- Highlight border for local player or new record
				if isLocalPlayer then
					local rowStroke = Instance.new("UIStroke")
					rowStroke.Color = Color3.new(0.5, 1, 0.5)
					rowStroke.Thickness = 2
					rowStroke.Parent = row
				elseif playerGotRecord then
					local rowStroke = Instance.new("UIStroke")
					rowStroke.Color = Color3.new(1, 0.85, 0)
					rowStroke.Thickness = 1
					rowStroke.Parent = row
				end

				-- Rank
				local rankLabel = Instance.new("TextLabel")
				rankLabel.Size = UDim2.new(0.08, 0, 1, 0)
				rankLabel.Position = UDim2.new(0, 0, 0, 0)
				rankLabel.BackgroundTransparency = 1
				rankLabel.Text = "#" .. rank
				rankLabel.TextColor3 = rank == 1 and Color3.new(1, 0.85, 0) or Color3.new(0.8, 0.8, 0.8)
				rankLabel.Font = Enum.Font.GothamBold
				rankLabel.TextSize = 14
				rankLabel.Parent = row

				-- Player name (with NEW! indicator for records)
				local displayName = playerData.name
				if playerGotRecord then
					displayName = playerData.name .. " *NEW*"
				end

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(0.32, 0, 1, 0)
				nameLabel.Position = UDim2.new(0.08, 0, 0, 0)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = displayName
				nameLabel.TextColor3 = playerGotRecord and Color3.new(1, 0.85, 0) or (isLocalPlayer and Color3.new(0.5, 1, 0.5) or Color3.new(1, 1, 1))
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.TextSize = 14
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
				nameLabel.Parent = row

				-- Kills
				local killsLabel = Instance.new("TextLabel")
				killsLabel.Size = UDim2.new(0.15, 0, 1, 0)
				killsLabel.Position = UDim2.new(0.4, 0, 0, 0)
				killsLabel.BackgroundTransparency = 1
				killsLabel.Text = tostring(stats.kodoKills or 0)
				killsLabel.TextColor3 = Color3.new(1, 1, 0.4)
				killsLabel.Font = Enum.Font.GothamBold
				killsLabel.TextSize = 14
				killsLabel.Parent = row

				-- Deaths
				local deathsLabel = Instance.new("TextLabel")
				deathsLabel.Size = UDim2.new(0.15, 0, 1, 0)
				deathsLabel.Position = UDim2.new(0.55, 0, 0, 0)
				deathsLabel.BackgroundTransparency = 1
				deathsLabel.Text = tostring(stats.deaths or 0)
				deathsLabel.TextColor3 = Color3.new(1, 0.4, 0.4)
				deathsLabel.Font = Enum.Font.GothamBold
				deathsLabel.TextSize = 14
				deathsLabel.Parent = row

				-- Saves
				local savesLabel = Instance.new("TextLabel")
				savesLabel.Size = UDim2.new(0.15, 0, 1, 0)
				savesLabel.Position = UDim2.new(0.7, 0, 0, 0)
				savesLabel.BackgroundTransparency = 1
				savesLabel.Text = tostring(stats.saves or 0)
				savesLabel.TextColor3 = Color3.new(0.4, 1, 0.8)
				savesLabel.Font = Enum.Font.GothamBold
				savesLabel.TextSize = 14
				savesLabel.Parent = row

				-- Gold earned
				local goldLabel = Instance.new("TextLabel")
				goldLabel.Size = UDim2.new(0.15, 0, 1, 0)
				goldLabel.Position = UDim2.new(0.85, 0, 0, 0)
				goldLabel.BackgroundTransparency = 1
				goldLabel.Text = tostring(stats.goldEarned or 0)
				goldLabel.TextColor3 = Color3.new(1, 0.85, 0)
				goldLabel.Font = Enum.Font.GothamBold
				goldLabel.TextSize = 14
				goldLabel.Parent = row
			end

			-- Update canvas size
			playerList.CanvasSize = UDim2.new(0, 0, 0, #sortedPlayers * 36)

			-- ============================================
			-- GLOBAL TOP 10 LEADERBOARD (Right side)
			-- ============================================
			if #globalTop10 > 0 then
				-- Create global leaderboard frame (to the right of session stats)
				local globalFrame = Instance.new("Frame")
				globalFrame.Name = "GlobalLeaderboard"
				globalFrame.Size = UDim2.new(0.35, 0, 0.55, 0)
				globalFrame.Position = UDim2.new(1.05, 0, 0.08, 0)
				globalFrame.BackgroundColor3 = Color3.new(0.08, 0.08, 0.12)
				globalFrame.BackgroundTransparency = 0.1
				globalFrame.BorderSizePixel = 0
				globalFrame.Parent = gameOverScreen

				local globalCorner = Instance.new("UICorner")
				globalCorner.CornerRadius = UDim.new(0, 10)
				globalCorner.Parent = globalFrame

				local globalStroke = Instance.new("UIStroke")
				globalStroke.Color = Color3.new(1, 0.85, 0)
				globalStroke.Thickness = 2
				globalStroke.Parent = globalFrame

				-- Global title
				local globalTitle = Instance.new("TextLabel")
				globalTitle.Size = UDim2.new(1, 0, 0, 30)
				globalTitle.Position = UDim2.new(0, 0, 0, 5)
				globalTitle.BackgroundTransparency = 1
				globalTitle.Text = "GLOBAL TOP 10"
				globalTitle.TextColor3 = Color3.new(1, 0.85, 0)
				globalTitle.Font = Enum.Font.GothamBlack
				globalTitle.TextSize = 18
				globalTitle.Parent = globalFrame

				-- Global player list
				local globalList = Instance.new("ScrollingFrame")
				globalList.Name = "GlobalList"
				globalList.Size = UDim2.new(1, -16, 1, -45)
				globalList.Position = UDim2.new(0, 8, 0, 40)
				globalList.BackgroundTransparency = 1
				globalList.BorderSizePixel = 0
				globalList.ScrollBarThickness = 4
				globalList.ScrollBarImageColor3 = Color3.new(0.6, 0.5, 0.2)
				globalList.Parent = globalFrame

				local globalLayout = Instance.new("UIListLayout")
				globalLayout.Padding = UDim.new(0, 3)
				globalLayout.Parent = globalList

				-- Create rows for top 10
				for _, entry in ipairs(globalTop10) do
					local isMe = (entry.name == player.Name)
					local rankColor = entry.rank == 1 and Color3.new(1, 0.85, 0) or
									  entry.rank == 2 and Color3.new(0.75, 0.75, 0.8) or
									  entry.rank == 3 and Color3.new(0.8, 0.5, 0.2) or
									  Color3.new(0.6, 0.6, 0.6)

					local entryRow = Instance.new("Frame")
					entryRow.Name = "Rank" .. entry.rank
					entryRow.Size = UDim2.new(1, 0, 0, 28)
					entryRow.BackgroundColor3 = isMe and Color3.new(0.2, 0.3, 0.15) or Color3.new(0.1, 0.1, 0.12)
					entryRow.BackgroundTransparency = 0.3
					entryRow.Parent = globalList

					local entryCorner = Instance.new("UICorner")
					entryCorner.CornerRadius = UDim.new(0, 5)
					entryCorner.Parent = entryRow

					if isMe then
						local meStroke = Instance.new("UIStroke")
						meStroke.Color = Color3.new(0.5, 1, 0.5)
						meStroke.Thickness = 2
						meStroke.Parent = entryRow
					end

					-- Rank
					local rankLabel = Instance.new("TextLabel")
					rankLabel.Size = UDim2.new(0.15, 0, 1, 0)
					rankLabel.Position = UDim2.new(0, 0, 0, 0)
					rankLabel.BackgroundTransparency = 1
					rankLabel.Text = "#" .. entry.rank
					rankLabel.TextColor3 = rankColor
					rankLabel.Font = Enum.Font.GothamBlack
					rankLabel.TextSize = 14
					rankLabel.Parent = entryRow

					-- Name
					local nameLabel = Instance.new("TextLabel")
					nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
					nameLabel.Position = UDim2.new(0.15, 0, 0, 0)
					nameLabel.BackgroundTransparency = 1
					nameLabel.Text = entry.name
					nameLabel.TextColor3 = isMe and Color3.new(0.5, 1, 0.5) or Color3.new(1, 1, 1)
					nameLabel.Font = Enum.Font.GothamBold
					nameLabel.TextSize = 12
					nameLabel.TextXAlignment = Enum.TextXAlignment.Left
					nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
					nameLabel.Parent = entryRow

					-- Wave
					local waveLabel = Instance.new("TextLabel")
					waveLabel.Size = UDim2.new(0.3, 0, 1, 0)
					waveLabel.Position = UDim2.new(0.7, 0, 0, 0)
					waveLabel.BackgroundTransparency = 1
					waveLabel.Text = "Wave " .. entry.wave
					waveLabel.TextColor3 = Color3.new(1, 0.7, 0.3)
					waveLabel.Font = Enum.Font.GothamBold
					waveLabel.TextSize = 12
					waveLabel.Parent = entryRow
				end

				-- Update canvas size
				globalList.CanvasSize = UDim2.new(0, 0, 0, #globalTop10 * 31)
			end

			-- Return countdown
			local countdownLabel = Instance.new("TextLabel")
			countdownLabel.Name = "CountdownLabel"
			countdownLabel.Size = UDim2.new(1, 0, 0, 30)
			countdownLabel.Position = UDim2.new(0, 0, 1, -35)
			countdownLabel.BackgroundTransparency = 1
			countdownLabel.Text = "Returning to lobby in " .. (data.returnDelay or 10) .. "..."
			countdownLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
			countdownLabel.Font = Enum.Font.Gotham
			countdownLabel.TextScaled = true
			countdownLabel.Parent = gameOverScreen

			-- Countdown timer
			local returnDelay = data.returnDelay or 10
			task.spawn(function()
				for i = returnDelay, 1, -1 do
					if countdownLabel and countdownLabel.Parent then
						countdownLabel.Text = "Returning to lobby in " .. i .. "..."
					end
					task.wait(1)
				end
				if countdownLabel and countdownLabel.Parent then
					countdownLabel.Text = "Teleporting..."
				end
			end)
		end)
	end

	print("HUD loaded successfully!")
else
	print("Lobby server - Game UI hidden")
end
