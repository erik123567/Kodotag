-- SELL SYSTEM UI
-- Toggle sell mode, click buildings to sell them

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Check if this is a game server (set by GameInitializer)
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	print("SellSystem: Lobby - disabled")
	return
end

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

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
	Barricade = 15,
	Wall = 60,
	Farm = 75,
	Workshop = 150
}

-- State
local sellModeActive = false
local currentTarget = nil
local highlightedBuilding = nil
local highlightBox = nil

-- Remote event
local sellBuildingEvent = ReplicatedStorage:WaitForChild("SellBuilding", 10)
if not sellBuildingEvent then
	sellBuildingEvent = Instance.new("RemoteEvent")
	sellBuildingEvent.Name = "SellBuilding"
	sellBuildingEvent.Parent = ReplicatedStorage
end

-- UI Setup
local screenGui = script.Parent

-- Sell Mode Toggle Button (bottom left)
local sellModeButton = Instance.new("TextButton")
sellModeButton.Name = "SellModeButton"
sellModeButton.Size = UDim2.new(0, 120, 0, 40)
sellModeButton.Position = UDim2.new(0, 175, 1, -60)
sellModeButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.35)
sellModeButton.Text = "Sell Mode"
sellModeButton.TextColor3 = Color3.new(1, 1, 1)
sellModeButton.Font = Enum.Font.GothamBold
sellModeButton.TextSize = 16
sellModeButton.Parent = screenGui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = sellModeButton

local buttonStroke = Instance.new("UIStroke")
buttonStroke.Color = Color3.new(0.5, 0.5, 0.5)
buttonStroke.Thickness = 2
buttonStroke.Parent = sellModeButton

-- Sell Confirmation Panel (appears when clicking a building)
local sellPanel = Instance.new("Frame")
sellPanel.Name = "SellPanel"
sellPanel.Size = UDim2.new(0, 220, 0, 120)
sellPanel.Position = UDim2.new(0.5, -110, 0.5, -60)
sellPanel.BackgroundColor3 = Color3.new(0.15, 0.15, 0.2)
sellPanel.BorderSizePixel = 0
sellPanel.Visible = false
sellPanel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = sellPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.new(1, 0.5, 0)
panelStroke.Thickness = 2
panelStroke.Parent = sellPanel

-- Panel title
local panelTitle = Instance.new("TextLabel")
panelTitle.Name = "Title"
panelTitle.Size = UDim2.new(1, 0, 0, 30)
panelTitle.Position = UDim2.new(0, 0, 0, 5)
panelTitle.BackgroundTransparency = 1
panelTitle.Text = "Sell Building"
panelTitle.TextColor3 = Color3.new(1, 0.7, 0.3)
panelTitle.Font = Enum.Font.GothamBold
panelTitle.TextSize = 18
panelTitle.Parent = sellPanel

-- Building name label
local buildingLabel = Instance.new("TextLabel")
buildingLabel.Name = "BuildingLabel"
buildingLabel.Size = UDim2.new(1, 0, 0, 25)
buildingLabel.Position = UDim2.new(0, 0, 0, 35)
buildingLabel.BackgroundTransparency = 1
buildingLabel.Text = "Turret"
buildingLabel.TextColor3 = Color3.new(1, 1, 1)
buildingLabel.Font = Enum.Font.Gotham
buildingLabel.TextSize = 16
buildingLabel.Parent = sellPanel

-- Sell value label
local valueLabel = Instance.new("TextLabel")
valueLabel.Name = "ValueLabel"
valueLabel.Size = UDim2.new(1, 0, 0, 25)
valueLabel.Position = UDim2.new(0, 0, 0, 55)
valueLabel.BackgroundTransparency = 1
valueLabel.Text = "+25 Gold"
valueLabel.TextColor3 = Color3.new(1, 0.85, 0)
valueLabel.Font = Enum.Font.GothamBold
valueLabel.TextSize = 18
valueLabel.Parent = sellPanel

-- Buttons container
local buttonsFrame = Instance.new("Frame")
buttonsFrame.Size = UDim2.new(1, -20, 0, 30)
buttonsFrame.Position = UDim2.new(0, 10, 1, -40)
buttonsFrame.BackgroundTransparency = 1
buttonsFrame.Parent = sellPanel

-- Confirm button
local confirmButton = Instance.new("TextButton")
confirmButton.Name = "ConfirmButton"
confirmButton.Size = UDim2.new(0.48, 0, 1, 0)
confirmButton.Position = UDim2.new(0, 0, 0, 0)
confirmButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
confirmButton.Text = "Sell"
confirmButton.TextColor3 = Color3.new(1, 1, 1)
confirmButton.Font = Enum.Font.GothamBold
confirmButton.TextSize = 14
confirmButton.Parent = buttonsFrame

