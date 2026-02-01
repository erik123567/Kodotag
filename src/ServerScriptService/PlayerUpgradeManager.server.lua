-- PLAYER UPGRADE MANAGER
-- Handles permanent player stat upgrades purchased with gold

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run on game servers
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("PlayerUpgradeManager: Lobby server - disabled")
	return
end

local PlayerUpgradeManager = {}

-- Upgrade definitions
local UPGRADES = {
	MaxHealth = {
		name = "Vitality",
		description = "+20 Max Health",
		baseCost = 50,
		costMultiplier = 1.5,
		maxLevel = 10,
		effect = 20, -- +20 health per level
	},
	MoveSpeed = {
		name = "Swift Feet",
		description = "+1 Movement Speed",
		baseCost = 75,
		costMultiplier = 1.6,
		maxLevel = 8,
		effect = 1, -- +1 speed per level
	},
	MaxEnergy = {
		name = "Endurance",
		description = "+15 Max Energy",
		baseCost = 40,
		costMultiplier = 1.4,
		maxLevel = 10,
		effect = 15, -- +15 energy per level
	},
	EnergyRegen = {
		name = "Second Wind",
		description = "+3 Energy Regen/sec",
		baseCost = 60,
		costMultiplier = 1.5,
		maxLevel = 8,
		effect = 3, -- +3 regen per level
	},
	SprintSpeed = {
		name = "Rush",
		description = "+10% Sprint Speed",
		baseCost = 80,
		costMultiplier = 1.6,
		maxLevel = 5,
		effect = 0.10, -- +10% per level
	},
	GoldBonus = {
		name = "Prospector",
		description = "+10% Gold from all sources",
		baseCost = 100,
		costMultiplier = 1.8,
		maxLevel = 5,
		effect = 0.10, -- +10% per level
	},
}

-- Player upgrade data storage
local playerUpgrades = {}

-- Initialize player upgrades
local function initPlayerUpgrades(player)
	if not playerUpgrades[player.Name] then
		playerUpgrades[player.Name] = {
			MaxHealth = 0,
			MoveSpeed = 0,
			MaxEnergy = 0,
			EnergyRegen = 0,
			SprintSpeed = 0,
			GoldBonus = 0,
		}
	end
	return playerUpgrades[player.Name]
end

-- Get upgrade cost for next level
local function getUpgradeCost(upgradeId, currentLevel)
	local upgrade = UPGRADES[upgradeId]
	if not upgrade then return 999999 end
	return math.floor(upgrade.baseCost * (upgrade.costMultiplier ^ currentLevel))
end

-- Get player's upgrade level
function PlayerUpgradeManager.getUpgradeLevel(playerName, upgradeId)
	local upgrades = playerUpgrades[playerName]
	if upgrades then
		return upgrades[upgradeId] or 0
	end
	return 0
end

-- Get total effect of an upgrade
function PlayerUpgradeManager.getUpgradeEffect(playerName, upgradeId)
	local level = PlayerUpgradeManager.getUpgradeLevel(playerName, upgradeId)
	local upgrade = UPGRADES[upgradeId]
	if upgrade then
		return level * upgrade.effect
	end
	return 0
end

