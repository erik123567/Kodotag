local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("UpgradeManager: Starting...")

-- Wait for RoundManager
wait(2)
local RoundManager = _G.RoundManager

-- Upgrade definitions
local UPGRADES = {
	ReinforcedStructures = {
		name = "Reinforced Structures",
		description = "+25% HP to all structures",
		maxLevel = 5,
		baseCost = 100,
		costMultiplier = 1.5,
		effect = 0.25, -- 25% per level
		baseTime = 10,
		timeMultiplier = 1.5
	},
	EnhancedDamage = {
		name = "Enhanced Damage",
		description = "+15% turret damage",
		maxLevel = 5,
		baseCost = 125,
		costMultiplier = 1.5,
		effect = 0.15,
		baseTime = 12,
		timeMultiplier = 1.5
	},
	RapidFire = {
		name = "Rapid Fire",
		description = "+15% fire rate (reduced cooldown)",
		maxLevel = 5,
		baseCost = 150,
		costMultiplier = 1.5,
		effect = 0.15,
		baseTime = 15,
		timeMultiplier = 1.5
	},
	ExtendedRange = {
		name = "Extended Range",
		description = "+10% turret range",
		maxLevel = 5,
		baseCost = 100,
		costMultiplier = 1.5,
		effect = 0.10,
		baseTime = 10,
		timeMultiplier = 1.5
	},
	EfficientFarms = {
		name = "Efficient Farms",
		description = "+1 gold per farm per tick",
		maxLevel = 3,
		baseCost = 200,
		costMultiplier = 2.0,
		effect = 1, -- +1 gold per level
		baseTime = 20,
		timeMultiplier = 1.5
	},
	BountyHunter = {
		name = "Bounty Hunter",
		description = "+5 gold per Kodo kill",
		maxLevel = 5,
		baseCost = 150,
		costMultiplier = 1.75,
		effect = 5,
		baseTime = 12,
		timeMultiplier = 1.5
	}
}

-- Track active upgrades in progress
local activeUpgrades = {} -- [playerName] = {upgradeId, endTime, startTime}

-- Player upgrade data
local playerUpgrades = {}

-- Initialize player upgrades
local function initPlayerUpgrades(player)
	if not playerUpgrades[player.Name] then
		playerUpgrades[player.Name] = {
			ReinforcedStructures = 0,
			EnhancedDamage = 0,
			RapidFire = 0,
			ExtendedRange = 0,
			EfficientFarms = 0,
			BountyHunter = 0
		}
		print("UpgradeManager: Initialized upgrades for", player.Name)
	end
	return playerUpgrades[player.Name]
end

-- Get upgrade cost for next level
local function getUpgradeCost(upgradeId, currentLevel)
	local upgrade = UPGRADES[upgradeId]
	if not upgrade then return 999999 end
	if currentLevel >= upgrade.maxLevel then return 999999 end

	return math.floor(upgrade.baseCost * (upgrade.costMultiplier ^ currentLevel))
end

-- Get upgrade time for next level
local function getUpgradeTime(upgradeId, currentLevel)
	local upgrade = UPGRADES[upgradeId]
	if not upgrade then return 999 end
	if currentLevel >= upgrade.maxLevel then return 999 end

	return math.floor(upgrade.baseTime * (upgrade.timeMultiplier ^ currentLevel))
end

-- Get player's upgrade level
local function getUpgradeLevel(playerName, upgradeId)
	if not playerUpgrades[playerName] then return 0 end
	return playerUpgrades[playerName][upgradeId] or 0
end

-- Check if player has an upgrade in progress
local function hasUpgradeInProgress(playerName)
	return activeUpgrades[playerName] ~= nil
end

-- Get active upgrade info
local function getActiveUpgrade(playerName)
	return activeUpgrades[playerName]
end

-- Create remote events
local purchaseUpgradeEvent = ReplicatedStorage:FindFirstChild("PurchaseUpgrade")
if not purchaseUpgradeEvent then
	purchaseUpgradeEvent = Instance.new("RemoteEvent")
	purchaseUpgradeEvent.Name = "PurchaseUpgrade"
	purchaseUpgradeEvent.Parent = ReplicatedStorage
end

local getUpgradesEvent = ReplicatedStorage:FindFirstChild("GetUpgrades")
if not getUpgradesEvent then
	getUpgradesEvent = Instance.new("RemoteFunction")
	getUpgradesEvent.Name = "GetUpgrades"
	getUpgradesEvent.Parent = ReplicatedStorage
end

local upgradesPurchasedEvent = ReplicatedStorage:FindFirstChild("UpgradesPurchased")
if not upgradesPurchasedEvent then
	upgradesPurchasedEvent = Instance.new("RemoteEvent")
	upgradesPurchasedEvent.Name = "UpgradesPurchased"
	upgradesPurchasedEvent.Parent = ReplicatedStorage
end

local upgradeProgressEvent = ReplicatedStorage:FindFirstChild("UpgradeProgress")
if not upgradeProgressEvent then
	upgradeProgressEvent = Instance.new("RemoteEvent")
	upgradeProgressEvent.Name = "UpgradeProgress"
	upgradeProgressEvent.Parent = ReplicatedStorage
end

