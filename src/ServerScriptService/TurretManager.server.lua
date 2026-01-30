local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run on game servers (reserved servers)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("TurretManager: Lobby server - disabled")
	return
end

local TurretManager = {}
TurretManager.activeTurrets = {}

-- Turret stats
local TURRET_STATS = {
	Turret = {
		damage = 50,
		fireRate = 0.5,
		range = 50,
		projectileSpeed = 100,
		projectileColor = Color3.new(1, 0.8, 0)
	},
	FastTurret = {
		damage = 40,
		fireRate = 0.2,
		range = 40,
		projectileSpeed = 120,
		projectileColor = Color3.new(0, 1, 1)
	},
	SlowTurret = {
		damage = 60,
		fireRate = 1.0,
		range = 60,
		projectileSpeed = 80,
		projectileColor = Color3.new(1, 0, 0)
	},
	FrostTurret = {
		damage = 20,
		fireRate = 0.8,
		range = 45,
		projectileSpeed = 90,
		projectileColor = Color3.new(0.5, 0.8, 1),
		specialEffect = "frost",
		slowAmount = 0.5, -- 50% speed reduction
		slowDuration = 3
	},
	PoisonTurret = {
		damage = 15,
		fireRate = 1.0,
		range = 50,
		projectileSpeed = 80,
		projectileColor = Color3.new(0.2, 0.8, 0.2),
		specialEffect = "poison",
		poisonDamage = 10,
		poisonDuration = 5,
		poisonTickRate = 1
	},
	MultiShotTurret = {
		damage = 25,
		fireRate = 0.6,
		range = 40,
		projectileSpeed = 110,
		projectileColor = Color3.new(1, 0.5, 0),
		specialEffect = "multishot",
		projectileCount = 3
	},
	CannonTurret = {
		damage = 80,
		fireRate = 2.0,
		range = 55,
		projectileSpeed = 60,
		projectileColor = Color3.new(0.3, 0.3, 0.3),
		specialEffect = "aoe",
		aoeRadius = 15,
		aoeDamageFalloff = 0.5 -- enemies at edge take 50% damage
	}
}

-- Track active effects on enemies
local activeEffects = {
	frost = {}, -- [kodo] = endTime
	poison = {} -- [kodo] = {endTime, nextTickTime, damage}
}

-- Create muzzle flash effect
local function createMuzzleFlash(turret, color)
	local base = turret:IsA("Model") and turret.PrimaryPart or turret
	if not base then return end

	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1, 1, 1)
	flash.Material = Enum.Material.Neon
	flash.Color = color or Color3.new(1, 1, 0)
	flash.Anchored = true
	flash.CanCollide = false
	flash.CFrame = base.CFrame * CFrame.new(0, 2, -2)
	flash.Parent = workspace

	task.spawn(function()
		wait(0.1)
		flash:Destroy()
	end)
end

-- Apply frost effect (slow)
local function applyFrostEffect(target, stats)
	local humanoid = target:FindFirstChild("Humanoid")
	if not humanoid then return end

	local originalSpeed = humanoid.WalkSpeed
	local currentTime = tick()
	local endTime = currentTime + stats.slowDuration

	-- Check if already frosted
	if activeEffects.frost[target] and activeEffects.frost[target] > currentTime then
		-- Extend duration instead
		activeEffects.frost[target] = endTime
		return
	end

	activeEffects.frost[target] = endTime
	humanoid.WalkSpeed = originalSpeed * stats.slowAmount

	-- Visual frost effect
	local frostEffect = Instance.new("Part")
	frostEffect.Name = "FrostEffect"
	frostEffect.Shape = Enum.PartType.Ball
	frostEffect.Size = Vector3.new(4, 4, 4)
	frostEffect.Material = Enum.Material.Ice
	frostEffect.Color = Color3.new(0.5, 0.8, 1)
	frostEffect.Transparency = 0.7
	frostEffect.Anchored = false
	frostEffect.CanCollide = false
	frostEffect.Parent = target

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = frostEffect
	weld.Part1 = target:FindFirstChild("HumanoidRootPart")
	weld.Parent = frostEffect

	if target:FindFirstChild("HumanoidRootPart") then
		frostEffect.CFrame = target.HumanoidRootPart.CFrame
	end

	task.spawn(function()
		wait(stats.slowDuration)
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
		end
		activeEffects.frost[target] = nil
		if frostEffect and frostEffect.Parent then
			frostEffect:Destroy()
		end
	end)

	print("TurretManager: Applied frost to", target.Name, "for", stats.slowDuration, "seconds")
