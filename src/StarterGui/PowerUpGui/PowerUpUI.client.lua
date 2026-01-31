-- POWER-UP UI
-- Shows notifications when power-ups are collected and tracks active effects

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Check if game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	print("PowerUpUI: Lobby - disabled")
	return
end

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Wait for remote events
local powerUpCollected = ReplicatedStorage:WaitForChild("PowerUpCollected", 10)
local powerUpSpawned = ReplicatedStorage:WaitForChild("PowerUpSpawned", 10)

if not powerUpCollected then
	warn("PowerUpUI: Missing remote events")
	return
end

-- Active effects display (top of screen, below game info)
local activeEffectsFrame = Instance.new("Frame")
activeEffectsFrame.Name = "ActiveEffects"
activeEffectsFrame.Size = UDim2.new(0, 300, 0, 50)
activeEffectsFrame.Position = UDim2.new(0.5, -150, 0, 100)
activeEffectsFrame.BackgroundTransparency = 1
activeEffectsFrame.Parent = screenGui

local effectsLayout = Instance.new("UIListLayout")
effectsLayout.FillDirection = Enum.FillDirection.Horizontal
effectsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
effectsLayout.Padding = UDim.new(0, 8)
effectsLayout.Parent = activeEffectsFrame

-- Notification container (center-right of screen)
local notificationFrame = Instance.new("Frame")
notificationFrame.Name = "Notifications"
notificationFrame.Size = UDim2.new(0, 250, 0, 300)
notificationFrame.Position = UDim2.new(1, -260, 0.3, 0)
notificationFrame.BackgroundTransparency = 1
notificationFrame.Parent = screenGui

local notificationLayout = Instance.new("UIListLayout")
notificationLayout.FillDirection = Enum.FillDirection.Vertical
notificationLayout.VerticalAlignment = Enum.VerticalAlignment.Top
notificationLayout.Padding = UDim.new(0, 5)
notificationLayout.Parent = notificationFrame

-- Track active effects
local activeEffects = {}

-- Create active effect indicator
local function createEffectIndicator(powerUpName, displayName, color, duration)
	local indicator = Instance.new("Frame")
	indicator.Name = "Effect_" .. powerUpName
	indicator.Size = UDim2.new(0, 60, 0, 50)
	indicator.BackgroundColor3 = color
	indicator.BackgroundTransparency = 0.3
	indicator.Parent = activeEffectsFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = indicator

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = indicator

	-- Icon/name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = displayName:sub(1, 8)
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 10
	nameLabel.TextScaled = true
	nameLabel.Parent = indicator

	-- Timer
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.Size = UDim2.new(1, 0, 0.5, 0)
	timerLabel.Position = UDim2.new(0, 0, 0.5, -2)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = duration .. "s"
	timerLabel.TextColor3 = Color3.new(1, 1, 1)
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextSize = 16
	timerLabel.Parent = indicator

	-- Progress bar background
	local progressBg = Instance.new("Frame")
	progressBg.Size = UDim2.new(0.9, 0, 0, 4)
	progressBg.Position = UDim2.new(0.05, 0, 1, -6)
	progressBg.BackgroundColor3 = Color3.new(0, 0, 0)
	progressBg.BackgroundTransparency = 0.5
	progressBg.BorderSizePixel = 0
	progressBg.Parent = indicator

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 2)
	progressCorner.Parent = progressBg

	-- Progress bar fill
	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.new(1, 0, 1, 0)
	progressFill.BackgroundColor3 = color
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 2)
	fillCorner.Parent = progressFill

	return indicator
end

-- Create collection notification
local function createNotification(collectorName, powerUpName, displayName, color, isLocal)
	local notification = Instance.new("Frame")
	notification.Size = UDim2.new(1, 0, 0, 40)
	notification.BackgroundColor3 = color
	notification.BackgroundTransparency = 0.7
	notification.Parent = notificationFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1
	stroke.Parent = notification

	-- Text
	local text = isLocal and "You collected " .. displayName .. "!" or collectorName .. " got " .. displayName
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -10, 1, 0)
	textLabel.Position = UDim2.new(0, 5, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = isLocal and 14 or 12
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextStrokeTransparency = 0.5
	textLabel.Parent = notification

	-- Animate in
	notification.Position = UDim2.new(1, 0, 0, 0)
	local slideIn = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0, 0, 0, 0)
	})
	slideIn:Play()

	-- Fade out after delay
	task.delay(3, function()
		local fadeOut = TweenService:Create(notification, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
			Position = UDim2.new(1, 0, 0, 0)
		})
		TweenService:Create(textLabel, TweenInfo.new(0.5), {
			TextTransparency = 1,
			TextStrokeTransparency = 1
		}):Play()
		fadeOut:Play()
		fadeOut.Completed:Wait()
		notification:Destroy()
	end)
end

