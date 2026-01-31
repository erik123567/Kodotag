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
local PLACEMENT_RANGE = 50

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
		size = Vector3.new(2, 5, 2),
		category = "Maze",
		stats = {
			health = 75,
			description = "Maze pillar. 3-stud gaps let players kite through but Kodos can't fit. Spam these to build mazes!"
		}
	},
	{
		name = "Wall",
		displayName = "Reinforced Wall",
		cost = 60,
		buildTime = 4,
		size = Vector3.new(12, 8, 2),
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
	}
}

-- State
local isPlacementMode = false
local isBuildMenuOpen = false
local previewModel = nil
local isValidPlacement = false
local selectedItem = nil
local currentRotation = 0
local currentGold = 0

-- UI References
local goldDisplayGui = playerGui:WaitForChild("GoldDisplayGui")

-- Create Build Menu UI if it doesn't exist
local buildMenu = goldDisplayGui:FindFirstChild("BuildMenu")
if not buildMenu then
	buildMenu = Instance.new("Frame")
	buildMenu.Name = "BuildMenu"
	buildMenu.Size = UDim2.new(0, 450, 0, 350)
	buildMenu.Position = UDim2.new(0.5, -225, 0.5, -175)
	buildMenu.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
	buildMenu.BackgroundTransparency = 0.1
	buildMenu.BorderSizePixel = 2
	buildMenu.BorderColor3 = Color3.new(1, 1, 1)
	buildMenu.Visible = false
	buildMenu.Parent = goldDisplayGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = buildMenu

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Build Menu (B to close)"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = buildMenu

	print("PlacementSystem: Created BuildMenu")
end

-- Create ItemList if it doesn't exist
local itemList = buildMenu:FindFirstChild("ItemList")
if not itemList then
	itemList = Instance.new("ScrollingFrame")
	itemList.Name = "ItemList"
	itemList.Size = UDim2.new(0.5, -10, 1, -50)
	itemList.Position = UDim2.new(0, 5, 0, 45)
	itemList.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	itemList.BackgroundTransparency = 0.5
	itemList.BorderSizePixel = 0
	itemList.ScrollBarThickness = 6
	itemList.Parent = buildMenu

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 5)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = itemList

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 5)
	listPadding.Parent = itemList

	print("PlacementSystem: Created ItemList")
end

-- Create InfoPanel if it doesn't exist
local infoPanel = buildMenu:FindFirstChild("InfoPanel")
if not infoPanel then
	infoPanel = Instance.new("Frame")
	infoPanel.Name = "InfoPanel"
	infoPanel.Size = UDim2.new(0.5, -10, 1, -50)
	infoPanel.Position = UDim2.new(0.5, 5, 0, 45)
	infoPanel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	infoPanel.BackgroundTransparency = 0.5
	infoPanel.BorderSizePixel = 0
	infoPanel.Visible = false
	infoPanel.Parent = buildMenu

	print("PlacementSystem: Created InfoPanel")
end

-- Create ItemName label if it doesn't exist
local itemNameLabel = infoPanel:FindFirstChild("ItemName")
if not itemNameLabel then
	itemNameLabel = Instance.new("TextLabel")
	itemNameLabel.Name = "ItemName"
	itemNameLabel.Size = UDim2.new(1, -10, 0, 30)
	itemNameLabel.Position = UDim2.new(0, 5, 0, 5)
	itemNameLabel.BackgroundTransparency = 1
	itemNameLabel.Text = "Item Name"
	itemNameLabel.TextColor3 = Color3.new(1, 0.84, 0)
	itemNameLabel.TextScaled = true
	itemNameLabel.Font = Enum.Font.GothamBold
	itemNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemNameLabel.Parent = infoPanel

	print("PlacementSystem: Created ItemName label")
end

-- Create ItemStats label if it doesn't exist
local itemStatsLabel = infoPanel:FindFirstChild("ItemStats")
if not itemStatsLabel then
	itemStatsLabel = Instance.new("TextLabel")
	itemStatsLabel.Name = "ItemStats"
	itemStatsLabel.Size = UDim2.new(1, -10, 1, -45)
	itemStatsLabel.Position = UDim2.new(0, 5, 0, 40)
	itemStatsLabel.BackgroundTransparency = 1
	itemStatsLabel.Text = ""
	itemStatsLabel.TextColor3 = Color3.new(1, 1, 1)
	itemStatsLabel.TextSize = 14
	itemStatsLabel.Font = Enum.Font.Gotham
	itemStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemStatsLabel.TextYAlignment = Enum.TextYAlignment.Top
	itemStatsLabel.TextWrapped = true
	itemStatsLabel.Parent = infoPanel

	print("PlacementSystem: Created ItemStats label")
end

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

-- Listen for gold updates
local updatePlayerStatsEvent = ReplicatedStorage:FindFirstChild("UpdatePlayerStats")
if updatePlayerStatsEvent then
	updatePlayerStatsEvent.OnClientEvent:Connect(function(stats)
		currentGold = stats.gold
		-- Update button colors if menu is open
		if isBuildMenuOpen then
			updateButtonAffordability()
		end
	end)
