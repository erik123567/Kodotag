-- PAD MANAGER
-- Handles all game pads from a single script
-- Each pad should have these attributes:
--   PadType (string): "SOLO", "SMALL", "MEDIUM", "LARGE"
--   MinPlayers (number): minimum players to start (ignored for SOLO)
--   MaxPlayers (number): maximum players allowed (ignored for SOLO)
--   CountdownTime (number): seconds to countdown (ignored for SOLO)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Check if this is a reserved server - don't run pad logic on game servers
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if isReservedServer then
	print("PadManager: This is a GAME server - pad logic disabled")
	return
end

print("PadManager: Initializing on LOBBY server")

-- Get/create broadcast events
local updatePadStatus = ReplicatedStorage:FindFirstChild("UpdatePadStatus")
if not updatePadStatus then
	updatePadStatus = Instance.new("RemoteEvent")
	updatePadStatus.Name = "UpdatePadStatus"
	updatePadStatus.Parent = ReplicatedStorage
end

local soloStartEvent = ReplicatedStorage:FindFirstChild("SoloStartRequest")

-- Event to notify clients teleport is starting (for loading screen)
local teleportStarting = ReplicatedStorage:FindFirstChild("TeleportStarting")
if not teleportStarting then
	teleportStarting = Instance.new("RemoteEvent")
	teleportStarting.Name = "TeleportStarting"
	teleportStarting.Parent = ReplicatedStorage
end
if not soloStartEvent then
	soloStartEvent = Instance.new("RemoteEvent")
	soloStartEvent.Name = "SoloStartRequest"
	soloStartEvent.Parent = ReplicatedStorage
end

-- Event to notify specific player when they join/leave a pad
local playerPadEvent = ReplicatedStorage:FindFirstChild("PlayerPadStatus")
if not playerPadEvent then
	playerPadEvent = Instance.new("RemoteEvent")
	playerPadEvent.Name = "PlayerPadStatus"
	playerPadEvent.Parent = ReplicatedStorage
end

-- Store state for each pad
local padStates = {} -- [pad] = { playersInPad, isCountingDown, countdownTime, playerDebounce, config }

-- Helper: count players in a table
local function countPlayers(playerTable)
	local count = 0
	for _ in pairs(playerTable) do
		count = count + 1
	end
	return count
end

-- Helper: get players as list
local function getPlayerList(playerTable)
	local list = {}
	for player, _ in pairs(playerTable) do
		table.insert(list, player)
	end
	return list
end

-- Update pad display
local function updateDisplay(pad)
	local state = padStates[pad]
	if not state then return end

	local config = state.config
	local billboard = pad:FindFirstChild("BillboardGui")
	local textLabel = billboard and billboard:FindFirstChild("TextLabel")
	if not textLabel then return end

	local playerCount = countPlayers(state.playersInPad)

	if config.isSolo then
		-- Solo pad display
		if state.isTeleporting then
			textLabel.Text = "STARTING..."
			textLabel.TextColor3 = Color3.new(1, 1, 0)
		elseif playerCount > 0 then
			textLabel.Text = "PRESS E TO START\nSOLO GAME"
			textLabel.TextColor3 = Color3.new(0, 1, 0)
		else
			textLabel.Text = "SOLO GAME\nSTAND HERE"
			textLabel.TextColor3 = Color3.new(1, 1, 1)
		end
	else
		-- Multiplayer pad display
		if state.isCountingDown then
			textLabel.Text = "STARTING IN " .. state.countdownTime .. "...\n" .. playerCount .. "/" .. config.maxPlayers .. " PLAYERS"
			textLabel.TextColor3 = Color3.new(1, 1, 0)
		elseif playerCount >= config.minPlayers then
			textLabel.Text = "READY!\n" .. playerCount .. "/" .. config.maxPlayers .. " PLAYERS"
			textLabel.TextColor3 = Color3.new(0, 1, 0)
		else
			textLabel.Text = config.padType .. " GAME (" .. config.minPlayers .. "-" .. config.maxPlayers .. ")\n" .. playerCount .. "/" .. config.maxPlayers .. " PLAYERS"
			textLabel.TextColor3 = Color3.new(1, 1, 1)
		end
	end

	-- Broadcast status to players on this pad
	local padData = {
		padType = config.padType,
		count = playerCount,
		maxPlayers = config.maxPlayers,
		minPlayers = config.minPlayers,
		isCountingDown = state.isCountingDown,
		countdownTime = state.countdownTime
	}
	for player, _ in pairs(state.playersInPad) do
		playerPadEvent:FireClient(player, {
			joined = true,
			padType = config.padType,
			count = playerCount,
			maxPlayers = config.maxPlayers,
			minPlayers = config.minPlayers,
			isCountingDown = state.isCountingDown,
			countdownTime = state.countdownTime
		})
	end
