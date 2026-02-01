local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Only run on game servers (reserved servers)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("TurretManager: Lobby server - disabled")
	return
end

local TurretManager = {}
TurretManager.activeTurrets = {}
TurretManager.turretRotations = {} -- Track current turret facing directions

-- Create damage number event
local showDamageNumber = Instance.new("RemoteEvent")
showDamageNumber.Name = "ShowDamageNumber"
showDamageNumber.Parent = ReplicatedStorage

-- Load KodoAI for damage multipliers
local KodoAI = require(script.Parent.KodoAI)

-- Map turret types to damage categories for resistance calculations
local TURRET_DAMAGE_TYPES = {
	Turret = "physical",
	FastTurret = "physical",
	SlowTurret = "physical",
	FrostTurret = "frost",
	PoisonTurret = "poison",
	MultiShotTurret = "multishot",
	CannonTurret = "aoe"
}

-- Turret stats with damage types for resistance calculations
local TURRET_STATS = {
	Turret = {
		damage = 15,
		fireRate = 0.8,
		range = 40,
		projectileSpeed = 100,
		projectileColor = Color3.new(1, 0.8, 0),
		damageType = "physical"
	},
	FastTurret = {
		damage = 8,
		fireRate = 0.25,
		range = 35,
		projectileSpeed = 120,
		projectileColor = Color3.new(0, 1, 1),
		damageType = "physical"
	},
	SlowTurret = {
		damage = 35,
		fireRate = 1.5,
		range = 50,
		projectileSpeed = 80,
		projectileColor = Color3.new(1, 0, 0),
		damageType = "physical"
	},
	FrostTurret = {
		damage = 10,
		fireRate = 1.0,
		range = 40,
		projectileSpeed = 90,
		projectileColor = Color3.new(0.3, 0.6, 1), -- Blue projectile
		damageType = "frost",
		specialEffect = "frost",
		slowAmount = 0.7, -- 30% speed reduction (0.7 = 70% of original speed)
		slowDuration = 3.0
	},
	PoisonTurret = {
		damage = 8,
		fireRate = 1.2,
		range = 45,
		projectileSpeed = 80,
		projectileColor = Color3.new(0.2, 0.8, 0.2),
		damageType = "poison",
		specialEffect = "poison",
		poisonDamage = 5,
		poisonDuration = 6,
		poisonTickRate = 1
	},
	MultiShotTurret = {
		damage = 10,
		fireRate = 0.8,
		range = 35,
		projectileSpeed = 110,
		projectileColor = Color3.new(1, 0.5, 0),
		damageType = "multishot",
		specialEffect = "multishot",
		projectileCount = 3
	},
	CannonTurret = {
		damage = 50,
		fireRate = 2.5,
		range = 45,
		projectileSpeed = 60,
		projectileColor = Color3.new(0.3, 0.3, 0.3),
		damageType = "aoe",
		specialEffect = "aoe",
		aoeRadius = 12,
		aoeDamageFalloff = 0.5 -- enemies at edge take 50% damage
	}
}

-- Track active effects on enemies
local activeEffects = {
	frost = {}, -- [kodo] = endTime
	poison = {} -- [kodo] = {endTime, nextTickTime, damage}
}

-- Get the turret's shoot position (top center of turret)
local function getTurretShootPosition(turret)
	local base = turret:IsA("Model") and turret.PrimaryPart or turret
	if base then
		-- Shoot from top of turret
		return base.Position + Vector3.new(0, base.Size.Y / 2 + 1, 0)
	end
	return nil
end

-- Create muzzle flash effect
local function createMuzzleFlash(turret, color)
	local shootPos = getTurretShootPosition(turret)
	if not shootPos then return end

	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1.2, 1.2, 1.2)
	flash.Material = Enum.Material.Neon
	flash.Color = color or Color3.new(1, 1, 0)
	flash.Anchored = true
	flash.CanCollide = false
	flash.CFrame = CFrame.new(shootPos)
	flash.Parent = workspace

	-- Add point light for flash effect
	local light = Instance.new("PointLight")
	light.Color = color or Color3.new(1, 1, 0)
	light.Brightness = 3
	light.Range = 8
	light.Parent = flash

	task.spawn(function()
		-- Quick fade out
		for i = 1, 5 do
			flash.Transparency = i / 5
			flash.Size = flash.Size * 0.8
			light.Brightness = light.Brightness * 0.6
			wait(0.02)
		end
		flash:Destroy()
	end)
