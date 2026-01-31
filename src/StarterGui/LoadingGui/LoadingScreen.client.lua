-- LOADING SCREEN
-- Shows during teleport and game initialization

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Create loading screen elements
local loadingFrame = Instance.new("Frame")
loadingFrame.Name = "LoadingFrame"
loadingFrame.Size = UDim2.new(1, 0, 1, 0)
loadingFrame.Position = UDim2.new(0, 0, 0, 0)
loadingFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
loadingFrame.BorderSizePixel = 0
loadingFrame.Visible = false
loadingFrame.ZIndex = 100
loadingFrame.Parent = screenGui

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 80)
titleLabel.Position = UDim2.new(0, 0, 0.35, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "KODO TAG"
titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 56
titleLabel.ZIndex = 101
titleLabel.Parent = loadingFrame

-- Loading text
local loadingLabel = Instance.new("TextLabel")
loadingLabel.Name = "LoadingText"
loadingLabel.Size = UDim2.new(1, 0, 0, 40)
loadingLabel.Position = UDim2.new(0, 0, 0.5, 0)
loadingLabel.BackgroundTransparency = 1
loadingLabel.Text = "Loading..."
loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
loadingLabel.Font = Enum.Font.GothamBold
loadingLabel.TextSize = 24
loadingLabel.ZIndex = 101
loadingLabel.Parent = loadingFrame

-- Spinner container
local spinnerFrame = Instance.new("Frame")
spinnerFrame.Name = "Spinner"
spinnerFrame.Size = UDim2.new(0, 60, 0, 60)
spinnerFrame.Position = UDim2.new(0.5, -30, 0.6, 0)
spinnerFrame.BackgroundTransparency = 1
spinnerFrame.ZIndex = 101
spinnerFrame.Parent = loadingFrame

-- Create spinner dots
local numDots = 8
local dots = {}
for i = 1, numDots do
	local angle = (i - 1) * (360 / numDots)
	local rad = math.rad(angle)
	local x = math.cos(rad) * 25
	local y = math.sin(rad) * 25

	local dot = Instance.new("Frame")
	dot.Name = "Dot" .. i
	dot.Size = UDim2.new(0, 10, 0, 10)
	dot.Position = UDim2.new(0.5, x - 5, 0.5, y - 5)
	dot.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
	dot.BorderSizePixel = 0
	dot.ZIndex = 101
	dot.Parent = spinnerFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	dots[i] = dot
end

-- Tip text
local tipLabel = Instance.new("TextLabel")
tipLabel.Name = "Tip"
tipLabel.Size = UDim2.new(0.8, 0, 0, 30)
tipLabel.Position = UDim2.new(0.1, 0, 0.75, 0)
tipLabel.BackgroundTransparency = 1
tipLabel.Text = ""
tipLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
tipLabel.Font = Enum.Font.Gotham
tipLabel.TextSize = 16
tipLabel.ZIndex = 101
tipLabel.Parent = loadingFrame

-- Tips to display
local tips = {
	"Build mazes to slow down the Kodos!",
	"Dead players can use abilities to help survivors",
	"Farms provide passive gold income",
	"Gold mines give more gold but require you to leave base",
	"Press M to open the full map",
	"Different turrets are effective against different Kodo types",
	"Mini Kodos can fit through small gaps!",
	"Power-ups spawn randomly around the map",
	"Barricades are cheap and great for maze building",
	"Work together to survive longer waves!",
}

-- Animate spinner
local spinnerConnection = nil
local function startSpinner()
	local time = 0
	spinnerConnection = RunService.RenderStepped:Connect(function(dt)
		time = time + dt * 3
		for i, dot in ipairs(dots) do
			local offset = (i - 1) / numDots * math.pi * 2
			local alpha = (math.sin(time + offset) + 1) / 2
			dot.BackgroundTransparency = 1 - alpha * 0.8
			dot.Size = UDim2.new(0, 6 + alpha * 6, 0, 6 + alpha * 6)

			local angle = (i - 1) * (360 / numDots)
			local rad = math.rad(angle)
			local x = math.cos(rad) * 25
			local y = math.sin(rad) * 25
			dot.Position = UDim2.new(0.5, x - (3 + alpha * 3), 0.5, y - (3 + alpha * 3))
		end
	end)
end

local function stopSpinner()
	if spinnerConnection then
		spinnerConnection:Disconnect()
		spinnerConnection = nil
	end
end

-- Show loading screen
local function showLoading(message)
	loadingLabel.Text = message or "Loading..."
	tipLabel.Text = tips[math.random(1, #tips)]
	loadingFrame.BackgroundTransparency = 1
	loadingFrame.Visible = true

	-- Fade in
	local fadeIn = TweenService:Create(loadingFrame, TweenInfo.new(0.3), {
		BackgroundTransparency = 0
	})
	fadeIn:Play()

	startSpinner()
end

-- Hide loading screen
local function hideLoading()
	-- Fade out
	local fadeOut = TweenService:Create(loadingFrame, TweenInfo.new(0.5), {
		BackgroundTransparency = 1
	})
	fadeOut:Play()
	fadeOut.Completed:Wait()

	loadingFrame.Visible = false
	stopSpinner()
end

-- Show loading screen IMMEDIATELY on any server (hide later if lobby)
-- This prevents the frozen screen gap during teleport
showLoading("Loading...")

-- Check if this is a game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 5)
if isGameServerValue and isGameServerValue.Value then
	-- We're on a game server, keep loading visible
	loadingLabel.Text = "Preparing game..."

	-- Wait for round to start
	local roundStarted = ReplicatedStorage:WaitForChild("RoundStarted", 30)
	if roundStarted then
		roundStarted.OnClientEvent:Connect(function()
			task.delay(0.5, function()
				hideLoading()
			end)
		end)
	end

	-- Fallback: hide after character loads and a short delay
	player.CharacterAdded:Connect(function()
		task.delay(2, function()
			if loadingFrame.Visible then
				hideLoading()
			end
		end)
	end)

	-- Safety timeout
	task.delay(15, function()
		if loadingFrame.Visible then
			hideLoading()
		end
	end)
else
	-- We're on lobby server, hide loading screen quickly
	task.delay(0.5, function()
		hideLoading()
	end)
end

-- Listen for teleport starting (from lobby)
local teleportStarting = ReplicatedStorage:FindFirstChild("TeleportStarting")
if teleportStarting then
	teleportStarting.OnClientEvent:Connect(function()
		showLoading("Teleporting to game...")
	end)
end

print("LoadingScreen: Ready")
