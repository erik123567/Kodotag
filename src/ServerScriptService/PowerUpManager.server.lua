-- POWER-UP MANAGER
-- Spawns collectible power-ups around the map that give temporary bonuses

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Check if game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	print("PowerUpManager: Lobby - disabled")
	return
end

-- Settings
local SPAWN_INTERVAL = 25 -- Seconds between spawn attempts
local MAX_POWERUPS = 5 -- Maximum power-ups on map at once
local DESPAWN_TIME = 30 -- Seconds before uncollected power-up disappears
local SPAWN_RADIUS = 80 -- Distance from center to spawn power-ups
local MIN_SPAWN_DISTANCE = 30 -- Minimum distance from any player's spawn

-- Power-up definitions
local POWERUPS = {
	GoldRush = {
		name = "Gold Rush",
		description = "+50 Gold",
		color = Color3.fromRGB(255, 215, 0),
		effect = function(player)
			-- Give gold
			local goldValue = player:FindFirstChild("Gold")
			if goldValue then
				goldValue.Value = goldValue.Value + 50
			end
		end,
		duration = 0, -- Instant
		weight = 30, -- Spawn chance weight
	},
	SpeedSurge = {
		name = "Speed Surge",
		description = "50% faster for 10s",
		color = Color3.fromRGB(100, 255, 150),
		effect = function(player)
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid then
					local originalSpeed = humanoid.WalkSpeed
					humanoid.WalkSpeed = originalSpeed * 1.5
					task.delay(10, function()
						if humanoid and humanoid.Parent then
							humanoid.WalkSpeed = originalSpeed
						end
					end)
				end
			end
		end,
		duration = 10,
		weight = 20,
	},
	Shield = {
		name = "Shield",
		description = "Invincible for 5s",
		color = Color3.fromRGB(100, 200, 255),
		effect = function(player)
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid then
					-- Create shield visual
					local shield = Instance.new("Part")
					shield.Name = "PowerUpShield"
					shield.Shape = Enum.PartType.Ball
					shield.Size = Vector3.new(8, 8, 8)
					shield.Transparency = 0.7
					shield.Color = Color3.fromRGB(100, 200, 255)
					shield.Material = Enum.Material.ForceField
					shield.CanCollide = false
					shield.Anchored = false
					shield.Parent = character

					local weld = Instance.new("WeldConstraint")
					weld.Part0 = character:FindFirstChild("HumanoidRootPart")
					weld.Part1 = shield
					weld.Parent = shield

					-- Store original health and make invincible
					local forceField = Instance.new("ForceField")
					forceField.Name = "PowerUpForceField"
					forceField.Visible = false
					forceField.Parent = character

					Debris:AddItem(shield, 5)
					Debris:AddItem(forceField, 5)
				end
			end
		end,
		duration = 5,
		weight = 10,
	},
	TurretBoost = {
		name = "Turret Boost",
		description = "Your turrets deal 2x damage for 15s",
		color = Color3.fromRGB(255, 100, 100),
		effect = function(player)
			-- Find all turrets owned by this player and boost them
			for _, obj in ipairs(workspace:GetChildren()) do
				if obj:FindFirstChild("Owner") and obj.Owner.Value == player.Name then
					if obj.Name:find("Turret") then
						local damageBoost = obj:FindFirstChild("DamageBoost")
						if not damageBoost then
							damageBoost = Instance.new("NumberValue")
							damageBoost.Name = "DamageBoost"
							damageBoost.Value = 1
							damageBoost.Parent = obj
						end
						damageBoost.Value = 2

						-- Visual indicator
						local base = obj:FindFirstChild("Base") or obj.PrimaryPart
						if base then
							local highlight = Instance.new("Highlight")
							highlight.FillColor = Color3.fromRGB(255, 100, 100)
							highlight.FillTransparency = 0.7
							highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
							highlight.Parent = obj
							Debris:AddItem(highlight, 15)
						end

						task.delay(15, function()
							if damageBoost and damageBoost.Parent then
								damageBoost.Value = 1
							end
						end)
					end
				end
			end
		end,
		duration = 15,
		weight = 15,
	},
	RepairKit = {
		name = "Repair Kit",
		description = "Heal all your structures 50%",
		color = Color3.fromRGB(100, 255, 100),
		effect = function(player)
			for _, obj in ipairs(workspace:GetChildren()) do
				if obj:FindFirstChild("Owner") and obj.Owner.Value == player.Name then
					local health = obj:FindFirstChild("Health")
					local maxHealth = obj:FindFirstChild("MaxHealth")
					if health and maxHealth then
						local healAmount = maxHealth.Value * 0.5
						health.Value = math.min(health.Value + healAmount, maxHealth.Value)

						-- Visual heal effect
						local part = obj:IsA("Model") and obj.PrimaryPart or obj
						if part then
							local particles = Instance.new("ParticleEmitter")
							particles.Color = ColorSequence.new(Color3.fromRGB(100, 255, 100))
							particles.Size = NumberSequence.new(0.5, 0)
							particles.Lifetime = NumberRange.new(0.5, 1)
							particles.Rate = 20
							particles.Speed = NumberRange.new(2, 4)
							particles.SpreadAngle = Vector2.new(180, 180)
							particles.Parent = part

							task.delay(0.5, function()
								particles.Enabled = false
								Debris:AddItem(particles, 1)
							end)
						end
					end
				end
			end
		end,
		duration = 0,
		weight = 15,
	},
	FreezeBomb = {
		name = "Freeze Bomb",
		description = "Freeze all Kodos for 4s",
		color = Color3.fromRGB(150, 200, 255),
		effect = function(player)
			-- Freeze all Kodos
			for _, obj in ipairs(workspace:GetChildren()) do
				if obj:FindFirstChild("Humanoid") and obj:FindFirstChild("KodoType") then
					local humanoid = obj.Humanoid
					local originalSpeed = humanoid.WalkSpeed
					humanoid.WalkSpeed = 0

					-- Ice visual
					local rootPart = obj:FindFirstChild("HumanoidRootPart")
					if rootPart then
						local ice = Instance.new("Part")
						ice.Size = Vector3.new(6, 6, 6)
						ice.Transparency = 0.5
						ice.Color = Color3.fromRGB(200, 230, 255)
						ice.Material = Enum.Material.Ice
						ice.CanCollide = false
						ice.Anchored = true
						ice.Position = rootPart.Position
						ice.Parent = workspace
						Debris:AddItem(ice, 4)
					end

					task.delay(4, function()
						if humanoid and humanoid.Parent then
							humanoid.WalkSpeed = originalSpeed
						end
					end)
				end
			end
		end,
		duration = 4,
		weight = 10,
	},
}

