-- SOUND HANDLER
-- Client-side script that plays sounds for game events

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

-- Sound IDs
local SOUNDS = {
	-- Turrets
	turret_shoot = "rbxassetid://1905364532",
	turret_heavy = "rbxassetid://168586621",
	turret_frost = "rbxassetid://2785493",
	turret_cannon = "rbxassetid://168513088",

	-- Kodos
	kodo_hit = "rbxassetid://3932505313",
	kodo_death = "rbxassetid://2801263",

	-- Building
	build_place = "rbxassetid://3398628452",
	build_destroy = "rbxassetid://5743125871",

	-- Pickups/Gold
	gold_pickup = "rbxassetid://138081500",
	powerup_pickup = "rbxassetid://6042053626",

	-- Player
	player_death = "rbxassetid://5743125871",

	-- Round
	round_start = "rbxassetid://1837390508",
	wave_warning = "rbxassetid://1837390508",

	-- Abilities
	ability_use = "rbxassetid://6042053626",
}

-- Create sound folder
local soundFolder = Instance.new("Folder")
soundFolder.Name = "GameSounds"
soundFolder.Parent = SoundService

-- Play a 2D sound (same volume everywhere)
local function playSound(soundId, volume, pitch)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = soundFolder
	sound:Play()
	Debris:AddItem(sound, 5)
	return sound
end

-- Play a 3D sound at position
local function playSound3D(soundId, position, volume, pitch)
	-- Don't play if too far from player
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local distance = (position - rootPart.Position).Magnitude
	if distance > 150 then return end  -- Too far to hear

	-- Create temporary part for 3D sound
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = workspace
	Debris:AddItem(part, 3)

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 100
	sound.Parent = part
	sound:Play()

	return sound
end

-- Track turrets and projectiles for sound effects
local trackedProjectiles = {}

-- Watch for new projectiles (turret bullets)
workspace.ChildAdded:Connect(function(child)
	-- Turret projectiles
	if child.Name == "TurretBullet" and child:IsA("BasePart") then
		-- Determine turret type from projectile color
		local color = child.Color
		local soundId = SOUNDS.turret_shoot
		local pitch = 1 + (math.random() - 0.5) * 0.2

		-- Frost turret (blue-ish)
		if color.B > 0.7 and color.R < 0.6 then
			soundId = SOUNDS.turret_frost
			pitch = 1.2
		-- Cannon (large projectile check done by size)
		elseif child.Size.X > 1 then
			soundId = SOUNDS.turret_cannon
			pitch = 0.8
		end

		playSound3D(soundId, child.Position, 0.3, pitch)
	end
end)

-- Listen for Kodo damage/death
workspace.ChildAdded:Connect(function(child)
	if child:IsA("Model") and child:FindFirstChild("KodoType") then
		-- New Kodo spawned - watch for death
		local humanoid = child:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.Died:Connect(function()
				local rootPart = child:FindFirstChild("HumanoidRootPart")
				if rootPart then
					playSound3D(SOUNDS.kodo_death, rootPart.Position, 0.5, 0.9 + math.random() * 0.2)
				end
			end)
		end
	end
end)

-- Listen for structure placement
workspace.ChildAdded:Connect(function(child)
	-- Check if it's a structure
	local owner = child:FindFirstChild("Owner")
	if owner and owner.Value == player.Name then
		local pos
		if child:IsA("Model") and child.PrimaryPart then
			pos = child.PrimaryPart.Position
		elseif child:IsA("BasePart") then
			pos = child.Position
		end

		if pos then
			playSound3D(SOUNDS.build_place, pos, 0.5, 1)
		end
	end
end)

-- Listen for structure destruction
workspace.ChildRemoved:Connect(function(child)
	-- Check if it was a structure
	local wasStructure = child:FindFirstChild("Health") or child:FindFirstChild("Owner")
	if wasStructure then
		-- Can't get position after removal, so just play 2D
		-- playSound(SOUNDS.build_destroy, 0.4, 1)
	end
end)

-- Listen for remote events
local powerUpCollected = ReplicatedStorage:WaitForChild("PowerUpCollected", 5)
if powerUpCollected then
	powerUpCollected.OnClientEvent:Connect(function(collectorName)
		if collectorName == player.Name then
			playSound(SOUNDS.powerup_pickup, 0.5, 1)
		end
	end)
end

local veinSpawned = ReplicatedStorage:FindFirstChild("VeinSpawned")
if veinSpawned then
	veinSpawned.OnClientEvent:Connect(function(position, goldAmount)
		playSound3D(SOUNDS.gold_pickup, position, 0.4, 1.2)
	end)
end

local roundStarted = ReplicatedStorage:FindFirstChild("RoundStarted")
if roundStarted then
	roundStarted.OnClientEvent:Connect(function()
		playSound(SOUNDS.round_start, 0.6, 1)
	end)
end

local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
if showNotification then
	showNotification.OnClientEvent:Connect(function(message)
		-- Wave warnings
		if message and message:find("Wave") then
			playSound(SOUNDS.wave_warning, 0.4, 1.2)
		end
	end)
end

local showGameOver = ReplicatedStorage:FindFirstChild("ShowGameOver")
if showGameOver then
	showGameOver.OnClientEvent:Connect(function()
		playSound(SOUNDS.player_death, 0.6, 0.8)
	end)
end

-- Death abilities
local deathAbilityUsed = ReplicatedStorage:FindFirstChild("DeathAbilityUsed")
if deathAbilityUsed then
	deathAbilityUsed.OnClientEvent:Connect(function()
		playSound(SOUNDS.ability_use, 0.5, 1)
	end)
end

-- Player death sound
player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			playSound(SOUNDS.player_death, 0.5, 1)
		end)
	end
end)

-- Mining sounds
local lastMiningSound = 0
local mineGoldEvent = ReplicatedStorage:FindFirstChild("MineGold")
-- Mining is client-to-server, so we watch for gold updates instead
local updatePlayerStats = ReplicatedStorage:FindFirstChild("UpdatePlayerStats")
if updatePlayerStats then
	local lastGold = 0
	updatePlayerStats.OnClientEvent:Connect(function(stats)
		if stats[player.Name] then
			local currentGold = stats[player.Name].gold or 0
			if currentGold > lastGold and lastGold > 0 then
				local now = tick()
				if now - lastMiningSound > 0.3 then
					playSound(SOUNDS.gold_pickup, 0.3, 1 + math.random() * 0.2)
					lastMiningSound = now
				end
			end
			lastGold = currentGold
		end
	end)
end

print("SoundHandler: Loaded")
