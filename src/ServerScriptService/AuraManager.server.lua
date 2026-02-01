-- AURA MANAGER
-- Handles aura buildings that buff nearby structures

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Only run on game servers
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("AuraManager: Lobby server - disabled")
	return
end

local AuraManager = {}

-- Aura definitions
local AURA_TYPES = {
	SpeedAura = {
		name = "Speed Aura",
		description = "Nearby turrets attack 15% faster",
		range = 25,
		effect = "attackSpeed",
		bonus = 0.15, -- 15% faster
		color = Color3.fromRGB(255, 200, 50),
		cost = 150,
	},
	DamageAura = {
		name = "Damage Aura",
		description = "Nearby turrets deal 20% more damage",
		range = 25,
		effect = "damage",
		bonus = 0.20, -- 20% more damage
		color = Color3.fromRGB(255, 80, 80),
		cost = 200,
	},
	FortifyAura = {
		name = "Fortify Aura",
		description = "Nearby buildings have 30% more health",
		range = 30,
		effect = "health",
		bonus = 0.30, -- 30% more health
		color = Color3.fromRGB(100, 200, 255),
		cost = 175,
	},
	RangeAura = {
		name = "Range Aura",
		description = "Nearby turrets have 20% more range",
		range = 25,
		effect = "range",
		bonus = 0.20, -- 20% more range
		color = Color3.fromRGB(150, 255, 150),
		cost = 225,
	},
	RegenAura = {
		name = "Regen Aura",
		description = "Nearby buildings regenerate 2 HP/sec",
		range = 30,
		effect = "regen",
		bonus = 2, -- 2 HP per second
		color = Color3.fromRGB(100, 255, 200),
		cost = 250,
	},
}

-- Track active auras and affected buildings
local activeAuras = {} -- {auraModel = auraData}
local buildingBuffs = {} -- {buildingModel = {buffType = totalBonus}}

-- Get aura type info
function AuraManager.getAuraType(auraName)
	return AURA_TYPES[auraName]
end

-- Get all aura types (for shop)
function AuraManager.getAllAuraTypes()
	return AURA_TYPES
end

-- Check if a building is a turret
local function isTurret(building)
	local name = building.Name
	return name:find("Turret") ~= nil
end

-- Check if a building can receive buffs
local function isBuffableBuilding(building)
	return building:FindFirstChild("Owner") ~= nil
end

-- Get building position
local function getBuildingPosition(building)
	if building:IsA("Model") and building.PrimaryPart then
		return building.PrimaryPart.Position
	elseif building:IsA("BasePart") then
		return building.Position
	end
	return nil
end

-- Calculate total buffs for a building from all nearby auras
local function calculateBuildingBuffs(building)
	local buffs = {
		attackSpeed = 0,
		damage = 0,
		health = 0,
		range = 0,
		regen = 0,
	}

	local buildingPos = getBuildingPosition(building)
	if not buildingPos then return buffs end

	local buildingOwner = building:FindFirstChild("Owner")
	local ownerName = buildingOwner and buildingOwner.Value or nil

	for auraModel, auraData in pairs(activeAuras) do
		if auraModel.Parent then -- Aura still exists
			local auraPos = getBuildingPosition(auraModel)
			if auraPos then
				local distance = (buildingPos - auraPos).Magnitude

				-- Check if in range and same owner
				local auraOwner = auraModel:FindFirstChild("Owner")
				local auraOwnerName = auraOwner and auraOwner.Value or nil

				if distance <= auraData.range and auraOwnerName == ownerName then
					local effectType = auraData.effect
					buffs[effectType] = buffs[effectType] + auraData.bonus
				end
			end
		end
	end

	return buffs
end

-- Apply health buff to a building
local function applyHealthBuff(building, healthBonus)
	local health = building:FindFirstChild("Health")
	local maxHealth = building:FindFirstChild("MaxHealth")
	local baseMaxHealth = building:FindFirstChild("BaseMaxHealth")

	if health and maxHealth then
		-- Store base max health if not already stored
		if not baseMaxHealth then
			baseMaxHealth = Instance.new("NumberValue")
			baseMaxHealth.Name = "BaseMaxHealth"
			baseMaxHealth.Value = maxHealth.Value
			baseMaxHealth.Parent = building
		end

		-- Calculate new max health
		local newMaxHealth = math.floor(baseMaxHealth.Value * (1 + healthBonus))

		-- Only update if changed
		if maxHealth.Value ~= newMaxHealth then
			local healthPercent = health.Value / maxHealth.Value
			maxHealth.Value = newMaxHealth
			health.Value = math.floor(newMaxHealth * healthPercent)
		end
	end