-- Apply stat upgrades to player character
local function applyUpgradesToCharacter(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local upgrades = playerUpgrades[player.Name]
	if not upgrades then return end

	-- Apply max health
	local healthBonus = upgrades.MaxHealth * UPGRADES.MaxHealth.effect
	humanoid.MaxHealth = 100 + healthBonus
	humanoid.Health = humanoid.MaxHealth

	-- Apply move speed
	local speedBonus = upgrades.MoveSpeed * UPGRADES.MoveSpeed.effect
	humanoid.WalkSpeed = 16 + speedBonus

	print("PlayerUpgradeManager: Applied upgrades to", player.Name)
	print("  - MaxHealth:", humanoid.MaxHealth, "(+" .. healthBonus .. ")")
	print("  - WalkSpeed:", humanoid.WalkSpeed, "(+" .. speedBonus .. ")")
end

-- Create remote events
local purchaseUpgrade = Instance.new("RemoteEvent")
purchaseUpgrade.Name = "PurchasePlayerUpgrade"
purchaseUpgrade.Parent = ReplicatedStorage

local getUpgrades = Instance.new("RemoteFunction")
getUpgrades.Name = "GetPlayerUpgrades"
getUpgrades.Parent = ReplicatedStorage

local upgradeApplied = Instance.new("RemoteEvent")
upgradeApplied.Name = "PlayerUpgradeApplied"
upgradeApplied.Parent = ReplicatedStorage

-- Handle upgrade purchase
purchaseUpgrade.OnServerEvent:Connect(function(player, upgradeId)
	local upgrades = initPlayerUpgrades(player)
	local upgrade = UPGRADES[upgradeId]

	if not upgrade then
		warn("PlayerUpgradeManager: Unknown upgrade:", upgradeId)
		return
	end

	local currentLevel = upgrades[upgradeId] or 0

	-- Check max level
	if currentLevel >= upgrade.maxLevel then
		print("PlayerUpgradeManager:", player.Name, "already at max level for", upgradeId)
		return
	end

	-- Get cost
	local cost = getUpgradeCost(upgradeId, currentLevel)

	-- Check if player has enough gold
	local RoundManager = _G.RoundManager
	if not RoundManager or not RoundManager.playerStats then
		warn("PlayerUpgradeManager: RoundManager not available")
		return
	end

	local stats = RoundManager.playerStats[player.Name]
	if not stats then
		warn("PlayerUpgradeManager: No stats for", player.Name)
		return
	end

	if stats.gold < cost then
		print("PlayerUpgradeManager:", player.Name, "can't afford", upgradeId, "(need", cost, "have", stats.gold, ")")
		return
	end

	-- Deduct gold
	stats.gold = stats.gold - cost

	-- Apply upgrade
	upgrades[upgradeId] = currentLevel + 1

	print("PlayerUpgradeManager:", player.Name, "purchased", upgrade.name, "level", upgrades[upgradeId], "for", cost, "gold")

	-- Apply to character immediately
	applyUpgradesToCharacter(player)

	-- Notify client
	upgradeApplied:FireClient(player, upgradeId, upgrades[upgradeId], stats.gold)

	-- Broadcast gold change
	RoundManager.broadcastPlayerStats()
end)

-- Handle get upgrades request
getUpgrades.OnServerInvoke = function(player)
	local upgrades = initPlayerUpgrades(player)

	-- Build response with full info
	local response = {}
	for upgradeId, upgrade in pairs(UPGRADES) do
		local currentLevel = upgrades[upgradeId] or 0
		response[upgradeId] = {
			name = upgrade.name,
			description = upgrade.description,
			level = currentLevel,
			maxLevel = upgrade.maxLevel,
			cost = getUpgradeCost(upgradeId, currentLevel),
			effect = upgrade.effect,
			totalEffect = currentLevel * upgrade.effect,
		}
	end
	return response
end

-- Apply upgrades when character spawns
Players.PlayerAdded:Connect(function(player)
	initPlayerUpgrades(player)

	player.CharacterAdded:Connect(function(character)
		-- Wait for humanoid to load
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			-- Small delay to let other scripts set defaults
			task.delay(0.5, function()
				applyUpgradesToCharacter(player)
			end)
		end
	end)
end)

-- Initialize existing players
for _, player in ipairs(Players:GetPlayers()) do
	initPlayerUpgrades(player)
	if player.Character then
		applyUpgradesToCharacter(player)
	end
end

_G.PlayerUpgradeManager = PlayerUpgradeManager
print("PlayerUpgradeManager: Loaded!")

return PlayerUpgradeManager
