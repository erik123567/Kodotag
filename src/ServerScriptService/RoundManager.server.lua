local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local RoundManager = {}

-- Settings for return to lobby
local RETURN_TO_LOBBY_DELAY = 10 -- Seconds to show results before teleporting

-- Check if this is a reserved (game) server
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

-- Only run RoundManager on reserved game servers
if not isReservedServer then
	print("RoundManager: This is the LOBBY server - game logic disabled")
	_G.RoundManager = RoundManager
	return RoundManager
end

print("RoundManager: This is a GAME server - initializing game logic")

-- Disable auto-respawn
Players.CharacterAutoLoads = false

-- Load Kodo AI module
local KodoAI = require(script.Parent.KodoAI)

-- Settings
local INTERMISSION_TIME = 10
local WAVE_INTERVAL = 30
local GOLD_PER_KODO_KILL = 10  -- Gold reward for killing Kodos

-- Base Difficulty (scales with wave and player count)
local BASE_KODOS = 2
local BASE_KODO_SPEED = 14
local BASE_KODO_HEALTH = 80
local BASE_KODO_DAMAGE = 20

-- Scaling multipliers (exponential growth)
local KODO_COUNT_GROWTH = 1.15      -- 15% more kodos per wave
local KODO_HEALTH_GROWTH = 1.12     -- 12% more health per wave
local KODO_DAMAGE_GROWTH = 1.08     -- 8% more damage per wave
local KODO_SPEED_GROWTH = 1.02      -- 2% faster per wave (capped)
local MAX_KODO_SPEED = 28           -- Speed cap

-- Player count scaling
local KODOS_PER_PLAYER = 1          -- Extra kodos per player beyond first
local HEALTH_PER_PLAYER = 0.1       -- 10% more health per extra player

-- Pad type difficulty multipliers
local DIFFICULTY_MULTIPLIERS = {
	SOLO = { kodos = 0.7, health = 0.8, damage = 0.8, speed = 0.9 },
	SMALL = { kodos = 1.0, health = 1.0, damage = 1.0, speed = 1.0 },
	MEDIUM = { kodos = 1.2, health = 1.1, damage = 1.1, speed = 1.0 },
	LARGE = { kodos = 1.4, health = 1.2, damage = 1.2, speed = 1.05 }
}

-- Special wave types
local BOSS_WAVE_INTERVAL = 5
local SWARM_WAVE_INTERVAL = 7       -- Lots of weak kodos
local ELITE_WAVE_INTERVAL = 10      -- Few but very strong kodos
local MINI_WAVE_INTERVAL = 6        -- Mini kodos that fit through maze gaps!

-- Boss Settings
local BOSS_HEALTH_MULTIPLIER = 5
local BOSS_SIZE_MULTIPLIER = 1.5
local BOSS_GOLD_REWARD = 100
local BOSS_COLOR = Color3.fromRGB(139, 0, 0)

-- Swarm Settings
local SWARM_COUNT_MULTIPLIER = 3    -- Triple the kodos
local SWARM_HEALTH_MULTIPLIER = 0.4 -- But much weaker
local SWARM_SPEED_MULTIPLIER = 1.2  -- And faster

-- Elite Settings
local ELITE_COUNT_MULTIPLIER = 0.5  -- Half the kodos
local ELITE_HEALTH_MULTIPLIER = 2.5 -- But much stronger
local ELITE_DAMAGE_MULTIPLIER = 1.5
local ELITE_GOLD_MULTIPLIER = 2     -- More gold reward

-- Mini Wave Settings - they fit through maze gaps!
local MINI_COUNT_MULTIPLIER = 2.5   -- Many mini kodos
local MINI_HEALTH_MULTIPLIER = 0.3  -- Very fragile
local MINI_SPEED_MULTIPLIER = 1.3   -- Fast

-- Kodo Types - spawn chances increase with wave number
local KODO_TYPES = {"Normal", "Armored", "Swift", "Frostborn", "Venomous", "Horde", "Mini"}
local function getKodoTypeForWave(wave, isSwarmWave, isMiniWave)
	-- Swarm waves always spawn Horde kodos
	if isSwarmWave then
		return "Horde"
	end

	-- Mini waves always spawn Mini kodos (they fit through maze gaps!)
	if isMiniWave then
		return "Mini"
	end

	-- Early waves: mostly normal
	if wave <= 3 then
		return "Normal"
	end

	-- Calculate spawn weights based on wave
	local weights = {
		Normal = math.max(50 - wave * 3, 10),     -- Decreases over time
		Armored = math.min(wave * 2, 20),          -- Increases slowly
		Swift = math.min(wave * 2, 20),            -- Increases slowly
		Frostborn = math.min((wave - 5) * 2, 15),  -- Appears after wave 5
		Venomous = math.min((wave - 5) * 2, 15),   -- Appears after wave 5
		Horde = math.min((wave - 7) * 3, 20),      -- Appears after wave 7
		Mini = math.min((wave - 5) * 2, 15)        -- Appears after wave 5
	}

	-- Clamp negative weights to 0
	for k, v in pairs(weights) do
		weights[k] = math.max(v, 0)
	end

	-- Calculate total weight
	local totalWeight = 0
	for _, w in pairs(weights) do
		totalWeight = totalWeight + w
	end

	-- Pick random type based on weights
	local roll = math.random() * totalWeight
	local cumulative = 0
	for kodoType, weight in pairs(weights) do
		cumulative = cumulative + weight
		if roll <= cumulative then
			return kodoType
		end
	end

	return "Normal"
