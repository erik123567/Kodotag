-- HELP SCREEN
-- Shows controls and gameplay tips

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Settings
local HELP_KEY = Enum.KeyCode.H

-- State
local isHelpOpen = false

-- Create Help Button (bottom right corner)
local helpButton = Instance.new("TextButton")
helpButton.Name = "HelpButton"
helpButton.Size = UDim2.new(0, 40, 0, 40)
helpButton.Position = UDim2.new(1, -50, 1, -50)
helpButton.AnchorPoint = Vector2.new(0, 0)
helpButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
helpButton.BorderSizePixel = 0
helpButton.Text = "?"
helpButton.TextColor3 = Color3.fromRGB(200, 200, 220)
helpButton.Font = Enum.Font.GothamBold
helpButton.TextSize = 24
helpButton.Parent = screenGui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = helpButton

local buttonStroke = Instance.new("UIStroke")
buttonStroke.Color = Color3.fromRGB(100, 100, 130)
buttonStroke.Thickness = 2
buttonStroke.Parent = helpButton

-- Create hint label
local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.new(0, 80, 0, 20)
hintLabel.Position = UDim2.new(1, -90, 1, -25)
hintLabel.BackgroundTransparency = 1
hintLabel.Text = "[H] Help"
hintLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 11
hintLabel.TextXAlignment = Enum.TextXAlignment.Right
hintLabel.Parent = screenGui

-- Create Help Panel
local helpPanel = Instance.new("Frame")
helpPanel.Name = "HelpPanel"
helpPanel.Size = UDim2.new(0, 600, 0, 500)
helpPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
helpPanel.AnchorPoint = Vector2.new(0.5, 0.5)
helpPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
helpPanel.BorderSizePixel = 0
helpPanel.Visible = false
helpPanel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = helpPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(80, 80, 100)
panelStroke.Thickness = 2
panelStroke.Parent = helpPanel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = helpPanel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 15)
titleFix.Position = UDim2.new(0, 0, 1, -15)
titleFix.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -20, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "KODO TAG - HELP & CONTROLS"
titleText.TextColor3 = Color3.fromRGB(255, 220, 100)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 16
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local closeHint = Instance.new("TextLabel")
closeHint.Size = UDim2.new(0, 120, 1, 0)
closeHint.Position = UDim2.new(1, -130, 0, 0)
closeHint.BackgroundTransparency = 1
closeHint.Text = "[H] or [Esc] Close"
closeHint.TextColor3 = Color3.fromRGB(120, 120, 140)
closeHint.Font = Enum.Font.Gotham
closeHint.TextSize = 11
closeHint.TextXAlignment = Enum.TextXAlignment.Right
closeHint.Parent = titleBar

-- Content area with scroll
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -20, 1, -50)
contentFrame.Position = UDim2.new(0, 10, 0, 45)
contentFrame.BackgroundTransparency = 1
contentFrame.BorderSizePixel = 0
contentFrame.ScrollBarThickness = 6
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.Parent = helpPanel

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 15)
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.Parent = contentFrame

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 5)
contentPadding.PaddingBottom = UDim.new(0, 10)
contentPadding.Parent = contentFrame

-- Helper: Create a section
local function createSection(title, content)
	local section = Instance.new("Frame")
	section.Name = title
	section.Size = UDim2.new(1, -20, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	section.BorderSizePixel = 0
	section.Parent = contentFrame

	local sectionCorner = Instance.new("UICorner")
	sectionCorner.CornerRadius = UDim.new(0, 8)
	sectionCorner.Parent = section

	local sectionPadding = Instance.new("UIPadding")
	sectionPadding.PaddingLeft = UDim.new(0, 12)
	sectionPadding.PaddingRight = UDim.new(0, 12)
	sectionPadding.PaddingTop = UDim.new(0, 10)
	sectionPadding.PaddingBottom = UDim.new(0, 10)
	sectionPadding.Parent = section

	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.Padding = UDim.new(0, 6)
	sectionLayout.Parent = section

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 22)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = section

	-- Content
	local contentLabel = Instance.new("TextLabel")
	contentLabel.Name = "Content"
	contentLabel.Size = UDim2.new(1, 0, 0, 0)
	contentLabel.AutomaticSize = Enum.AutomaticSize.Y
	contentLabel.BackgroundTransparency = 1
	contentLabel.Text = content
	contentLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	contentLabel.Font = Enum.Font.Gotham
	contentLabel.TextSize = 13
	contentLabel.TextXAlignment = Enum.TextXAlignment.Left
	contentLabel.TextYAlignment = Enum.TextYAlignment.Top
	contentLabel.TextWrapped = true
	contentLabel.RichText = true
	contentLabel.Parent = section

	return section
end

-- Create sections
createSection("OBJECTIVE",
	"Survive against waves of Kodos! Build mazes to slow them down, place turrets to deal damage, and work with your team to last as long as possible.")

