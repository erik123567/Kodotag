-- DEATH ABILITIES UI
-- Shows ability panel when player is dead

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Check if game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	print("DeathAbilitiesUI: Lobby - disabled")
	return
end

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Wait for remote events
local useDeathAbility = ReplicatedStorage:WaitForChild("UseDeathAbility", 10)
local deathAbilityUsed = ReplicatedStorage:WaitForChild("DeathAbilityUsed", 10)
local getDeathAbilities = ReplicatedStorage:WaitForChild("GetDeathAbilities", 10)
local updatePlayerStats = ReplicatedStorage:FindFirstChild("UpdatePlayerStats")

if not useDeathAbility or not getDeathAbilities then
	warn("DeathAbilitiesUI: Missing remote events")
	return
end

-- Get abilities from server
local ABILITIES = getDeathAbilities:InvokeServer()
if not ABILITIES then
	warn("DeathAbilitiesUI: Failed to get abilities")
	return
end

-- State
local currentGold = 0
local cooldowns = {}
local isDead = false

-- Ability button order and colors
local ABILITY_ORDER = {"SlowAura", "LightningStrike", "SpeedBoost", "QuickRevive"}
local ABILITY_COLORS = {
	SlowAura = Color3.fromRGB(100, 150, 255),      -- Blue
	LightningStrike = Color3.fromRGB(255, 255, 100), -- Yellow
	SpeedBoost = Color3.fromRGB(100, 255, 150),     -- Green
	QuickRevive = Color3.fromRGB(255, 150, 255)     -- Purple
}

-- Create main panel
local deathPanel = Instance.new("Frame")
deathPanel.Name = "DeathAbilitiesPanel"
deathPanel.Size = UDim2.new(0, 320, 0, 220)
deathPanel.Position = UDim2.new(0, 10, 0.5, -110)
deathPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
deathPanel.BackgroundTransparency = 0.1
deathPanel.BorderSizePixel = 0
deathPanel.Visible = false
deathPanel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = deathPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(150, 50, 50)
panelStroke.Thickness = 2
panelStroke.Parent = deathPanel

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "DEATH ABILITIES"
titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 18
titleLabel.Parent = deathPanel

-- Subtitle
local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Size = UDim2.new(1, 0, 0, 20)
subtitleLabel.Position = UDim2.new(0, 0, 0, 32)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "Help your team from beyond the grave!"
subtitleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextSize = 12
subtitleLabel.Parent = deathPanel

-- Abilities container
local abilitiesFrame = Instance.new("Frame")
abilitiesFrame.Name = "AbilitiesFrame"
abilitiesFrame.Size = UDim2.new(1, -20, 1, -65)
abilitiesFrame.Position = UDim2.new(0, 10, 0, 55)
abilitiesFrame.BackgroundTransparency = 1
abilitiesFrame.Parent = deathPanel

local abilitiesLayout = Instance.new("UIListLayout")
abilitiesLayout.Padding = UDim.new(0, 6)
abilitiesLayout.FillDirection = Enum.FillDirection.Vertical
abilitiesLayout.Parent = abilitiesFrame

-- Store button references for updating
local abilityButtons = {}

