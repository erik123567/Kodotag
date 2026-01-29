local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- Check if this is a reserved server
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

print("Server starting - Reserved Server: " .. tostring(isReservedServer))

-- Disable auto character loading
Players.CharacterAutoLoads = false

if isReservedServer then
	-- This is a GAME server (reserved)
	print("GAME SERVER - This is where the actual Kodo Tag game runs")

	-- Get teleport data
	local teleportData = nil

	Players.PlayerAdded:Connect(function(player)
		print("Player joined game server: " .. player.Name)

		-- Get teleport data
		local success, data = pcall(function()
			return TeleportService:GetLocalPlayerTeleportData()
		end)

		if success and data then
			teleportData = data
			print("Game config:", data)
		end

		-- Let RoundManager handle spawning
		-- (we'll update RoundManager to detect reserved server mode)
	end)

else
	-- This is the LOBBY server (main)
	print("LOBBY SERVER - Players spawn here and choose game mode")

	-- Function to spawn player in lobby
	local function spawnInLobby(player)
		player:LoadCharacter()

		local character = player.Character or player.CharacterAdded:Wait()
		wait(0.1)

		local lobbySpawns = workspace:FindFirstChild("LobbySpawns")
		if lobbySpawns then
			local spawns = lobbySpawns:GetChildren()
			if #spawns > 0 then
				local randomSpawn = spawns[math.random(1, #spawns)]
				local hrp = character:WaitForChild("HumanoidRootPart")
				hrp.CFrame = CFrame.new(randomSpawn.Position + Vector3.new(0, 3, 0))
				print("Spawned " .. player.Name .. " in lobby")
			else
				warn("LobbySpawns folder is empty!")
			end
		else
			warn("LobbySpawns folder not found!")
		end
	end

	Players.PlayerAdded:Connect(function(player)
		print("Player joined lobby: " .. player.Name)
		wait(0.5)
		spawnInLobby(player)

		-- Respawn in lobby if they die
		player.CharacterAdded:Connect(function(character)
			wait(0.1)
			local lobbySpawns = workspace:FindFirstChild("LobbySpawns")
			if lobbySpawns then
				local spawns = lobbySpawns:GetChildren()
				if #spawns > 0 then
					local randomSpawn = spawns[math.random(1, #spawns)]
					local hrp = character:WaitForChild("HumanoidRootPart")
					hrp.CFrame = CFrame.new(randomSpawn.Position + Vector3.new(0, 3, 0))
				end
			end
		end)
	end)
end

print("GameInitializer ready")