end

-- Apply poison effect (DoT)
local function applyPoisonEffect(target, stats)
	local humanoid = target:FindFirstChild("Humanoid")
	if not humanoid then return end

	local currentTime = tick()
	local endTime = currentTime + stats.poisonDuration

	-- Check if already poisoned - refresh duration
	if activeEffects.poison[target] then
		activeEffects.poison[target].endTime = endTime
		return
	end

	activeEffects.poison[target] = {
		endTime = endTime,
		nextTickTime = currentTime + stats.poisonTickRate,
		damage = stats.poisonDamage
	}

	-- Visual poison effect
	local poisonEffect = Instance.new("ParticleEmitter")
	poisonEffect.Name = "PoisonEffect"
	poisonEffect.Color = ColorSequence.new(Color3.new(0.2, 0.8, 0.2))
	poisonEffect.Size = NumberSequence.new(0.5)
	poisonEffect.Rate = 20
	poisonEffect.Lifetime = NumberRange.new(0.5, 1)
	poisonEffect.Speed = NumberRange.new(2, 4)
	poisonEffect.SpreadAngle = Vector2.new(180, 180)

	local hrp = target:FindFirstChild("HumanoidRootPart")
	if hrp then
		poisonEffect.Parent = hrp
	end

	task.spawn(function()
		while activeEffects.poison[target] and tick() < activeEffects.poison[target].endTime do
			if tick() >= activeEffects.poison[target].nextTickTime then
				if humanoid and humanoid.Health > 0 then
					local newHealth = humanoid.Health - stats.poisonDamage
					if newHealth <= 0 then
						humanoid.Health = 0
						print("TurretManager: Kodo killed by poison!")
					else
						humanoid.Health = newHealth
					end
					print("TurretManager: Poison tick dealt", stats.poisonDamage, "damage")
				end
				activeEffects.poison[target].nextTickTime = tick() + stats.poisonTickRate
			end
			wait(0.1)
		end
		activeEffects.poison[target] = nil
		if poisonEffect and poisonEffect.Parent then
			poisonEffect:Destroy()
		end
	end)

	print("TurretManager: Applied poison to", target.Name, "for", stats.poisonDuration, "seconds")
end

-- Apply AOE damage
local function applyAOEDamage(position, stats)
	local kodoList = {}

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name:match("Kodo") and obj:FindFirstChild("Humanoid") then
			local humanoid = obj:FindFirstChild("Humanoid")
			if humanoid.Health > 0 then
				local kodoRoot = obj:FindFirstChild("HumanoidRootPart")
				if kodoRoot then
					local distance = (kodoRoot.Position - position).Magnitude
					if distance <= stats.aoeRadius then
						table.insert(kodoList, {kodo = obj, distance = distance})
					end
				end
			end
		end
	end

	-- Deal damage to all in range
	for _, kodoData in ipairs(kodoList) do
		local humanoid = kodoData.kodo:FindFirstChild("Humanoid")
		if humanoid then
			-- Calculate damage falloff
			local falloff = 1 - (kodoData.distance / stats.aoeRadius) * (1 - stats.aoeDamageFalloff)
			local damage = math.floor(stats.damage * falloff)

			local newHealth = humanoid.Health - damage
			if newHealth <= 0 then
				humanoid.Health = 0
				print("TurretManager: Kodo killed by AOE!")
			else
				humanoid.Health = newHealth
			end
			print("TurretManager: AOE dealt", damage, "damage to", kodoData.kodo.Name)
		end
	end

	-- AOE visual effect
	local aoeEffect = Instance.new("Part")
	aoeEffect.Shape = Enum.PartType.Cylinder
	aoeEffect.Size = Vector3.new(1, stats.aoeRadius * 2, stats.aoeRadius * 2)
	aoeEffect.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	aoeEffect.Material = Enum.Material.Neon
	aoeEffect.Color = Color3.new(1, 0.3, 0)
	aoeEffect.Transparency = 0.5
	aoeEffect.Anchored = true
	aoeEffect.CanCollide = false
	aoeEffect.Parent = workspace

	task.spawn(function()
		for i = 1, 15 do
			aoeEffect.Transparency = 0.5 + (i / 15) * 0.5
			wait(0.03)
		end
		aoeEffect:Destroy()
	end)

	return #kodoList