-- Create spawn notification (subtle indicator)
local function createSpawnIndicator(powerUpName, displayName, position, color)
	-- Create a brief on-screen indicator showing direction
	local camera = workspace.CurrentCamera
	if not camera then return end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Calculate direction
	local direction = (Vector3.new(position.X, 0, position.Z) - Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)).Unit
	local distance = (position - rootPart.Position).Magnitude

	if distance > 150 then return end -- Too far to show

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 150, 0, 30)
	indicator.Position = UDim2.new(0.5, -75, 0.85, 0)
	indicator.BackgroundColor3 = color
	indicator.BackgroundTransparency = 0.6
	indicator.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = indicator

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = displayName .. " spawned!"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 12
	text.Parent = indicator

	-- Fade out
	task.delay(2, function()
		local fadeOut = TweenService:Create(indicator, TweenInfo.new(0.5), {
			BackgroundTransparency = 1
		})
		TweenService:Create(text, TweenInfo.new(0.5), {
			TextTransparency = 1
		}):Play()
		fadeOut:Play()
		fadeOut.Completed:Wait()
		indicator:Destroy()
	end)
end

-- Handle power-up collection
powerUpCollected.OnClientEvent:Connect(function(collectorName, powerUpName, displayName, color, duration)
	local isLocal = (collectorName == player.Name)

	-- Show notification
	createNotification(collectorName, powerUpName, displayName, color, isLocal)

	-- If it's our power-up with duration, show active effect
	if isLocal and duration > 0 then
		local indicator = createEffectIndicator(powerUpName, displayName, color, duration)

		-- Track effect
		local endTime = tick() + duration
		activeEffects[powerUpName] = {
			indicator = indicator,
			endTime = endTime,
			duration = duration
		}
	end

	-- Play sound effect for local player
	if isLocal then
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://6042053626" -- Power-up sound
		sound.Volume = 0.5
		sound.Parent = screenGui
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
end)

-- Handle power-up spawn notification
if powerUpSpawned then
	powerUpSpawned.OnClientEvent:Connect(function(powerUpName, displayName, position, color)
		createSpawnIndicator(powerUpName, displayName, position, color)
	end)
end

-- Handle bonus vein spawn notification
local veinSpawned = ReplicatedStorage:FindFirstChild("VeinSpawned")
if veinSpawned then
	veinSpawned.OnClientEvent:Connect(function(position, goldAmount)
		-- Show spawn indicator
		local character = player.Character
		if not character then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		local distance = (position - rootPart.Position).Magnitude
		if distance > 150 then return end

		local indicator = Instance.new("Frame")
		indicator.Size = UDim2.new(0, 180, 0, 35)
		indicator.Position = UDim2.new(0.5, -90, 0.82, 0)
		indicator.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		indicator.BackgroundTransparency = 0.4
		indicator.Parent = screenGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = indicator

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 215, 0)
		stroke.Thickness = 2
		stroke.Parent = indicator

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Text = "BONUS VEIN: " .. goldAmount .. "g!"
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 14
		text.Parent = indicator

		-- Attention-grabbing animation
		local pulse = TweenService:Create(indicator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 2, true), {
			Size = UDim2.new(0, 195, 0, 40)
		})
		pulse:Play()

		-- Fade out
		task.delay(3, function()
			local fadeOut = TweenService:Create(indicator, TweenInfo.new(0.5), {
				BackgroundTransparency = 1
			})
			TweenService:Create(text, TweenInfo.new(0.5), {
				TextTransparency = 1
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.5), {
				Transparency = 1
			}):Play()
			fadeOut:Play()
			fadeOut.Completed:Wait()
			indicator:Destroy()
		end)

		-- Play sound
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://4612373815" -- Sparkle/coin sound
		sound.Volume = 0.4
		sound.Parent = screenGui
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end)
end

-- Update active effects
RunService.Heartbeat:Connect(function()
	for powerUpName, data in pairs(activeEffects) do
		local remaining = data.endTime - tick()

		if remaining <= 0 then
			-- Effect expired
			if data.indicator.Parent then
				local fadeOut = TweenService:Create(data.indicator, TweenInfo.new(0.3), {
					BackgroundTransparency = 1
				})
				fadeOut:Play()
				fadeOut.Completed:Wait()
				data.indicator:Destroy()
			end
			activeEffects[powerUpName] = nil
		else
			-- Update timer
			local timerLabel = data.indicator:FindFirstChild("Timer")
			if timerLabel then
				timerLabel.Text = math.ceil(remaining) .. "s"
			end

			-- Update progress bar
			local progressBg = data.indicator:FindFirstChild("Frame")
			if progressBg then
				local fill = progressBg:FindFirstChild("Fill")
				if fill then
					fill.Size = UDim2.new(remaining / data.duration, 0, 1, 0)
				end
			end
		end
	end
end)

print("PowerUpUI: Loaded!")