end

print("PlacementSystem: Found PlaceItem event")
print("PlacementSystem: Loaded")

-- Helper: Get current gold from UI
local function getCurrentGold()
	if not goldText then return 0 end
	local goldString = goldText.Text
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

-- Helper: Update button colors based on affordability and workshop requirement
local function updateButtonAffordability()
	currentGold = getCurrentGold()
	local hasWorkshop = playerHasWorkshop()

	for _, child in ipairs(itemList:GetChildren()) do
		if child:IsA("TextButton") then
			-- Find the item data for this button
			local itemName = child.Name
			for _, itemData in ipairs(BUILDABLE_ITEMS) do
				if itemData.displayName == itemName then
					local needsWorkshop = REQUIRES_WORKSHOP[itemData.name]
					local canAfford = currentGold >= itemData.cost
					local meetsRequirements = (not needsWorkshop) or hasWorkshop

					if canAfford and meetsRequirements then
						-- Can afford and meets requirements - normal colors
						child.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
						child.TextColor3 = Color3.new(1, 1, 1)
					elseif not meetsRequirements then
						-- Missing workshop - orange/locked
						child.BackgroundColor3 = Color3.new(0.25, 0.15, 0.05)
						child.TextColor3 = Color3.new(0.6, 0.4, 0.2)
					else
						-- Can't afford - red/grayed out
						child.BackgroundColor3 = Color3.new(0.2, 0.1, 0.1)
						child.TextColor3 = Color3.new(0.5, 0.5, 0.5)
					end
					break
				end
			end
		end
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
				-- Barricades are 2x2 pillars - allow close placement for maze building
				-- Grid is 5 studs, so barricades 5 studs apart have 3-stud gaps (player fits, Kodo doesn't)
				-- Block only if overlapping (within 2 studs center-to-center)
				if isBarricade and dist < 2 then
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
			end
		end
	end

	return true
end

-- Helper: Create preview based on item type
local function createPreview(itemData)
	if previewModel then
		previewModel:Destroy()
	end

	local preview = Instance.new("Model")
	preview.Name = "PreviewModel"

	if itemData.category == "Turrets" then
		local base = Instance.new("Part")
		base.Name = "Base"
		base.Size = itemData.size
		base.Anchored = true
		base.CanCollide = false
		base.Material = Enum.Material.Metal
		base.Transparency = 0.5
		base.Color = Color3.new(0, 1, 0)
		base.Parent = preview

		preview.PrimaryPart = base

		if itemData.stats and itemData.stats.range then
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
			rangeCircle.Parent = preview
		end

	elseif itemData.category == "Maze" then
		-- Barricade - square maze obstacle
		local barricade = Instance.new("Part")
		barricade.Name = "Barricade"
		barricade.Size = itemData.size
		barricade.Anchored = true
		barricade.CanCollide = false
		barricade.Material = Enum.Material.Wood
		barricade.Transparency = 0.5
		barricade.Color = Color3.new(0, 1, 0)
		barricade.Parent = preview

		preview.PrimaryPart = barricade

	elseif itemData.category == "Defense" then
		-- Reinforced Wall - heavy defensive structure
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Size = itemData.size
		wall.Anchored = true
		wall.CanCollide = false
		wall.Material = Enum.Material.Concrete
		wall.Transparency = 0.5
		wall.Color = Color3.new(0, 1, 0)
		wall.Parent = preview

		preview.PrimaryPart = wall

	elseif itemData.category == "Farms" then
		local farm = Instance.new("Part")
		farm.Name = "Farm"
		farm.Size = itemData.size
		farm.Anchored = true
		farm.CanCollide = false
		farm.Material = Enum.Material.Grass
		farm.Transparency = 0.5
		farm.Color = Color3.new(0, 1, 0)
		farm.Parent = preview

		preview.PrimaryPart = farm

	elseif itemData.category == "Utility" then
		local building = Instance.new("Part")
		building.Name = itemData.name
		building.Size = itemData.size
		building.Anchored = true
		building.CanCollide = false
		building.Material = Enum.Material.WoodPlanks
		building.Transparency = 0.5
		building.Color = Color3.new(0, 1, 0)
		building.Parent = preview

		preview.PrimaryPart = building
	end

	preview.Parent = workspace
	previewModel = preview

	print("PlacementSystem: Created preview for", itemData.displayName)
	return preview
end

-- Helper: Update preview
local function updatePreview()
	if not previewModel or not isPlacementMode or not selectedItem then return end

	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	-- Filter out character, preview, AND all buildings
	local filterList = {player.Character, previewModel}

	-- Add all turrets, walls, barricades, farms, and workshops to filter list
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "Turret" or obj.Name == "FastTurret" or obj.Name == "SlowTurret"
			or obj.Name == "FrostTurret" or obj.Name == "PoisonTurret"
			or obj.Name == "MultiShotTurret" or obj.Name == "CannonTurret"
			or obj.Name == "Wall" or obj.Name == "Barricade" or obj.Name == "Farm" or obj.Name == "Workshop" then
			table.insert(filterList, obj)
		end
	end

	raycastParams.FilterDescendantsInstances = filterList

	local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)

	if raycastResult then
		-- Check if we hit the ground (not a building)
		local hitPart = raycastResult.Instance
		local hitGround = (hitPart.Name == "Baseplate" or hitPart:IsA("Terrain") or hitPart.Parent == workspace)

		if not hitGround then
			-- Hit something other than ground - invalid
			isValidPlacement = false
			for _, part in ipairs(previewModel:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Color = Color3.new(1, 0, 0)
				end
			end
			return
		end

		local hitPosition = raycastResult.Position
		local snappedPosition = snapToGrid(Vector3.new(
			hitPosition.X,
			hitPosition.Y + selectedItem.size.Y/2,
			hitPosition.Z
			))

		isValidPlacement = checkPlacementValid(snappedPosition, selectedItem.size)

		-- Also check if player can afford it
		currentGold = getCurrentGold()
		if currentGold < selectedItem.cost then
			isValidPlacement = false
		end

		if previewModel.PrimaryPart then
			local rotationCFrame = CFrame.Angles(0, math.rad(currentRotation), 0)
			previewModel:SetPrimaryPartCFrame(CFrame.new(snappedPosition) * rotationCFrame)
		end

		local rangeIndicator = previewModel:FindFirstChild("RangeIndicator")
		if rangeIndicator then
			rangeIndicator.CFrame = CFrame.new(snappedPosition.X, hitPosition.Y + 0.5, snappedPosition.Z) * CFrame.Angles(0, 0, math.rad(90))
		end

		local color = isValidPlacement and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
		for _, part in ipairs(previewModel:GetDescendants()) do
			if part:IsA("BasePart") then
				if part.Name == "RangeIndicator" then
					part.Color = color
					part.Transparency = 0.8
				else
					part.Color = color
				end
			end
		end
	else
		isValidPlacement = false
		for _, part in ipairs(previewModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = Color3.new(1, 0, 0)
			end
		end
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
	infoPanel.Visible = true
end

-- Helper: Hide info panel
local function hideInfoPanel()
	infoPanel.Visible = false
end

-- Build menu functions
local function populateBuildMenu()
	print("PlacementSystem: populateBuildMenu called")

	currentGold = getCurrentGold()
	local hasWorkshop = playerHasWorkshop()

	for _, child in ipairs(itemList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, itemData in ipairs(BUILDABLE_ITEMS) do
		print("PlacementSystem: Creating button for", itemData.displayName)

		local needsWorkshop = REQUIRES_WORKSHOP[itemData.name]
		local meetsRequirements = (not needsWorkshop) or hasWorkshop

		local button = Instance.new("TextButton")
		button.Name = itemData.displayName
		button.Size = UDim2.new(0.95, 0, 0, 50)
		button.BorderSizePixel = 1
		button.BorderColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.GothamBold
		button.TextScaled = true

		-- Add lock indicator if workshop is required but not built
		if needsWorkshop and not hasWorkshop then
			button.Text = "[LOCKED] " .. itemData.displayName .. " - " .. itemData.cost .. " Gold"
		else
			button.Text = itemData.displayName .. " - " .. itemData.cost .. " Gold"
		end
		button.Parent = itemList

		-- Set colors based on affordability and requirements
		local canAfford = currentGold >= itemData.cost

		if canAfford and meetsRequirements then
			button.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
			button.TextColor3 = Color3.new(1, 1, 1)
		elseif not meetsRequirements then
			button.BackgroundColor3 = Color3.new(0.25, 0.15, 0.05)
			button.TextColor3 = Color3.new(0.6, 0.4, 0.2)
		else
			button.BackgroundColor3 = Color3.new(0.2, 0.1, 0.1)
			button.TextColor3 = Color3.new(0.5, 0.5, 0.5)
		end

		button.MouseButton1Click:Connect(function()
			-- Check affordability and requirements when clicked
			currentGold = getCurrentGold()
			local needsWorkshop = REQUIRES_WORKSHOP[itemData.name]
			local hasWorkshop = playerHasWorkshop()

			if needsWorkshop and not hasWorkshop then
				print("PlacementSystem:", itemData.displayName, "requires a Workshop")
			elseif currentGold >= itemData.cost then
				selectItem(itemData)
			else
				print("PlacementSystem: Cannot afford", itemData.displayName)
			end
		end)

		button.MouseEnter:Connect(function()
			showInfoPanel(itemData)
		end)

		button.MouseLeave:Connect(function()
			hideInfoPanel()
		end)
	end

	print("PlacementSystem: Created", #BUILDABLE_ITEMS, "buttons")
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
	createPreview(selectedItem)
	print("PlacementSystem: Entered placement mode for", selectedItem.displayName)
end

function exitPlacementMode()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end

	isPlacementMode = false
	isValidPlacement = false
	selectedItem = nil
	currentRotation = 0
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
	end
end)

print("PlacementSystem ready - Press B to open build menu")