end

-- Create and fire a single projectile
local function fireSingleProjectile(turret, target, stats, offset)
	local base = turret:IsA("Model") and turret.PrimaryPart or turret
	if not base then return end

	local targetPos = target:FindFirstChild("HumanoidRootPart")
	if not targetPos then return end

	offset = offset or Vector3.new(0, 0, 0)

	-- Cannon turrets have bigger projectiles
	local bulletSize = stats.specialEffect == "aoe" and Vector3.new(1.5, 1.5, 1.5) or Vector3.new(0.5, 0.5, 0.5)

	-- Create bullet
	local bullet = Instance.new("Part")
	bullet.Name = "Bullet"
	bullet.Shape = Enum.PartType.Ball
	bullet.Size = bulletSize
	bullet.Material = Enum.Material.Neon
	bullet.Color = stats.projectileColor
	bullet.Anchored = true
	bullet.CanCollide = false
	bullet.CFrame = base.CFrame * CFrame.new(0 + offset.X, 2 + offset.Y, 0 + offset.Z)
	bullet.Parent = workspace

	-- Add trail
	local attachment0 = Instance.new("Attachment", bullet)
	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment0
	trail.Lifetime = 0.2
	trail.Color = ColorSequence.new(stats.projectileColor)
	trail.Parent = bullet

	-- Move bullet toward target
	task.spawn(function()
		local startPos = bullet.Position
		local endPos = targetPos.Position + offset * 2
		local distance = (endPos - startPos).Magnitude
		local duration = distance / stats.projectileSpeed
		local startTime = tick()

		while tick() - startTime < duration do
			if not bullet or not bullet.Parent then break end
			if not target or not target.Parent then
				bullet:Destroy()
				break
			end

			local progress = (tick() - startTime) / duration
			endPos = targetPos.Position + offset * 2
			bullet.CFrame = CFrame.new(startPos:Lerp(endPos, progress))

			wait()
		end

		-- Hit target
		if bullet and bullet.Parent and target and target.Parent then
			local impactPosition = bullet.Position

			-- Handle AOE damage specially
			if stats.specialEffect == "aoe" then
				applyAOEDamage(impactPosition, stats)
			else
				-- Normal damage
				local humanoid = target:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health > 0 then
					local newHealth = humanoid.Health - stats.damage
					print("TurretManager: Dealt", stats.damage, "damage to Kodo. Health:", humanoid.Health, "->", newHealth)

					if newHealth <= 0 then
						humanoid.Health = 0
						print("TurretManager: Kodo killed!")
					else
						humanoid.Health = newHealth
					end

					-- Apply special effects
					if stats.specialEffect == "frost" then
						applyFrostEffect(target, stats)
					elseif stats.specialEffect == "poison" then
						applyPoisonEffect(target, stats)
					end
				end
			end

			-- Impact effect with color matching turret type
			local impactColor = stats.projectileColor
			if stats.specialEffect == "aoe" then
				impactColor = Color3.new(1, 0.3, 0)
			end

			local impact = Instance.new("Part")
			impact.Shape = Enum.PartType.Ball
			impact.Size = stats.specialEffect == "aoe" and Vector3.new(3, 3, 3) or Vector3.new(1.5, 1.5, 1.5)
			impact.Material = Enum.Material.Neon
			impact.Color = impactColor
			impact.Anchored = true
			impact.CanCollide = false
			impact.CFrame = bullet.CFrame
			impact.Parent = workspace

			task.spawn(function()
				for i = 1, 10 do
					impact.Transparency = i / 10
					impact.Size = impact.Size + Vector3.new(0.2, 0.2, 0.2)
					wait(0.02)
				end
				impact:Destroy()
			end)
		end

		if bullet and bullet.Parent then
			bullet:Destroy()
		end
	end)
