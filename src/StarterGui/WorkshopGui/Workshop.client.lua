local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("Workshop: Starting...")

-- Settings
local WORKSHOP_RANGE = 15 -- Must be within 15 studs of a workshop

-- Remote events
local getUpgradesEvent = ReplicatedStorage:WaitForChild("GetUpgrades", 10)
local purchaseUpgradeEvent = ReplicatedStorage:WaitForChild("PurchaseUpgrade", 10)
local upgradesPurchasedEvent = ReplicatedStorage:WaitForChild("UpgradesPurchased", 10)
local upgradeProgressEvent = ReplicatedStorage:WaitForChild("UpgradeProgress", 10)
local updatePlayerStatsEvent = ReplicatedStorage:FindFirstChild("UpdatePlayerStats")

if not getUpgradesEvent or not purchaseUpgradeEvent then
	warn("Workshop: Remote events not found!")
	return
end

-- State
local isWorkshopOpen = false
local currentGold = 0
local nearWorkshop = false
local activeUpgradeId = nil
local activeUpgradeProgress = 0

-- UI References
local workshopGui = playerGui:WaitForChild("WorkshopGui")

-- Check if player is near any completed workshop
local function isNearWorkshop()
	local character = player.Character
	if not character then return false end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end

	local playerPos = humanoidRootPart.Position

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "Workshop" then
			-- Skip workshops under construction
			local underConstruction = obj:FindFirstChild("UnderConstruction")
			if underConstruction and underConstruction.Value then
				continue
			end

			local workshopPos = nil
			if obj:IsA("Model") and obj.PrimaryPart then
				workshopPos = obj.PrimaryPart.Position
			elseif obj:IsA("BasePart") then
				workshopPos = obj.Position
			end

			if workshopPos then
				local distance = (workshopPos - playerPos).Magnitude
				if distance <= WORKSHOP_RANGE then
					return true
				end
			end
		end
	end

	return false
end

-- Get current gold from UI
local function getCurrentGold()
	local goldDisplayGui = playerGui:FindFirstChild("GoldDisplayGui")
	if goldDisplayGui then
		local goldDisplay = goldDisplayGui:FindFirstChild("GoldDisplay")
		if goldDisplay then
			local goldText = goldDisplay:FindFirstChild("GoldText")
			if goldText then
				local gold = tonumber(goldText.Text:match("%d+"))
				return gold or 0
			end
		end
	end
	return currentGold
end

-- Create Workshop UI
local workshopFrame = workshopGui:FindFirstChild("WorkshopFrame")
if not workshopFrame then
	workshopFrame = Instance.new("Frame")
	workshopFrame.Name = "WorkshopFrame"
	workshopFrame.Size = UDim2.new(0, 520, 0, 550)
	workshopFrame.Position = UDim2.new(0.5, -260, 0.5, -275)
	workshopFrame.BackgroundColor3 = Color3.new(0.12, 0.12, 0.15)
	workshopFrame.BackgroundTransparency = 0.05
	workshopFrame.BorderSizePixel = 2
	workshopFrame.BorderColor3 = Color3.new(0.8, 0.6, 0.2)
	workshopFrame.Visible = false
	workshopFrame.Parent = workshopGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = workshopFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 45)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.new(0.8, 0.6, 0.2)
	title.BackgroundTransparency = 0.3
	title.Text = "Upgrades Workshop (U or ESC to close)"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = workshopFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 12)
	titleCorner.Parent = title

	-- Upgrade list
	local upgradeList = Instance.new("ScrollingFrame")
	upgradeList.Name = "UpgradeList"
	upgradeList.Size = UDim2.new(1, -20, 1, -60)
	upgradeList.Position = UDim2.new(0, 10, 0, 50)
	upgradeList.BackgroundColor3 = Color3.new(0.08, 0.08, 0.1)
	upgradeList.BackgroundTransparency = 0.5
	upgradeList.BorderSizePixel = 0
	upgradeList.ScrollBarThickness = 8
	upgradeList.ScrollBarImageColor3 = Color3.new(0.8, 0.6, 0.2)
	upgradeList.CanvasSize = UDim2.new(0, 0, 0, 0)
	upgradeList.Parent = workshopFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = upgradeList

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 8)
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.Parent = upgradeList

	print("Workshop: Created UI")
