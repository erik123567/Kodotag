local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundManager = {}

-- Disable auto-respawn
Players.CharacterAutoLoads = false

-- Load Kodo AI module
local KodoAI = require(script.Parent.KodoAI)

-- Settings
local INTERMISSION_TIME = 10
local INITIAL_KODOS = 2
local KODOS_PER_WAVE = 1
local WAVE_INTERVAL = 30
local KODO_SPEED_INCREASE = 2
local INITIAL_KODO_SPEED = 16
local GOLD_PER_KODO_KILL = 10  -- NEW: Gold reward for killing Kodos

-- References
local gameArea = workspace:FindFirstChild("GameArea")
if not gameArea then
	warn("GameArea folder not found in Workspace!")
end

local spawnLocations = gameArea and gameArea:FindFirstChild("SpawnLocations")
local kodoSpawns = gameArea and gameArea:FindFirstChild("KodoSpawns")
local kodoTemplate = game.ServerStorage:FindFirstChild("KodoStorage") and game.ServerStorage.KodoStorage:FindFirstChild("Kodo")

if not spawnLocations or not kodoSpawns or not kodoTemplate then
	warn("Missing game components! Check SpawnLocations, KodoSpawns, and Kodo template")
end

-- Game state
local currentRound = 0
local roundTime = 0
local currentWave = 1
local gameActive = false

-- Player tracking
local alivePlayers = {}
local deadPlayers = {}
local activeKodos = {}
local playerStats = {}

RoundManager.playerStats = playerStats
RoundManager.alivePlayers = alivePlayers

-- Create RemoteEvents
local updateGameState = Instance.new("RemoteEvent")
updateGameState.Name = "UpdateGameState"
updateGameState.Parent = ReplicatedStorage

local updatePlayerStats = Instance.new("RemoteEvent")
updatePlayerStats.Name = "UpdatePlayerStats"
updatePlayerStats.Parent = ReplicatedStorage

local showNotification = Instance.new("RemoteEvent")
showNotification.Name = "ShowNotification"
showNotification.Parent = ReplicatedStorage

