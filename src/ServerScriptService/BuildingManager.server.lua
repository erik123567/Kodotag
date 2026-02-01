local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

-- Only run on game servers (reserved servers)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("BuildingManager: Lobby server - disabled")
	return
end

print("BuildingManager: Starting...")

-- Wait for RoundManager
wait(2)
local RoundManager = _G.RoundManager

-- Build times for each item (in seconds)
local BUILD_TIMES = {
	Turret = 3,
	FastTurret = 4,
	SlowTurret = 2,
	FrostTurret = 5,
	PoisonTurret = 5,
	MultiShotTurret = 6,
	CannonTurret = 8,
	Barricade = 1,  -- Fast maze building
	Wall = 4,       -- Heavy defensive wall
	Farm = 5,
	Workshop = 10,
	-- Aura buildings
	SpeedAura = 6,
	DamageAura = 7,
	FortifyAura = 6,
	RangeAura = 7,
	RegenAura = 8,
}

-- Turrets that require a workshop to build
local REQUIRES_WORKSHOP = {
	SlowTurret = true,
	FrostTurret = true,
	PoisonTurret = true,
	MultiShotTurret = true
}

-- Helper: Check if player has a completed workshop
local function playerHasWorkshop(playerName)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "Workshop" then
			local owner = obj:FindFirstChild("Owner")
			local underConstruction = obj:FindFirstChild("UnderConstruction")
			if owner and owner.Value == playerName then
				-- Must be completed (not under construction)
				if not underConstruction or underConstruction.Value == false then
					return true
				end
			end
		end
	end
	return false
end

-- References
local buildableItems = ServerStorage:FindFirstChild("BuildableItems")
if not buildableItems then
	warn("BuildableItems folder not found in ServerStorage!")
	return
end

print("BuildingManager: Found BuildableItems folder")

-- Create remote events
local placeItemEvent = ReplicatedStorage:FindFirstChild("PlaceItem")
if not placeItemEvent then
	placeItemEvent = Instance.new("RemoteEvent")
	placeItemEvent.Name = "PlaceItem"
	placeItemEvent.Parent = ReplicatedStorage
	print("BuildingManager: Created PlaceItem RemoteEvent")
else
	print("BuildingManager: Found existing PlaceItem RemoteEvent")
end

local getBuildableItemsEvent = ReplicatedStorage:FindFirstChild("GetBuildableItems")
if not getBuildableItemsEvent then
	getBuildableItemsEvent = Instance.new("RemoteFunction")
	getBuildableItemsEvent.Name = "GetBuildableItems"
	getBuildableItemsEvent.Parent = ReplicatedStorage
end

local getItemTemplateEvent = ReplicatedStorage:FindFirstChild("GetItemTemplate")
if not getItemTemplateEvent then
	getItemTemplateEvent = Instance.new("RemoteFunction")
	getItemTemplateEvent.Name = "GetItemTemplate"
	getItemTemplateEvent.Parent = ReplicatedStorage
end

-- Create assist construction event
local assistConstructionEvent = ReplicatedStorage:FindFirstChild("AssistConstruction")
if not assistConstructionEvent then
	assistConstructionEvent = Instance.new("RemoteEvent")
	assistConstructionEvent.Name = "AssistConstruction"
	assistConstructionEvent.Parent = ReplicatedStorage
end

print("BuildingManager: Created remote events")

-- Track construction assist state
local constructionAssists = {} -- [constructionSite] = {players = {}, speedMultiplier = 1}
local ASSIST_RANGE = 15 -- Studs
local ASSIST_SPEED_BONUS = 0.5 -- 50% faster per player assisting
local ASSIST_COOLDOWN = 0.1 -- Seconds between assist ticks

-- Track last assist time per player
local lastAssistTime = {}

