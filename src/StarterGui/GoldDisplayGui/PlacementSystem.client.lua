local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Check if this is a game server (set by GameInitializer)
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	print("PlacementSystem: Lobby - disabled")
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

print("PlacementSystem: Starting...")

-- Settings
local GRID_SIZE = 5
local PLACEMENT_RANGE = 15 -- Max studs from player to place structures

-- Maze building settings
-- Walls can be placed with gaps: 3-6 studs = player only, 7+ = both pass
local MIN_WALL_GAP = 2  -- Minimum studs between wall edges (allows player-only gaps)

-- Turrets that require a workshop to build
local REQUIRES_WORKSHOP = {
	SlowTurret = true,
	FrostTurret = true,
	PoisonTurret = true,
	MultiShotTurret = true
}

-- Helper: Find model in ReplicatedStorage/BuildableItems
local function findBuildableModel(itemName)
	local buildableItems = ReplicatedStorage:FindFirstChild("BuildableItems")
	if not buildableItems then
		return nil
	end

	-- Search all subfolders
	for _, folder in ipairs(buildableItems:GetChildren()) do
		if folder:IsA("Folder") then
			local model = folder:FindFirstChild(itemName)
			if model then
				return model
			end
		end
	end

	-- Also check root level
	local model = buildableItems:FindFirstChild(itemName)
	if model then
		return model
	end

	return nil
end

-- Helper: Calculate bounding box size of a model
local function getModelBoundingBox(model)
	if not model then return nil end

	if model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		return size
	elseif model:IsA("BasePart") then
		return model.Size
	end

	return nil
end

-- Fallback sizes if model not found in ReplicatedStorage
-- These should match actual models OR dynamic templates in BuildingManager
local FALLBACK_SIZES = {
	-- Turrets (from actual models)
	Turret = Vector3.new(5, 4, 9),           -- Actual: 4.6 x 4.1 x 8.7
	FastTurret = Vector3.new(4, 6, 4),       -- No model yet - placeholder
	SlowTurret = Vector3.new(4, 6, 4),       -- No model yet - placeholder
	FrostTurret = Vector3.new(6, 11, 6),     -- Actual: 6.2 x 10.7 x 5.9
	PoisonTurret = Vector3.new(4, 6, 2),     -- Actual: 4 x 6 x 2
	MultiShotTurret = Vector3.new(4, 6, 2),  -- Actual: 4 x 6 x 2
	CannonTurret = Vector3.new(4, 6, 2),     -- Actual: 4 x 6 x 2
	-- Defense (dynamic templates)
	Barricade = Vector3.new(3, 6, 3),        -- Maze pillar - 2 stud gaps on 5 stud grid
	Wall = Vector3.new(10, 8, 2),            -- Wide barrier, taller than Kodo
	-- Economy
	Farm = Vector3.new(7, 5, 10),            -- Actual: 7.3 x 5.2 x 9.9
	Workshop = Vector3.new(8, 8, 8),         -- Landmark building (actual model is tiny, needs fixing)
	-- Auras (dynamic templates - 4x8x4 total with crystal)
	SpeedAura = Vector3.new(4, 8, 4),
	DamageAura = Vector3.new(4, 8, 4),
	FortifyAura = Vector3.new(4, 8, 4),
	RangeAura = Vector3.new(4, 8, 4),
	RegenAura = Vector3.new(4, 8, 4),
}