-- Create ability buttons
for _, abilityName in ipairs(ABILITY_ORDER) do
	local ability = ABILITIES[abilityName]
	if not ability then continue end

	local color = ABILITY_COLORS[abilityName] or Color3.fromRGB(100, 100, 100)

	local button = Instance.new("TextButton")
	button.Name = abilityName
	button.Size = UDim2.new(1, 0, 0, 36)
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.7
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = abilitiesFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Name = "Stroke"
	buttonStroke.Color = color
	buttonStroke.Thickness = 1
	buttonStroke.Parent = button

	-- Ability name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "AbilityName"
	nameLabel.Size = UDim2.new(0.55, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 8, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ability.name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = button

	-- Cost
	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "Cost"
	costLabel.Size = UDim2.new(0, 50, 0.5, 0)
	costLabel.Position = UDim2.new(1, -58, 0, 2)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = ability.cost .. "g"
	costLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 14
	costLabel.TextXAlignment = Enum.TextXAlignment.Right
	costLabel.Parent = button

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.Size = UDim2.new(1, -16, 0.5, 0)
	descLabel.Position = UDim2.new(0, 8, 0.5, -2)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = ability.description
	descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 11
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = button

	-- Cooldown overlay
	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
	cooldownOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	cooldownOverlay.BackgroundTransparency = 0.5
	cooldownOverlay.Visible = false
	cooldownOverlay.ZIndex = 2
	cooldownOverlay.Parent = button

	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, 6)
	overlayCorner.Parent = cooldownOverlay

	local cooldownText = Instance.new("TextLabel")
	cooldownText.Name = "CooldownText"
	cooldownText.Size = UDim2.new(1, 0, 1, 0)
	cooldownText.BackgroundTransparency = 1
	cooldownText.Text = "5s"
	cooldownText.TextColor3 = Color3.new(1, 1, 1)
	cooldownText.Font = Enum.Font.GothamBold
	cooldownText.TextSize = 16
	cooldownText.ZIndex = 3
	cooldownText.Parent = cooldownOverlay

	-- Store reference
	abilityButtons[abilityName] = {
		button = button,
		cost = ability.cost,
		cooldown = ability.cooldown,
		color = color,
		cooldownOverlay = cooldownOverlay,
		cooldownText = cooldownText,
		stroke = buttonStroke
	}

	-- Click handler
	button.MouseButton1Click:Connect(function()
		if cooldowns[abilityName] and cooldowns[abilityName] > tick() then
			return -- On cooldown
		end
		if currentGold < ability.cost then
			return -- Can't afford
		end

		print("DeathAbilitiesUI: Using " .. abilityName)
		useDeathAbility:FireServer(abilityName)
	end)

	-- Hover effects
	button.MouseEnter:Connect(function()
		if cooldowns[abilityName] and cooldowns[abilityName] > tick() then return end
		if currentGold < ability.cost then return end
		button.BackgroundTransparency = 0.5
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundTransparency = 0.7
	end)
end

-- Update button states based on gold and cooldowns
local function updateButtonStates()
	for abilityName, data in pairs(abilityButtons) do
		local canAfford = currentGold >= data.cost
		local onCooldown = cooldowns[abilityName] and cooldowns[abilityName] > tick()

		if onCooldown then
			data.cooldownOverlay.Visible = true
			local remaining = math.ceil(cooldowns[abilityName] - tick())
			data.cooldownText.Text = remaining .. "s"
			data.stroke.Color = Color3.fromRGB(80, 80, 80)
		elseif not canAfford then
			data.cooldownOverlay.Visible = false
			data.button.BackgroundTransparency = 0.85
			data.stroke.Color = Color3.fromRGB(80, 80, 80)
		else
			data.cooldownOverlay.Visible = false
			data.button.BackgroundTransparency = 0.7
			data.stroke.Color = data.color
		end
	end
end

-- Listen for gold updates
if updatePlayerStats then
	updatePlayerStats.OnClientEvent:Connect(function(playerStats)
		if playerStats[player.Name] then
			currentGold = playerStats[player.Name].gold or 0
			updateButtonStates()
		end
	end)
end

-- Listen for ability cooldown start
if deathAbilityUsed then
	deathAbilityUsed.OnClientEvent:Connect(function(abilityName, cooldownTime)
		if cooldownTime > 0 then
			cooldowns[abilityName] = tick() + cooldownTime
		end
		updateButtonStates()
	end)
end

-- Check if player is dead
local function checkDeathState()
	local character = player.Character
	if not character then
		isDead = true
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	isDead = not humanoid or humanoid.Health <= 0
end

-- Monitor player state
local function onCharacterAdded(character)
	isDead = false
	deathPanel.Visible = false

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			isDead = true
			deathPanel.Visible = true
			-- Reset cooldowns on death (except QuickRevive which is one-time)
			for abilityName, _ in pairs(cooldowns) do
				if abilityName ~= "QuickRevive" then
					cooldowns[abilityName] = nil
				end
			end
			updateButtonStates()
		end)
	end
end

-- Connect to character events
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

-- Update loop for cooldown timers
RunService.Heartbeat:Connect(function()
	if isDead and deathPanel.Visible then
		updateButtonStates()
	end
end)

print("DeathAbilitiesUI: Loaded!")