-- Handle assist construction requests
assistConstructionEvent.OnServerEvent:Connect(function(player, constructionSite)
	-- Cooldown check
	local now = tick()
	if lastAssistTime[player.Name] and now - lastAssistTime[player.Name] < ASSIST_COOLDOWN then
		return
	end
	lastAssistTime[player.Name] = now

	-- Validate construction site
	if not constructionSite or not constructionSite.Parent then
		return
	end

	local underConstruction = constructionSite:FindFirstChild("UnderConstruction")
	if not underConstruction or underConstruction.Value ~= true then
		return
	end

	-- Validate ownership (can only assist your own buildings)
	local owner = constructionSite:FindFirstChild("Owner")
	if not owner or owner.Value ~= player.Name then
		return
	end

	-- Validate distance
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local structurePos
	if constructionSite:IsA("Model") and constructionSite.PrimaryPart then
		structurePos = constructionSite.PrimaryPart.Position
	elseif constructionSite:IsA("BasePart") then
		structurePos = constructionSite.Position
	else
		return
	end

	local distance = (hrp.Position - structurePos).Magnitude
	if distance > ASSIST_RANGE then
		return
	end

	-- Mark this construction as being assisted
	if not constructionAssists[constructionSite] then
		constructionAssists[constructionSite] = {players = {}, lastAssistTick = 0}
	end
	constructionAssists[constructionSite].players[player.Name] = now
	constructionAssists[constructionSite].lastAssistTick = now
end)

-- Helper: Get assist speed multiplier for a construction site
local function getAssistMultiplier(constructionSite)
	local assistData = constructionAssists[constructionSite]
	if not assistData then return 1 end

	-- Count active assisters (assisted within last 0.3 seconds)
	local now = tick()
	local activeCount = 0
	for playerName, lastTime in pairs(assistData.players) do
		if now - lastTime < 0.3 then
			activeCount = activeCount + 1
		end
	end

	if activeCount > 0 then
		return 1 + (ASSIST_SPEED_BONUS * activeCount)
	end
	return 1
end

-- Cleanup assist data when player leaves
Players.PlayerRemoving:Connect(function(player)
	lastAssistTime[player.Name] = nil
	for site, data in pairs(constructionAssists) do
		if data.players then
			data.players[player.Name] = nil
		end
	end
end)

-- Helper: Get size of model or part
local function getModelSize(template)
	if template:IsA("Model") then
		local success, result = pcall(function()
			local cf, size = template:GetBoundingBox()
			return size
		end)
		if success then
			return result
		end
	elseif template:IsA("BasePart") then
		return template.Size
	end
	return Vector3.new(5, 5, 5)
end

