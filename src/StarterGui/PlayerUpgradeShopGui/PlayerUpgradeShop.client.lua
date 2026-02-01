-- PLAYER UPGRADE SHOP UI
-- Press P to open/close the upgrade shop

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Check if game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	return
end

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Remote events
local purchaseUpgrade = ReplicatedStorage:WaitForChild("PurchasePlayerUpgrade", 10)
local getUpgrades = ReplicatedStorage:WaitForChild("GetPlayerUpgrades", 10)
local upgradeApplied = ReplicatedStorage:WaitForChild("PlayerUpgradeApplied", 10)

if not purchaseUpgrade or not getUpgrades then
	warn("PlayerUpgradeShop: Missing remote events")
	return
end

-- State
local isOpen = false
local upgradeButtons = {}

-- Upgrade order for display
local UPGRADE_ORDER = {
	"MaxHealth",
	"MoveSpeed",
	"MaxEnergy",
	"EnergyRegen",
	"SprintSpeed",
	"GoldBonus",
}

-- Upgrade icons/colors
local UPGRADE_COLORS = {
	MaxHealth = Color3.fromRGB(255, 80, 80),
	MoveSpeed = Color3.fromRGB(80, 255, 150),
	MaxEnergy = Color3.fromRGB(80, 180, 255),
	EnergyRegen = Color3.fromRGB(150, 120, 255),
	SprintSpeed = Color3.fromRGB(255, 200, 80),
	GoldBonus = Color3.fromRGB(255, 215, 0),
}

-- Create main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "UpgradeShop"
mainFrame.Size = UDim2.new(0, 400, 0, 450)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(100, 100, 120)
mainStroke.Thickness = 2
mainStroke.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

-- Fix bottom corners of title bar
local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

-- Title text
local titleText = Instance.new("TextLabel")
titleText.Name = "Title"
titleText.Size = UDim2.new(1, -50, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "PLAYER UPGRADES"
titleText.TextColor3 = Color3.fromRGB(220, 220, 220)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 18
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

-- Hint text
local hintText = Instance.new("TextLabel")
hintText.Name = "Hint"
hintText.Size = UDim2.new(1, 0, 0, 20)
hintText.Position = UDim2.new(0, 0, 0, 42)
hintText.BackgroundTransparency = 1
hintText.Text = "Press P to close"
hintText.TextColor3 = Color3.fromRGB(120, 120, 140)
hintText.Font = Enum.Font.Gotham
hintText.TextSize = 11
hintText.Parent = mainFrame

-- Scrolling frame for upgrades
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "UpgradeList"
scrollFrame.Size = UDim2.new(1, -20, 1, -75)
scrollFrame.Position = UDim2.new(0, 10, 0, 65)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Parent = scrollFrame

-- Create upgrade button
local function createUpgradeButton(upgradeId, upgradeData)
	local color = UPGRADE_COLORS[upgradeId] or Color3.fromRGB(100, 100, 100)

	local button = Instance.new("Frame")
	button.Name = upgradeId
	button.Size = UDim2.new(1, -10, 0, 70)
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	button.BorderSizePixel = 0
	button.Parent = scrollFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = button

	-- Color accent
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(0, 4, 1, -10)
	accent.Position = UDim2.new(0, 5, 0, 5)
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0
	accent.Parent = button

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 2)
	accentCorner.Parent = accent

	-- Upgrade name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(0.5, -20, 0, 22)
	nameLabel.Position = UDim2.new(0, 20, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = upgradeData.name
	nameLabel.TextColor3 = color
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = button

	-- Level indicator
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.Size = UDim2.new(0.3, 0, 0, 22)
	levelLabel.Position = UDim2.new(0.5, 0, 0, 8)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Lv " .. upgradeData.level .. "/" .. upgradeData.maxLevel
	levelLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextSize = 14
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = button

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.Size = UDim2.new(0.6, -20, 0, 18)
	descLabel.Position = UDim2.new(0, 20, 0, 30)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = upgradeData.description
	descLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = button

	-- Current effect
	local effectLabel = Instance.new("TextLabel")
	effectLabel.Name = "Effect"
	effectLabel.Size = UDim2.new(0.6, -20, 0, 16)
	effectLabel.Position = UDim2.new(0, 20, 0, 48)
	effectLabel.BackgroundTransparency = 1
	effectLabel.Text = "Current: +" .. tostring(upgradeData.totalEffect)
	effectLabel.TextColor3 = Color3.fromRGB(120, 180, 120)
	effectLabel.Font = Enum.Font.Gotham
	effectLabel.TextSize = 11
	effectLabel.TextXAlignment = Enum.TextXAlignment.Left
	effectLabel.Parent = button

	-- Buy button
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.Size = UDim2.new(0, 90, 0, 35)
	buyButton.Position = UDim2.new(1, -100, 0.5, -17)
	buyButton.BorderSizePixel = 0
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 13
	buyButton.Parent = button

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 6)
	buyCorner.Parent = buyButton

	-- Update buy button state
	local function updateBuyButton()
		if upgradeData.level >= upgradeData.maxLevel then
			buyButton.Text = "MAXED"
			buyButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			buyButton.TextColor3 = Color3.fromRGB(150, 150, 150)
		else
			buyButton.Text = upgradeData.cost .. "g"
			buyButton.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
			buyButton.TextColor3 = Color3.new(1, 1, 1)
		end
	end

	updateBuyButton()

	-- Buy click handler
	buyButton.MouseButton1Click:Connect(function()
		if upgradeData.level >= upgradeData.maxLevel then return end
		purchaseUpgrade:FireServer(upgradeId)
	end)

	-- Hover effect
	buyButton.MouseEnter:Connect(function()
		if upgradeData.level < upgradeData.maxLevel then
			TweenService:Create(buyButton, TweenInfo.new(0.1), {
				BackgroundColor3 = Color3.fromRGB(80, 200, 80)
			}):Play()
		end
	end)

	buyButton.MouseLeave:Connect(function()
		updateBuyButton()
	end)

	upgradeButtons[upgradeId] = {
		frame = button,
		data = upgradeData,
		levelLabel = levelLabel,
		effectLabel = effectLabel,
		buyButton = buyButton,
		updateBuyButton = updateBuyButton,
	}

	return button
