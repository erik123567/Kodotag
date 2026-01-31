-- SPECTATOR CAMERA
-- Free camera when dead, can follow other players or fly freely

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Check if game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)
if not isGameServerValue or not isGameServerValue.Value then
	return
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local screenGui = script.Parent

-- State
local isSpectating = false
local spectateMode = "free" -- "free" or "follow"
local followTarget = nil
local followIndex = 1

-- Camera settings
local FREE_MOVE_SPEED = 50
local FREE_SPRINT_MULTIPLIER = 2
local MOUSE_SENSITIVITY = 0.3
local FOLLOW_DISTANCE = 20
local FOLLOW_HEIGHT = 10

-- Input state
local moveDirection = Vector3.new(0, 0, 0)
local cameraAngleX = 0
local cameraAngleY = 0
local isSprinting = false

-- UI Elements
local spectatorPanel = Instance.new("Frame")
spectatorPanel.Name = "SpectatorPanel"
spectatorPanel.Size = UDim2.new(0, 300, 0, 100)
spectatorPanel.Position = UDim2.new(0.5, -150, 1, -120)
spectatorPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
spectatorPanel.BackgroundTransparency = 0.3
spectatorPanel.BorderSizePixel = 0
spectatorPanel.Visible = false
spectatorPanel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = spectatorPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(100, 100, 120)
panelStroke.Thickness = 2
panelStroke.Parent = spectatorPanel

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 25)
titleLabel.Position = UDim2.new(0, 0, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SPECTATOR MODE"
titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = spectatorPanel

-- Mode label
local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "Mode"
modeLabel.Size = UDim2.new(1, 0, 0, 20)
modeLabel.Position = UDim2.new(0, 0, 0, 28)
modeLabel.BackgroundTransparency = 1
modeLabel.Text = "Free Camera"
modeLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextSize = 16
modeLabel.Parent = spectatorPanel

-- Controls help
local controlsLabel = Instance.new("TextLabel")
controlsLabel.Name = "Controls"
controlsLabel.Size = UDim2.new(1, -20, 0, 40)
controlsLabel.Position = UDim2.new(0, 10, 0, 52)
controlsLabel.BackgroundTransparency = 1
controlsLabel.Text = "WASD: Move | Mouse: Look | Shift: Fast\nQ/E: Up/Down | Tab: Follow Player | Space: Free Cam"
controlsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
controlsLabel.Font = Enum.Font.Gotham
controlsLabel.TextSize = 11
controlsLabel.TextWrapped = true
controlsLabel.Parent = spectatorPanel

-- Get alive players (for follow mode)
local function getAlivePlayers()
	local alive = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local humanoid = p.Character:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(alive, p)
			end
		end
	end
	return alive
end

-- Start spectating
local function startSpectating()
	if isSpectating then return end
	isSpectating = true

	-- Store current camera angles based on camera direction
	local lookVector = camera.CFrame.LookVector
	cameraAngleY = math.atan2(-lookVector.X, -lookVector.Z)
	cameraAngleX = math.asin(lookVector.Y)

	-- Set camera to scriptable
	camera.CameraType = Enum.CameraType.Scriptable

	-- Show UI
	spectatorPanel.Visible = true

	-- Start in free mode at current position
	spectateMode = "free"
	modeLabel.Text = "Free Camera"

	print("SpectatorCamera: Started spectating")
end

-- Stop spectating
local function stopSpectating()
	if not isSpectating then return end
	isSpectating = false

	-- Reset camera
	camera.CameraType = Enum.CameraType.Custom

	-- Hide UI
	spectatorPanel.Visible = false

	followTarget = nil

	print("SpectatorCamera: Stopped spectating")
end

-- Switch to follow mode
local function switchToFollow()
	local alivePlayers = getAlivePlayers()
	if #alivePlayers == 0 then
		modeLabel.Text = "No players to follow"
		return
	end

	spectateMode = "follow"
	followIndex = ((followIndex - 1) % #alivePlayers) + 1
	followTarget = alivePlayers[followIndex]

	if followTarget then
		modeLabel.Text = "Following: " .. followTarget.DisplayName
	end

	followIndex = followIndex + 1
end

-- Switch to free mode
local function switchToFree()
	spectateMode = "free"
	followTarget = nil
	modeLabel.Text = "Free Camera"
end

-- Handle input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not isSpectating then return end
	if gameProcessed then return end

	-- Movement
	if input.KeyCode == Enum.KeyCode.W then
		moveDirection = moveDirection + Vector3.new(0, 0, -1)
	elseif input.KeyCode == Enum.KeyCode.S then
		moveDirection = moveDirection + Vector3.new(0, 0, 1)
	elseif input.KeyCode == Enum.KeyCode.A then
		moveDirection = moveDirection + Vector3.new(-1, 0, 0)
	elseif input.KeyCode == Enum.KeyCode.D then
		moveDirection = moveDirection + Vector3.new(1, 0, 0)
	elseif input.KeyCode == Enum.KeyCode.Q then
		moveDirection = moveDirection + Vector3.new(0, -1, 0)
	elseif input.KeyCode == Enum.KeyCode.E then
		moveDirection = moveDirection + Vector3.new(0, 1, 0)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = true
	-- Mode switching
	elseif input.KeyCode == Enum.KeyCode.Tab then
		switchToFollow()
	elseif input.KeyCode == Enum.KeyCode.Space then
		switchToFree()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if not isSpectating then return end

	-- Movement
	if input.KeyCode == Enum.KeyCode.W then
		moveDirection = moveDirection - Vector3.new(0, 0, -1)
	elseif input.KeyCode == Enum.KeyCode.S then
		moveDirection = moveDirection - Vector3.new(0, 0, 1)
	elseif input.KeyCode == Enum.KeyCode.A then
		moveDirection = moveDirection - Vector3.new(-1, 0, 0)
	elseif input.KeyCode == Enum.KeyCode.D then
		moveDirection = moveDirection - Vector3.new(1, 0, 0)
	elseif input.KeyCode == Enum.KeyCode.Q then
		moveDirection = moveDirection - Vector3.new(0, -1, 0)
	elseif input.KeyCode == Enum.KeyCode.E then
		moveDirection = moveDirection - Vector3.new(0, 1, 0)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = false
	end
end)

-- Mouse look
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if not isSpectating then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

	-- Only process when right mouse is held or in free mode
	if spectateMode == "free" or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		local delta = input.Delta
		cameraAngleY = cameraAngleY - delta.X * MOUSE_SENSITIVITY * 0.01
		cameraAngleX = math.clamp(cameraAngleX - delta.Y * MOUSE_SENSITIVITY * 0.01, -math.pi/2 + 0.1, math.pi/2 - 0.1)
	end
end)