end

-- Teleport players to reserved server
local function teleportPlayers(playerList, padType)
	print("=== TELEPORT START ===")
	print("Players: " .. #playerList)
	print("PadType: " .. padType)
	print("PlaceId: " .. tostring(game.PlaceId))

	-- Create reserved server
	print("Creating reserved server...")
	local success, reservedCode = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)

	print("ReserveServer result - Success: " .. tostring(success) .. ", Code: " .. tostring(reservedCode))

	if success and reservedCode then
		local gameData = {
			padType = padType,
			difficulty = "NORMAL",
			playerCount = #playerList
		}

		-- Create teleport options with data
		local teleportOptions = Instance.new("TeleportOptions")
		teleportOptions.ReservedServerAccessCode = reservedCode
		teleportOptions:SetTeleportData(gameData)

		-- Notify clients that teleport is starting (show loading screen)
		for _, p in ipairs(playerList) do
			teleportStarting:FireClient(p)
		end
		task.wait(0.2)  -- Brief delay for loading screen to appear

		-- Teleport players
		print("Calling TeleportAsync...")
		local teleportSuccess, teleportError = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, playerList, teleportOptions)
		end)

		if not teleportSuccess then
			warn("!!! Teleport failed: " .. tostring(teleportError))
			-- Notify players
			for _, player in ipairs(playerList) do
				-- Create simple notification
				local hint = Instance.new("Hint")
				hint.Text = "Teleport failed! Please try again."
				hint.Parent = player:FindFirstChild("PlayerGui") or workspace
				task.delay(3, function() hint:Destroy() end)
			end
			return false
		end

		print("=== TELEPORT SUCCESS ===")
		return true
	else
		warn("!!! Failed to reserve server: " .. tostring(reservedCode))
		-- Notify players
		for _, player in ipairs(playerList) do
			local hint = Instance.new("Hint")
			hint.Text = "Failed to create game server. Error: " .. tostring(reservedCode)
			hint.Parent = player:FindFirstChild("PlayerGui") or workspace
			task.delay(5, function() hint:Destroy() end)
		end
		return false
	end
end

-- Start multiplayer game
local function startMultiplayerGame(pad)
	local state = padStates[pad]
	if not state then return end

	print("Starting " .. state.config.padType .. " game!")

	local playerList = getPlayerList(state.playersInPad)
	teleportPlayers(playerList, state.config.padType)

	-- Clear pad
	state.playersInPad = {}
	state.isCountingDown = false
	state.countdownTime = 0
	updateDisplay(pad)
end

-- Start countdown for multiplayer pad
local function startCountdown(pad)
	local state = padStates[pad]
	if not state or state.isCountingDown then return end

	local config = state.config
	local playerCount = countPlayers(state.playersInPad)

	if playerCount < config.minPlayers then return end

	state.isCountingDown = true
	state.countdownTime = config.countdownTime

	-- Countdown loop
	task.spawn(function()
		while state.countdownTime > 0 and state.isCountingDown do
			updateDisplay(pad)
			task.wait(1)
			state.countdownTime = state.countdownTime - 1

			-- Check if still enough players
			local currentCount = countPlayers(state.playersInPad)
			if currentCount < config.minPlayers then
				print("Not enough players, canceling countdown")
				state.isCountingDown = false
				updateDisplay(pad)
				return
			end
		end

		if state.isCountingDown then
			startMultiplayerGame(pad)
		end
	end)
end

-- Start solo game
local function startSoloGame(pad, player)
	local state = padStates[pad]
	if not state or state.isTeleporting then return end

	-- Verify player is on this pad
	if not state.playersInPad[player] then return end

	state.isTeleporting = true
	updateDisplay(pad)

	print("Starting solo game for " .. player.Name)

	local success = teleportPlayers({player}, "SOLO")

	if not success then
		state.isTeleporting = false
		updateDisplay(pad)
	end
end