-- Helper functions
local function getRandomSpawn()
	if not spawnLocations then return nil end
	local spawns = spawnLocations:GetChildren()
	if #spawns == 0 then return nil end
	return spawns[math.random(1, #spawns)]
end

local function getRandomKodoSpawn()
	if not kodoSpawns then return nil end
	local spawns = kodoSpawns:GetChildren()
	if #spawns == 0 then return nil end
	return spawns[math.random(1, #spawns)]
end

function RoundManager.initPlayerStats(player)
	if not playerStats[player.Name] then
		playerStats[player.Name] = {
			deaths = 0,
			saves = 0,
			kodoKills = 0,
			gold = 50
		}
	end
end

function RoundManager.broadcastGameState()
	local data = {
		round = currentRound,
		alive = #alivePlayers,
		dead = #deadPlayers,
		time = roundTime
	}
	updateGameState:FireAllClients(data)
end

function RoundManager.broadcastPlayerStats()
	updatePlayerStats:FireAllClients(playerStats)
end

local function isPlayerAlive(player)
	for _, p in ipairs(alivePlayers) do
		if p == player then
			return true
		end
	end
	return false
end

local function isPlayerDead(player)
	for _, p in ipairs(deadPlayers) do
		if p == player then
			return true
		end
	end
	return false
end

local function addToAliveList(player)
	if not isPlayerAlive(player) then
		table.insert(alivePlayers, player)
		print("Added " .. player.Name .. " to alive list")
	end
end

local function removeFromAliveList(player)
	for i, p in ipairs(alivePlayers) do
		if p == player then
			table.remove(alivePlayers, i)
			print("Removed " .. player.Name .. " from alive list")
			return
		end
	end
end

local function addToDeadList(player)
	if not isPlayerDead(player) then
		table.insert(deadPlayers, player)
		print("Added " .. player.Name .. " to dead list")
	end
end

local function removeFromDeadList(player)
	for i, p in ipairs(deadPlayers) do
		if p == player then
			table.remove(deadPlayers, i)
			print("Removed " .. player.Name .. " from dead list")
			return
		end
	end
end

-- Spawn a player in game
local function spawnPlayerInGame(player)
	if not gameActive then
		warn("Cannot spawn player - game not active")
		return false
	end

	RoundManager.initPlayerStats(player)

	-- Destroy old character if exists
	if player.Character then
		player.Character:Destroy()
	end

	-- Load new character
	player:LoadCharacter()

	-- Wait for character
	local character = player.Character or player.CharacterAdded:Wait()
	wait(0.1)

	if character and gameActive then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local spawnPoint = getRandomSpawn()
			if spawnPoint then
				humanoidRootPart.CFrame = CFrame.new(spawnPoint.Position + Vector3.new(0, 3, 0))
				print("Spawned " .. player.Name .. " in game area")
			else
				warn("No spawn point found!")
			end
		end

		-- Update tracking lists
		removeFromDeadList(player)
		addToAliveList(player)

		-- Listen for death ONCE per spawn
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			local deathConnection
			deathConnection = humanoid.Died:Connect(function()
				if gameActive then
					handlePlayerDeath(player)
				end
				if deathConnection then
					deathConnection:Disconnect()
				end
			end)
		end

		RoundManager.broadcastGameState()
		RoundManager.broadcastPlayerStats()

		return true
	end

	return false
end

-- Handle player death
function handlePlayerDeath(player)
	if not gameActive then
		return
	end

	-- Prevent duplicate death handling
	if isPlayerDead(player) then
		return
	end

	-- Update tracking
	removeFromAliveList(player)
	addToDeadList(player)

	-- Update stats
	RoundManager.initPlayerStats(player)
	playerStats[player.Name].deaths = playerStats[player.Name].deaths + 1

	print(player.Name .. " died! Alive: " .. #alivePlayers .. " Dead: " .. #deadPlayers)

	-- Notifications
	showNotification:FireAllClients(player.Name .. " was killed by a Kodo!", Color3.new(1, 0, 0))

	RoundManager.broadcastGameState()
	RoundManager.broadcastPlayerStats()

	-- Check for game over
	if #alivePlayers == 0 then
		print("All players dead - Game Over!")
		showNotification:FireAllClients("All players eliminated! Survived " .. currentWave .. " waves!", Color3.new(1, 0, 0))
		endRound()
	end
end

-- Spawn wave of Kodos
local function spawnKodoWave()
	if not gameActive or not kodoTemplate then
		return
	end

	local shrine = workspace:FindFirstChild("ResurrectionShrine")
	local shrinePos = shrine and shrine.Position or Vector3.new(0, 0, 0)

	local kodoCount = INITIAL_KODOS + (currentWave - 1) * KODOS_PER_WAVE
	local kodoSpeed = INITIAL_KODO_SPEED + (currentWave - 1) * KODO_SPEED_INCREASE

	print("Spawning wave " .. currentWave .. " with " .. kodoCount .. " Kodos at speed " .. kodoSpeed)
	showNotification:FireAllClients("Wave " .. currentWave .. " incoming!", Color3.new(1, 0.5, 0))

	for i = 1, kodoCount do
		if not gameActive then
			break
		end

		local kodoSpawn = getRandomKodoSpawn()
		if not kodoSpawn then
			warn("No Kodo spawn point found!")
			break
		end

		-- Avoid spawning near shrine
		local attempts = 0
		while shrine and (kodoSpawn.Position - shrinePos).Magnitude < 30 and attempts < 10 do
			kodoSpawn = getRandomKodoSpawn()
			if not kodoSpawn then break end
			attempts = attempts + 1
		end

		if kodoSpawn then
			local kodo = KodoAI.spawnKodo(kodoTemplate, kodoSpawn.Position, kodoSpeed)

			if kodo then
				table.insert(activeKodos, kodo)

				-- CRITICAL: Connect gold reward when Kodo dies
				local humanoid = kodo:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.Died:Connect(function()
						print("=== ROUNDMANAGER: KODO DIED ===")

						-- Remove from active Kodos list
						for j, k in ipairs(activeKodos) do
							if k == kodo then
								table.remove(activeKodos, j)
								print("RoundManager: Removed Kodo from active list. Remaining:", #activeKodos)
								break
							end
						end

						-- Award gold to ALL players (not just alive ones)
						for _, player in ipairs(Players:GetPlayers()) do
							RoundManager.initPlayerStats(player)

							-- Base gold + Bounty Hunter bonus
							local goldReward = GOLD_PER_KODO_KILL
							if _G.UpgradeManager then
								local bountyBonus = _G.UpgradeManager.getUpgradeEffect(player.Name, "BountyHunter")
								goldReward = goldReward + bountyBonus
							end

							playerStats[player.Name].gold = playerStats[player.Name].gold + goldReward
							playerStats[player.Name].kodoKills = playerStats[player.Name].kodoKills + 1
							print("RoundManager: Awarded", goldReward, "gold to", player.Name, "- New total:", playerStats[player.Name].gold)
						end

						RoundManager.broadcastPlayerStats()
					end)
					print("RoundManager: Connected Died event for Kodo #" .. i)
				else
					warn("RoundManager: Kodo has no Humanoid!")
				end
			end
		end
	end

	print("Spawned " .. #activeKodos .. " Kodos")
end

-- End the round
function endRound()
	if not gameActive then
		return
	end

	print("Ending round...")
	gameActive = false

	-- Round completion bonus - +20 gold for everyone
	for _, player in ipairs(Players:GetPlayers()) do
		RoundManager.initPlayerStats(player)
		playerStats[player.Name].gold = playerStats[player.Name].gold + 20
		print(player.Name .. " earned 20 gold for completing the round. Total: " .. playerStats[player.Name].gold)
	end
	RoundManager.broadcastPlayerStats()

	-- Clean up all Kodos
	for _, kodo in ipairs(activeKodos) do
		if kodo then
			kodo:Destroy()
		end
	end
	activeKodos = {}

	-- Clear player lists
	alivePlayers = {}
	deadPlayers = {}

	RoundManager.broadcastGameState()

	wait(5)
end

-- Start a new round
local function startRound()
	if gameActive then
		warn("Cannot start round - game already active")
		return
	end

	if not spawnLocations or not kodoSpawns or not kodoTemplate then
		warn("Cannot start round - missing game components!")
		return
	end

	print("Starting new round...")

	-- Reset state
	gameActive = true
	currentRound = currentRound + 1
	currentWave = 1
	roundTime = 0
	alivePlayers = {}
	deadPlayers = {}
	activeKodos = {}

	showNotification:FireAllClients("Round " .. currentRound .. " starting!", Color3.new(0, 1, 1))

	-- Spawn all players
	for _, player in ipairs(Players:GetPlayers()) do
		spawnPlayerInGame(player)
	end

	print("Spawned " .. #alivePlayers .. " players")
	RoundManager.broadcastGameState()

	wait(2)

	-- Spawn initial wave
	spawnKodoWave()

	-- Round loop
	local lastWaveTime = 0

	while gameActive do
		wait(1)
		roundTime = roundTime + 1

		-- Passive gold income (+1 every 5 seconds, +1 per farm owned, +efficient farms bonus)
		if roundTime % 5 == 0 then
			for _, player in ipairs(alivePlayers) do
				RoundManager.initPlayerStats(player)

				-- Count farms owned by this player (excluding those under construction)
				local farmCount = 0
				for _, obj in ipairs(workspace:GetChildren()) do
					if obj.Name == "Farm" then
						local owner = obj:FindFirstChild("Owner")
						local underConstruction = obj:FindFirstChild("UnderConstruction")
						-- Only count completed farms
						if owner and owner.Value == player.Name and not (underConstruction and underConstruction.Value) then
							farmCount = farmCount + 1
						end
					end
				end

				-- Get Efficient Farms upgrade bonus (extra gold per farm)
				local farmEfficiencyBonus = 0
				if _G.UpgradeManager and farmCount > 0 then
					local bonusPerFarm = _G.UpgradeManager.getUpgradeEffect(player.Name, "EfficientFarms")
					farmEfficiencyBonus = farmCount * bonusPerFarm
				end

				-- Base income (1) + farm bonus (1 per farm) + efficiency bonus
				local totalIncome = 1 + farmCount + farmEfficiencyBonus
				playerStats[player.Name].gold = playerStats[player.Name].gold + totalIncome

				if farmCount > 0 then
					print("RoundManager:", player.Name, "earned", totalIncome, "gold (1 base +", farmCount, "farms +", farmEfficiencyBonus, "efficiency)")
				end
			end
			RoundManager.broadcastPlayerStats()
		end

		-- Spawn new waves
		if roundTime - lastWaveTime >= WAVE_INTERVAL then
			currentWave = currentWave + 1
			spawnKodoWave()
			lastWaveTime = roundTime
		end

		RoundManager.broadcastGameState()
	end

	-- Round ended
	print("Round loop ended")
end

-- Initialize existing players
for _, player in ipairs(Players:GetPlayers()) do
	RoundManager.initPlayerStats(player)
end

-- Handle new players joining
Players.PlayerAdded:Connect(function(player)
	RoundManager.initPlayerStats(player)
	RoundManager.broadcastPlayerStats()
end)

print("RoundManager loaded - starting game loop")

-- Start the game loop in a separate thread
local function startGameLoop()
	wait(3)

	while true do
		-- Intermission
		print("=== INTERMISSION ===")
		for i = INTERMISSION_TIME, 0, -1 do
			showNotification:FireAllClients("Round starting in " .. i .. " seconds", Color3.new(1, 1, 1))
			wait(1)
		end

		local playerList = Players:GetPlayers()
		print("Player count: " .. #playerList)

		if #playerList < 1 then
			print("Not enough players. Waiting...")
			wait(5)
			continue
		end

		-- Start round
		startRound()

		-- After round ends, wait before next intermission
		wait(3)
	end
end

task.spawn(startGameLoop)

_G.RoundManager = RoundManager
return RoundManager