-- Remote events
local powerUpCollected = Instance.new("RemoteEvent")
powerUpCollected.Name = "PowerUpCollected"
powerUpCollected.Parent = ReplicatedStorage

local powerUpSpawned = Instance.new("RemoteEvent")
powerUpSpawned.Name = "PowerUpSpawned"
powerUpSpawned.Parent = ReplicatedStorage

-- Track active power-ups
local activePowerUps = {}

-- Get spawn locations to avoid
local function getSpawnLocations()
	local spawns = {}
	local gameArea = workspace:FindFirstChild("GameArea")
	if gameArea then
		local spawnLocations = gameArea:FindFirstChild("SpawnLocations")
		if spawnLocations then
			for _, spawn in ipairs(spawnLocations:GetChildren()) do
				if spawn:IsA("BasePart") then
					table.insert(spawns, spawn.Position)
				end
			end
		end
	end
	return spawns
end

-- Get a random power-up based on weights
local function getRandomPowerUp()
	local totalWeight = 0
	for _, data in pairs(POWERUPS) do
		totalWeight = totalWeight + data.weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for name, data in pairs(POWERUPS) do
		cumulative = cumulative + data.weight
		if roll <= cumulative then
			return name, data
		end
	end

	-- Fallback
	return "GoldRush", POWERUPS.GoldRush
end

-- Find a valid spawn position
local function findSpawnPosition()
	local spawnLocations = getSpawnLocations()
	local center = Vector3.new(0, 0, 0)

	-- Calculate center from spawns if available
	if #spawnLocations > 0 then
		local total = Vector3.new(0, 0, 0)
		for _, pos in ipairs(spawnLocations) do
			total = total + pos
		end
		center = total / #spawnLocations
	end

	-- Try to find a valid position
	for attempt = 1, 20 do
		local angle = math.random() * math.pi * 2
		local distance = math.random() * SPAWN_RADIUS
		local x = center.X + math.cos(angle) * distance
		local z = center.Z + math.sin(angle) * distance
		local position = Vector3.new(x, 5, z)

		-- Check distance from player spawns
		local tooClose = false
		for _, spawnPos in ipairs(spawnLocations) do
			if (Vector3.new(position.X, 0, position.Z) - Vector3.new(spawnPos.X, 0, spawnPos.Z)).Magnitude < MIN_SPAWN_DISTANCE then
				tooClose = true
				break
			end
		end

		if not tooClose then
			-- Raycast to find ground
			local rayOrigin = Vector3.new(x, 50, z)
			local rayDirection = Vector3.new(0, -100, 0)
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = {}

			local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
			if result then
				return Vector3.new(x, result.Position.Y + 3, z)
			else
				return Vector3.new(x, 3, z)
			end
		end
	end

	-- Fallback to center area
	return Vector3.new(center.X + math.random(-20, 20), 3, center.Z + math.random(-20, 20))
end

