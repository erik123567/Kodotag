local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Check if this is a reserved server
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

print("Server starting - Reserved Server: " .. tostring(isReservedServer))

-- Disable auto character loading
Players.CharacterAutoLoads = false

-- Store game config globally for RoundManager
_G.GameConfig = {
	isReservedServer = isReservedServer,
	padType = "SOLO",
	difficulty = "NORMAL",
	expectedPlayers = 1,
	playersReady = false
}

-- Create a value in ReplicatedStorage so clients know if this is a game server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local isGameServer = Instance.new("BoolValue")
isGameServer.Name = "IsGameServer"
isGameServer.Value = isReservedServer
isGameServer.Parent = ReplicatedStorage
print("IsGameServer flag set to: " .. tostring(isReservedServer))

-- Create GameReady event (fires when players arrive, before intermission)
local gameReady = Instance.new("RemoteEvent")
gameReady.Name = "GameReady"
gameReady.Parent = ReplicatedStorage

-- Create a flag clients can check if they miss the event
local gameReadyFlag = Instance.new("BoolValue")
gameReadyFlag.Name = "GameReadyFlag"
gameReadyFlag.Value = false
gameReadyFlag.Parent = ReplicatedStorage

if isReservedServer then
	-- This is a GAME server (reserved)
	print("GAME SERVER - This is where the actual Kodo Tag game runs")

	local arrivedPlayers = {}
	local gameStarted = false
	local WAIT_TIMEOUT = 30 -- Max seconds to wait for all players

	Players.PlayerAdded:Connect(function(player)
		print("Player joined game server: " .. player.Name)
		table.insert(arrivedPlayers, player)

		-- Get teleport data from the first player
		if #arrivedPlayers == 1 then
			local success, data = pcall(function()
				return player:GetJoinData().TeleportData
			end)

			if success and data then
				_G.GameConfig.padType = data.padType or "SOLO"
				_G.GameConfig.difficulty = data.difficulty or "NORMAL"
				_G.GameConfig.expectedPlayers = data.playerCount or 1
				print("Game config received - Type:", _G.GameConfig.padType, "Difficulty:", _G.GameConfig.difficulty, "Expected:", _G.GameConfig.expectedPlayers)
			else
				print("No teleport data, using defaults")
			end
		end

		print("Players arrived: " .. #arrivedPlayers .. "/" .. _G.GameConfig.expectedPlayers)

		-- Check if all expected players have arrived
		if #arrivedPlayers >= _G.GameConfig.expectedPlayers and not gameStarted then
			gameStarted = true
			_G.GameConfig.playersReady = true
			print("All players arrived! Waiting for map and characters to load...")

			-- Wait for everything to be ready in a separate thread
			task.spawn(function()
				-- Wait for map to be generated
				local mapWaitStart = tick()
				while not _G.MapInfo and tick() - mapWaitStart < 15 do
					task.wait(0.2)
				end
				if _G.MapInfo then
					print("GameInitializer: Map is ready")
				else
					print("GameInitializer: Map wait timeout, continuing anyway")
				end

				-- Wait for all players to have characters
				for _, p in ipairs(arrivedPlayers) do
					local charWaitStart = tick()
					while not p.Character and tick() - charWaitStart < 10 do
						task.wait(0.2)
					end
					if p.Character then
						print("GameInitializer: " .. p.Name .. " character loaded")
					end
				end

				-- Extra delay to ensure everything renders
				task.wait(5)

				print("GameInitializer: Everything ready, showing game!")
				-- Set flag so late-loading clients know game is ready
				gameReadyFlag.Value = true
				-- Fire GameReady to hide loading screens
				gameReady:FireAllClients()
			end)
		end
	end)

	-- Timeout: start game even if not all players arrived
	task.spawn(function()
		wait(WAIT_TIMEOUT)
		if not gameStarted and #arrivedPlayers > 0 then
			gameStarted = true
			_G.GameConfig.playersReady = true
			print("Timeout reached with " .. #arrivedPlayers .. " players. Starting game...")
			-- Set flag and fire GameReady to hide loading screens
			gameReadyFlag.Value = true
			gameReady:FireAllClients()
		end
	end)

else
	-- This is the LOBBY server (main)
	print("LOBBY SERVER - Players spawn here and choose game mode")

	-- Re-enable auto character loading for lobby (we disabled it globally above)
	Players.CharacterAutoLoads = true

	-- Find lobby spawn position
	local lobbySpawns = workspace:FindFirstChild("LobbySpawns")
	local lobbySpawnPosition = Vector3.new(0, 10, 0) -- Default fallback

	if lobbySpawns then
		local spawns = lobbySpawns:GetChildren()
		if #spawns > 0 then
			lobbySpawnPosition = spawns[1].Position
			print("Found LobbySpawns at: " .. tostring(lobbySpawnPosition))
		else
			warn("LobbySpawns folder is empty!")
		end
	else
		warn("LobbySpawns folder not found! Using default position")
	end

	-- Disable ALL existing SpawnLocations
	print("Disabling game SpawnLocations for lobby...")
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") then
			obj.Enabled = false
			print("  Disabled: " .. obj:GetFullName())
		end
	end

	-- Create a LOBBY SpawnLocation at the correct position
	local lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "LobbySpawnLocation"
	lobbySpawn.Size = Vector3.new(10, 1, 10)
	lobbySpawn.Position = lobbySpawnPosition + Vector3.new(0, 0.5, 0)
	lobbySpawn.Anchored = true
	lobbySpawn.CanCollide = false
	lobbySpawn.Transparency = 1
	lobbySpawn.Enabled = true
	lobbySpawn.Neutral = true
	lobbySpawn.Parent = workspace
	print("Created LobbySpawnLocation at: " .. tostring(lobbySpawn.Position))

	-- Disable any new SpawnLocations that get added (except ours)
	workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("SpawnLocation") and obj.Name ~= "LobbySpawnLocation" then
			obj.Enabled = false
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		print("Player joined lobby: " .. player.Name)

		-- Character will auto-spawn at our LobbySpawnLocation
		-- Just need to wait for them to load
		player.CharacterAdded:Connect(function(character)
			print(player.Name .. " character loaded in lobby")
		end)
	end)
end

print("GameInitializer ready")