local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run on game servers (reserved servers)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("SellSystemServer: Lobby server - disabled")
	return
end

print("SellSystemServer: Starting...")

-- Wait for RoundManager
wait(2)
local RoundManager = _G.RoundManager

-- Settings
local SELL_PERCENTAGE = 0.5
local MAX_SELL_DISTANCE = 50

-- Item costs (must match build menu)
local ITEM_COSTS = {
	Turret = 50,
	FastTurret = 75,
	SlowTurret = 30,
	FrostTurret = 100,
	PoisonTurret = 90,
	MultiShotTurret = 120,
	CannonTurret = 150,
	Wall = 25,
	Farm = 75,
	Workshop = 150
}

-- Create remote event
local sellBuildingEvent = ReplicatedStorage:FindFirstChild("SellBuilding")
if not sellBuildingEvent then
	sellBuildingEvent = Instance.new("RemoteEvent")
	sellBuildingEvent.Name = "SellBuilding"
	sellBuildingEvent.Parent = ReplicatedStorage
end

-- Helper: Calculate sell value
local function getSellValue(buildingName)
	local originalCost = ITEM_COSTS[buildingName] or 0
	return math.floor(originalCost * SELL_PERCENTAGE)
end

-- Helper: Validate building is close enough
local function isWithinRange(player, building)
	if not player.Character then return false end

	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end

	local buildingPos
	if building:IsA("Model") and building.PrimaryPart then
		buildingPos = building.PrimaryPart.Position
	elseif building:IsA("BasePart") then
		buildingPos = building.Position
	else
		return false
	end

	local distance = (humanoidRootPart.Position - buildingPos).Magnitude
	return distance <= MAX_SELL_DISTANCE
end

-- Handle sell request
sellBuildingEvent.OnServerEvent:Connect(function(player, building)
	print("SellSystemServer: Sell request from", player.Name, "for", building)

	-- Wait for RoundManager if not loaded
	if not RoundManager then
		print("SellSystemServer: Waiting for RoundManager...")
		local attempts = 0
		while not RoundManager and attempts < 20 do
			wait(0.1)
			RoundManager = _G.RoundManager
			attempts = attempts + 1
		end
	end

	if not RoundManager or not RoundManager.playerStats then
		warn("SellSystemServer: RoundManager not available")
		return
	end

	-- Validate building exists
	if not building or not building.Parent then
		warn("SellSystemServer: Invalid building")
		return
	end

	-- Validate distance
	if not isWithinRange(player, building) then
		warn("SellSystemServer:", player.Name, "too far from building")
		return
	end

	-- Validate building type
	local buildingName = building.Name
	if not ITEM_COSTS[buildingName] then
		warn("SellSystemServer: Unknown building type:", buildingName)
		return
	end

	-- Calculate sell value
	local sellValue = getSellValue(buildingName)
	print("SellSystemServer:", player.Name, "selling", buildingName, "for", sellValue, "gold")

	-- Give gold
	RoundManager.initPlayerStats(player)
	RoundManager.playerStats[player.Name].gold = RoundManager.playerStats[player.Name].gold + sellValue
	print("SellSystemServer:", player.Name, "received", sellValue, "gold. New total:", RoundManager.playerStats[player.Name].gold)

	RoundManager.broadcastPlayerStats()

	-- Destroy building
	building:Destroy()
	print("SellSystemServer: Building destroyed")

	-- Notify player
	local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
	if showNotification then
		showNotification:FireClient(player, "Sold " .. buildingName .. " for " .. sellValue .. " gold!", Color3.new(0, 1, 0))
	end
end)

print("SellSystemServer: Loaded - Players can sell buildings for 50% refund")