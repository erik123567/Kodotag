local workspace = game:GetService("Workspace")

-- Only run on game servers (reserved servers)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("StructureHealthBars: Lobby server - disabled")
	return
end

-- Create health bar for a structure
local function createHealthBar(structure)
	print("StructureHealthBars: Attempting to create health bar for", structure.Name)

	-- Wait for Health value to be added
	local health = structure:WaitForChild("Health", 10)
	if not health then
		warn("StructureHealthBars: No Health value found for", structure.Name, "after 10 seconds")
		return
	end

	-- Wait for MaxHealth value (may take a moment)
	local maxHealthValue = structure:WaitForChild("MaxHealth", 5)
	if not maxHealthValue then
		-- Create MaxHealth if it doesn't exist (fallback)
		maxHealthValue = Instance.new("IntValue")
		maxHealthValue.Name = "MaxHealth"
		maxHealthValue.Value = health.Value
		maxHealthValue.Parent = structure
	end

	print("StructureHealthBars: Found Health:", health.Value, "MaxHealth:", maxHealthValue.Value)

	local structurePart = structure:IsA("Model") and structure.PrimaryPart or structure

	if not structurePart then
		warn("StructureHealthBars: No valid part found for", structure.Name)
		return
	end

	-- Check if health bar already exists
	if structurePart:FindFirstChild("HealthBar") then
		print("StructureHealthBars: Health bar already exists for", structure.Name)
		return
	end

	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.new(6, 0, 0.8, 0)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = structurePart
	billboard.Parent = structurePart

	-- Background
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	background.BorderSizePixel = 2
	background.BorderColor3 = Color3.new(0, 0, 0)
	background.Parent = billboard

	-- Health bar
	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.BackgroundColor3 = Color3.new(0, 0.8, 0)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = background

	-- Health text
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = health.Value .. " / " .. maxHealthValue.Value
	healthText.TextColor3 = Color3.new(1, 1, 1)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.GothamBold
	healthText.TextStrokeTransparency = 0.5
	healthText.Parent = background

	print("StructureHealthBars: Created health bar for", structure.Name)

	-- Function to update health bar display
	local function updateHealthBar()
		local currentMax = maxHealthValue.Value
		local currentHealth = health.Value
		local healthPercent = currentMax > 0 and (currentHealth / currentMax) or 0

		healthBar.Size = UDim2.new(math.clamp(healthPercent, 0, 1), 0, 1, 0)
		healthText.Text = math.floor(currentHealth) .. " / " .. currentMax

		-- Color based on health
		if healthPercent > 0.6 then
			healthBar.BackgroundColor3 = Color3.new(0, 0.8, 0)
		elseif healthPercent > 0.3 then
			healthBar.BackgroundColor3 = Color3.new(1, 1, 0)
		else
			healthBar.BackgroundColor3 = Color3.new(1, 0, 0)
		end
	end

	-- Update when health changes
	health.Changed:Connect(updateHealthBar)

	-- Update when max health changes (from aura buffs)
	maxHealthValue.Changed:Connect(updateHealthBar)
end

-- Valid structure names
local VALID_STRUCTURES = {
	Barricade = true, Wall = true,
	Turret = true, FastTurret = true, SlowTurret = true,
	FrostTurret = true, PoisonTurret = true, MultiShotTurret = true, CannonTurret = true,
	Farm = true, Workshop = true,
	-- Aura buildings
	SpeedAura = true, DamageAura = true, FortifyAura = true, RangeAura = true, RegenAura = true
}

-- Monitor workspace for new structures
workspace.ChildAdded:Connect(function(child)
	if VALID_STRUCTURES[child.Name] then
		print("StructureHealthBars: New structure detected:", child.Name)
		-- Wait a moment for the structure to fully load
		wait(0.5)
		createHealthBar(child)
	end
end)

-- Add health bars to existing structures
print("StructureHealthBars: Checking for existing structures...")
for _, child in ipairs(workspace:GetChildren()) do
	if VALID_STRUCTURES[child.Name] then
		print("StructureHealthBars: Found existing structure:", child.Name)
		if child:FindFirstChild("Health") then
			createHealthBar(child)
		else
			print("StructureHealthBars: Waiting for Health value to be added to", child.Name)
			task.spawn(function()
				local health = child:WaitForChild("Health", 10)
				if health then
					createHealthBar(child)
				end
			end)
		end
	end
end

print("StructureHealthBars: Monitoring structures!")