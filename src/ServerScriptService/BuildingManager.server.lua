local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

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
	Wall = 2,
	Farm = 5,
	Workshop = 10
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

print("BuildingManager: Created remote events")

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
local function getBaseHealth(categoryName)
	if categoryName == "Walls" then
		return 200
	elseif categoryName == "Turrets" then
		return 100
	elseif categoryName == "Farms" then
		return 150
	elseif categoryName == "Utility" then
		return 250
	end
	return 100
end

-- Function: Add health to structure (with upgrade bonus)
local function addHealthToStructure(structure, itemName, categoryName, playerName)
	local health = Instance.new("IntValue")
	health.Name = "Health"

	local baseHealth = getBaseHealth(categoryName)

	-- Apply Reinforced Structures upgrade bonus
	local healthBonus = 1.0
	if _G.UpgradeManager and playerName then
		local bonusPercent = _G.UpgradeManager.getUpgradeEffect(playerName, "ReinforcedStructures")
		healthBonus = 1.0 + bonusPercent
	end

	health.Value = math.floor(baseHealth * healthBonus)
	print("BuildingManager: Added", health.Value, "HP to", itemName, "(base:", baseHealth, "bonus:", healthBonus .. "x)")

	health.Parent = structure
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

-- Function: Create construction site
local function createConstructionSite(itemName, position, rotation, categoryName, playerName, template)
	-- Get the size from template
	local templateSize = Vector3.new(4, 4, 4)
	if template:IsA("Model") then
		local success, result = pcall(function()
			local cf, size = template:GetBoundingBox()
			return size
		end)
		if success then
			templateSize = result
		end
	elseif template:IsA("BasePart") then
		templateSize = template.Size
	end

	-- Create construction site model
	local constructionSite = Instance.new("Model")
	constructionSite.Name = itemName -- Use the same name for collision detection

	-- Create base scaffold
	local scaffold = Instance.new("Part")
	scaffold.Name = "Scaffold"
	scaffold.Size = templateSize
	scaffold.Anchored = true
	scaffold.CanCollide = true
	scaffold.Material = Enum.Material.WoodPlanks
	scaffold.Color = Color3.new(0.6, 0.5, 0.3)
	scaffold.Transparency = 0.3
	scaffold.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
	scaffold.Parent = constructionSite

	constructionSite.PrimaryPart = scaffold

	-- Add markers
	local underConstruction = Instance.new("BoolValue")
	underConstruction.Name = "UnderConstruction"
	underConstruction.Value = true
	underConstruction.Parent = constructionSite

	local ownerValue = Instance.new("StringValue")
	ownerValue.Name = "Owner"
	ownerValue.Value = playerName
	ownerValue.Parent = constructionSite

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
	local baseHealth = getBaseHealth(categoryName)
	local healthBonus = 1.0
	if _G.UpgradeManager and playerName then
		local bonusPercent = _G.UpgradeManager.getUpgradeEffect(playerName, "ReinforcedStructures")
		healthBonus = 1.0 + bonusPercent
	end

	local health = Instance.new("IntValue")
	health.Name = "Health"
	health.Value = math.floor(baseHealth * healthBonus * 0.5) -- 50% health during construction
	health.Parent = constructionSite

	constructionSite.Parent = workspace

	return constructionSite
end

-- Function: Complete construction
local function completeConstruction(constructionSite, template, playerName, categoryName)
	if not constructionSite or not constructionSite.Parent then
		print("BuildingManager: Construction site was destroyed before completion")
		return nil
	end

	local position = constructionSite.PrimaryPart.Position
	local buildInfo = constructionSite:FindFirstChild("BuildInfo")
	local rotation = buildInfo and buildInfo:FindFirstChild("Rotation") and buildInfo.Rotation.Value or 0

	-- Remove construction site
	constructionSite:Destroy()

	-- Clone and place actual item
	local newItem = template:Clone()

	if newItem:IsA("Model") then
		newItem:MoveTo(position)
		if newItem.PrimaryPart then
			newItem.PrimaryPart.Anchored = true
		end
		for _, part in ipairs(newItem:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		if rotation and newItem.PrimaryPart then
			local currentCFrame = newItem:GetPrimaryPartCFrame()
			newItem:SetPrimaryPartCFrame(currentCFrame * CFrame.Angles(0, math.rad(rotation), 0))
		end
	elseif newItem:IsA("BasePart") then
		newItem.Position = position
		newItem.Anchored = true
		if rotation then
			newItem.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0)
		end
	end

	-- Add full health
	addHealthToStructure(newItem, newItem.Name, categoryName, playerName)

	-- Add owner
	local ownerValue = Instance.new("StringValue")
	ownerValue.Name = "Owner"
	ownerValue.Value = playerName
	ownerValue.Parent = newItem

	newItem.Parent = workspace

	return newItem
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

	if not template then
		warn("BuildingManager: Template not found for", itemName)
		return
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
		local startTime = tick()
		local endTime = startTime + buildTime

		while tick() < endTime do
			-- Check if construction site was destroyed
			if not constructionSite or not constructionSite.Parent then
				print("BuildingManager: Construction site destroyed before completion")
				return
			end

			-- Update progress bar
			local elapsed = tick() - startTime
			local progress = elapsed / buildTime

			if progressBar and progressBar.Parent then
				progressBar.Size = UDim2.new(progress, 0, 1, 0)
			end
			if timeText and timeText.Parent then
				timeText.Text = string.format("%.1fs", buildTime - elapsed)
			end

			wait(0.1)
		end

		-- Complete construction
		if constructionSite and constructionSite.Parent then
			print("BuildingManager: Construction complete for", itemName)

			local newItem = completeConstruction(constructionSite, template, player.Name, categoryName)

			if newItem then
				-- Activate turret if applicable
				if categoryName == "Turrets" then
					local activateTurretEvent = ReplicatedStorage:FindFirstChild("ActivateTurret")
					if activateTurretEvent then
						activateTurretEvent:Fire(newItem, player.Name)
						print("BuildingManager: Activated turret for", player.Name)
					end
				end

				-- Notify player
				if showNotification then
					showNotification:FireClient(player, itemName .. " construction complete!", Color3.new(0, 1, 0))
				end

				print("BuildingManager: Successfully completed", itemName, "for", player.Name)
			end
		end
	end)

	print("BuildingManager: Started construction of", itemName, "for", player.Name)
end)

print("BuildingManager: Event handler connected!")
print("BuildingManager loaded!")