-- Hardcoded buildable items with stats
local BUILDABLE_ITEMS = {
	{
		name = "Turret",
		displayName = "Basic Turret",
		cost = 50,
		buildTime = 3,
		size = Vector3.new(4, 6, 4),
		category = "Turrets",
		stats = {
			damage = 50,
			fireRate = "0.5s",
			range = 50,
			health = 100,
			description = "Balanced turret for general defense"
		}
	},
	{
		name = "FastTurret",
		displayName = "Fast Turret",
		cost = 75,
		buildTime = 4,
		size = Vector3.new(4, 6, 4),
		category = "Turrets",
		stats = {
			damage = 40,
			fireRate = "0.2s",
			range = 40,
			health = 75,
			description = "Rapid fire, lower damage per shot"
		}
	},
	{
		name = "SlowTurret",
		displayName = "Slow Turret",
		cost = 30,
		buildTime = 2,
		size = Vector3.new(4, 6, 4),
		category = "Turrets",
		stats = {
			damage = 60,
			fireRate = "1.0s",
			range = 60,
			health = 150,
			description = "Heavy hitter with slow fire rate"
		}
	},
	{
		name = "FrostTurret",
		displayName = "Frost Turret",
		cost = 100,
		buildTime = 5,
		size = Vector3.new(4, 6, 4),
		category = "Turrets",
		stats = {
			damage = 20,
			fireRate = "0.8s",
			range = 45,
			health = 100,
			description = "Slows enemies by 50% for 3 seconds"
		}
	},
	{
		name = "PoisonTurret",
		displayName = "Poison Turret",
		cost = 90,
		buildTime = 5,
		size = Vector3.new(4, 6, 4),
		category = "Turrets",
		stats = {
			damage = 15,
			fireRate = "1.0s",
			range = 50,
			health = 100,
			description = "Poisons enemies for 10 dmg/sec over 5s"
		}
	},
	{
		name = "MultiShotTurret",
		displayName = "Multi-Shot Turret",
		cost = 120,
		buildTime = 6,
		size = Vector3.new(4, 6, 4),
		category = "Turrets",
		stats = {
			damage = "25x3",
			fireRate = "0.6s",
			range = 40,
			health = 100,
			description = "Fires 3 projectiles at once"
		}
	},
	{
		name = "CannonTurret",
		displayName = "Cannon Turret",
		cost = 150,
		buildTime = 8,
		size = Vector3.new(4, 6, 4),
		category = "Turrets",
		stats = {
			damage = 80,
			fireRate = "2.0s",
			range = 55,
			health = 125,
			description = "Explosive AOE damage in 15 stud radius"
		}
	},
	{
		name = "Barricade",
		displayName = "Barricade",
		cost = 15,
		buildTime = 1,
		size = Vector3.new(3, 6, 3),
		category = "Maze",
		stats = {
			health = 100,
			description = "Maze pillar. Players can squeeze through gaps but Kodos can't. Spam these to build mazes!"
		}
	},
	{
		name = "Wall",
		displayName = "Reinforced Wall",
		cost = 60,
		buildTime = 4,
		size = Vector3.new(10, 8, 2),
		category = "Defense",
		stats = {
			health = 500,
			description = "Heavy defensive wall for protecting your base. Place behind turrets to create strongholds."
		}
	},
	{
		name = "Farm",
		displayName = "Farm",
		cost = 75,
		buildTime = 5,
		size = Vector3.new(6, 4, 6),
		category = "Farms",
		stats = {
			health = 150,
			income = "+1 gold/5s",
			description = "Generates +1 passive gold every 5 seconds"
		}
	},
	{
		name = "Workshop",
		displayName = "Workshop",
		cost = 150,
		buildTime = 10,
		size = Vector3.new(8, 6, 8),
		category = "Utility",
		stats = {
			health = 250,
			description = "Approach and press U to purchase upgrades"
		}
	},
	-- Aura Buildings
	{
		name = "SpeedAura",
		displayName = "Speed Aura",
		cost = 150,
		buildTime = 6,
		size = Vector3.new(4, 8, 4),
		category = "Auras",
		stats = {
			health = 100,
			range = 25,
			description = "Nearby turrets attack 15% faster"
		}
	},
	{
		name = "DamageAura",
		displayName = "Damage Aura",
		cost = 200,
		buildTime = 7,
		size = Vector3.new(4, 8, 4),
		category = "Auras",
		stats = {
			health = 100,
			range = 25,
			description = "Nearby turrets deal 20% more damage"
		}
	},
	{
		name = "FortifyAura",
		displayName = "Fortify Aura",
		cost = 175,
		buildTime = 6,
		size = Vector3.new(4, 8, 4),
		category = "Auras",
		stats = {
			health = 150,
			range = 30,
			description = "Nearby buildings have 30% more health"
		}
	},
	{
		name = "RangeAura",
		displayName = "Range Aura",
		cost = 225,
		buildTime = 7,
		size = Vector3.new(4, 8, 4),
		category = "Auras",
		stats = {
			health = 100,
			range = 25,
			description = "Nearby turrets have 20% more range"
		}
	},
	{
		name = "RegenAura",
		displayName = "Regen Aura",
		cost = 250,
		buildTime = 8,
		size = Vector3.new(4, 8, 4),
		category = "Auras",
		stats = {
			health = 125,
			range = 30,
			description = "Nearby buildings regenerate 2 HP/sec"
		}
	}
}

-- Populate sizes from actual models in ReplicatedStorage
local function populateModelSizes()
	local updated = 0
	local notFound = {}

	for _, itemData in ipairs(BUILDABLE_ITEMS) do
		local model = findBuildableModel(itemData.name)
		if model then
			local actualSize = getModelBoundingBox(model)
			if actualSize then
				-- Round to nearest 0.5 to avoid floating point weirdness
				local roundedSize = Vector3.new(
					math.floor(actualSize.X * 2 + 0.5) / 2,
					math.floor(actualSize.Y * 2 + 0.5) / 2,
					math.floor(actualSize.Z * 2 + 0.5) / 2
				)
				itemData.size = roundedSize
				updated = updated + 1
			end
		else
			-- Use fallback size
			if FALLBACK_SIZES[itemData.name] then
				itemData.size = FALLBACK_SIZES[itemData.name]
			end
			table.insert(notFound, itemData.name)
		end
	end

	print("PlacementSystem: Updated " .. updated .. " item sizes from models")
	if #notFound > 0 then
		print("PlacementSystem: Models not found (using fallbacks): " .. table.concat(notFound, ", "))
	end
end

-- Wait briefly for ReplicatedStorage to sync, then populate sizes
task.spawn(function()
	task.wait(0.5) -- Brief wait for replication
	populateModelSizes()
end)

-- State
local isPlacementMode = false
local isBuildMenuOpen = false
local previewModel = nil
local isValidPlacement = false
local selectedItem = nil
local currentRotation = 0
local currentGold = 0
local placementRangeIndicator = nil -- Shows build radius around player
local lastValidPosition = nil -- Track last valid placement position

-- UI References
local goldDisplayGui = playerGui:WaitForChild("GoldDisplayGui")

-- Category definitions for tabs
local CATEGORIES = {
	{ id = "Turrets", name = "Turrets", color = Color3.fromRGB(255, 100, 100) },
	{ id = "Defense", name = "Defense", color = Color3.fromRGB(100, 150, 255) },
	{ id = "Economy", name = "Economy", color = Color3.fromRGB(255, 200, 50) },
	{ id = "Auras", name = "Auras", color = Color3.fromRGB(150, 100, 255) },
}

-- Map item categories to tab categories
local CATEGORY_MAP = {
	Turrets = "Turrets",
	Maze = "Defense",
	Defense = "Defense",
	Farms = "Economy",
	Utility = "Economy",
	Auras = "Auras",
}

local selectedCategory = "Turrets"

-- Create Build Menu UI
local buildMenu = goldDisplayGui:FindFirstChild("BuildMenu")
if buildMenu then buildMenu:Destroy() end

