-- PAD STATUS UI
-- Shows game mode info when player is standing on a lobby pad

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Check if this is a lobby server (not a game server)
local isGameServerValue = ReplicatedStorage:FindFirstChild("IsGameServer")
local isGameServer = isGameServerValue and isGameServerValue.Value

-- Only run on lobby servers
if isGameServer and not RunService:IsStudio() then
	print("PadStatusUI: Game server - disabled")
	return
end

print("PadStatusUI: Lobby server - initializing")

-- Wait for remote event
local playerPadEvent = ReplicatedStorage:WaitForChild("PlayerPadStatus", 10)
if not playerPadEvent then
	warn("PadStatusUI: PlayerPadStatus event not found")
	return
end

-- Create the UI panel
local padPanel = Instance.new("Frame")
padPanel.Name = "PadStatusPanel"
padPanel.Size = UDim2.new(0, 300, 0, 120)
padPanel.Position = UDim2.new(0.5, -150, 1, -140)
padPanel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
padPanel.BackgroundTransparency = 0.1
padPanel.BorderSizePixel = 0
padPanel.Visible = false
padPanel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = padPanel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(0.3, 0.6, 1)
stroke.Thickness = 2
stroke.Parent = padPanel

-- Game mode title
local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.Size = UDim2.new(1, 0, 0, 35)
modeLabel.Position = UDim2.new(0, 0, 0, 8)
modeLabel.BackgroundTransparency = 1
modeLabel.Text = "SOLO GAME"
modeLabel.TextColor3 = Color3.new(1, 1, 1)
modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextSize = 24
modeLabel.Parent = padPanel

-- Player count
local countLabel = Instance.new("TextLabel")
countLabel.Name = "CountLabel"
countLabel.Size = UDim2.new(1, 0, 0, 25)
countLabel.Position = UDim2.new(0, 0, 0, 45)
countLabel.BackgroundTransparency = 1
countLabel.Text = "1/1 Players"
countLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
countLabel.Font = Enum.Font.Gotham
countLabel.TextSize = 18
countLabel.Parent = padPanel

-- Status text (countdown or instruction)
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -20, 0, 30)
statusLabel.Position = UDim2.new(0, 10, 1, -40)
statusLabel.BackgroundColor3 = Color3.new(0.2, 0.5, 0.3)
statusLabel.BackgroundTransparency = 0.5
statusLabel.Text = "Press E to Start"
statusLabel.TextColor3 = Color3.new(0.5, 1, 0.5)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 16
statusLabel.Parent = padPanel

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 6)
statusCorner.Parent = statusLabel

-- Update the UI based on pad data
local function updateUI(data)
	if not data or not data.joined then
		padPanel.Visible = false
		return
	end

	padPanel.Visible = true

	-- Update mode label and border color based on pad type
	local modeText = data.padType or "UNKNOWN"
	if data.padType == "SOLO" then
		modeText = "SOLO GAME"
		stroke.Color = Color3.new(0.3, 0.8, 0.4)
	elseif data.padType == "SMALL" then
		modeText = "SMALL GAME"
		stroke.Color = Color3.new(0.3, 0.6, 1)
	elseif data.padType == "MEDIUM" then
		modeText = "MEDIUM GAME"
		stroke.Color = Color3.new(0.8, 0.6, 0.2)
	elseif data.padType == "LARGE" then
		modeText = "LARGE GAME"
		stroke.Color = Color3.new(0.8, 0.3, 0.3)
	end
	modeLabel.Text = modeText

	-- Update player count (hide for solo pads)
	local count = data.count or 0
	local maxPlayers = data.maxPlayers or 1

	-- Update status based on pad type and state
	if data.padType == "SOLO" then
		countLabel.Text = ""  -- Hide player count for solo
		statusLabel.Text = "Press E to Start"
		statusLabel.TextColor3 = Color3.new(0.5, 1, 0.5)
		statusLabel.BackgroundColor3 = Color3.new(0.2, 0.5, 0.3)
	else
		countLabel.Text = count .. "/" .. maxPlayers .. " Players"
		-- Multiplayer pad
		local minPlayers = data.minPlayers or 2

		if data.isCountingDown then
			statusLabel.Text = "Starting in " .. (data.countdownTime or 0) .. "..."
			statusLabel.TextColor3 = Color3.new(1, 1, 0.5)
			statusLabel.BackgroundColor3 = Color3.new(0.5, 0.5, 0.2)
		elseif count >= minPlayers then
			statusLabel.Text = "Ready! Starting soon..."
			statusLabel.TextColor3 = Color3.new(0.5, 1, 0.5)
			statusLabel.BackgroundColor3 = Color3.new(0.2, 0.5, 0.3)
		else
			local needed = minPlayers - count
			statusLabel.Text = "Need " .. needed .. " more player" .. (needed > 1 and "s" or "")
			statusLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
			statusLabel.BackgroundColor3 = Color3.new(0.3, 0.3, 0.35)
		end
	end
end

-- Listen for pad status updates from server
playerPadEvent.OnClientEvent:Connect(function(data)
	if data.joined then
		updateUI(data)
	else
		-- Player left the pad
		padPanel.Visible = false
	end
end)

print("PadStatusUI: Loaded successfully")