-- Handle player entering pad
local function onPlayerEnter(pad, player)
	local state = padStates[pad]
	if not state then return end

	local config = state.config

	-- Debounce check
	if state.playerDebounce[player] then return end

	-- Check if already in pad
	if state.playersInPad[player] then return end

	local currentCount = countPlayers(state.playersInPad)

	-- Check max players (for multiplayer)
	if not config.isSolo and currentCount >= config.maxPlayers then
		return
	end

	-- For solo, only one player at a time
	if config.isSolo and currentCount > 0 then
		return
	end

	state.playerDebounce[player] = true
	state.playersInPad[player] = true
	print(player.Name .. " entered " .. config.padType:lower() .. " pad")
	updateDisplay(pad)

	-- Notify the player they joined this pad
	playerPadEvent:FireClient(player, {
		joined = true,
		padType = config.padType,
		count = currentCount + 1,
		maxPlayers = config.maxPlayers,
		minPlayers = config.minPlayers,
		isCountingDown = state.isCountingDown,
		countdownTime = state.countdownTime
	})

	-- Start countdown if enough players (multiplayer only)
	if not config.isSolo then
		if currentCount + 1 >= config.minPlayers and not state.isCountingDown then
			startCountdown(pad)
		end
	end

	-- Clear debounce after short delay
	task.delay(0.5, function()
		state.playerDebounce[player] = false
	end)
end

-- Handle player leaving pad
local function onPlayerLeave(pad, player)
	local state = padStates[pad]
	if not state then return end

	if not state.playersInPad[player] then return end

	state.playersInPad[player] = nil
	state.playerDebounce[player] = nil
	print(player.Name .. " left " .. state.config.padType:lower() .. " pad")
	updateDisplay(pad)

	-- Notify the player they left this pad
	playerPadEvent:FireClient(player, {
		joined = false,
		padType = state.config.padType
	})

	-- Cancel countdown if not enough players (multiplayer)
	if not state.config.isSolo then
		local currentCount = countPlayers(state.playersInPad)
		if currentCount < state.config.minPlayers and state.isCountingDown then
			state.isCountingDown = false
			updateDisplay(pad)
		end
	end
end

-- Check if player is still touching pad
local function isPlayerTouchingPad(player, pad)
	local character = player.Character
	if not character then return false end

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			local touching = part:GetTouchingParts()
			for _, touchedPart in ipairs(touching) do
				if touchedPart == pad then
					return true
				end
			end
		end
	end
	return false
end

-- Setup a single pad
local function setupPad(pad)
	-- Read configuration from attributes
	local padType = pad:GetAttribute("PadType") or "SOLO"
	local isSolo = padType == "SOLO"
	local minPlayers = pad:GetAttribute("MinPlayers") or 2
	local maxPlayers = pad:GetAttribute("MaxPlayers") or 4
	local countdownTime = pad:GetAttribute("CountdownTime") or 15

	-- Initialize state for this pad
	padStates[pad] = {
		playersInPad = {},
		isCountingDown = false,
		countdownTime = 0,
		isTeleporting = false,
		playerDebounce = {},
		config = {
			padType = padType,
			isSolo = isSolo,
			minPlayers = minPlayers,
			maxPlayers = maxPlayers,
			countdownTime = countdownTime
		}
	}

	-- Connect touch events
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		onPlayerEnter(pad, player)
	end)

	pad.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- Wait a moment to avoid flickering
		task.wait(0.3)

		-- Verify player actually left
		if not isPlayerTouchingPad(player, pad) then
			onPlayerLeave(pad, player)
		end
	end)

	-- Initialize display
	updateDisplay(pad)

	if isSolo then
		print("Solo Pad ready: " .. pad:GetFullName())
	else
		print(padType .. " Game Pad ready: " .. pad:GetFullName() .. " (Min: " .. minPlayers .. ", Max: " .. maxPlayers .. ")")
	end
end

-- Handle solo start request (E key press)
soloStartEvent.OnServerEvent:Connect(function(player)
	-- Find which solo pad the player is on
	for pad, state in pairs(padStates) do
		if state.config.isSolo and state.playersInPad[player] then
			startSoloGame(pad, player)
			return
		end
	end
end)

-- Handle player leaving the game
Players.PlayerRemoving:Connect(function(player)
	for pad, state in pairs(padStates) do
		if state.playersInPad[player] then
			state.playersInPad[player] = nil
			state.playerDebounce[player] = nil
			print(player.Name .. " left the game, removing from " .. state.config.padType:lower() .. " pad")
			updateDisplay(pad)
		end
	end
end)

-- Find and setup all pads
-- Option 1: Look for pads in a "GamePads" folder in workspace
local gamePadsFolder = workspace:FindFirstChild("GamePads")
if gamePadsFolder then
	for _, pad in ipairs(gamePadsFolder:GetChildren()) do
		if pad:IsA("BasePart") and pad:GetAttribute("PadType") then
			setupPad(pad)
		end
	end
end

-- Option 2: Look for parts with "Pad" in the name that have PadType attribute
for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("BasePart") and obj:GetAttribute("PadType") and not padStates[obj] then
		setupPad(obj)
	end
end

print("PadManager: Loaded - Found " .. countPlayers(padStates) .. " pads")