-- Create power-up visual
local function createPowerUp(powerUpName, data, position)
	local powerUp = Instance.new("Part")
	powerUp.Name = "PowerUp_" .. powerUpName
	powerUp.Size = Vector3.new(2, 2, 2)
	powerUp.Position = position
	powerUp.Anchored = true
	powerUp.CanCollide = false
	powerUp.Shape = Enum.PartType.Ball
	powerUp.Color = data.color
	powerUp.Material = Enum.Material.Neon
	powerUp.Parent = workspace

	-- Store power-up type
	local typeValue = Instance.new("StringValue")
	typeValue.Name = "PowerUpType"
	typeValue.Value = powerUpName
	typeValue.Parent = powerUp

	-- Add glow effect
	local light = Instance.new("PointLight")
	light.Color = data.color
	light.Brightness = 2
	light.Range = 12
	light.Parent = powerUp

	-- Add particle effect
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(data.color)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Rate = 15
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = powerUp

	-- Add billboard with name
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = powerUp

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.name
	nameLabel.TextColor3 = data.color
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Parent = billboard

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, 0, 0.5, 0)
	descLabel.Position = UDim2.new(0, 0, 0.5, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = data.description
	descLabel.TextColor3 = Color3.new(1, 1, 1)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 11
	descLabel.TextStrokeTransparency = 0.5
	descLabel.Parent = billboard

	-- Floating animation
	local originalY = position.Y
	local floatConnection
	local time = 0
	floatConnection = RunService.Heartbeat:Connect(function(dt)
		if not powerUp.Parent then
			floatConnection:Disconnect()
			return
		end
		time = time + dt
		powerUp.Position = Vector3.new(position.X, originalY + math.sin(time * 2) * 0.5, position.Z)
		powerUp.Orientation = Vector3.new(0, time * 50, 0)
	end)

	-- Touch detection
	local touchDebounce = false
	powerUp.Touched:Connect(function(hit)
		if touchDebounce then return end

		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)

		if player then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				touchDebounce = true

				-- Apply effect
				data.effect(player)

				-- Notify clients
				powerUpCollected:FireAllClients(player.Name, powerUpName, data.name, data.color, data.duration)

				-- Remove from tracking
				activePowerUps[powerUp] = nil

				-- Collection effect
				local explosion = Instance.new("Part")
				explosion.Size = Vector3.new(1, 1, 1)
				explosion.Position = powerUp.Position
				explosion.Anchored = true
				explosion.CanCollide = false
				explosion.Transparency = 0.5
				explosion.Color = data.color
				explosion.Material = Enum.Material.Neon
				explosion.Shape = Enum.PartType.Ball
				explosion.Parent = workspace

				local tween = TweenService:Create(explosion, TweenInfo.new(0.3), {
					Size = Vector3.new(8, 8, 8),
					Transparency = 1
				})
				tween:Play()
				Debris:AddItem(explosion, 0.5)

				-- Destroy power-up
				floatConnection:Disconnect()
				powerUp:Destroy()

				print("PowerUp: " .. player.Name .. " collected " .. data.name)
			end
		end
	end)

	-- Track and auto-despawn
	activePowerUps[powerUp] = true

	task.delay(DESPAWN_TIME, function()
		if powerUp.Parent then
			activePowerUps[powerUp] = nil

			-- Fade out
			local tween = TweenService:Create(powerUp, TweenInfo.new(1), {
				Transparency = 1
			})
			tween:Play()
			tween.Completed:Wait()

			floatConnection:Disconnect()
			powerUp:Destroy()
		end
	end)

	-- Notify clients
	powerUpSpawned:FireAllClients(powerUpName, data.name, position, data.color)

	return powerUp
end

-- Count active power-ups
local function countActivePowerUps()
	local count = 0
	for powerUp, _ in pairs(activePowerUps) do
		if powerUp.Parent then
			count = count + 1
		else
			activePowerUps[powerUp] = nil
		end
	end
	return count
end

-- Spawn loop
local function startSpawning()
	while true do
		task.wait(SPAWN_INTERVAL)

		-- Check if we can spawn more
		if countActivePowerUps() < MAX_POWERUPS then
			local powerUpName, data = getRandomPowerUp()
			local position = findSpawnPosition()
			createPowerUp(powerUpName, data, position)
			print("PowerUp: Spawned " .. data.name .. " at " .. tostring(position))
		end
	end
end

-- Wait for round to start, then begin spawning
local roundStarted = ReplicatedStorage:WaitForChild("RoundStarted", 30)
if roundStarted then
	roundStarted.OnServerEvent:Connect(function()
		-- Clear any existing power-ups
		for powerUp, _ in pairs(activePowerUps) do
			if powerUp.Parent then
				powerUp:Destroy()
			end
		end
		activePowerUps = {}
	end)
end

-- Start spawning after a delay
task.delay(10, function()
	startSpawning()
end)

print("PowerUpManager: Loaded!")