end

-- Apply frost effect (slow)
local function applyFrostEffect(target, stats, multiplier)
	local humanoid = target:FindFirstChild("Humanoid")
	if not humanoid then return end

	multiplier = multiplier or 1.0
	if multiplier == 0 then return end -- Immune

	local currentTime = tick()
	-- More effective slow on weak targets
	local effectiveDuration = stats.slowDuration * (multiplier > 1 and 1.5 or 1)
	local endTime = currentTime + effectiveDuration

	-- Check if already frosted - just extend duration
	if activeEffects.frost[target] then
		if activeEffects.frost[target].endTime > currentTime then
			activeEffects.frost[target].endTime = endTime
			return
		end
	end

	-- Store original speed and apply slow
	local originalSpeed = humanoid.WalkSpeed
	local slowAmount = stats.slowAmount
	if multiplier > 1 then
		slowAmount = slowAmount * 0.8 -- Even slower if weak to frost
	end
	humanoid.WalkSpeed = originalSpeed * slowAmount

	-- Create visual frost indicator (BillboardGui above head - no physics!)
	local hrp = target:FindFirstChild("HumanoidRootPart")
	local frostIndicator = nil

	if hrp then
		frostIndicator = Instance.new("BillboardGui")
		frostIndicator.Name = "FrostIndicator"
		frostIndicator.Size = UDim2.new(0, 50, 0, 20)
		frostIndicator.StudsOffset = Vector3.new(0, 4, 0)
		frostIndicator.AlwaysOnTop = true
		frostIndicator.Adornee = hrp
		frostIndicator.Parent = hrp

		local frostLabel = Instance.new("TextLabel")
		frostLabel.Size = UDim2.new(1, 0, 1, 0)
		frostLabel.BackgroundTransparency = 1
		frostLabel.Text = "SLOWED"
		frostLabel.TextColor3 = Color3.new(0.3, 0.7, 1)
		frostLabel.TextStrokeColor3 = Color3.new(0, 0, 0.3)
		frostLabel.TextStrokeTransparency = 0.3
		frostLabel.Font = Enum.Font.GothamBold
		frostLabel.TextScaled = true
		frostLabel.Parent = frostIndicator

		-- Add particle effect on HumanoidRootPart (no physics interference)
		local frostParticles = Instance.new("ParticleEmitter")
		frostParticles.Name = "FrostParticles"
		frostParticles.Color = ColorSequence.new(Color3.new(0.5, 0.8, 1))
		frostParticles.Size = NumberSequence.new(0.3, 0)
		frostParticles.Transparency = NumberSequence.new(0.3, 1)
		frostParticles.Lifetime = NumberRange.new(0.5, 1)
		frostParticles.Rate = 10
		frostParticles.Speed = NumberRange.new(1, 2)
		frostParticles.SpreadAngle = Vector2.new(180, 180)
		frostParticles.Parent = hrp

		-- Store particles reference for cleanup
		activeEffects.frost[target] = {
			endTime = endTime,
			originalSpeed = originalSpeed,
			indicator = frostIndicator,
			particles = frostParticles
		}
	else
		activeEffects.frost[target] = {
			endTime = endTime,
			originalSpeed = originalSpeed
		}
	end

	-- Cleanup after duration
	task.spawn(function()
		wait(effectiveDuration)
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = activeEffects.frost[target] and activeEffects.frost[target].originalSpeed or originalSpeed
		end
		if activeEffects.frost[target] then
			if activeEffects.frost[target].indicator then
				activeEffects.frost[target].indicator:Destroy()
			end
			if activeEffects.frost[target].particles then
				activeEffects.frost[target].particles:Destroy()
			end
		end
		activeEffects.frost[target] = nil
	end)

	print("TurretManager: Applied frost to", target.Name, "- 30% slow for", effectiveDuration, "seconds")
end