end

-- Create and fire projectile(s)
local function fireProjectile(turret, target, stats)
	-- Muzzle flash
	createMuzzleFlash(turret, stats.projectileColor)

	-- Multi-shot fires multiple projectiles
	if stats.specialEffect == "multishot" then
		local count = stats.projectileCount or 3
		local spread = 2 -- spread distance

		for i = 1, count do
			local offsetX = (i - (count + 1) / 2) * spread
			local offset = Vector3.new(offsetX, 0, 0)
			fireSingleProjectile(turret, target, stats, offset)
		end
	else
		fireSingleProjectile(turret, target, stats, nil)
	end
end

-- Find nearest Kodo in range
local function findNearestKodo(turretPosition, range)
	local nearestKodo = nil
	local nearestDistance = range

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name:match("Kodo") and obj:FindFirstChild("Humanoid") then
			local humanoid = obj:FindFirstChild("Humanoid")
			if humanoid.Health > 0 then
				local kodoRoot = obj:FindFirstChild("HumanoidRootPart")
				if kodoRoot then
					local distance = (kodoRoot.Position - turretPosition).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestKodo = obj
					end
				end
			end
		end
	end

	return nearestKodo
end

-- Get modified stats based on owner's upgrades
local function getModifiedStats(baseStats, ownerName)
	local modifiedStats = {}

	-- Copy base stats
	for key, value in pairs(baseStats) do
		modifiedStats[key] = value
	end

	-- Apply upgrades if UpgradeManager is available
	if _G.UpgradeManager and ownerName then
		-- Enhanced Damage upgrade
		local damageBonus = _G.UpgradeManager.getUpgradeEffect(ownerName, "EnhancedDamage")
		modifiedStats.damage = math.floor(baseStats.damage * (1 + damageBonus))

		-- Rapid Fire upgrade (reduces fire rate = faster shooting)
		local fireRateBonus = _G.UpgradeManager.getUpgradeEffect(ownerName, "RapidFire")
		modifiedStats.fireRate = baseStats.fireRate * (1 - fireRateBonus)
		modifiedStats.fireRate = math.max(modifiedStats.fireRate, 0.1) -- Minimum 0.1s

		-- Extended Range upgrade
		local rangeBonus = _G.UpgradeManager.getUpgradeEffect(ownerName, "ExtendedRange")
		modifiedStats.range = math.floor(baseStats.range * (1 + rangeBonus))

		print("TurretManager: Modified stats for", ownerName, "- Damage:", modifiedStats.damage, "FireRate:", modifiedStats.fireRate, "Range:", modifiedStats.range)
	end

	return modifiedStats
end

-- Activate turret
function TurretManager.activateTurret(turret, ownerName)
	local turretName = turret.Name
	local baseStats = TURRET_STATS[turretName]

	if not baseStats then
		warn("TurretManager: Unknown turret type:", turretName)
		return
	end

	-- Get modified stats based on owner's upgrades
	local stats = getModifiedStats(baseStats, ownerName)

	local turretPosition = turret:IsA("Model") and turret.PrimaryPart.Position or turret.Position

	table.insert(TurretManager.activeTurrets, turret)
	print("TurretManager: Activated", turretName, "for", ownerName)

	-- Shooting loop
	task.spawn(function()
		while turret and turret.Parent do
			-- Re-fetch modified stats each shot to pick up upgrades purchased mid-game
			local currentStats = getModifiedStats(baseStats, ownerName)
			local target = findNearestKodo(turretPosition, currentStats.range)

			if target then
				fireProjectile(turret, target, currentStats)
			end

			wait(currentStats.fireRate)
		end
	end)
end

-- Setup remote event
local activateTurretEvent = ReplicatedStorage:FindFirstChild("ActivateTurret")
if not activateTurretEvent then
	activateTurretEvent = Instance.new("BindableEvent")
	activateTurretEvent.Name = "ActivateTurret"
	activateTurretEvent.Parent = ReplicatedStorage
end

activateTurretEvent.Event:Connect(function(turret, ownerName)
	TurretManager.activateTurret(turret, ownerName)
end)

print("TurretManager loaded with projectile system!")

return TurretManager