-- REPAIR MANAGER
-- Handles structure repair requests from clients

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run on game servers
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("RepairManager: Lobby - disabled")
	return
end

print("RepairManager: Starting...")

-- Settings
local REPAIR_RATE = 20 -- HP per second
local GOLD_PER_HP = 0.2 -- 1 gold per 5 HP (0.2 gold per HP)
local REPAIR_RANGE = 20 -- Max distance to repair
local REPAIR_COOLDOWN = 0.1 -- Seconds between repair ticks

-- Track last repair time per player
local lastRepairTime = {}

-- Wait for RoundManager
task.wait(2)

-- Create remote event
local repairStructure = Instance.new("RemoteEvent")
repairStructure.Name = "RepairStructure"
repairStructure.Parent = ReplicatedStorage

-- Handle repair requests
repairStructure.OnServerEvent:Connect(function(player, structure)
	-- Cooldown check
	local now = tick()
	if lastRepairTime[player.Name] and now - lastRepairTime[player.Name] < REPAIR_COOLDOWN then
		return
	end
	lastRepairTime[player.Name] = now

	-- Validate structure exists
	if not structure or not structure.Parent then
		return
	end

	-- Validate ownership
	local owner = structure:FindFirstChild("Owner")
	if not owner or owner.Value ~= player.Name then
		return
	end

	-- Get health values
	local health = structure:FindFirstChild("Health")
	local maxHealth = structure:FindFirstChild("MaxHealth")
	if not health or not maxHealth then
		return
	end

	-- Check if already full health
	if health.Value >= maxHealth.Value then
		return
	end

	-- Validate distance
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local structurePos
	if structure:IsA("Model") and structure.PrimaryPart then
		structurePos = structure.PrimaryPart.Position
	elseif structure:IsA("BasePart") then
		structurePos = structure.Position
	else
		return
	end

	local distance = (hrp.Position - structurePos).Magnitude
	if distance > REPAIR_RANGE then
		return
	end

	-- Get player gold from RoundManager
	if not _G.RoundManager or not _G.RoundManager.playerStats then
		return
	end

	local stats = _G.RoundManager.playerStats[player.Name]
	if not stats then
		return
	end

	-- Calculate repair amount this tick
	local repairAmount = math.floor(REPAIR_RATE * REPAIR_COOLDOWN)
	repairAmount = math.min(repairAmount, maxHealth.Value - health.Value) -- Don't overheal

	if repairAmount <= 0 then
		return
	end

	-- Calculate gold cost
	local goldCost = math.ceil(repairAmount * GOLD_PER_HP)

	-- Check if player can afford
	if stats.gold < goldCost then
		-- Repair what they can afford
		local affordableHP = math.floor(stats.gold / GOLD_PER_HP)
		if affordableHP <= 0 then
			return
		end
		repairAmount = math.min(affordableHP, repairAmount)
		goldCost = math.ceil(repairAmount * GOLD_PER_HP)
	end

	-- Apply repair
	health.Value = health.Value + repairAmount

	-- Deduct gold
	stats.gold = stats.gold - goldCost

	-- Broadcast updated stats
	_G.RoundManager.broadcastPlayerStats()

	-- Visual feedback (green particles)
	local part = structure:IsA("Model") and structure.PrimaryPart or structure
	if part then
		-- Create repair particles
		local attachment = part:FindFirstChild("RepairAttachment")
		if not attachment then
			attachment = Instance.new("Attachment")
			attachment.Name = "RepairAttachment"
			attachment.Parent = part
		end

		local particles = attachment:FindFirstChild("RepairParticles")
		if not particles then
			particles = Instance.new("ParticleEmitter")
			particles.Name = "RepairParticles"
			particles.Color = ColorSequence.new(Color3.fromRGB(100, 255, 100))
			particles.Size = NumberSequence.new(0.3, 0)
			particles.Transparency = NumberSequence.new(0, 1)
			particles.Lifetime = NumberRange.new(0.5, 1)
			particles.Rate = 0 -- Manual emit
			particles.Speed = NumberRange.new(2, 4)
			particles.SpreadAngle = Vector2.new(180, 180)
			particles.Parent = attachment
		end

		-- Emit a few particles
		particles:Emit(3)
	end
end)

-- Cleanup when players leave
Players.PlayerRemoving:Connect(function(player)
	lastRepairTime[player.Name] = nil
end)

print("RepairManager: Loaded - Hold F to repair structures (1 gold per 5 HP)")