-- Function: Get all buildable items
function getBuildableItemsEvent.OnServerInvoke(player)
	print("BuildingManager: GetBuildableItems called by", player.Name)

	local items = {}

	if not buildableItems then
		warn("BuildingManager: buildableItems is nil!")
		return items
	end

	print("BuildingManager: Scanning buildableItems folder...")

	-- Scan all categories
	for _, category in ipairs(buildableItems:GetChildren()) do
		if category:IsA("Folder") then
			print("BuildingManager: Checking category:", category.Name)

			for _, item in ipairs(category:GetChildren()) do
				print("BuildingManager: Checking item:", item.Name)

				local displayName = item:FindFirstChild("DisplayName")
				local cost = item:FindFirstChild("Cost")

				if displayName and cost then
					print("BuildingManager: Found valid item:", item.Name, "Display:", displayName.Value, "Cost:", cost.Value)

					local size = getModelSize(item)
					print("BuildingManager: Item size:", size)

					table.insert(items, {
						name = item.Name,
						displayName = displayName.Value,
						cost = cost.Value,
						category = category.Name,
						size = size
					})
				else
					warn("BuildingManager: Item", item.Name, "missing DisplayName or Cost")
					if not displayName then
						warn("  - Missing DisplayName")
					end
					if not cost then
						warn("  - Missing Cost")
					end
				end
			end
		end
	end

	print("BuildingManager: Sending", #items, "buildable items to", player.Name)
	return items
end

-- Function: Get item template for preview
function getItemTemplateEvent.OnServerInvoke(player, itemName)
	print("BuildingManager: GetItemTemplate called by", player.Name, "for", itemName)

	-- Search all categories for the item
	for _, category in ipairs(buildableItems:GetChildren()) do
		if category:IsA("Folder") then
			local item = category:FindFirstChild(itemName)
			if item then
				print("BuildingManager: Sending template for", itemName, "to", player.Name)
				return item
			end
		end
	end

	warn("BuildingManager: Item not found:", itemName)
	return nil
end

-- Function: Get base health for structure type
local function getBaseHealth(categoryName, itemName)
	-- Item-specific health overrides
	local itemHealth = {
		Barricade = 100,  -- Maze pillar
		Wall = 500,       -- Heavy defensive wall
		SpeedAura = 100,
		DamageAura = 100,
		FortifyAura = 150,
		RangeAura = 100,
		RegenAura = 125,
	}

	if itemHealth[itemName] then
		return itemHealth[itemName]
	end

	-- Category defaults
	if categoryName == "Maze" then
		return 75
	elseif categoryName == "Defense" then
		return 500
	elseif categoryName == "Walls" then  -- Legacy
		return 200
	elseif categoryName == "Turrets" then
		return 100
	elseif categoryName == "Farms" then
		return 150
	elseif categoryName == "Utility" then
		return 250
	elseif categoryName == "Auras" then
		return 100
	end
	return 100
end

-- Function: Add health to structure (with upgrade bonus)
local function addHealthToStructure(structure, itemName, categoryName, playerName)
	local baseHealth = getBaseHealth(categoryName, itemName)

	-- Apply Reinforced Structures upgrade bonus
	local healthBonus = 1.0
	if _G.UpgradeManager and playerName then
		local bonusPercent = _G.UpgradeManager.getUpgradeEffect(playerName, "ReinforcedStructures")
		healthBonus = 1.0 + bonusPercent
	end

	local finalHealth = math.floor(baseHealth * healthBonus)

	-- Create Health value
	local health = Instance.new("IntValue")
	health.Name = "Health"
	health.Value = finalHealth
	health.Parent = structure

	-- Create MaxHealth value (needed for health bars and aura buffs)
	local maxHealth = Instance.new("IntValue")
	maxHealth.Name = "MaxHealth"
	maxHealth.Value = finalHealth
	maxHealth.Parent = structure

	print("BuildingManager: Added", finalHealth, "HP to", itemName, "(base:", baseHealth, "bonus:", healthBonus .. "x)")

	return health
end

-- Function: Create construction progress bar
local function createConstructionProgressBar(constructionSite, buildTime)
	local part = constructionSite:IsA("Model") and constructionSite.PrimaryPart or constructionSite
	if not part then return end

	-- Create BillboardGui for progress
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ConstructionProgress"
	billboard.Size = UDim2.new(6, 0, 1.2, 0)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = part

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.4, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Under Construction"
	titleLabel.TextColor3 = Color3.new(1, 0.8, 0)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = billboard

	-- Background bar
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 0.4, 0)
	background.Position = UDim2.new(0, 0, 0.5, 0)
	background.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	background.BorderSizePixel = 2
	background.BorderColor3 = Color3.new(0, 0, 0)
	background.Parent = billboard

	-- Progress bar
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressBar.BackgroundColor3 = Color3.new(1, 0.7, 0)
	progressBar.BorderSizePixel = 0
	progressBar.Parent = background

	-- Time text
	local timeText = Instance.new("TextLabel")
	timeText.Name = "TimeText"
	timeText.Size = UDim2.new(1, 0, 1, 0)
	timeText.BackgroundTransparency = 1
	timeText.Text = buildTime .. "s"
	timeText.TextColor3 = Color3.new(1, 1, 1)
	timeText.TextScaled = true
	timeText.Font = Enum.Font.GothamBold
	timeText.TextStrokeTransparency = 0.5
	timeText.Parent = background

	return billboard, progressBar, timeText
end