createSection("CONTROLS",
	"<font color='rgb(100,200,255)'>[B]</font> - Open Build Menu\n" ..
	"<font color='rgb(100,200,255)'>[R]</font> - Rotate building (while placing)\n" ..
	"<font color='rgb(100,200,255)'>[X]</font> - Toggle Sell Mode\n" ..
	"<font color='rgb(100,200,255)'>[F]</font> - Repair / Assist Build (hold near structure)\n" ..
	"<font color='rgb(100,200,255)'>[E]</font> - Mine gold (at gold mines)\n" ..
	"<font color='rgb(100,200,255)'>[U]</font> - Open Workshop (near Workshop building)\n" ..
	"<font color='rgb(100,200,255)'>[P]</font> - Player Upgrades\n" ..
	"<font color='rgb(100,200,255)'>[M]</font> - Toggle Minimap / Full Map\n" ..
	"<font color='rgb(100,200,255)'>[H]</font> - This Help Screen\n" ..
	"<font color='rgb(100,200,255)'>[Shift]</font> - Sprint\n" ..
	"<font color='rgb(100,200,255)'>[Esc]</font> - Close menus / Cancel placement")

createSection("BUILDING TIPS",
	"<font color='rgb(255,200,100)'>Barricades</font> - Cheap maze walls. Place them with small gaps - you can squeeze through but Kodos can't!\n\n" ..
	"<font color='rgb(255,200,100)'>Walls</font> - Heavy defensive barriers. Use to protect your turrets.\n\n" ..
	"<font color='rgb(255,200,100)'>Turrets</font> - Deal damage to Kodos. Different types counter different Kodo types.\n\n" ..
	"<font color='rgb(255,200,100)'>Farms</font> - Generate passive gold income. Protect them!\n\n" ..
	"<font color='rgb(255,200,100)'>Workshop</font> - Unlocks advanced turrets. Build one early!\n\n" ..
	"<font color='rgb(255,200,100)'>Auras</font> - Buff nearby turrets and buildings.")

createSection("EARNING GOLD",
	"<font color='rgb(255,220,100)'>Passive Income</font> - Small amount every few seconds\n" ..
	"<font color='rgb(255,220,100)'>Gold Mines</font> - Stand near and hold E to mine (risky but fast!)\n" ..
	"<font color='rgb(255,220,100)'>Farms</font> - Build farms for steady income\n" ..
	"<font color='rgb(255,220,100)'>Kill Gold</font> - Earn gold when turrets kill Kodos\n" ..
	"<font color='rgb(255,220,100)'>Power-ups</font> - Grab Gold Rush pickups on the map")

createSection("CONSTRUCTION",
	"Buildings start transparent and fade in as they're built.\n\n" ..
	"<font color='rgb(100,255,200)'>Speed up construction:</font> Stand near your building and hold F to assist. Adds +50% build speed but puts you at risk!")

createSection("REPAIR",
	"Damaged buildings show a <font color='rgb(255,100,100)'>red health bar</font>.\n\n" ..
	"Stand near and hold F to repair. Costs gold (1 gold per 5 HP repaired).")

createSection("KODO TYPES",
	"<font color='rgb(200,150,100)'>Normal</font> - Balanced threat\n" ..
	"<font color='rgb(255,255,255)'>Swift</font> - Fast but fragile, weak to frost\n" ..
	"<font color='rgb(255,180,100)'>Mini</font> - Tiny! Can fit through maze gaps\n" ..
	"<font color='rgb(200,50,50)'>Horde</font> - Swarms of weak kodos\n" ..
	"<font color='rgb(100,255,100)'>Venomous</font> - Immune to poison, weak to frost\n" ..
	"<font color='rgb(150,200,255)'>Frostborn</font> - Immune to frost, weak to physical\n" ..
	"<font color='rgb(150,150,150)'>Armored</font> - Tanky, weak to poison/AOE\n" ..
	"<font color='rgb(100,80,60)'>Brute</font> - Slow but devastating to buildings")

-- Toggle help panel
local function toggleHelp()
	isHelpOpen = not isHelpOpen
	helpPanel.Visible = isHelpOpen
end

local function closeHelp()
	isHelpOpen = false
	helpPanel.Visible = false
end

-- Button click
helpButton.MouseButton1Click:Connect(toggleHelp)

-- Keyboard shortcuts
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == HELP_KEY then
		toggleHelp()
	elseif input.KeyCode == Enum.KeyCode.Escape and isHelpOpen then
		closeHelp()
	end
end)

-- Button hover effects
helpButton.MouseEnter:Connect(function()
	helpButton.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
end)

helpButton.MouseLeave:Connect(function()
	helpButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
end)

print("HelpScreen: Loaded - Press H or click ? for help")