-- Handle get upgrades request
getUpgradesEvent.OnServerInvoke = function(player)
	initPlayerUpgrades(player)

	local upgradeData = {}
	for upgradeId, upgrade in pairs(UPGRADES) do
		local currentLevel = getUpgradeLevel(player.Name, upgradeId)
		upgradeData[upgradeId] = {
			name = upgrade.name,
			description = upgrade.description,
			maxLevel = upgrade.maxLevel,
			currentLevel = currentLevel,
			cost = getUpgradeCost(upgradeId, currentLevel),
			upgradeTime = getUpgradeTime(upgradeId, currentLevel),
			effect = upgrade.effect
		}
	end

	-- Include active upgrade info
	local active = getActiveUpgrade(player.Name)
	local activeUpgradeInfo = nil
	if active then
		local remaining = active.endTime - tick()
		if remaining > 0 then
			activeUpgradeInfo = {
				upgradeId = active.upgradeId,
				remainingTime = remaining,
				totalTime = active.endTime - active.startTime
			}
		end
	end

	return upgradeData, activeUpgradeInfo
end

-- Handle purchase request
purchaseUpgradeEvent.OnServerEvent:Connect(function(player, upgradeId)
	print("UpgradeManager: Purchase request from", player.Name, "for", upgradeId)

	-- Wait for RoundManager if not loaded
	if not RoundManager then
		local attempts = 0
		while not RoundManager and attempts < 20 do
			wait(0.1)
			RoundManager = _G.RoundManager
			attempts = attempts + 1
		end
	end

	if not RoundManager or not RoundManager.playerStats then
		warn("UpgradeManager: RoundManager not available")
		return
	end

	-- Validate upgrade exists
	if not UPGRADES[upgradeId] then
		warn("UpgradeManager: Invalid upgrade:", upgradeId)
		return
	end

	-- Check if player already has an upgrade in progress
	if hasUpgradeInProgress(player.Name) then
		local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
		if showNotification then
			showNotification:FireClient(player, "Already researching an upgrade!", Color3.new(1, 0.5, 0))
		end
		print("UpgradeManager:", player.Name, "already has an upgrade in progress")
		return
	end

	initPlayerUpgrades(player)
	local currentLevel = getUpgradeLevel(player.Name, upgradeId)
	local upgrade = UPGRADES[upgradeId]

	-- Check max level
	if currentLevel >= upgrade.maxLevel then
		print("UpgradeManager: Already at max level for", upgradeId)
		return
	end

	-- Check cost
	local cost = getUpgradeCost(upgradeId, currentLevel)
	local stats = RoundManager.playerStats[player.Name]

	if not stats then
		RoundManager.initPlayerStats(player)
		stats = RoundManager.playerStats[player.Name]
	end

	if stats.gold < cost then
		print("UpgradeManager: Not enough gold. Have:", stats.gold, "Need:", cost)
		return
	end

	-- Deduct gold
	stats.gold = stats.gold - cost
	RoundManager.broadcastPlayerStats()

	-- Get upgrade time
	local upgradeTime = getUpgradeTime(upgradeId, currentLevel)
	local startTime = tick()
	local endTime = startTime + upgradeTime

	-- Set active upgrade
	activeUpgrades[player.Name] = {
		upgradeId = upgradeId,
		startTime = startTime,
		endTime = endTime,
		targetLevel = currentLevel + 1
	}

	print("UpgradeManager:", player.Name, "started researching", upgrade.name, "level", currentLevel + 1, "for", cost, "gold (", upgradeTime, "seconds)")

	-- Show notification
	local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
	if showNotification then
		showNotification:FireClient(player, "Researching " .. upgrade.name .. " (" .. upgradeTime .. "s)", Color3.new(1, 0.8, 0))
	end

	-- Send initial progress
	upgradeProgressEvent:FireClient(player, upgradeId, 0, upgradeTime)

	-- Upgrade progress loop
	task.spawn(function()
		while tick() < endTime do
			-- Check if player disconnected
			if not player.Parent then
				activeUpgrades[player.Name] = nil
				return
			end

			local elapsed = tick() - startTime
			local progress = elapsed / upgradeTime

			-- Send progress update
			upgradeProgressEvent:FireClient(player, upgradeId, progress, upgradeTime - elapsed)

			wait(0.5)
		end

		-- Complete upgrade
		if activeUpgrades[player.Name] and activeUpgrades[player.Name].upgradeId == upgradeId then
			playerUpgrades[player.Name][upgradeId] = currentLevel + 1
			activeUpgrades[player.Name] = nil

			print("UpgradeManager:", player.Name, "completed", upgrade.name, "level", currentLevel + 1)

			-- Notify client of completion
			upgradesPurchasedEvent:FireClient(player, upgradeId, currentLevel + 1)
			upgradeProgressEvent:FireClient(player, nil, 1, 0) -- Clear progress

			if showNotification then
				showNotification:FireClient(player, upgrade.name .. " level " .. (currentLevel + 1) .. " complete!", Color3.new(0.5, 1, 0.5))
			end
		end
	end)
end)

-- Expose upgrade data globally for other systems
_G.UpgradeManager = {
	getUpgradeLevel = function(playerName, upgradeId)
		return getUpgradeLevel(playerName, upgradeId)
	end,

	getUpgradeEffect = function(playerName, upgradeId)
		local level = getUpgradeLevel(playerName, upgradeId)
		local upgrade = UPGRADES[upgradeId]
		if not upgrade then return 0 end
		return level * upgrade.effect
	end,

	UPGRADES = UPGRADES
}

-- Initialize existing players
for _, player in ipairs(Players:GetPlayers()) do
	initPlayerUpgrades(player)
end

-- Handle new players
Players.PlayerAdded:Connect(function(player)
	initPlayerUpgrades(player)
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	playerUpgrades[player.Name] = nil
end)

print("UpgradeManager: Loaded!")