-- Function: Create construction site using actual model (starts transparent)
local function createConstructionSite(itemName, position, rotation, categoryName, playerName, template)
	-- Clone the actual template
	local constructionSite = template:Clone()
	constructionSite.Name = itemName

	-- Position the model
	if constructionSite:IsA("Model") then
		-- Ensure all parts are anchored
		for _, part in ipairs(constructionSite:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				-- Start very transparent (construction starting)
				part.Transparency = 0.8
				-- Disable particles during construction
			elseif part:IsA("ParticleEmitter") then
				part.Enabled = false
			elseif part:IsA("PointLight") or part:IsA("SpotLight") or part:IsA("SurfaceLight") then
				part.Enabled = false
			end
		end

		if constructionSite.PrimaryPart then
			constructionSite.PrimaryPart.Anchored = true
			local targetCFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
			constructionSite:SetPrimaryPartCFrame(targetCFrame)
		else
			constructionSite:MoveTo(position)
		end
	elseif constructionSite:IsA("BasePart") then
		constructionSite.Anchored = true
		constructionSite.Transparency = 0.8
		constructionSite.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
	end

	-- Add markers
	local underConstruction = Instance.new("BoolValue")
	underConstruction.Name = "UnderConstruction"
	underConstruction.Value = true
	underConstruction.Parent = constructionSite

	local ownerValue = constructionSite:FindFirstChild("Owner")
	if not ownerValue then
		ownerValue = Instance.new("StringValue")
		ownerValue.Name = "Owner"
		ownerValue.Parent = constructionSite
	end
	ownerValue.Value = playerName

	-- Store build info
	local buildInfo = Instance.new("Folder")
	buildInfo.Name = "BuildInfo"
	buildInfo.Parent = constructionSite

	local categoryValue = Instance.new("StringValue")
	categoryValue.Name = "Category"
	categoryValue.Value = categoryName
	categoryValue.Parent = buildInfo

	local rotationValue = Instance.new("NumberValue")
	rotationValue.Name = "Rotation"
	rotationValue.Value = rotation or 0
	rotationValue.Parent = buildInfo

	-- Add health (construction sites have 50% health)
	local baseHealth = getBaseHealth(categoryName, itemName)
	local healthBonus = 1.0
	if _G.UpgradeManager and playerName then
		local bonusPercent = _G.UpgradeManager.getUpgradeEffect(playerName, "ReinforcedStructures")
		healthBonus = 1.0 + bonusPercent
	end

	local health = Instance.new("IntValue")
	health.Name = "Health"
	health.Value = math.floor(baseHealth * healthBonus * 0.5) -- 50% health during construction
	health.Parent = constructionSite

	local maxHealth = Instance.new("IntValue")
	maxHealth.Name = "MaxHealth"
	maxHealth.Value = math.floor(baseHealth * healthBonus)
	maxHealth.Parent = constructionSite

	constructionSite.Parent = workspace

	return constructionSite
end

-- Function: Update construction site transparency based on progress
local function updateConstructionTransparency(constructionSite, progress)
	if not constructionSite or not constructionSite.Parent then return end

	-- progress goes from 0 to 1
	-- transparency goes from 0.8 (start) to 0 (complete)
	local targetTransparency = 0.8 * (1 - progress)

	pcall(function()
		if constructionSite:IsA("Model") then
			for _, part in ipairs(constructionSite:GetDescendants()) do
				if part:IsA("BasePart") and part.Parent then
					-- Keep crystals and special parts slightly transparent
					if part.Name == "Crystal" then
						part.Transparency = math.max(0.3, targetTransparency)
					else
						part.Transparency = targetTransparency
					end
				end
			end
		elseif constructionSite:IsA("BasePart") then
			constructionSite.Transparency = targetTransparency
		end
	end)
end

-- Function: Apply completion effect (sparkles and flash, no size change)
local function applyCompletionEffect(item)
	local centerPart = item:IsA("Model") and item.PrimaryPart or item
	if not centerPart then return end

	-- Create sparkle particles
	local sparkleAttachment = Instance.new("Attachment")
	sparkleAttachment.Parent = centerPart

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.new(1, 0.9, 0.3))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 0)
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	sparkles.Lifetime = NumberRange.new(0.3, 0.6)
	sparkles.Rate = 0
	sparkles.Speed = NumberRange.new(5, 10)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = sparkleAttachment

	-- Burst of sparkles
	sparkles:Emit(15)

	-- Flash effect
	local flash = Instance.new("PointLight")
	flash.Color = Color3.new(1, 0.9, 0.5)
	flash.Brightness = 3
	flash.Range = 15
	flash.Parent = centerPart

	task.spawn(function()
		for i = 1, 10 do
			flash.Brightness = 3 * (1 - i/10)
			task.wait(0.03)
		end
		flash:Destroy()
	end)

	-- Clean up sparkles after they fade
	task.delay(1, function()
		sparkleAttachment:Destroy()
	end)
end

