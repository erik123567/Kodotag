-- DEATH ABILITIES
-- Dead players can spend gold to help survivors

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run on game servers
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("DeathAbilities: Lobby - disabled")
	return
end

print("DeathAbilities: Starting...")

-- Wait for dependencies
task.wait(2)

-- Ability definitions
local ABILITIES = {
	SlowAura = {
		name = "Slow Aura",
		description = "Slow all Kodos by 50% for 5 seconds",
		cost = 40,
		cooldown = 15,
		icon = "rbxassetid://0" -- placeholder
	},
	LightningStrike = {
		name = "Lightning Strike",
		description = "Deal 100 damage to all Kodos",
		cost = 50,
		cooldown = 20,
		icon = "rbxassetid://0"
	},
	SpeedBoost = {
		name = "Speed Boost",
		description = "All survivors run 50% faster for 8 seconds",
		cost = 30,
		cooldown = 25,
		icon = "rbxassetid://0"
	},
	QuickRevive = {
		name = "Quick Revive",
		description = "Instantly respawn at a random spawn point",
		cost = 100,
		cooldown = 0, -- One-time use per death
		icon = "rbxassetid://0"
	}
}

-- Track cooldowns per player
local playerCooldowns = {}

-- Create RemoteEvents
local useDeathAbility = Instance.new("RemoteEvent")
useDeathAbility.Name = "UseDeathAbility"
useDeathAbility.Parent = ReplicatedStorage

local deathAbilityUsed = Instance.new("RemoteEvent")
deathAbilityUsed.Name = "DeathAbilityUsed"
deathAbilityUsed.Parent = ReplicatedStorage

local getDeathAbilities = Instance.new("RemoteFunction")
getDeathAbilities.Name = "GetDeathAbilities"
getDeathAbilities.Parent = ReplicatedStorage

-- Get ability list for client
getDeathAbilities.OnServerInvoke = function(player)
	return ABILITIES
end

-- Check if player is dead
local function isPlayerDead(player)
	if not player.Character then return true end
	local humanoid = player.Character:FindFirstChild("Humanoid")
	return not humanoid or humanoid.Health <= 0
end

-- Apply Slow Aura effect
local function applySlowAura(player)
	print("DeathAbilities: " .. player.Name .. " used Slow Aura!")

	local slowedKodos = {}

	-- Find all Kodos and slow them
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:FindFirstChild("Humanoid") and obj:FindFirstChild("KodoType") then
			local humanoid = obj.Humanoid
			local originalSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = originalSpeed * 0.5
			table.insert(slowedKodos, {kodo = obj, humanoid = humanoid, originalSpeed = originalSpeed})
		end
	end

	-- Visual effect on Kodos
	for _, data in ipairs(slowedKodos) do
		if data.kodo and data.kodo.Parent then
			for _, part in ipairs(data.kodo:GetDescendants()) do
				if part:IsA("BasePart") then
					-- Add blue tint
					local originalColor = part.Color
					part.Color = Color3.new(
						originalColor.R * 0.5,
						originalColor.G * 0.5,
						math.min(1, originalColor.B + 0.5)
					)
				end
			end
		end
	end

	-- Notify all clients
	local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
	if showNotification then
		showNotification:FireAllClients(player.Name .. " used Slow Aura! Kodos slowed for 5s", Color3.new(0.5, 0.7, 1))
	end

	-- Restore speed after duration
	task.delay(5, function()
		for _, data in ipairs(slowedKodos) do
			if data.kodo and data.kodo.Parent and data.humanoid then
				data.humanoid.WalkSpeed = data.originalSpeed
				-- Restore colors (approximate - they may have changed)
				for _, part in ipairs(data.kodo:GetDescendants()) do
					if part:IsA("BasePart") then
						local kodoType = data.kodo:FindFirstChild("KodoType")
						if kodoType then
							local KodoAI = require(script.Parent.KodoAI)
							local typeConfig = KodoAI.KODO_TYPES[kodoType.Value]
							if typeConfig then
								part.Color = typeConfig.color
							end
						end
					end
				end
			end
		end
	end)

	return true
end

-- Apply Lightning Strike effect
local function applyLightningStrike(player)
	print("DeathAbilities: " .. player.Name .. " used Lightning Strike!")

	local kodoCount = 0
	local totalDamage = 0

	-- Find all Kodos and damage them
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:FindFirstChild("Humanoid") and obj:FindFirstChild("KodoType") then
			local humanoid = obj.Humanoid
			local damage = 100
			humanoid:TakeDamage(damage)
			kodoCount = kodoCount + 1
			totalDamage = totalDamage + damage

			-- Visual lightning effect
			local rootPart = obj:FindFirstChild("HumanoidRootPart")
			if rootPart then
				-- Create lightning beam effect
				local lightning = Instance.new("Part")
				lightning.Name = "LightningEffect"
				lightning.Size = Vector3.new(1, 100, 1)
				lightning.Position = rootPart.Position + Vector3.new(0, 50, 0)
				lightning.Anchored = true
				lightning.CanCollide = false
				lightning.Material = Enum.Material.Neon
				lightning.Color = Color3.new(1, 1, 0.5)
				lightning.Transparency = 0.3
				lightning.Parent = workspace

				-- Remove after short delay
				task.delay(0.3, function()
					if lightning and lightning.Parent then
						lightning:Destroy()
					end
				end)
			end
		end
	end

	-- Notify all clients
	local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
	if showNotification then
		showNotification:FireAllClients(player.Name .. " called Lightning Strike! " .. kodoCount .. " Kodos hit!", Color3.new(1, 1, 0.3))
	end

	return true
