-- SPRINT SYSTEM
-- Hold Shift to sprint, uses energy that regenerates

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Check if game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	return
end

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Base Settings (can be modified by upgrades)
local BASE_MAX_ENERGY = 100
local BASE_ENERGY_DRAIN_RATE = 20 -- Energy per second while sprinting
local BASE_ENERGY_REGEN_RATE = 15 -- Energy per second while not sprinting
local REGEN_DELAY = 0.5 -- Seconds after stopping sprint before regen starts
local BASE_SPRINT_SPEED_MULTIPLIER = 1.6 -- 60% faster
local BASE_WALK_SPEED = 16

-- Current stats (modified by upgrades)
local MAX_ENERGY = BASE_MAX_ENERGY
local ENERGY_DRAIN_RATE = BASE_ENERGY_DRAIN_RATE
local ENERGY_REGEN_RATE = BASE_ENERGY_REGEN_RATE
local SPRINT_SPEED_MULTIPLIER = BASE_SPRINT_SPEED_MULTIPLIER

-- State
local energy = MAX_ENERGY
local isSprinting = false
local lastSprintTime = 0
local originalWalkSpeed = BASE_WALK_SPEED

-- Remote for getting upgrades
local getUpgrades = ReplicatedStorage:WaitForChild("GetPlayerUpgrades", 10)
local upgradeApplied = ReplicatedStorage:WaitForChild("PlayerUpgradeApplied", 10)

-- Update stats from upgrades
local function updateStatsFromUpgrades()
	if not getUpgrades then return end

	local success, upgrades = pcall(function()
		return getUpgrades:InvokeServer()
	end)

	if success and upgrades then
		-- Max Energy upgrade
		if upgrades.MaxEnergy then
			MAX_ENERGY = BASE_MAX_ENERGY + (upgrades.MaxEnergy.level * upgrades.MaxEnergy.effect)
		end

		-- Energy Regen upgrade
		if upgrades.EnergyRegen then
			ENERGY_REGEN_RATE = BASE_ENERGY_REGEN_RATE + (upgrades.EnergyRegen.level * upgrades.EnergyRegen.effect)
		end

		-- Sprint Speed upgrade
		if upgrades.SprintSpeed then
			SPRINT_SPEED_MULTIPLIER = BASE_SPRINT_SPEED_MULTIPLIER + (upgrades.SprintSpeed.level * upgrades.SprintSpeed.effect)
		end

		print("Sprint: Updated stats - MaxEnergy:", MAX_ENERGY, "Regen:", ENERGY_REGEN_RATE, "SprintMult:", SPRINT_SPEED_MULTIPLIER)
	end
end

-- Update stats when upgrades are purchased
if upgradeApplied then
	upgradeApplied.OnClientEvent:Connect(function()
		local oldMax = MAX_ENERGY
		updateStatsFromUpgrades()
		-- Restore energy proportionally when max increases
		if MAX_ENERGY > oldMax then
			energy = math.min(energy + (MAX_ENERGY - oldMax), MAX_ENERGY)
		end
	end)
end

-- Initial stats update
task.delay(1, updateStatsFromUpgrades)

-- Create energy bar UI
local energyFrame = Instance.new("Frame")
energyFrame.Name = "EnergyFrame"
energyFrame.Size = UDim2.new(0, 200, 0, 12)
energyFrame.Position = UDim2.new(0.5, -100, 1, -50)
energyFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
energyFrame.BackgroundTransparency = 0.3
energyFrame.BorderSizePixel = 0
energyFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 6)
frameCorner.Parent = energyFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(60, 60, 80)
frameStroke.Thickness = 1
frameStroke.Parent = energyFrame

-- Energy fill bar
local energyBar = Instance.new("Frame")
energyBar.Name = "EnergyBar"
energyBar.Size = UDim2.new(1, -4, 1, -4)
energyBar.Position = UDim2.new(0, 2, 0, 2)
energyBar.BackgroundColor3 = Color3.fromRGB(50, 200, 255)
energyBar.BorderSizePixel = 0
energyBar.Parent = energyFrame

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 4)
barCorner.Parent = energyBar

-- Energy label
local energyLabel = Instance.new("TextLabel")
energyLabel.Name = "EnergyLabel"
energyLabel.Size = UDim2.new(1, 0, 0, 14)
energyLabel.Position = UDim2.new(0, 0, 0, -16)
energyLabel.BackgroundTransparency = 1
energyLabel.Text = "ENERGY"
energyLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
energyLabel.Font = Enum.Font.GothamBold
energyLabel.TextSize = 10
energyLabel.Parent = energyFrame

-- Sprint icon (shows when sprinting)
local sprintIcon = Instance.new("TextLabel")
sprintIcon.Name = "SprintIcon"
sprintIcon.Size = UDim2.new(0, 20, 0, 20)
sprintIcon.Position = UDim2.new(0, -25, 0.5, -10)
sprintIcon.BackgroundTransparency = 1
sprintIcon.Text = ">"
sprintIcon.TextColor3 = Color3.fromRGB(50, 200, 255)
sprintIcon.Font = Enum.Font.GothamBold
sprintIcon.TextSize = 16
sprintIcon.Visible = false
sprintIcon.Parent = energyFrame

-- Get humanoid
local function getHumanoid()
	local character = player.Character
	if character then
		return character:FindFirstChild("Humanoid")
	end
	return nil
end

-- Update energy bar visual
local function updateEnergyBar()
	local percent = energy / MAX_ENERGY
	energyBar.Size = UDim2.new(percent, -4, 1, -4)

	-- Color based on energy level
	if percent > 0.5 then
		energyBar.BackgroundColor3 = Color3.fromRGB(50, 200, 255)
	elseif percent > 0.25 then
		energyBar.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	else
		energyBar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	end
end

-- Start sprinting
local function startSprint()
	if isSprinting then return end
	if energy <= 0 then return end

	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then return end

	isSprinting = true
	originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = originalWalkSpeed * SPRINT_SPEED_MULTIPLIER

	sprintIcon.Visible = true

	-- Animate sprint icon
	local pulse = TweenService:Create(sprintIcon, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true), {
		TextTransparency = 0.5
	})
	pulse:Play()
end

-- Stop sprinting
local function stopSprint()
	if not isSprinting then return end

	isSprinting = false
	lastSprintTime = tick()

	local humanoid = getHumanoid()
	if humanoid then
		humanoid.WalkSpeed = originalWalkSpeed
	end

	sprintIcon.Visible = false
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		startSprint()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		stopSprint()
	end
end)

-- Update loop
RunService.Heartbeat:Connect(function(dt)
	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		stopSprint()
		return
	end

	if isSprinting then
		-- Drain energy
		energy = energy - ENERGY_DRAIN_RATE * dt

		if energy <= 0 then
			energy = 0
			stopSprint()
		end
	else
		-- Regenerate energy after delay
		if tick() - lastSprintTime >= REGEN_DELAY then
			energy = math.min(energy + ENERGY_REGEN_RATE * dt, MAX_ENERGY)
		end
	end

	updateEnergyBar()
end)

-- Handle character respawn
player.CharacterAdded:Connect(function(character)
	energy = MAX_ENERGY
	isSprinting = false
	originalWalkSpeed = BASE_WALK_SPEED

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		originalWalkSpeed = humanoid.WalkSpeed
	end
end)

-- Initialize with current character
if player.Character then
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if humanoid then
		originalWalkSpeed = humanoid.WalkSpeed
	end
end

print("Sprint: Loaded - Hold Shift to sprint")