end

local upgradeList = workshopFrame:FindFirstChild("UpgradeList")

-- Upgrade order for consistent display
local UPGRADE_ORDER = {
	"ReinforcedStructures",
	"EnhancedDamage",
	"RapidFire",
	"ExtendedRange",
	"EfficientFarms",
	"BountyHunter"
}

-- Create upgrade card
local function createUpgradeCard(upgradeId, upgradeData)
	local card = Instance.new("Frame")
	card.Name = upgradeId
	card.Size = UDim2.new(0.95, 0, 0, 110)
	card.BackgroundColor3 = Color3.new(0.18, 0.18, 0.22)
	card.BorderSizePixel = 0

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	-- Upgrade name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.55, 0, 0, 22)
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = upgradeData.name
	nameLabel.TextColor3 = Color3.new(1, 0.85, 0.4)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(0.55, 0, 0, 18)
	descLabel.Position = UDim2.new(0, 10, 0, 27)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = upgradeData.description
	descLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	descLabel.TextSize = 12
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = card

	-- Level indicator
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0.55, 0, 0, 18)
	levelLabel.Position = UDim2.new(0, 10, 0, 48)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.new(0.6, 0.8, 1)
	levelLabel.TextSize = 12
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = card

	if upgradeData.currentLevel >= upgradeData.maxLevel then
		levelLabel.Text = "Level: " .. upgradeData.currentLevel .. "/" .. upgradeData.maxLevel .. " (MAX)"
		levelLabel.TextColor3 = Color3.new(0.4, 1, 0.4)
	else
		levelLabel.Text = "Level: " .. upgradeData.currentLevel .. "/" .. upgradeData.maxLevel .. " | Time: " .. (upgradeData.upgradeTime or "?") .. "s"
	end

	-- Progress bar background (for active upgrades)
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBg"
	progressBg.Size = UDim2.new(0.55, 0, 0, 12)
	progressBg.Position = UDim2.new(0, 10, 0, 70)
	progressBg.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	progressBg.BorderSizePixel = 0
	progressBg.Visible = (activeUpgradeId == upgradeId)
	progressBg.Parent = card

	local progressBgCorner = Instance.new("UICorner")
	progressBgCorner.CornerRadius = UDim.new(0, 4)
	progressBgCorner.Parent = progressBg

	-- Progress bar fill
	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(activeUpgradeId == upgradeId and activeUpgradeProgress or 0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.new(1, 0.7, 0)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg

	local progressFillCorner = Instance.new("UICorner")
	progressFillCorner.CornerRadius = UDim.new(0, 4)
	progressFillCorner.Parent = progressFill

	-- Progress text
	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Size = UDim2.new(1, 0, 1, 0)
	progressText.BackgroundTransparency = 1
	progressText.Text = "Researching..."
	progressText.TextColor3 = Color3.new(1, 1, 1)
	progressText.TextSize = 10
	progressText.Font = Enum.Font.GothamBold
	progressText.Parent = progressBg

	-- Buy button
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.Size = UDim2.new(0, 110, 0, 70)
	buyButton.Position = UDim2.new(1, -120, 0.5, -35)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 14
	buyButton.TextWrapped = true
	buyButton.Parent = card

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = buyButton

	-- Update button state
	local function updateButton()
		currentGold = getCurrentGold()

		-- Check if this upgrade is in progress
		if activeUpgradeId == upgradeId then
			buyButton.Text = "Researching..."
			buyButton.BackgroundColor3 = Color3.new(0.5, 0.4, 0.1)
			buyButton.TextColor3 = Color3.new(1, 0.9, 0.5)
			buyButton.Active = false
			progressBg.Visible = true
		elseif activeUpgradeId ~= nil then
			-- Another upgrade is in progress
			buyButton.Text = upgradeData.cost .. " Gold\n(" .. (upgradeData.upgradeTime or "?") .. "s)"
			buyButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
			buyButton.TextColor3 = Color3.new(0.5, 0.5, 0.5)
			buyButton.Active = false
			progressBg.Visible = false
		elseif upgradeData.currentLevel >= upgradeData.maxLevel then
			buyButton.Text = "MAXED"
			buyButton.BackgroundColor3 = Color3.new(0.3, 0.5, 0.3)
			buyButton.TextColor3 = Color3.new(0.7, 0.9, 0.7)
			buyButton.Active = false
			progressBg.Visible = false
		elseif currentGold >= upgradeData.cost then
			buyButton.Text = upgradeData.cost .. " Gold\n(" .. (upgradeData.upgradeTime or "?") .. "s)"
			buyButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
			buyButton.TextColor3 = Color3.new(1, 1, 1)
			buyButton.Active = true
			progressBg.Visible = false
		else
			buyButton.Text = upgradeData.cost .. " Gold\n(" .. (upgradeData.upgradeTime or "?") .. "s)"
			buyButton.BackgroundColor3 = Color3.new(0.4, 0.2, 0.2)
			buyButton.TextColor3 = Color3.new(0.6, 0.6, 0.6)
			buyButton.Active = true
			progressBg.Visible = false
		end
	end

	-- Update progress bar
	local function updateProgress(progress, remainingTime)
		if progressFill then
			progressFill.Size = UDim2.new(progress, 0, 1, 0)
		end
		if progressText then
			progressText.Text = string.format("%.1fs remaining", remainingTime)
		end
	end

	updateButton()

	-- Buy button click
	buyButton.MouseButton1Click:Connect(function()
		if upgradeData.currentLevel >= upgradeData.maxLevel then return end
		if activeUpgradeId ~= nil then return end -- Already researching

		currentGold = getCurrentGold()
		if currentGold >= upgradeData.cost then
			print("Workshop: Requesting purchase of", upgradeId)
			purchaseUpgradeEvent:FireServer(upgradeId)
		else
			print("Workshop: Not enough gold for", upgradeId)
		end
	end)

	card.Parent = upgradeList
	return card, updateButton
end

-- Track update functions for each card
local cardUpdateFunctions = {}

-- Populate upgrade list
local function populateUpgradeList()
	-- Clear existing cards
	for _, child in ipairs(upgradeList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	cardUpdateFunctions = {}

	-- Get upgrade data from server (now returns two values)
	local upgradeData, activeUpgradeInfo = getUpgradesEvent:InvokeServer()

	if not upgradeData then
		warn("Workshop: Failed to get upgrade data")
		return
	end

	-- Update active upgrade state
	if activeUpgradeInfo then
		activeUpgradeId = activeUpgradeInfo.upgradeId
		activeUpgradeProgress = 1 - (activeUpgradeInfo.remainingTime / activeUpgradeInfo.totalTime)
	else
		activeUpgradeId = nil
		activeUpgradeProgress = 0
	end

	-- Create cards in order
	for _, upgradeId in ipairs(UPGRADE_ORDER) do
		if upgradeData[upgradeId] then
			local card, updateFunc = createUpgradeCard(upgradeId, upgradeData[upgradeId])
			cardUpdateFunctions[upgradeId] = {
				card = card,
				updateFunc = updateFunc,
				data = upgradeData[upgradeId]
			}
		end
	end

	-- Update canvas size
	local listLayout = upgradeList:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		upgradeList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
	end

	print("Workshop: Populated upgrade list")
end

-- Update all buttons (when gold changes)
local function updateAllButtons()
	currentGold = getCurrentGold()
	for _, cardInfo in pairs(cardUpdateFunctions) do
		if cardInfo.updateFunc then
			cardInfo.updateFunc()
		end
	end
end

-- Create proximity hint UI
local proximityHint = Instance.new("TextLabel")
proximityHint.Name = "ProximityHint"
proximityHint.Size = UDim2.new(0, 300, 0, 40)
proximityHint.Position = UDim2.new(0.5, -150, 0.75, 0)
proximityHint.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
proximityHint.BackgroundTransparency = 0.3
proximityHint.BorderSizePixel = 0
proximityHint.Text = "Press U to open Workshop"
proximityHint.TextColor3 = Color3.new(0.8, 0.6, 0.2)
proximityHint.TextScaled = true
proximityHint.Font = Enum.Font.GothamBold
proximityHint.Visible = false
proximityHint.Parent = workshopGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = proximityHint

-- Open/close workshop
local function openWorkshop()
	if not isNearWorkshop() then
		print("Workshop: Not near a workshop!")
		return false
	end

	workshopFrame.Visible = true
	isWorkshopOpen = true
	proximityHint.Visible = false
	populateUpgradeList()
	print("Workshop: Opened")
	return true
end

local function closeWorkshop()
	workshopFrame.Visible = false
	isWorkshopOpen = false
	print("Workshop: Closed")
end

local function toggleWorkshop()
	if isWorkshopOpen then
		closeWorkshop()
	else
		openWorkshop()
	end
end

-- Handle upgrade purchased (completed)
upgradesPurchasedEvent.OnClientEvent:Connect(function(upgradeId, newLevel)
	print("Workshop: Upgrade completed -", upgradeId, "now level", newLevel)
	activeUpgradeId = nil
	activeUpgradeProgress = 0
	if isWorkshopOpen then
		populateUpgradeList()
	end
end)

-- Handle upgrade progress updates
if upgradeProgressEvent then
	upgradeProgressEvent.OnClientEvent:Connect(function(upgradeId, progress, remainingTime)
		if upgradeId == nil then
			-- Upgrade completed or cancelled
			activeUpgradeId = nil
			activeUpgradeProgress = 0
		else
			activeUpgradeId = upgradeId
			activeUpgradeProgress = progress
		end

		-- Update the specific card's progress bar if workshop is open
		if isWorkshopOpen and cardUpdateFunctions[upgradeId] then
			local cardInfo = cardUpdateFunctions[upgradeId]
			local card = cardInfo.card
			if card then
				local progressBg = card:FindFirstChild("ProgressBg")
				if progressBg then
					progressBg.Visible = true
					local progressFill = progressBg:FindFirstChild("ProgressFill")
					if progressFill then
						progressFill.Size = UDim2.new(progress, 0, 1, 0)
					end
					local progressText = progressBg:FindFirstChild("ProgressText")
					if progressText then
						progressText.Text = string.format("%.1fs remaining", remainingTime)
					end
				end
			end
			-- Update all buttons to show disabled state
			updateAllButtons()
		end
	end)
end

-- Handle gold updates
if updatePlayerStatsEvent then
	updatePlayerStatsEvent.OnClientEvent:Connect(function(stats)
		currentGold = stats.gold
		if isWorkshopOpen then
			updateAllButtons()
		end
	end)
end

-- Check proximity and update hint
RunService.Heartbeat:Connect(function()
	local wasNear = nearWorkshop
	nearWorkshop = isNearWorkshop()

	-- Show/hide proximity hint
	if nearWorkshop and not isWorkshopOpen then
		proximityHint.Visible = true
	else
		proximityHint.Visible = false
	end

	-- Auto-close if player walks away
	if isWorkshopOpen and not nearWorkshop then
		closeWorkshop()
		print("Workshop: Closed - walked out of range")
	end
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.U then
		if isWorkshopOpen then
			closeWorkshop()
		elseif nearWorkshop then
			openWorkshop()
		end
	end

	if input.KeyCode == Enum.KeyCode.Escape and isWorkshopOpen then
		closeWorkshop()
	end
end)

print("Workshop: Loaded - Build a Workshop and press U nearby to open upgrades")