buildMenu = Instance.new("Frame")
buildMenu.Name = "BuildMenu"
buildMenu.Size = UDim2.new(0, 500, 0, 320)
buildMenu.Position = UDim2.new(0.5, -250, 0.5, -160)
buildMenu.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
buildMenu.BackgroundTransparency = 0.05
buildMenu.BorderSizePixel = 0
buildMenu.Visible = false
buildMenu.Parent = goldDisplayGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 8)
menuCorner.Parent = buildMenu

local menuStroke = Instance.new("UIStroke")
menuStroke.Color = Color3.fromRGB(80, 80, 100)
menuStroke.Thickness = 2
menuStroke.Parent = buildMenu

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = buildMenu

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

-- Fix bottom corners of title bar
local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 10)
titleFix.Position = UDim2.new(0, 0, 1, -10)
titleFix.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -10, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "BUILD MENU"
title.TextColor3 = Color3.fromRGB(200, 200, 220)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local closeHint = Instance.new("TextLabel")
closeHint.Size = UDim2.new(0, 100, 1, 0)
closeHint.Position = UDim2.new(1, -110, 0, 0)
closeHint.BackgroundTransparency = 1
closeHint.Text = "[B] Close"
closeHint.TextColor3 = Color3.fromRGB(120, 120, 140)
closeHint.Font = Enum.Font.Gotham
closeHint.TextSize = 11
closeHint.TextXAlignment = Enum.TextXAlignment.Right
closeHint.Parent = titleBar

-- Category tabs container
local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(1, -10, 0, 30)
tabContainer.Position = UDim2.new(0, 5, 0, 38)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = buildMenu

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabContainer

-- Create category tabs
local categoryTabs = {}
for _, cat in ipairs(CATEGORIES) do
	local tab = Instance.new("TextButton")
	tab.Name = cat.id .. "Tab"
	tab.Size = UDim2.new(0, 118, 1, 0)
	tab.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	tab.BorderSizePixel = 0
	tab.Text = cat.name
	tab.TextColor3 = Color3.fromRGB(180, 180, 200)
	tab.Font = Enum.Font.GothamBold
	tab.TextSize = 12
	tab.Parent = tabContainer

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 6)
	tabCorner.Parent = tab

	categoryTabs[cat.id] = { button = tab, color = cat.color }
end

-- Content area (items + info panel)
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -10, 1, -78)
contentArea.Position = UDim2.new(0, 5, 0, 73)
contentArea.BackgroundTransparency = 1
contentArea.Parent = buildMenu

-- Item list (left side)
local itemList = Instance.new("ScrollingFrame")
itemList.Name = "ItemList"
itemList.Size = UDim2.new(0.48, 0, 1, 0)
itemList.Position = UDim2.new(0, 0, 0, 0)
itemList.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
itemList.BackgroundTransparency = 0.3
itemList.BorderSizePixel = 0
itemList.ScrollBarThickness = 4
itemList.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
itemList.CanvasSize = UDim2.new(0, 0, 0, 0)
itemList.AutomaticCanvasSize = Enum.AutomaticSize.Y
itemList.Parent = contentArea

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 6)
listCorner.Parent = itemList

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent = itemList

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.PaddingBottom = UDim.new(0, 4)
listPadding.Parent = itemList

-- Info panel (right side)
local infoPanel = Instance.new("Frame")
infoPanel.Name = "InfoPanel"
infoPanel.Size = UDim2.new(0.50, 0, 1, 0)
infoPanel.Position = UDim2.new(0.50, 0, 0, 0)
infoPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
infoPanel.BackgroundTransparency = 0.3
infoPanel.BorderSizePixel = 0
infoPanel.Parent = contentArea

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 6)
infoCorner.Parent = infoPanel

local infoPadding = Instance.new("UIPadding")
infoPadding.PaddingLeft = UDim.new(0, 10)
infoPadding.PaddingRight = UDim.new(0, 10)
infoPadding.PaddingTop = UDim.new(0, 8)
infoPadding.Parent = infoPanel

-- Info panel content
local itemNameLabel = Instance.new("TextLabel")
itemNameLabel.Name = "ItemName"
itemNameLabel.Size = UDim2.new(1, 0, 0, 24)
itemNameLabel.BackgroundTransparency = 1
itemNameLabel.Text = "Select an item"
itemNameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
itemNameLabel.Font = Enum.Font.GothamBold
itemNameLabel.TextSize = 16
itemNameLabel.TextXAlignment = Enum.TextXAlignment.Left
itemNameLabel.Parent = infoPanel

local itemStatsLabel = Instance.new("TextLabel")
itemStatsLabel.Name = "ItemStats"
itemStatsLabel.Size = UDim2.new(1, 0, 1, -30)
itemStatsLabel.Position = UDim2.new(0, 0, 0, 28)
itemStatsLabel.BackgroundTransparency = 1
itemStatsLabel.Text = "Hover over an item to see details"
itemStatsLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
itemStatsLabel.Font = Enum.Font.Gotham
itemStatsLabel.TextSize = 12
itemStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
itemStatsLabel.TextYAlignment = Enum.TextYAlignment.Top
itemStatsLabel.TextWrapped = true
itemStatsLabel.Parent = infoPanel

print("PlacementSystem: Created tabbed BuildMenu")

-- Get reference to GoldText (created by GoldDisplayUpdater)
local goldDisplay = goldDisplayGui:WaitForChild("GoldDisplay", 5)
local goldText = goldDisplay and goldDisplay:WaitForChild("GoldText", 5)

if not goldText then
	warn("PlacementSystem: Could not find GoldText, gold checking may not work")
end

-- Remote events
print("PlacementSystem: Waiting for PlaceItem event...")
local placeItemEvent = ReplicatedStorage:WaitForChild("PlaceItem", 10)