end

-- Refresh upgrades display
local function refreshUpgrades()
	local upgrades = getUpgrades:InvokeServer()
	if not upgrades then return end

	-- Clear existing buttons
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	upgradeButtons = {}

	-- Create buttons in order
	for _, upgradeId in ipairs(UPGRADE_ORDER) do
		local upgradeData = upgrades[upgradeId]
		if upgradeData then
			createUpgradeButton(upgradeId, upgradeData)
		end
	end

	-- Update canvas size
	listLayout:ApplyLayout()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end

-- Open shop
local function openShop()
	if isOpen then return end
	isOpen = true

	refreshUpgrades()

	mainFrame.Visible = true
	mainFrame.Position = UDim2.new(0.5, -200, 0.5, -200)
	mainFrame.BackgroundTransparency = 1

	TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -200, 0.5, -225),
		BackgroundTransparency = 0.1
	}):Play()
end

-- Close shop
local function closeShop()
	if not isOpen then return end
	isOpen = false

	local tween = TweenService:Create(mainFrame, TweenInfo.new(0.15), {
		Position = UDim2.new(0.5, -200, 0.5, -200),
		BackgroundTransparency = 1
	})
	tween:Play()
	tween.Completed:Connect(function()
		if not isOpen then
			mainFrame.Visible = false
		end
	end)
end

-- Toggle shop
local function toggleShop()
	if isOpen then
		closeShop()
	else
		openShop()
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.P then
		toggleShop()
	end
end)

-- Close button
closeButton.MouseButton1Click:Connect(closeShop)

-- Handle upgrade applied
upgradeApplied.OnClientEvent:Connect(function(upgradeId, newLevel, newGold)
	local buttonInfo = upgradeButtons[upgradeId]
	if buttonInfo then
		buttonInfo.data.level = newLevel
		buttonInfo.data.cost = math.floor(buttonInfo.data.cost * 1.5) -- Approximate next cost
		buttonInfo.data.totalEffect = newLevel * buttonInfo.data.effect

		buttonInfo.levelLabel.Text = "Lv " .. newLevel .. "/" .. buttonInfo.data.maxLevel
		buttonInfo.effectLabel.Text = "Current: +" .. tostring(buttonInfo.data.totalEffect)
		buttonInfo.updateBuyButton()

		-- Flash effect on successful purchase
		local flash = TweenService:Create(buttonInfo.frame, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(80, 120, 80)
		})
		flash:Play()
		flash.Completed:Connect(function()
			TweenService:Create(buttonInfo.frame, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(40, 40, 55)
			}):Play()
		end)
	end

	-- Refresh to get accurate costs
	task.delay(0.2, refreshUpgrades)
end)

print("PlayerUpgradeShop: Loaded - Press P to open")