end

-- Apply regen to buildings
local function applyRegen(dt)
	for building, buffs in pairs(buildingBuffs) do
		if building.Parent and buffs.regen > 0 then
			local health = building:FindFirstChild("Health")
			local maxHealth = building:FindFirstChild("MaxHealth")

			if health and maxHealth and health.Value < maxHealth.Value then
				health.Value = math.min(health.Value + buffs.regen * dt, maxHealth.Value)
			end
		end
	end
end

-- Get buff multiplier for a building
function AuraManager.getBuffMultiplier(building, buffType)
	local buffs = buildingBuffs[building]
	if buffs and buffs[buffType] then
		return 1 + buffs[buffType]
	end
	return 1
end

-- Get raw buff bonus for a building
function AuraManager.getBuffBonus(building, buffType)
	local buffs = buildingBuffs[building]
	if buffs and buffs[buffType] then
		return buffs[buffType]
	end
	return 0
end

-- Register an aura building
function AuraManager.registerAura(auraModel, auraType)
	local auraData = AURA_TYPES[auraType]
	if not auraData then
		warn("AuraManager: Unknown aura type:", auraType)
		return false
	end

	activeAuras[auraModel] = {
		type = auraType,
		range = auraData.range,
		effect = auraData.effect,
		bonus = auraData.bonus,
		color = auraData.color,
	}

	local auraPos = getBuildingPosition(auraModel)
	if not auraPos then
		warn("AuraManager: Could not get aura position")
		return false
	end

	-- Create subtle visual range indicator on the ground
	local rangeIndicator = Instance.new("Part")
	rangeIndicator.Name = "AuraRange"
	rangeIndicator.Shape = Enum.PartType.Cylinder
	rangeIndicator.Size = Vector3.new(0.1, auraData.range * 2, auraData.range * 2)
	-- Position on ground (Y = 0.15 to sit just above ground)
	rangeIndicator.CFrame = CFrame.new(auraPos.X, 0.15, auraPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	rangeIndicator.Anchored = true
	rangeIndicator.CanCollide = false
	rangeIndicator.Material = Enum.Material.SmoothPlastic
	rangeIndicator.Color = auraData.color
	rangeIndicator.Transparency = 0.92
	rangeIndicator.Parent = auraModel

	print("AuraManager: Registered", auraType, "aura at", auraPos)
	return true
end

-- Aura icon symbols (simple text representations)
local AURA_ICONS = {
	attackSpeed = { symbol = ">>", name = "Speed" },
	damage = { symbol = "!!", name = "Damage" },
	range = { symbol = "()", name = "Range" },
	health = { symbol = "++", name = "Fortify" },
	regen = { symbol = "<3", name = "Regen" },
}

-- Add or update buff indicator on a building
local function updateBuildingBuffIndicator(building, buffs)
	-- Collect active buffs
	local activeBuffs = {}

	if buffs.attackSpeed > 0 then
		table.insert(activeBuffs, { type = "attackSpeed", color = AURA_TYPES.SpeedAura.color, bonus = buffs.attackSpeed })
	end
	if buffs.damage > 0 then
		table.insert(activeBuffs, { type = "damage", color = AURA_TYPES.DamageAura.color, bonus = buffs.damage })
	end
	if buffs.range > 0 then
		table.insert(activeBuffs, { type = "range", color = AURA_TYPES.RangeAura.color, bonus = buffs.range })
	end
	if buffs.health > 0 then
		table.insert(activeBuffs, { type = "health", color = AURA_TYPES.FortifyAura.color, bonus = buffs.health })
	end
	if buffs.regen > 0 then
		table.insert(activeBuffs, { type = "regen", color = AURA_TYPES.RegenAura.color, bonus = buffs.regen })
	end

	-- Get the part to attach the billboard to
	local structurePart = building:IsA("Model") and building.PrimaryPart or building
	if not structurePart then return end

	-- Find or create buff indicator billboard
	local billboard = structurePart:FindFirstChild("AuraBuffIcons")

	if #activeBuffs > 0 then
		if not billboard then
			-- Create new billboard for icons
			billboard = Instance.new("BillboardGui")
			billboard.Name = "AuraBuffIcons"
			billboard.Size = UDim2.new(0, 80, 0, 20)
			billboard.StudsOffset = Vector3.new(0, 7, 0) -- Above the health bar
			billboard.AlwaysOnTop = true
			billboard.Adornee = structurePart
			billboard.Parent = structurePart

			-- Container for icons
			local container = Instance.new("Frame")
			container.Name = "Container"
			container.Size = UDim2.new(1, 0, 1, 0)
			container.BackgroundTransparency = 1
			container.Parent = billboard

			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.Padding = UDim.new(0, 2)
			layout.Parent = container
		end

		local container = billboard:FindFirstChild("Container")
		if not container then return end

		-- Clear existing icons
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		-- Create icon for each active buff
		for i, buff in ipairs(activeBuffs) do
			local iconInfo = AURA_ICONS[buff.type]
			if iconInfo then
				local iconFrame = Instance.new("Frame")
				iconFrame.Name = buff.type .. "Icon"
				iconFrame.Size = UDim2.new(0, 16, 0, 16)
				iconFrame.BackgroundColor3 = buff.color
				iconFrame.BackgroundTransparency = 0.3
				iconFrame.BorderSizePixel = 0
				iconFrame.Parent = container

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 4)
				corner.Parent = iconFrame

				local iconLabel = Instance.new("TextLabel")
				iconLabel.Name = "Symbol"
				iconLabel.Size = UDim2.new(1, 0, 1, 0)
				iconLabel.BackgroundTransparency = 1
				iconLabel.Text = iconInfo.symbol
				iconLabel.TextColor3 = Color3.new(1, 1, 1)
				iconLabel.TextScaled = true
				iconLabel.Font = Enum.Font.GothamBold
				iconLabel.Parent = iconFrame
			end
		end

		-- Adjust billboard width based on number of icons
		billboard.Size = UDim2.new(0, #activeBuffs * 18 + 4, 0, 20)
	else
		-- Remove billboard if no buffs
		if billboard then
			billboard:Destroy()
		end
	end
end

-- Unregister an aura building
function AuraManager.unregisterAura(auraModel)
	activeAuras[auraModel] = nil
	print("AuraManager: Unregistered aura")
end

-- Update all building buffs
local function updateAllBuffs()
	-- Track which buildings we've processed
	local processedBuildings = {}

	-- Find all buffable buildings
	for _, obj in ipairs(workspace:GetChildren()) do
		if isBuffableBuilding(obj) and not obj.Name:find("Aura") then
			local buffs = calculateBuildingBuffs(obj)
			buildingBuffs[obj] = buffs
			processedBuildings[obj] = true

			-- Apply health buff
			if buffs.health > 0 then
				applyHealthBuff(obj, buffs.health)
			end

			-- Update visual buff indicator
			updateBuildingBuffIndicator(obj, buffs)
		end
	end

	-- Clean up indicators on buildings no longer tracked
	for building, _ in pairs(buildingBuffs) do
		if not processedBuildings[building] then
			local indicator = building:FindFirstChild("AuraBuffIndicator")
			if indicator then
				indicator:Destroy()
			end
			buildingBuffs[building] = nil
		end
	end
end

-- Clean up destroyed auras
local function cleanupDestroyedAuras()
	for auraModel, _ in pairs(activeAuras) do
		if not auraModel.Parent then
			activeAuras[auraModel] = nil
		end
	end
end

-- Update loop
local updateTimer = 0
local UPDATE_INTERVAL = 0.5 -- Update buffs every 0.5 seconds

RunService.Heartbeat:Connect(function(dt)
	updateTimer = updateTimer + dt

	if updateTimer >= UPDATE_INTERVAL then
		updateTimer = 0
		cleanupDestroyedAuras()
		updateAllBuffs()
	end

	-- Apply regen every frame
	applyRegen(dt)
end)

-- Listen for building destruction to clean up
workspace.ChildRemoved:Connect(function(child)
	if activeAuras[child] then
		AuraManager.unregisterAura(child)
	end
	if buildingBuffs[child] then
		buildingBuffs[child] = nil
	end
end)

-- Also listen for new buildings to immediately check for buffs
workspace.ChildAdded:Connect(function(child)
	-- Small delay to let Owner value be set
	task.delay(0.5, function()
		if child.Parent and isBuffableBuilding(child) and not child.Name:find("Aura") then
			local buffs = calculateBuildingBuffs(child)
			buildingBuffs[child] = buffs
			updateBuildingBuffIndicator(child, buffs)
		end
	end)
end)

_G.AuraManager = AuraManager
print("AuraManager: Loaded!")

return AuraManager