if not placeItemEvent then
	warn("PlacementSystem: PlaceItem event not found after 10 seconds!")
	return
end

print("PlacementSystem: Found PlaceItem event")
print("PlacementSystem: Loaded")

-- Forward declarations (must be before event listeners that use them)
local populateBuildMenu
local exitPlacementMode

-- Listen for gold updates (wait for event to exist)
task.spawn(function()
	local updatePlayerStatsEvent = ReplicatedStorage:WaitForChild("UpdatePlayerStats", 15)
	if updatePlayerStatsEvent then
		updatePlayerStatsEvent.OnClientEvent:Connect(function(stats)
			currentGold = stats.gold
			-- Update button colors if menu is open
			if isBuildMenuOpen and populateBuildMenu then
				populateBuildMenu() -- Full refresh to update button colors
			end
			-- Exit placement mode if can't afford selected item anymore
			if isPlacementMode and selectedItem and currentGold < selectedItem.cost and exitPlacementMode then
				print("PlacementSystem: Can't afford " .. selectedItem.displayName .. ", exiting placement mode")
				exitPlacementMode()
			end
		end)
		print("PlacementSystem: Listening for gold updates")
	else
		warn("PlacementSystem: UpdatePlayerStats event not found")
	end
end)

-- Helper: Get current gold from UI
local function getCurrentGold()
	if not goldText then return 0 end
	local success, goldString = pcall(function() return goldText.Text end)
	if not success or not goldString then return 0 end
	local gold = tonumber(goldString:match("%d+"))
	return gold or 0
end

-- Helper: Check if player has a completed workshop
local function playerHasWorkshop()
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "Workshop" then
			local owner = obj:FindFirstChild("Owner")
			local underConstruction = obj:FindFirstChild("UnderConstruction")
			if owner and owner.Value == player.Name then
				-- Must be completed (not under construction)
				if not underConstruction or underConstruction.Value == false then
					return true
				end
			end
		end
	end
	return false
end

-- Helper: Update button colors based on affordability (just refresh the menu)
local function updateButtonAffordability()
	if isBuildMenuOpen then
		populateBuildMenu()
	end
end

-- Helper: Snap position to grid
local function snapToGrid(position)
	return Vector3.new(
		math.floor(position.X / GRID_SIZE + 0.5) * GRID_SIZE,
		position.Y,
		math.floor(position.Z / GRID_SIZE + 0.5) * GRID_SIZE
	)
end

-- Helper: Check if placement is valid - SIMPLIFIED
local function checkPlacementValid(position, size)
	local character = player.Character
	if not character then return false end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end

	local distance = (position - humanoidRootPart.Position).Magnitude
	if distance > PLACEMENT_RANGE then
		return false
	end

	-- Use center-to-center distance checking with small collision radii
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Camera") or obj:IsA("Terrain") then
			continue
		end

		local objPos = nil
		if obj:IsA("Model") and obj.PrimaryPart then
			objPos = obj.PrimaryPart.Position
		elseif obj:IsA("BasePart") then
			objPos = obj.Position
		end

		if objPos then
			local dist = (objPos - position).Magnitude
			local isTurret = (obj.Name == "Turret" or obj.Name == "FastTurret" or obj.Name == "SlowTurret"
				or obj.Name == "FrostTurret" or obj.Name == "PoisonTurret"
				or obj.Name == "MultiShotTurret" or obj.Name == "CannonTurret")
			local isWall = (obj.Name == "Wall")
			local isBarricade = (obj.Name == "Barricade")
			local isFarm = (obj.Name == "Farm")
			local isWorkshop = (obj.Name == "Workshop")

			-- If placing a TURRET
			if selectedItem and selectedItem.category == "Turrets" then
				-- Only block if another turret is within 5 studs (center to center)
				if isTurret and dist < 5 then
					return false
				end
				-- Block if farm is within 5 studs
				if isFarm and dist < 5 then
					return false
				end
				-- Walls/Barricades don't block turrets (can place turrets behind walls)

			-- If placing a BARRICADE (maze building)
			elseif selectedItem and selectedItem.category == "Maze" then
				-- Barricades are 3x3 pillars - allow close placement for maze building
				-- Grid is 5 studs, so barricades 5 studs apart have 2-stud gaps (player squeezes through, Kodo can't)
				-- Block only if overlapping (within 3 studs center-to-center)
				if isBarricade and dist < 3 then
					return false
				end
				-- Block if wall is within 3 studs
				if isWall and dist < 3 then
					return false
				end
				-- Block if turret is within 2 studs
				if isTurret and dist < 2 then
					return false
				end
				-- Block if farm is within 3 studs
				if isFarm and dist < 3 then
					return false
				end

			-- If placing a WALL (defensive)
			elseif selectedItem and selectedItem.category == "Defense" then
				-- Block if another wall is within 5 studs
				if isWall and dist < 5 then
					return false
				end
				-- Block if barricade is within 4 studs
				if isBarricade and dist < 4 then
					return false
				end
				-- Block if turret is within 5 studs
				if isTurret and dist < 5 then
					return false
				end
				-- Block if farm is within 5 studs
				if isFarm and dist < 5 then
					return false
				end

			-- If placing a FARM
			elseif selectedItem and selectedItem.category == "Farms" then
				-- Block if another farm is within 6 studs
				if isFarm and dist < 6 then
					return false
				end
				-- Block if turret is within 5 studs
				if isTurret and dist < 5 then
					return false
				end
				-- Block if wall is within 4 studs
				if isWall and dist < 4 then
					return false
				end
				-- Block if barricade is within 4 studs
				if isBarricade and dist < 4 then
					return false
				end
				-- Block if workshop is within 6 studs
				if isWorkshop and dist < 6 then
					return false
				end

			-- If placing a UTILITY building (Workshop)
			elseif selectedItem and selectedItem.category == "Utility" then
				-- Block if another workshop is within 8 studs
				if isWorkshop and dist < 8 then
					return false
				end
				-- Block if turret is within 6 studs
				if isTurret and dist < 6 then
					return false
				end
				-- Block if wall is within 5 studs
				if isWall and dist < 5 then
					return false
				end
				-- Block if barricade is within 4 studs
				if isBarricade and dist < 4 then
					return false
				end
				-- Block if farm is within 6 studs
				if isFarm and dist < 6 then
					return false
				end

			-- If placing an AURA building
			elseif selectedItem and selectedItem.category == "Auras" then
				local isAura = obj.Name:find("Aura") ~= nil
				-- Block if another aura is within 5 studs
				if isAura and dist < 5 then
					return false
				end
				-- Block if turret is within 4 studs
				if isTurret and dist < 4 then
					return false
				end
				-- Block if wall is within 4 studs
				if isWall and dist < 4 then
					return false
				end
				-- Block if barricade is within 3 studs
				if isBarricade and dist < 3 then
					return false
				end
				-- Block if farm is within 4 studs
				if isFarm and dist < 4 then
					return false
				end
				-- Block if workshop is within 5 studs
				if isWorkshop and dist < 5 then
					return false
				end
			end
		end
	end

	return true
end

-- Helper: Create/update placement range indicator around player
local function updatePlacementRangeIndicator()
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if not placementRangeIndicator then
		placementRangeIndicator = Instance.new("Part")
		placementRangeIndicator.Name = "PlacementRangeIndicator"
		placementRangeIndicator.Shape = Enum.PartType.Cylinder
		placementRangeIndicator.Size = Vector3.new(0.1, PLACEMENT_RANGE * 2, PLACEMENT_RANGE * 2)
		placementRangeIndicator.Anchored = true
		placementRangeIndicator.CanCollide = false
		placementRangeIndicator.Material = Enum.Material.Neon
		placementRangeIndicator.Color = Color3.fromRGB(100, 150, 255)
		placementRangeIndicator.Transparency = 0.9
		placementRangeIndicator.CastShadow = false
		placementRangeIndicator.Parent = workspace
	end

	-- Position at player's feet, rotated to be horizontal
	placementRangeIndicator.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 2.5, hrp.Position.Z)
		* CFrame.Angles(0, 0, math.rad(90))