-- Update loop
RunService.RenderStepped:Connect(function(dt)
	if not isSpectating then return end

	if spectateMode == "free" then
		-- Free camera movement
		local speed = FREE_MOVE_SPEED * (isSprinting and FREE_SPRINT_MULTIPLIER or 1)

		-- Calculate camera rotation
		local rotation = CFrame.Angles(cameraAngleX, cameraAngleY, 0)

		-- Move in camera direction
		local move = rotation:VectorToWorldSpace(moveDirection.Unit * speed * dt)
		if moveDirection.Magnitude > 0 then
			camera.CFrame = camera.CFrame + move
		end

		-- Apply rotation
		camera.CFrame = CFrame.new(camera.CFrame.Position) * rotation

	elseif spectateMode == "follow" and followTarget then
		-- Check if target still valid
		if not followTarget.Character or not followTarget.Character:FindFirstChild("HumanoidRootPart") then
			-- Target died or left, find new target
			local alivePlayers = getAlivePlayers()
			if #alivePlayers > 0 then
				followTarget = alivePlayers[1]
				modeLabel.Text = "Following: " .. followTarget.DisplayName
			else
				switchToFree()
				modeLabel.Text = "No players left"
				return
			end
		end

		local targetPart = followTarget.Character:FindFirstChild("HumanoidRootPart")
		if targetPart then
			-- Orbit around target
			local rotation = CFrame.Angles(0, cameraAngleY, 0)
			local offset = rotation:VectorToWorldSpace(Vector3.new(0, FOLLOW_HEIGHT, FOLLOW_DISTANCE))
			local targetPos = targetPart.Position + offset

			-- Smooth camera movement
			camera.CFrame = camera.CFrame:Lerp(
				CFrame.new(targetPos, targetPart.Position),
				dt * 5
			)
		end
	end
end)

-- Watch for player death/respawn
local function onCharacterAdded(character)
	-- Player respawned, stop spectating
	task.delay(0.5, function()
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid and humanoid.Health > 0 then
			stopSpectating()
		end
	end)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			-- Start spectating after death
			task.delay(1, function()
				startSpectating()
			end)
		end)
	end
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

-- Lock mouse when spectating in free mode
RunService.RenderStepped:Connect(function()
	if isSpectating and spectateMode == "free" then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

print("SpectatorCamera: Loaded")
