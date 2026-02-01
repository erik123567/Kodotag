-- DAMAGE NUMBERS
-- Floating damage text when Kodos take damage

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Check if game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	return
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local screenGui = script.Parent

-- Settings
local FLOAT_DISTANCE = 3 -- How high numbers float
local FLOAT_TIME = 0.8 -- How long numbers last
local SPREAD_RANGE = 1.5 -- Random horizontal spread
local MAX_VISIBLE = 30 -- Max damage numbers on screen

-- Colors by damage type
local DAMAGE_COLORS = {
	physical = Color3.fromRGB(255, 255, 255),   -- White
	frost = Color3.fromRGB(100, 200, 255),      -- Light blue
	poison = Color3.fromRGB(100, 255, 100),     -- Green
	aoe = Color3.fromRGB(255, 150, 50),         -- Orange
	multishot = Color3.fromRGB(255, 200, 100),  -- Yellow-orange
	critical = Color3.fromRGB(255, 255, 0),     -- Bright yellow
	weak = Color3.fromRGB(150, 150, 150),       -- Gray (resisted)
	strong = Color3.fromRGB(255, 100, 100),     -- Red (bonus damage)
}

-- Pool of damage number labels
local labelPool = {}
local activeLabels = {}

-- Create a damage number label
local function createLabel()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumber"
	billboard.Size = UDim2.new(0, 100, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Active = false
	billboard.Parent = screenGui

	local label = Instance.new("TextLabel")
	label.Name = "Number"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "0"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 24
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard

	return billboard
end

-- Get a label from pool or create new one
local function getLabel()
	if #labelPool > 0 then
		return table.remove(labelPool)
	end
	return createLabel()
end

-- Return label to pool
local function returnLabel(billboard)
	billboard.Enabled = false
	billboard.Adornee = nil
	table.insert(labelPool, billboard)
end

-- Show a damage number
local function showDamageNumber(position, damage, damageType, isWeak, isStrong)
	-- Limit active labels
	if #activeLabels >= MAX_VISIBLE then
		local oldest = table.remove(activeLabels, 1)
		returnLabel(oldest.billboard)
	end

	local billboard = getLabel()
	local label = billboard:FindFirstChild("Number")

	-- Set text
	local damageText = tostring(math.floor(damage))
	if isStrong then
		damageText = damageText .. "!"
	end
	label.Text = damageText

	-- Set color
	local color = DAMAGE_COLORS.physical
	if isWeak then
		color = DAMAGE_COLORS.weak
	elseif isStrong then
		color = DAMAGE_COLORS.strong
	elseif DAMAGE_COLORS[damageType] then
		color = DAMAGE_COLORS[damageType]
	end
	label.TextColor3 = color

	-- Set size based on damage
	local baseSize = 20
	if damage >= 100 then
		baseSize = 32
	elseif damage >= 50 then
		baseSize = 28
	elseif damage >= 25 then
		baseSize = 24
	end
	if isStrong then
		baseSize = baseSize + 4
	end
	label.TextSize = baseSize

	-- Random horizontal offset for visual variety
	local offsetX = (math.random() - 0.5) * SPREAD_RANGE * 2
	local offsetZ = (math.random() - 0.5) * SPREAD_RANGE * 2
	local startPos = position + Vector3.new(offsetX, 0.5, offsetZ)

	-- Create anchor part for billboard
	local anchor = Instance.new("Part")
	anchor.Name = "DamageAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = startPos
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	billboard.Adornee = anchor
	billboard.Enabled = true
	billboard.StudsOffset = Vector3.new(0, 0, 0)

	-- Reset label properties
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0

	-- Track this label
	local labelData = {
		billboard = billboard,
		anchor = anchor,
		startTime = tick(),
		startY = startPos.Y
	}
	table.insert(activeLabels, labelData)

	-- Animate float up and fade
	local endPos = startPos + Vector3.new(0, FLOAT_DISTANCE, 0)

	local moveTween = TweenService:Create(anchor, TweenInfo.new(FLOAT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = endPos
	})

	local fadeTween = TweenService:Create(label, TweenInfo.new(FLOAT_TIME * 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, FLOAT_TIME * 0.5), {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})

	moveTween:Play()
	fadeTween:Play()

	-- Pop-in effect
	local originalSize = label.TextSize
	label.TextSize = originalSize * 0.5
	local popTween = TweenService:Create(label, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = originalSize
	})
	popTween:Play()

	-- Cleanup
	task.delay(FLOAT_TIME + 0.1, function()
		-- Remove from active list
		for i, data in ipairs(activeLabels) do
			if data.billboard == billboard then
				table.remove(activeLabels, i)
				break
			end
		end

		returnLabel(billboard)
		anchor:Destroy()
	end)
end

-- Listen for damage events from server
local damageEvent = ReplicatedStorage:WaitForChild("ShowDamageNumber", 10)
if damageEvent then
	damageEvent.OnClientEvent:Connect(function(position, damage, damageType, isWeak, isStrong)
		showDamageNumber(position, damage, damageType, isWeak, isStrong)
	end)
end

-- Pre-create some labels for pool
for i = 1, 10 do
	table.insert(labelPool, createLabel())
end

print("DamageNumbers: Loaded")