end

local function showPlacementRangeIndicator()
	updatePlacementRangeIndicator()
	if placementRangeIndicator then
		placementRangeIndicator.Transparency = 0.85
	end
end

local function hidePlacementRangeIndicator()
	if placementRangeIndicator then
		placementRangeIndicator:Destroy()
		placementRangeIndicator = nil
	end
end

-- Helper: Create a fallback simple preview (colored box)
local function createSimplePreview(itemData)
	local preview = Instance.new("Model")
	preview.Name = "PreviewModel"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = itemData.size
	base.Anchored = true
	base.CanCollide = false
	base.Material = Enum.Material.SmoothPlastic
	base.Transparency = 0.4
	base.Parent = preview

	preview.PrimaryPart = base
	return preview
end

-- Helper: Update preview highlight color
local function setPreviewValid(preview, isValid)
	local highlight = preview:FindFirstChild("PreviewHighlight")
	if highlight then
		if isValid then
			highlight.FillColor = Color3.new(0, 1, 0)
			highlight.OutlineColor = Color3.new(0.5, 1, 0.5)
		else
			highlight.FillColor = Color3.new(1, 0, 0)
			highlight.OutlineColor = Color3.new(1, 0.5, 0.5)
		end
	end

	-- Also update range indicator color
	local rangeIndicator = preview:FindFirstChild("RangeIndicator")
	if rangeIndicator then
		rangeIndicator.Color = isValid and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
	end
end