end

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
RoundManager.deadPlayers = deadPlayers

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

local showGameOver = Instance.new("RemoteEvent")
showGameOver.Name = "ShowGameOver"
showGameOver.Parent = ReplicatedStorage

local showWavePreview = Instance.new("RemoteEvent")
showWavePreview.Name = "ShowWavePreview"
showWavePreview.Parent = ReplicatedStorage

local roundStarted = Instance.new("RemoteEvent")
roundStarted.Name = "RoundStarted"
roundStarted.Parent = ReplicatedStorage

-- Wave preview timing
local WAVE_PREVIEW_TIME = 5 -- Seconds to show preview before spawning

-- Return all players to lobby
local function returnToLobby()
	print("Returning all players to lobby in " .. RETURN_TO_LOBBY_DELAY .. " seconds...")

	-- Collect final stats for each player and save high scores
	local finalStats = {}
	local highScoreData = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local stats = playerStats[player.Name] or {deaths = 0, saves = 0, kodoKills = 0, gold = 0}
		finalStats[player.Name] = {
			wavesReached = currentWave,
			deaths = stats.deaths,
			saves = stats.saves,
			kodoKills = stats.kodoKills,
			goldEarned = stats.gold
		}

		-- Save high score and check for new record
		if _G.HighScoreManager then
			local isNewRecord, data = _G.HighScoreManager.saveHighScore(player, currentWave, stats.kodoKills)
			highScoreData[player.Name] = {
				bestWave = data.bestWave,
				isNewRecord = isNewRecord,
				totalGames = data.totalGames,
				totalKills = data.totalKills
			}
		end
	end

	-- Send game over screen to all clients
	showGameOver:FireAllClients({
		wavesReached = currentWave,
		playerStats = finalStats,
		highScores = highScoreData,
		returnDelay = RETURN_TO_LOBBY_DELAY
	})

	-- Wait before teleporting
	task.wait(RETURN_TO_LOBBY_DELAY)

	-- Teleport all players back to lobby (main place)
	local playerList = Players:GetPlayers()
	if #playerList > 0 then
		print("Teleporting " .. #playerList .. " players back to lobby...")

		for _, player in ipairs(playerList) do
			local success, err = pcall(function()
				TeleportService:Teleport(game.PlaceId, player)
			end)

			if not success then
				warn("Failed to teleport " .. player.Name .. ": " .. tostring(err))
			end
		end
	end
end

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
		wave = currentWave,
		alive = #alivePlayers,
		dead = #deadPlayers,
		time = roundTime,
		kodosRemaining = #activeKodos
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

		-- Return all players to lobby
		task.spawn(function()
			returnToLobby()
		end)
	end
end

-- Expose functions for death abilities
RoundManager.removeFromDeadList = removeFromDeadList
RoundManager.addToAliveList = addToAliveList
RoundManager.handlePlayerDeath = handlePlayerDeath
RoundManager.isPlayerDead = isPlayerDead

-- Spawn wave of Kodos
local function spawnKodoWave()
	if not gameActive or not kodoTemplate then
		return
	end

	local shrine = (gameArea and gameArea:FindFirstChild("ResurrectionShrine")) or (gameArea and gameArea:FindFirstChild("RessurectionShrine")) or workspace:FindFirstChild("ResurrectionShrine")
	local shrinePos = shrine and shrine.Position or Vector3.new(0, 0, 0)

	-- Get game config for difficulty
	local gameConfig = _G.GameConfig or {}
	local padType = gameConfig.padType or "SOLO"
	local diffMult = DIFFICULTY_MULTIPLIERS[padType] or DIFFICULTY_MULTIPLIERS.SOLO
	local playerCount = #Players:GetPlayers()

	-- Determine wave type (priority: Boss > Elite > Swarm > Mini)
	local isBossWave = (currentWave % BOSS_WAVE_INTERVAL == 0)
	local isEliteWave = (currentWave % ELITE_WAVE_INTERVAL == 0) and not isBossWave
	local isSwarmWave = (currentWave % SWARM_WAVE_INTERVAL == 0) and not isBossWave and not isEliteWave
	local isMiniWave = (currentWave % MINI_WAVE_INTERVAL == 0) and not isBossWave and not isEliteWave and not isSwarmWave

	-- Calculate base stats with exponential scaling
	local waveMultiplier = currentWave - 1
	local baseKodoCount = BASE_KODOS * math.pow(KODO_COUNT_GROWTH, waveMultiplier)
	local baseHealth = BASE_KODO_HEALTH * math.pow(KODO_HEALTH_GROWTH, waveMultiplier)
	local baseDamage = BASE_KODO_DAMAGE * math.pow(KODO_DAMAGE_GROWTH, waveMultiplier)
	local baseSpeed = math.min(BASE_KODO_SPEED * math.pow(KODO_SPEED_GROWTH, waveMultiplier), MAX_KODO_SPEED)

	-- Apply player count scaling
	local playerMultiplier = 1 + (playerCount - 1) * KODOS_PER_PLAYER * 0.5
	local playerHealthMult = 1 + (playerCount - 1) * HEALTH_PER_PLAYER
	baseKodoCount = baseKodoCount * playerMultiplier
	baseHealth = baseHealth * playerHealthMult

	-- Apply pad type difficulty
	local kodoCount = math.floor(baseKodoCount * diffMult.kodos)
	local kodoHealth = math.floor(baseHealth * diffMult.health)
	local kodoDamage = math.floor(baseDamage * diffMult.damage)
	local kodoSpeed = baseSpeed * diffMult.speed

	-- Apply wave type modifiers
	local waveTypeText = ""
	local waveColor = Color3.new(1, 0.5, 0)
	local goldMultiplier = 1

	if isSwarmWave then
		kodoCount = math.floor(kodoCount * SWARM_COUNT_MULTIPLIER)
		kodoHealth = math.floor(kodoHealth * SWARM_HEALTH_MULTIPLIER)
		kodoSpeed = kodoSpeed * SWARM_SPEED_MULTIPLIER
		waveTypeText = "SWARM "
		waveColor = Color3.new(1, 1, 0)
	elseif isEliteWave then
		kodoCount = math.max(2, math.floor(kodoCount * ELITE_COUNT_MULTIPLIER))
		kodoHealth = math.floor(kodoHealth * ELITE_HEALTH_MULTIPLIER)
		kodoDamage = math.floor(kodoDamage * ELITE_DAMAGE_MULTIPLIER)
		goldMultiplier = ELITE_GOLD_MULTIPLIER
		waveTypeText = "ELITE "
		waveColor = Color3.new(0.8, 0.2, 1)
	elseif isMiniWave then
		-- Mini kodos fit through maze gaps! Many, fast, but fragile
		kodoCount = math.floor(kodoCount * MINI_COUNT_MULTIPLIER)
		kodoHealth = math.floor(kodoHealth * MINI_HEALTH_MULTIPLIER)
		kodoSpeed = kodoSpeed * MINI_SPEED_MULTIPLIER
		waveTypeText = "MINI "
		waveColor = Color3.new(1, 0.7, 0.3) -- Orange
	elseif isBossWave then
		waveTypeText = "BOSS "
		waveColor = Color3.new(1, 0, 0)
	end

	-- Ensure minimums
	kodoCount = math.max(2, kodoCount)
	kodoHealth = math.max(50, kodoHealth)
	kodoDamage = math.max(10, kodoDamage)
	kodoSpeed = math.max(10, kodoSpeed)

	-- Pre-calculate Kodo types for this wave (store in list for spawning)
	local kodoTypesToSpawn = {}
	local waveComposition = {}
	for i = 1, kodoCount do
		local kodoType = getKodoTypeForWave(currentWave, isSwarmWave, isMiniWave)
		table.insert(kodoTypesToSpawn, kodoType)
		waveComposition[kodoType] = (waveComposition[kodoType] or 0) + 1
	end

	-- Build composition summary for preview
	local compositionList = {}
	for kodoType, count in pairs(waveComposition) do
		table.insert(compositionList, {type = kodoType, count = count})
	end
	-- Sort by count descending
	table.sort(compositionList, function(a, b) return a.count > b.count end)

	print("Spawning " .. waveTypeText .. "wave " .. currentWave .. " with " .. kodoCount .. " Kodos (HP:" .. kodoHealth .. " DMG:" .. kodoDamage .. " Speed:" .. string.format("%.1f", kodoSpeed) .. ")")

	-- Send wave preview to all clients
	showWavePreview:FireAllClients({
		wave = currentWave,
		waveType = waveTypeText ~= "" and waveTypeText:gsub(" ", "") or nil, -- "BOSS", "SWARM", "ELITE", or nil
		totalCount = kodoCount,
		composition = compositionList,
		health = kodoHealth,
		previewTime = WAVE_PREVIEW_TIME,
		isBossWave = isBossWave
	})

	-- Wait for preview time
	task.wait(WAVE_PREVIEW_TIME)

	-- Helper function to connect kodo death event
	local function connectKodoDeath(kodo, isBoss, kodoGoldMult)
		local humanoid = kodo:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				print("=== ROUNDMANAGER: " .. (isBoss and "BOSS " or "") .. "KODO DIED ===")

				-- Remove from active Kodos list
				for j, k in ipairs(activeKodos) do
					if k == kodo then
						table.remove(activeKodos, j)
						print("RoundManager: Removed Kodo from active list. Remaining:", #activeKodos)
						break
					end
				end

				-- Award gold to ALL players
				for _, player in ipairs(Players:GetPlayers()) do
					RoundManager.initPlayerStats(player)

					-- Base gold * wave multiplier + Bounty Hunter bonus + Boss bonus
					local goldReward = math.floor(GOLD_PER_KODO_KILL * (kodoGoldMult or 1))
					if isBoss then
						goldReward = goldReward + BOSS_GOLD_REWARD
					end
					if _G.UpgradeManager then
						local bountyBonus = _G.UpgradeManager.getUpgradeEffect(player.Name, "BountyHunter")
						goldReward = goldReward + bountyBonus
					end

					playerStats[player.Name].gold = playerStats[player.Name].gold + goldReward
					playerStats[player.Name].kodoKills = playerStats[player.Name].kodoKills + 1
					print("RoundManager: Awarded", goldReward, "gold to", player.Name)
				end

				if isBoss then
					showNotification:FireAllClients("BOSS DEFEATED! +" .. BOSS_GOLD_REWARD .. " bonus gold!", Color3.new(0, 1, 0))
				end

				RoundManager.broadcastPlayerStats()
			end)
		end
	end

	-- Spawn regular kodos
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
			-- Use pre-calculated kodo type for this spawn
			local kodoType = kodoTypesToSpawn[i] or "Normal"
			local kodo = KodoAI.spawnKodo(kodoTemplate, kodoSpawn.Position, kodoSpeed, kodoHealth, kodoDamage, false, kodoType)

			if kodo then
				table.insert(activeKodos, kodo)
				connectKodoDeath(kodo, false, goldMultiplier)
				print("RoundManager: Spawned " .. kodoType .. " Kodo #" .. i)
			end
		end
	end

	-- Spawn boss on milestone waves
	if isBossWave then
		local bossHealth = kodoHealth * BOSS_HEALTH_MULTIPLIER
		local bossDamage = kodoDamage * 2
		local bossSpeed = kodoSpeed * 0.8  -- Slightly slower

		showNotification:FireAllClients("BOSS KODO INCOMING!", Color3.new(1, 0, 0))

		local kodoSpawn = getRandomKodoSpawn()
		if kodoSpawn then
			-- Avoid shrine
			local attempts = 0
			while shrine and (kodoSpawn.Position - shrinePos).Magnitude < 30 and attempts < 10 do
				kodoSpawn = getRandomKodoSpawn()
				if not kodoSpawn then break end
				attempts = attempts + 1
			end

			if kodoSpawn then
				-- Boss is always Normal type (no special resistances, just big and tough)
				local boss = KodoAI.spawnKodo(kodoTemplate, kodoSpawn.Position, bossSpeed, bossHealth, bossDamage, true, "Normal")

				if boss then
					table.insert(activeKodos, boss)
					connectKodoDeath(boss, true, goldMultiplier)
					print("RoundManager: Spawned BOSS KODO with", bossHealth, "HP")
				end
			end
		end
	end

	print("Spawned " .. #activeKodos .. " Kodos total")
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

	-- Notify clients that round has started (hide loading screen)
	roundStarted:FireAllClients()

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

print("RoundManager loaded - waiting for players to arrive...")

-- Start the game loop in a separate thread
local function startGameLoop()
	-- Wait for GameInitializer to signal that players are ready
	print("RoundManager: Waiting for players to teleport in...")

	while not _G.GameConfig or not _G.GameConfig.playersReady do
		wait(0.5)
	end

	-- Get game configuration
	local gameConfig = _G.GameConfig
	print("RoundManager: Game starting!")
	print("  - Pad Type: " .. (gameConfig.padType or "UNKNOWN"))
	print("  - Difficulty: " .. (gameConfig.difficulty or "NORMAL"))
	print("  - Expected Players: " .. (gameConfig.expectedPlayers or 1))

	-- Brief delay for players to load
	wait(2)

	-- Notify players
	showNotification:FireAllClients("Game mode: " .. (gameConfig.padType or "SOLO"), Color3.new(0, 1, 1))

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
			print("No players remaining. Ending game server...")
			-- Could add logic here to shut down the server
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