end

-- Apply Speed Boost effect
local function applySpeedBoost(player)
	print("DeathAbilities: " .. player.Name .. " used Speed Boost!")

	local boostedPlayers = {}

	-- Find all alive players and boost them
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			local humanoid = p.Character:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local originalSpeed = humanoid.WalkSpeed
				humanoid.WalkSpeed = originalSpeed * 1.5
				table.insert(boostedPlayers, {player = p, humanoid = humanoid, originalSpeed = originalSpeed})

				-- Visual effect - add sparkles
				local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local sparkles = Instance.new("Sparkles")
					sparkles.Name = "SpeedSparkles"
					sparkles.SparkleColor = Color3.new(0.3, 1, 0.3)
					sparkles.Parent = rootPart

					task.delay(8, function()
						if sparkles and sparkles.Parent then
							sparkles:Destroy()
						end
					end)
				end
			end
		end
	end

	-- Notify all clients
	local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
	if showNotification then
		showNotification:FireAllClients(player.Name .. " activated Speed Boost! Run faster for 8s!", Color3.new(0.3, 1, 0.3))
	end

	-- Restore speed after duration
	task.delay(8, function()
		for _, data in ipairs(boostedPlayers) do
			if data.player and data.player.Character and data.humanoid then
				data.humanoid.WalkSpeed = data.originalSpeed
			end
		end
	end)

	return true
end

-- Apply Quick Revive effect
local function applyQuickRevive(player)
	print("DeathAbilities: " .. player.Name .. " used Quick Revive!")

	-- Check if RoundManager is available
	local RoundManager = _G.RoundManager
	if not RoundManager then
		warn("DeathAbilities: RoundManager not available for revive")
		return false
	end

	-- Respawn the player
	if player.Character then
		player.Character:Destroy()
	end

	player:LoadCharacter()

	local character = player.Character or player.CharacterAdded:Wait()
	task.wait(0.1)

	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			-- Find a spawn point
			local gameArea = workspace:FindFirstChild("GameArea")
			local spawnLocations = gameArea and gameArea:FindFirstChild("SpawnLocations")
			if spawnLocations then
				local spawns = spawnLocations:GetChildren()
				if #spawns > 0 then
					local spawn = spawns[math.random(1, #spawns)]
					humanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
				end
			end
		end

		-- Update player lists
		if RoundManager.removeFromDeadList then
			RoundManager.removeFromDeadList(player)
		end
		if RoundManager.addToAliveList then
			RoundManager.addToAliveList(player)
		end

		-- Set up death listener again
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				if RoundManager.handlePlayerDeath then
					RoundManager.handlePlayerDeath(player)
				end
			end)
		end
	end

	-- Notify all clients
	local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
	if showNotification then
		showNotification:FireAllClients(player.Name .. " has revived!", Color3.new(0.3, 1, 0.5))
	end

	return true
end

-- Handle ability use request
useDeathAbility.OnServerEvent:Connect(function(player, abilityName)
	print("DeathAbilities: " .. player.Name .. " wants to use " .. tostring(abilityName))

	-- Validate ability
	local ability = ABILITIES[abilityName]
	if not ability then
		warn("DeathAbilities: Unknown ability:", abilityName)
		return
	end

	-- Check if player is dead (except for revive check later)
	if abilityName ~= "QuickRevive" and not isPlayerDead(player) then
		print("DeathAbilities: " .. player.Name .. " is not dead, cannot use ability")
		return
	end

	-- Check cooldown
	if not playerCooldowns[player.Name] then
		playerCooldowns[player.Name] = {}
	end

	local lastUsed = playerCooldowns[player.Name][abilityName] or 0
	local timeSinceUse = tick() - lastUsed

	if timeSinceUse < ability.cooldown then
		local remaining = math.ceil(ability.cooldown - timeSinceUse)
		print("DeathAbilities: " .. abilityName .. " on cooldown for " .. remaining .. "s")
		return
	end

	-- Check gold
	local RoundManager = _G.RoundManager
	if not RoundManager or not RoundManager.playerStats then
		warn("DeathAbilities: RoundManager not available")
		return
	end

	local stats = RoundManager.playerStats[player.Name]
	if not stats then
		warn("DeathAbilities: No stats for player")
		return
	end

	if stats.gold < ability.cost then
		print("DeathAbilities: " .. player.Name .. " cannot afford " .. abilityName)
		local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
		if showNotification then
			showNotification:FireClient(player, "Not enough gold! Need " .. ability.cost .. "g", Color3.new(1, 0.3, 0.3))
		end
		return
	end

	-- Deduct gold
	stats.gold = stats.gold - ability.cost
	RoundManager.broadcastPlayerStats()

	-- Set cooldown
	playerCooldowns[player.Name][abilityName] = tick()

	-- Apply ability effect
	local success = false
	if abilityName == "SlowAura" then
		success = applySlowAura(player)
	elseif abilityName == "LightningStrike" then
		success = applyLightningStrike(player)
	elseif abilityName == "SpeedBoost" then
		success = applySpeedBoost(player)
	elseif abilityName == "QuickRevive" then
		success = applyQuickRevive(player)
	end

	-- Notify client of ability use
	if success then
		deathAbilityUsed:FireClient(player, abilityName, ability.cooldown)
	end
end)

-- Clean up on player leave
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.Name] = nil
end)

print("DeathAbilities: Loaded!")