-- Helper: Create preview based on item type (uses actual model if available)
local function createPreview(itemData)
	if previewModel then
		previewModel:Destroy()
	end

	local preview = nil
	local usedActualModel = false

	-- Try to use actual model from ReplicatedStorage
	local actualModel = findBuildableModel(itemData.name)
	if actualModel then
		preview = actualModel:Clone()
		preview.Name = "PreviewModel"
		usedActualModel = true

		-- Make all parts semi-transparent and non-collidable
		for _, part in ipairs(preview:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.Transparency = math.max(part.Transparency, 0.3)
				part.CastShadow = false
			elseif part:IsA("ParticleEmitter") or part:IsA("Fire") or part:IsA("Smoke") or part:IsA("Sparkles") then
				part:Destroy()
			end
		end

		-- Also handle if model is a single BasePart
		if preview:IsA("BasePart") then
			preview.Anchored = true
			preview.CanCollide = false
			preview.Transparency = math.max(preview.Transparency, 0.3)
		end

		-- Ensure PrimaryPart is set
		if preview:IsA("Model") and not preview.PrimaryPart then
			local primaryPart = preview:FindFirstChild("HumanoidRootPart")
				or preview:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				preview.PrimaryPart = primaryPart
			end
		end
	end

	-- Fallback to simple preview if model not found or invalid
	if not preview or (preview:IsA("Model") and not preview.PrimaryPart) then
		if preview then preview:Destroy() end
		preview = createSimplePreview(itemData)
		usedActualModel = false
		print("PlacementSystem: Using simple preview for", itemData.displayName, "(model not found or invalid)")
	end

	-- Add Highlight for valid/invalid indication
	local highlight = Instance.new("Highlight")
	highlight.Name = "PreviewHighlight"
	highlight.FillColor = Color3.new(0, 1, 0)
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.new(0.5, 1, 0.5)
	highlight.OutlineTransparency = 0
	highlight.Parent = preview

	-- Add range indicator for turrets and auras
	local showRange = (itemData.category == "Turrets" or itemData.category == "Auras")
		and itemData.stats and itemData.stats.range
	if showRange then
		local rangeCircle = Instance.new("Part")
		rangeCircle.Name = "RangeIndicator"
		rangeCircle.Shape = Enum.PartType.Cylinder
		rangeCircle.Size = Vector3.new(0.2, itemData.stats.range * 2, itemData.stats.range * 2)
		rangeCircle.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		rangeCircle.Anchored = true
		rangeCircle.CanCollide = false
		rangeCircle.Material = Enum.Material.Neon
		rangeCircle.Color = Color3.new(0, 1, 0)
		rangeCircle.Transparency = 0.8
		rangeCircle.CastShadow = false
		rangeCircle.Parent = preview
	end

	preview.Parent = workspace
	previewModel = preview

	if usedActualModel then
		print("PlacementSystem: Created preview from actual model for", itemData.displayName)
	else
		print("PlacementSystem: Created preview for", itemData.displayName)
	end
	return preview
end

-- Helper: Check if an object is something we should filter from raycast
local function shouldFilterFromRaycast(obj)
	-- Filter player-owned structures (have Owner attribute)
	if obj:FindFirstChild("Owner") then
		return true
	end

	-- Filter by name - buildings, turrets, etc.
	local name = obj.Name
	if name == "Turret" or name == "FastTurret" or name == "SlowTurret"
		or name == "FrostTurret" or name == "PoisonTurret"
		or name == "MultiShotTurret" or name == "CannonTurret"
		or name == "Wall" or name == "Barricade" or name == "Farm" or name == "Workshop"
		or name:find("Aura")
		or name == "Kodo" or name:find("Kodo") -- Filter Kodos
		or name == "GoldMine" or name:find("Mine") -- Filter gold mines
		or name == "PowerUp" or name:find("PowerUp") -- Filter power-ups
		or name == "ResurrectionShrine" -- Filter shrines
	then
		return true
	end

	-- Filter other players' characters
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and (obj == p.Character or obj:IsDescendantOf(p.Character)) then
			return true
		end
	end

	return false
end

-- Helper: Update preview
local function updatePreview()
	if not previewModel or not isPlacementMode or not selectedItem then return end

	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Build comprehensive filter list
	local filterList = {player.Character, previewModel}

	-- Filter all relevant objects in workspace
	for _, obj in ipairs(workspace:GetChildren()) do
		if shouldFilterFromRaycast(obj) then
			table.insert(filterList, obj)
		end
	end

	-- Also check for objects in common folders
	local foldersToCheck = {"Kodos", "PowerUps", "GoldMines", "Structures", "Buildings"}
	for _, folderName in ipairs(foldersToCheck) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			table.insert(filterList, folder)
		end
	end

	raycastParams.FilterDescendantsInstances = filterList

	local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)

	if raycastResult then
		local hitPart = raycastResult.Instance
		local hitPosition = raycastResult.Position

		-- More permissive ground check - accept if it's:
		-- 1. Named like ground (Baseplate, Ground, Floor, etc.)
		-- 2. Is Terrain
		-- 3. Is a direct child of workspace (likely ground)
		-- 4. Has no Owner (not a player structure)
		-- 5. Is in a "Map" or "Environment" folder
		local isGroundLike = (
			hitPart.Name == "Baseplate"
			or hitPart.Name == "Ground"
			or hitPart.Name == "Floor"
			or hitPart.Name:find("Ground")
			or hitPart.Name:find("Floor")
			or hitPart:IsA("Terrain")
			or hitPart.Parent == workspace
			or (hitPart.Parent and (hitPart.Parent.Name == "Map" or hitPart.Parent.Name == "Environment"))
		)

		-- Also accept if it's clearly not a building (no Owner, not a Model with health)
		local isNotBuilding = (
			not hitPart:FindFirstChild("Owner")
			and not hitPart:FindFirstChild("Health")
			and not (hitPart.Parent and hitPart.Parent:FindFirstChild("Owner"))
		)

		if not isGroundLike and not isNotBuilding then
			-- Hit something that looks like a building - invalid
			isValidPlacement = false
			setPreviewValid(previewModel, false)
			return
		end

		-- Get player position for range check
		local character = player.Character
		local playerPos = character and character:FindFirstChild("HumanoidRootPart")
			and character.HumanoidRootPart.Position
			or Vector3.new(0, 0, 0)

		-- Snap the hit position to grid first
		local snappedPosition = snapToGrid(Vector3.new(
			hitPosition.X,
			hitPosition.Y + selectedItem.size.Y/2,
			hitPosition.Z
		))

		-- Check if snapped position is within range
		local toSnapped = Vector3.new(snappedPosition.X - playerPos.X, 0, snappedPosition.Z - playerPos.Z)
		local snappedDistance = toSnapped.Magnitude

		-- Check if this position is valid (within range AND passes collision check)
		local withinRange = snappedDistance <= PLACEMENT_RANGE
		local passesCollision = checkPlacementValid(snappedPosition, selectedItem.size)

		-- Check affordability
		if not currentGold or currentGold == 0 then
			currentGold = getCurrentGold() or 0
		end
		local canAfford = (currentGold or 0) >= selectedItem.cost

		-- Position is valid only if all checks pass
		local positionIsValid = withinRange and passesCollision and canAfford

		if positionIsValid then
			-- This is a valid position - update preview and store it
			lastValidPosition = snappedPosition
			isValidPlacement = true

			if previewModel.PrimaryPart then
				local rotationCFrame = CFrame.Angles(0, math.rad(currentRotation), 0)
				previewModel:SetPrimaryPartCFrame(CFrame.new(snappedPosition) * rotationCFrame)
			end

			local rangeIndicator = previewModel:FindFirstChild("RangeIndicator")
			if rangeIndicator then
				rangeIndicator.CFrame = CFrame.new(snappedPosition.X, hitPosition.Y + 0.5, snappedPosition.Z) * CFrame.Angles(0, 0, math.rad(90))
			end

			setPreviewValid(previewModel, true)
		else
			-- Invalid position - keep preview at last valid position if we have one
			if lastValidPosition and previewModel.PrimaryPart then
				-- Stay at last valid position and show as valid (green)
				local rotationCFrame = CFrame.Angles(0, math.rad(currentRotation), 0)
				previewModel:SetPrimaryPartCFrame(CFrame.new(lastValidPosition) * rotationCFrame)

				local rangeIndicator = previewModel:FindFirstChild("RangeIndicator")
				if rangeIndicator then
					rangeIndicator.CFrame = CFrame.new(lastValidPosition.X, hitPosition.Y + 0.5, lastValidPosition.Z) * CFrame.Angles(0, 0, math.rad(90))
				end

				-- Show green since we're at a valid position - can still place here
				setPreviewValid(previewModel, true)
				isValidPlacement = true
			else
				-- No valid position found yet - clamp to range edge and show red
				local toHit = Vector3.new(hitPosition.X - playerPos.X, 0, hitPosition.Z - playerPos.Z)
				local distanceXZ = toHit.Magnitude

				local clampedPosition = snappedPosition
				if distanceXZ > PLACEMENT_RANGE and toHit.Magnitude > 0 then
					local direction = toHit.Unit
					clampedPosition = snapToGrid(Vector3.new(
						playerPos.X + direction.X * (PLACEMENT_RANGE - 2),
						hitPosition.Y + selectedItem.size.Y/2,
						playerPos.Z + direction.Z * (PLACEMENT_RANGE - 2)
					))
				end

				if previewModel.PrimaryPart then
					local rotationCFrame = CFrame.Angles(0, math.rad(currentRotation), 0)
					previewModel:SetPrimaryPartCFrame(CFrame.new(clampedPosition) * rotationCFrame)
				end

				local rangeIndicator = previewModel:FindFirstChild("RangeIndicator")
				if rangeIndicator then
					rangeIndicator.CFrame = CFrame.new(clampedPosition.X, hitPosition.Y + 0.5, clampedPosition.Z) * CFrame.Angles(0, 0, math.rad(90))
				end

				setPreviewValid(previewModel, false)
				isValidPlacement = false
			end
		end
	else
		isValidPlacement = false
		setPreviewValid(previewModel, false)
	end