-- Apply poison effect (DoT)
local function applyPoisonEffect(target, stats, multiplier)
	local humanoid = target:FindFirstChild("Humanoid")
	if not humanoid then return end

	multiplier = multiplier or 1.0
	if multiplier == 0 then return end -- Immune

	local currentTime = tick()
	-- More effective duration on weak targets
	local effectiveDuration = stats.poisonDuration * (multiplier > 1 and 1.5 or 1)
	local endTime = currentTime + effectiveDuration

	-- Calculate effective damage
	local effectiveDamage = math.floor(stats.poisonDamage * multiplier)

	-- Check if already poisoned - refresh duration and use higher damage
	if activeEffects.poison[target] then
		activeEffects.poison[target].endTime = endTime
		activeEffects.poison[target].damage = math.max(activeEffects.poison[target].damage, effectiveDamage)
		return
	end

	activeEffects.poison[target] = {
		endTime = endTime,
		nextTickTime = currentTime + stats.poisonTickRate,
		damage = effectiveDamage
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

					-- Show damage number for poison tick
					local targetRoot = target:FindFirstChild("HumanoidRootPart")
					if targetRoot then
						showDamageNumber:FireAllClients(targetRoot.Position, stats.poisonDamage, "poison", false, false)
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
			local baseDamage = math.floor(stats.damage * falloff)

			-- Apply resistance multiplier
			local multiplier = KodoAI.getDamageMultiplier(kodoData.kodo, "aoe")
			local finalDamage = math.floor(baseDamage * multiplier)

			local newHealth = humanoid.Health - finalDamage
			if newHealth <= 0 then
				humanoid.Health = 0
				print("TurretManager: Kodo killed by AOE!")
			else
				humanoid.Health = newHealth
			end

			-- Show damage number
			local kodoRoot = kodoData.kodo:FindFirstChild("HumanoidRootPart")
			if kodoRoot then
				local isWeak = multiplier < 1
				local isStrong = multiplier > 1
				showDamageNumber:FireAllClients(kodoRoot.Position, finalDamage, "aoe", isWeak, isStrong)
			end

			local damageText = finalDamage .. (multiplier > 1 and " (Weak)" or (multiplier < 1 and " (Resist)" or ""))
			print("TurretManager: AOE dealt", damageText, "to", kodoData.kodo.Name)
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
	local shootPos = getTurretShootPosition(turret)
	if not shootPos then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	offset = offset or Vector3.new(0, 0, 0)

	-- Cannon turrets have bigger projectiles
	local bulletSize = stats.specialEffect == "aoe" and Vector3.new(1.5, 1.5, 1.5) or Vector3.new(0.6, 0.6, 0.6)

	-- Create bullet at turret's shoot position
	local bullet = Instance.new("Part")
	bullet.Name = "Bullet"
	bullet.Shape = Enum.PartType.Ball
	bullet.Size = bulletSize
	bullet.Material = Enum.Material.Neon
	bullet.Color = stats.projectileColor
	bullet.Anchored = true
	bullet.CanCollide = false
	bullet.CFrame = CFrame.new(shootPos + offset)
	bullet.Parent = workspace

	-- Add proper trail with two attachments at opposite ends
	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, 0, bulletSize.Z * 0.4)
	attachment0.Parent = bullet

	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, 0, -bulletSize.Z * 0.4)
	attachment1.Parent = bullet

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = 0.15
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, stats.projectileColor),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
	})
	trail.Parent = bullet

	-- Add glow effect to bullet
	local light = Instance.new("PointLight")
	light.Color = stats.projectileColor
	light.Brightness = 1.5
	light.Range = 4
	light.Parent = bullet

	-- Move bullet toward target
	task.spawn(function()
		local startPos = bullet.Position
		local endPos = targetRoot.Position + offset * 2
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
			endPos = targetRoot.Position + offset * 2
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
				-- Normal damage with resistance check
				local humanoid = target:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health > 0 then
					-- Get damage multiplier based on kodo type
					local damageType = stats.damageType or "physical"
					local multiplier = KodoAI.getDamageMultiplier(target, damageType)
					local finalDamage = math.floor(stats.damage * multiplier)

					-- Show resistance/weakness indicator
					local damageText = finalDamage
					if multiplier < 1 then
						damageText = damageText .. " (Resist)"
					elseif multiplier > 1 then
						damageText = damageText .. " (Weak)"
					end

					local newHealth = humanoid.Health - finalDamage
					print("TurretManager: Dealt", damageText, "to", target.Name, ". Health:", humanoid.Health, "->", math.max(0, newHealth))

					-- Show damage number to clients
					local targetRoot = target:FindFirstChild("HumanoidRootPart")
					if targetRoot then
						local isWeak = multiplier < 1
						local isStrong = multiplier > 1
						showDamageNumber:FireAllClients(targetRoot.Position, finalDamage, damageType, isWeak, isStrong)
					end

					if newHealth <= 0 then
						humanoid.Health = 0
						print("TurretManager: Kodo killed!")
					else
						humanoid.Health = newHealth
					end

					-- Apply special effects (frost effectiveness also affected)
					if stats.specialEffect == "frost" then
						if multiplier > 0 then -- Not immune
							applyFrostEffect(target, stats, multiplier)
						end
					elseif stats.specialEffect == "poison" then
						if multiplier > 0 then -- Not immune
							applyPoisonEffect(target, stats, multiplier)
						end
					end
				end
			end

			-- Impact effect with color matching turret type
			local impactColor = stats.projectileColor
			if stats.specialEffect == "aoe" then
				impactColor = Color3.new(1, 0.3, 0)
			end

			local impactPosition = bullet.Position

			-- Create impact flash
			local impact = Instance.new("Part")
			impact.Shape = Enum.PartType.Ball
			impact.Size = stats.specialEffect == "aoe" and Vector3.new(3, 3, 3) or Vector3.new(1.5, 1.5, 1.5)
			impact.Material = Enum.Material.Neon
			impact.Color = impactColor
			impact.Anchored = true
			impact.CanCollide = false
			impact.CFrame = bullet.CFrame
			impact.Parent = workspace

			-- Add impact light
			local impactLight = Instance.new("PointLight")
			impactLight.Color = impactColor
			impactLight.Brightness = 4
			impactLight.Range = 10
			impactLight.Parent = impact

			-- Create particle burst on impact
			local attachment = Instance.new("Attachment")
			attachment.Parent = impact

			local particles = Instance.new("ParticleEmitter")
			particles.Color = ColorSequence.new(impactColor)
			particles.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 0)
			})
			particles.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1)
			})
			particles.Lifetime = NumberRange.new(0.2, 0.4)
			particles.Rate = 0 -- We'll emit manually
			particles.Speed = NumberRange.new(8, 15)
			particles.SpreadAngle = Vector2.new(180, 180)
			particles.Parent = attachment

			-- Emit burst of particles
			particles:Emit(stats.specialEffect == "aoe" and 25 or 10)

			task.spawn(function()
				for i = 1, 10 do
					impact.Transparency = i / 10
					impact.Size = impact.Size + Vector3.new(0.3, 0.3, 0.3)
					impactLight.Brightness = impactLight.Brightness * 0.7
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
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

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

-- Get modified stats based on owner's upgrades and aura buffs
local function getModifiedStats(baseStats, ownerName, turret)
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
	end

	-- Apply aura buffs if AuraManager is available
	if _G.AuraManager and turret then
		-- Damage aura
		local damageAuraBonus = _G.AuraManager.getBuffBonus(turret, "damage")
		if damageAuraBonus > 0 then
			modifiedStats.damage = math.floor(modifiedStats.damage * (1 + damageAuraBonus))
		end

		-- Attack speed aura (reduces fire rate)
		local speedAuraBonus = _G.AuraManager.getBuffBonus(turret, "attackSpeed")
		if speedAuraBonus > 0 then
			modifiedStats.fireRate = modifiedStats.fireRate * (1 - speedAuraBonus)
			modifiedStats.fireRate = math.max(modifiedStats.fireRate, 0.1)
		end

		-- Range aura
		local rangeAuraBonus = _G.AuraManager.getBuffBonus(turret, "range")
		if rangeAuraBonus > 0 then
			modifiedStats.range = math.floor(modifiedStats.range * (1 + rangeAuraBonus))
		end
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

	-- Get modified stats based on owner's upgrades and auras
	local stats = getModifiedStats(baseStats, ownerName, turret)

	local turretPosition = turret:IsA("Model") and turret.PrimaryPart.Position or turret.Position

	table.insert(TurretManager.activeTurrets, turret)
	print("TurretManager: Activated", turretName, "for", ownerName)

	-- Shooting loop
	task.spawn(function()
		while turret and turret.Parent do
			-- Re-fetch modified stats each shot to pick up upgrades and aura changes
			local currentStats = getModifiedStats(baseStats, ownerName, turret)
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