local confirmCorner = Instance.new("UICorner")
confirmCorner.CornerRadius = UDim.new(0, 6)
confirmCorner.Parent = confirmButton

-- Cancel button
local cancelButton = Instance.new("TextButton")
cancelButton.Name = "CancelButton"
cancelButton.Size = UDim2.new(0.48, 0, 1, 0)
cancelButton.Position = UDim2.new(0.52, 0, 0, 0)
cancelButton.BackgroundColor3 = Color3.new(0.5, 0.3, 0.3)
cancelButton.Text = "Cancel"
cancelButton.TextColor3 = Color3.new(1, 1, 1)
cancelButton.Font = Enum.Font.GothamBold
cancelButton.TextSize = 14
cancelButton.Parent = buttonsFrame

local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 6)
cancelCorner.Parent = cancelButton

-- Helper: Get building under mouse
local function getBuildingUnderMouse()
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {player.Character}

	local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_SELL_DISTANCE, raycastParams)

	if result then
		local hit = result.Instance

		-- Check the hit part and its ancestors for valid building names
		local current = hit
		while current and current ~= workspace do
			if ITEM_COSTS[current.Name] then
				return current
			end
			current = current.Parent
		end
	end

	return nil
end

-- Helper: Calculate sell value
local function getSellValue(building)
	local buildingName = building.Name
	local originalCost = ITEM_COSTS[buildingName] or 0
	return math.floor(originalCost * SELL_PERCENTAGE)
end

-- Helper: Create highlight box around building
local function createHighlight(building)
	removeHighlight()

	local highlight = Instance.new("SelectionBox")
	highlight.Name = "SellHighlight"
	highlight.Color3 = Color3.new(1, 0.5, 0)
	highlight.LineThickness = 0.05
	highlight.SurfaceTransparency = 0.8
	highlight.SurfaceColor3 = Color3.new(1, 0.3, 0)
	highlight.Adornee = building
	highlight.Parent = building

	highlightBox = highlight
	highlightedBuilding = building
end

-- Helper: Remove highlight
function removeHighlight()
	if highlightBox then
		highlightBox:Destroy()
		highlightBox = nil
	end
	highlightedBuilding = nil
end

-- Helper: Update sell mode button appearance
local function updateSellModeButton()
	if sellModeActive then
		sellModeButton.BackgroundColor3 = Color3.new(0.8, 0.4, 0.1)
		sellModeButton.Text = "EXIT SELL"
		buttonStroke.Color = Color3.new(1, 0.6, 0.2)
	else
		sellModeButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.35)
		sellModeButton.Text = "Sell Mode"
		buttonStroke.Color = Color3.new(0.5, 0.5, 0.5)
	end
end

-- Helper: Show sell panel for a building
local function showSellPanel(building)
	currentTarget = building
	buildingLabel.Text = building.Name
	valueLabel.Text = "+" .. getSellValue(building) .. " Gold"
	sellPanel.Visible = true
end

-- Helper: Hide sell panel
local function hideSellPanel()
	sellPanel.Visible = false
	currentTarget = nil
end

-- Toggle sell mode
local function toggleSellMode()
	sellModeActive = not sellModeActive
	updateSellModeButton()

	if not sellModeActive then
		removeHighlight()
		hideSellPanel()
	end

	print("SellSystem: Sell mode", sellModeActive and "ENABLED" or "DISABLED")
end

-- Sell the current target
local function sellCurrentTarget()
	if currentTarget and currentTarget.Parent then
		print("SellSystem: Selling", currentTarget.Name)
		sellBuildingEvent:FireServer(currentTarget)
		removeHighlight()
		hideSellPanel()
	end
end

-- Button events
sellModeButton.MouseButton1Click:Connect(toggleSellMode)
confirmButton.MouseButton1Click:Connect(sellCurrentTarget)
cancelButton.MouseButton1Click:Connect(hideSellPanel)

-- Keyboard shortcut: X to toggle sell mode
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.X then
		toggleSellMode()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if sellPanel.Visible then
			hideSellPanel()
		elseif sellModeActive then
			toggleSellMode()
		end
	end
end)

-- Mouse click handling in sell mode
mouse.Button1Down:Connect(function()
	if not sellModeActive then return end
	if sellPanel.Visible then return end -- Don't process if panel is open

	local building = getBuildingUnderMouse()
	if building then
		showSellPanel(building)
	end
end)

-- Update loop: highlight buildings when in sell mode
RunService.RenderStepped:Connect(function()
	if not sellModeActive or sellPanel.Visible then
		if highlightedBuilding and not sellPanel.Visible then
			removeHighlight()
		end
		return
	end

	local building = getBuildingUnderMouse()

	if building then
		if building ~= highlightedBuilding then
			createHighlight(building)
		end
	else
		removeHighlight()
	end
end)

print("SellSystem: Loaded - Press X or click button to toggle sell mode")