end

-- Helper: Rotate placement
local function rotatePlacement()
	if not isPlacementMode then return end
	currentRotation = (currentRotation + 90) % 360
	print("PlacementSystem: Rotated to", currentRotation, "degrees")
end

-- Helper: Format stats for display
local function formatStats(itemData)
	local stats = itemData.stats
	local text = "Cost: " .. itemData.cost .. " Gold\n"

	-- Show workshop requirement if applicable
	if REQUIRES_WORKSHOP[itemData.name] then
		local hasWorkshop = playerHasWorkshop()
		if hasWorkshop then
			text = text .. "Requires: Workshop (OK)\n\n"
		else
			text = text .. "Requires: Workshop (NEEDED)\n\n"
		end
	else
		text = text .. "\n"
	end

	-- Show build time
	text = text .. "Build Time: " .. (itemData.buildTime or 0) .. "s\n"

	if itemData.category == "Turrets" then
		text = text .. "Damage: " .. stats.damage .. "\n"
		text = text .. "Fire Rate: " .. stats.fireRate .. "\n"
		text = text .. "Range: " .. stats.range .. " studs\n"
		text = text .. "Health: " .. stats.health .. "\n\n"
	elseif itemData.category == "Maze" then
		text = text .. "Health: " .. stats.health .. "\n\n"
	elseif itemData.category == "Defense" then
		text = text .. "Health: " .. stats.health .. "\n\n"
	elseif itemData.category == "Farms" then
		text = text .. "Income: " .. stats.income .. "\n"
		text = text .. "Health: " .. stats.health .. "\n\n"
	elseif itemData.category == "Utility" then
		text = text .. "Health: " .. stats.health .. "\n\n"
	elseif itemData.category == "Auras" then
		text = text .. "Health: " .. stats.health .. "\n"
		text = text .. "Range: " .. stats.range .. " studs\n\n"
	end

	text = text .. stats.description

	if itemData.category == "Defense" then
		text = text .. "\n\nPress R to rotate"
	end

	return text
end

-- Helper: Show info panel
local function showInfoPanel(itemData)
	itemNameLabel.Text = itemData.displayName
	itemStatsLabel.Text = formatStats(itemData)
end

-- Helper: Hide info panel (reset to default)
local function hideInfoPanel()
	itemNameLabel.Text = "Select an item"
	itemStatsLabel.Text = "Hover over an item to see details"
end

-- Helper: Update tab appearance
local function updateTabAppearance()
	for catId, tabData in pairs(categoryTabs) do
		if catId == selectedCategory then
			tabData.button.BackgroundColor3 = tabData.color
			tabData.button.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			tabData.button.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
			tabData.button.TextColor3 = Color3.fromRGB(150, 150, 170)
		end
	end
end