-- Function: Complete construction (finalize the existing model)
local function completeConstruction(constructionSite, template, playerName, categoryName)
	if not constructionSite or not constructionSite.Parent then
		print("BuildingManager: Construction site was destroyed before completion")
		return nil
	end

	-- Remove construction progress bar
	for _, descendant in ipairs(constructionSite:GetDescendants()) do
		if descendant:IsA("BillboardGui") and descendant.Name == "ConstructionProgress" then
			descendant:Destroy()
			break
		end
	end

	-- Remove construction markers
	local underConstruction = constructionSite:FindFirstChild("UnderConstruction")
	if underConstruction then
		underConstruction.Value = false
	end

	local buildInfo = constructionSite:FindFirstChild("BuildInfo")
	if buildInfo then
		buildInfo:Destroy()
	end

	-- Set final transparency and enable effects
	if constructionSite:IsA("Model") then
		for _, part in ipairs(constructionSite:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Final transparency (0 for most parts, 0.3 for crystals)
				if part.Name == "Crystal" then
					part.Transparency = 0.3
				else
					part.Transparency = 0
				end
			elseif part:IsA("ParticleEmitter") then
				part.Enabled = true
			elseif part:IsA("PointLight") or part:IsA("SpotLight") or part:IsA("SurfaceLight") then
				part.Enabled = true
			end
		end
	elseif constructionSite:IsA("BasePart") then
		constructionSite.Transparency = 0
	end

	-- Update health to full
	local health = constructionSite:FindFirstChild("Health")
	local maxHealth = constructionSite:FindFirstChild("MaxHealth")
	if health and maxHealth then
		health.Value = maxHealth.Value
	elseif not health then
		-- Add health if missing
		addHealthToStructure(constructionSite, constructionSite.Name, categoryName, playerName)
	end

	-- Apply completion effect (sparkles and flash)
	applyCompletionEffect(constructionSite)

	return constructionSite
end

-- Function: Handle item placement WITH ROTATION
print("BuildingManager: Connecting PlaceItem event handler...")

placeItemEvent.OnServerEvent:Connect(function(player, itemName, position, rotation)
	print("BuildingManager: ===== PLACEMENT REQUEST RECEIVED =====")
	print("BuildingManager:", player.Name, "wants to place", itemName, "at", position, "with rotation", rotation or 0)

	-- Wait for RoundManager if not loaded
	if not RoundManager then
		print("BuildingManager: Waiting for RoundManager...")
		local attempts = 0
		while not RoundManager and attempts < 20 do
			wait(0.1)
			RoundManager = _G.RoundManager
			attempts = attempts + 1
		end
	end

	if not RoundManager or not RoundManager.playerStats then
		warn("BuildingManager: RoundManager not available")
		return
	end

	print("BuildingManager: RoundManager found, searching for template...")

	-- Find the item template
	local template = nil
	local categoryName = nil
	for _, category in ipairs(buildableItems:GetChildren()) do
		if category:IsA("Folder") then
			local item = category:FindFirstChild(itemName)
			if item then
				template = item
				categoryName = category.Name
				print("BuildingManager: Found template in category:", category.Name)
				break
			end
		end
	end

	-- Create dynamic templates for items that don't have pre-made templates
	if not template then
		if itemName == "Barricade" then
			-- Create Barricade template dynamically (pillar for maze building)
			-- 3x6x3 size creates 2-stud gaps on 5-stud grid - players squeeze through, Kodos can't
			template = Instance.new("Part")
			template.Name = "Barricade"
			template.Size = Vector3.new(3, 6, 3)
			template.Material = Enum.Material.Wood
			template.BrickColor = BrickColor.new("Brown")
			template.Anchored = true

			local cost = Instance.new("IntValue")
			cost.Name = "Cost"
			cost.Value = 15
			cost.Parent = template

			categoryName = "Maze"
			print("BuildingManager: Created dynamic Barricade template")
		elseif itemName == "Wall" then
			-- Create Wall template dynamically (reinforced wall)
			-- 10x8x2 - wide defensive barrier, taller than Kodo (7.5)
			template = Instance.new("Part")
			template.Name = "Wall"
			template.Size = Vector3.new(10, 8, 2)
			template.Material = Enum.Material.Concrete
			template.BrickColor = BrickColor.new("Medium stone grey")
			template.Anchored = true

			local cost = Instance.new("IntValue")
			cost.Name = "Cost"
			cost.Value = 60
			cost.Parent = template

			categoryName = "Defense"
			print("BuildingManager: Created dynamic Wall template")
		elseif itemName:find("Aura") then
			-- Create Aura building template dynamically
			local auraColors = {
				SpeedAura = Color3.fromRGB(255, 200, 50),
				DamageAura = Color3.fromRGB(255, 80, 80),
				FortifyAura = Color3.fromRGB(100, 200, 255),
				RangeAura = Color3.fromRGB(150, 255, 150),
				RegenAura = Color3.fromRGB(100, 255, 200),
			}
			local auraCosts = {
				SpeedAura = 150,
				DamageAura = 200,
				FortifyAura = 175,
				RangeAura = 225,
				RegenAura = 250,
			}
			local auraRanges = {
				SpeedAura = 25,
				DamageAura = 25,
				FortifyAura = 30,
				RangeAura = 25,
				RegenAura = 30,
			}

			local auraModel = Instance.new("Model")
			auraModel.Name = itemName

			-- Base pillar - 4x6x4, taller to be visible over walls
			-- Total height ~8 studs (base 6 + crystal 3, overlapping slightly)
			local base = Instance.new("Part")
			base.Name = "Base"
			base.Size = Vector3.new(4, 6, 4)
			base.CFrame = CFrame.new(0, 0, 0) -- Will be positioned by MoveTo
			base.Material = Enum.Material.SmoothPlastic
			base.Color = auraColors[itemName] or Color3.new(1, 1, 1)
			base.Anchored = true
			base.CanCollide = true
			base.Parent = auraModel

			-- Crystal on top - positioned so total height is ~8 studs
			local crystal = Instance.new("Part")
			crystal.Name = "Crystal"
			crystal.Size = Vector3.new(2, 3, 2)
			crystal.CFrame = CFrame.new(0, 5, 0) -- Higher up for taller total height
			crystal.Material = Enum.Material.Neon
			crystal.Color = auraColors[itemName] or Color3.new(1, 1, 1)
			crystal.Anchored = true
			crystal.CanCollide = false
			crystal.Transparency = 0.3
			crystal.Parent = auraModel

			-- Add point light
			local light = Instance.new("PointLight")
			light.Color = auraColors[itemName] or Color3.new(1, 1, 1)
			light.Brightness = 2
			light.Range = 15
			light.Parent = crystal

			-- Add particle emitter for visual effect
			local attachment = Instance.new("Attachment")
			attachment.Parent = crystal

			local particles = Instance.new("ParticleEmitter")
			particles.Color = ColorSequence.new(auraColors[itemName] or Color3.new(1, 1, 1))
			particles.Size = NumberSequence.new(0.3, 0)
			particles.Lifetime = NumberRange.new(1, 2)
			particles.Rate = 5
			particles.Speed = NumberRange.new(0.5, 1)
			particles.SpreadAngle = Vector2.new(180, 180)
			particles.Transparency = NumberSequence.new(0.3, 1)
			particles.Parent = attachment

			-- Store aura type for later use
			local auraType = Instance.new("StringValue")
			auraType.Name = "AuraType"
			auraType.Value = itemName
			auraType.Parent = auraModel

			-- Store aura range
			local rangeValue = Instance.new("NumberValue")
			rangeValue.Name = "AuraRange"
			rangeValue.Value = auraRanges[itemName] or 25
			rangeValue.Parent = auraModel

			auraModel.PrimaryPart = base

			local cost = Instance.new("IntValue")
			cost.Name = "Cost"
			cost.Value = auraCosts[itemName] or 150
			cost.Parent = auraModel

			template = auraModel
			categoryName = "Auras"
			print("BuildingManager: Created dynamic", itemName, "template")
		else
			warn("BuildingManager: Template not found for", itemName)
			return
		end
	end

	-- Check if this item requires a workshop
	if REQUIRES_WORKSHOP[itemName] then
		if not playerHasWorkshop(player.Name) then
			local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
			if showNotification then
				showNotification:FireClient(player, itemName .. " requires a Workshop!", Color3.new(1, 0.5, 0))
			end
			print("BuildingManager:", player.Name, "tried to build", itemName, "without a Workshop")
			return
		end
	end

	-- Get cost
	local costValue = template:FindFirstChild("Cost")
	if not costValue then
		warn("BuildingManager: No cost defined for", itemName)
		return
	end

	local cost = costValue.Value
	print("BuildingManager: Item cost:", cost)

	-- Check if player has enough gold
	local stats = RoundManager.playerStats[player.Name]
	if not stats then
		warn("BuildingManager: No stats for", player.Name)
		return
	end

	print("BuildingManager: Player has", stats.gold, "gold, needs", cost)

	if stats.gold < cost then
		local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
		if showNotification then
			showNotification:FireClient(player, "Not enough gold! Need " .. cost .. ", have " .. stats.gold, Color3.new(1, 0, 0))
		end
		print("BuildingManager:", player.Name, "cannot afford", itemName)
		return
	end

	-- Deduct gold
	stats.gold = stats.gold - cost
	print("BuildingManager:", player.Name, "spent", cost, "gold. Remaining:", stats.gold)
	RoundManager.broadcastPlayerStats()

	-- Get build time
	local buildTime = BUILD_TIMES[itemName] or 5

	-- Create construction site
	print("BuildingManager: Creating construction site for", itemName)
	local constructionSite = createConstructionSite(itemName, position, rotation, categoryName, player.Name, template)

	-- Create progress bar
	local billboard, progressBar, timeText = createConstructionProgressBar(constructionSite, buildTime)

	-- Notify player
	local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
	if showNotification then
		showNotification:FireClient(player, "Building " .. itemName .. " (" .. buildTime .. "s)", Color3.new(1, 0.8, 0))
	end

	-- Construction progress
	task.spawn(function()
		local effectiveElapsed = 0 -- Tracks progress accounting for assist bonus
		local lastTick = tick()

		while effectiveElapsed < buildTime do
			-- Check if construction site was destroyed
			if not constructionSite or not constructionSite.Parent then
				print("BuildingManager: Construction site destroyed before completion")
				-- Cleanup assist data
				constructionAssists[constructionSite] = nil
				return
			end

			-- Calculate time delta with assist multiplier
			local now = tick()
			local delta = now - lastTick
			local assistMultiplier = getAssistMultiplier(constructionSite)
			effectiveElapsed = effectiveElapsed + (delta * assistMultiplier)
			lastTick = now

			-- Update progress bar
			local progress = math.min(effectiveElapsed / buildTime, 1)
			local remainingTime = (buildTime - effectiveElapsed) / assistMultiplier

			if progressBar and progressBar.Parent then
				progressBar.Size = UDim2.new(progress, 0, 1, 0)
				-- Change color when being assisted
				if assistMultiplier > 1 then
					progressBar.BackgroundColor3 = Color3.new(0, 1, 0.5) -- Green-cyan when assisted
				else
					progressBar.BackgroundColor3 = Color3.new(1, 0.7, 0) -- Orange normally
				end
			end
			if timeText and timeText.Parent then
				if assistMultiplier > 1 then
					timeText.Text = string.format("%.1fs (%.0f%% faster)", math.max(0, remainingTime), (assistMultiplier - 1) * 100)
				else
					timeText.Text = string.format("%.1fs", math.max(0, remainingTime))
				end
			end

			-- Update model transparency (fade in as construction progresses)
			updateConstructionTransparency(constructionSite, progress)

			wait(0.1)
		end

		-- Cleanup assist data
		constructionAssists[constructionSite] = nil

		-- Remove progress bar billboard first (always clean up)
		if billboard and billboard.Parent then
			billboard:Destroy()
		end

		-- Complete construction
		if constructionSite and constructionSite.Parent then
			print("BuildingManager: Construction complete for", itemName)

			local success, newItem = pcall(function()
				return completeConstruction(constructionSite, template, player.Name, categoryName)
			end)

			if success and newItem then
				-- Activate turret if applicable
				if categoryName == "Turrets" then
					local activateTurretEvent = ReplicatedStorage:FindFirstChild("ActivateTurret")
					if activateTurretEvent then
						activateTurretEvent:Fire(newItem, player.Name)
						print("BuildingManager: Activated turret for", player.Name)
					end
				end

				-- Register aura if applicable
				if itemName:find("Aura") and _G.AuraManager then
					_G.AuraManager.registerAura(newItem, itemName)
					print("BuildingManager: Registered aura", itemName, "for", player.Name)
				end

				-- Notify player
				if showNotification then
					showNotification:FireClient(player, itemName .. " construction complete!", Color3.new(0, 1, 0))
				end

				print("BuildingManager: Successfully completed", itemName, "for", player.Name)
			elseif not success then
				warn("BuildingManager: Error completing construction:", newItem)
			end
		end
	end)

	print("BuildingManager: Started construction of", itemName, "for", player.Name)
end)

print("BuildingManager: Event handler connected!")
print("BuildingManager loaded!")