-- Build menu functions
populateBuildMenu = function()
	-- Only read from UI if currentGold hasn't been set by event yet
	if not currentGold or currentGold == 0 then
		currentGold = getCurrentGold() or 0
	end
	local hasWorkshop = playerHasWorkshop()

	-- Clear existing buttons
	for _, child in ipairs(itemList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Update tab visuals
	updateTabAppearance()

	-- Filter items by selected category
	for _, itemData in ipairs(BUILDABLE_ITEMS) do
		local itemTabCategory = CATEGORY_MAP[itemData.category]
		if itemTabCategory ~= selectedCategory then
			continue
		end

		local needsWorkshop = REQUIRES_WORKSHOP[itemData.name]
		local meetsRequirements = (not needsWorkshop) or hasWorkshop
		local canAfford = (currentGold or 0) >= (itemData.cost or 0)

		local button = Instance.new("TextButton")
		button.Name = itemData.displayName
		button.Size = UDim2.new(0.95, 0, 0, 36)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.Parent = itemList

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 4)
		btnCorner.Parent = button

		-- Build button text
		local displayText = itemData.displayName
		if needsWorkshop and not hasWorkshop then
			displayText = "[Locked] " .. displayText
		end

		button.Text = displayText .. "  -  " .. itemData.cost .. "g"

		-- Set colors based on affordability and requirements
		if canAfford and meetsRequirements then
			button.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
			button.TextColor3 = Color3.fromRGB(230, 230, 240)
		elseif not meetsRequirements then
			button.BackgroundColor3 = Color3.fromRGB(60, 40, 20)
			button.TextColor3 = Color3.fromRGB(180, 130, 80)
		else
			button.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
			button.TextColor3 = Color3.fromRGB(120, 120, 130)
		end

		button.MouseButton1Click:Connect(function()
			-- Use currentGold from event, fallback to UI if needed
			if not currentGold or currentGold == 0 then
				currentGold = getCurrentGold() or 0
			end
			local needsWorkshop = REQUIRES_WORKSHOP[itemData.name]
			local hasWorkshop = playerHasWorkshop()

			if needsWorkshop and not hasWorkshop then
				print("PlacementSystem:", itemData.displayName, "requires a Workshop")
			elseif (currentGold or 0) >= (itemData.cost or 0) then
				selectItem(itemData)
			else
				print("PlacementSystem: Cannot afford", itemData.displayName)
			end
		end)

		button.MouseEnter:Connect(function()
			showInfoPanel(itemData)
			if canAfford and meetsRequirements then
				button.BackgroundColor3 = Color3.fromRGB(70, 75, 95)
			end
		end)

		button.MouseLeave:Connect(function()
			hideInfoPanel()
			if canAfford and meetsRequirements then
				button.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
			end
		end)
	end
end

-- Set up tab click handlers
for catId, tabData in pairs(categoryTabs) do
	tabData.button.MouseButton1Click:Connect(function()
		selectedCategory = catId
		populateBuildMenu()
	end)
end

function selectItem(itemData)
	print("PlacementSystem: Selected", itemData.displayName)
	selectedItem = itemData
	currentRotation = 0
	closeBuildMenu()
	enterPlacementMode()
end

function openBuildMenu()
	buildMenu.Visible = true
	isBuildMenuOpen = true
	-- Refresh gold from UI when opening menu
	local uiGold = getCurrentGold() or 0
	if uiGold > (currentGold or 0) then
		currentGold = uiGold
	end
	populateBuildMenu()
	print("PlacementSystem: Build menu opened")
end

function closeBuildMenu()
	buildMenu.Visible = false
	isBuildMenuOpen = false
	hideInfoPanel()
	print("PlacementSystem: Build menu closed")
end

function toggleBuildMenu()
	if isBuildMenuOpen then
		closeBuildMenu()
	else
		openBuildMenu()
	end
end

function enterPlacementMode()
	if not selectedItem then
		warn("PlacementSystem: No item selected!")
		return
	end

	isPlacementMode = true
	currentRotation = 0
	lastValidPosition = nil -- Reset last valid position
	createPreview(selectedItem)
	showPlacementRangeIndicator()
	print("PlacementSystem: Entered placement mode for", selectedItem.displayName)
end

exitPlacementMode = function()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end

	hidePlacementRangeIndicator()

	isPlacementMode = false
	isValidPlacement = false
	selectedItem = nil
	currentRotation = 0
	lastValidPosition = nil -- Reset last valid position
	print("PlacementSystem: Exited placement mode")
end

function confirmPlacement()
	if not isPlacementMode or not previewModel or not isValidPlacement or not selectedItem then
		if isPlacementMode and not isValidPlacement then
			print("PlacementSystem: Invalid placement location")
		end
		return
	end

	local position
	if previewModel.PrimaryPart then
		position = previewModel.PrimaryPart.Position
	else
		warn("PlacementSystem: No PrimaryPart found")
		return
	end

	placeItemEvent:FireServer(selectedItem.name, position, currentRotation)
	print("PlacementSystem: Requested placement of", selectedItem.displayName, "at", position, "with rotation", currentRotation)

	-- Predict new gold after placement and exit if can't afford another
	local predictedGold = currentGold - selectedItem.cost
	if predictedGold < selectedItem.cost then
		print("PlacementSystem: Can't afford another " .. selectedItem.displayName .. ", exiting placement mode")
		exitPlacementMode()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.B then
		toggleBuildMenu()
	end

	if input.KeyCode == Enum.KeyCode.R and isPlacementMode then
		rotatePlacement()
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and isPlacementMode then
		confirmPlacement()
	end

	if (input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape) then
		if isPlacementMode then
			exitPlacementMode()
		elseif isBuildMenuOpen then
			closeBuildMenu()
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if isPlacementMode and previewModel and selectedItem then
		updatePreview()
		updatePlacementRangeIndicator()
	end
end)

print("PlacementSystem ready - Press B to open build menu")
