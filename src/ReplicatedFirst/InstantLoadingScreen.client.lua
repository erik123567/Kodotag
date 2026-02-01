-- INSTANT LOADING SCREEN - ReplicatedFirst
print(">>> InstantLoadingScreen: STARTING")

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Remove Roblox loading screen immediately
ReplicatedFirst:RemoveDefaultLoadingScreen()
print(">>> InstantLoadingScreen: Removed default loading screen")

-- Get player GUI
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
print(">>> InstantLoadingScreen: Got PlayerGui")

-- CREATE GUI IMMEDIATELY
local gui = Instance.new("ScreenGui")
gui.Name = "InstantLoading"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
frame.BackgroundTransparency = 0
frame.BorderSizePixel = 0
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 80)
title.Position = UDim2.new(0, 0, 0.35, 0)
title.BackgroundTransparency = 1
title.Text = "KODO TAG"
title.TextColor3 = Color3.fromRGB(255, 100, 100)
title.Font = Enum.Font.GothamBlack
title.TextSize = 56
title.Parent = frame

local loading = Instance.new("TextLabel")
loading.Size = UDim2.new(1, 0, 0, 40)
loading.Position = UDim2.new(0, 0, 0.5, 0)
loading.BackgroundTransparency = 1
loading.Text = "Loading..."
loading.TextColor3 = Color3.fromRGB(200, 200, 200)
loading.Font = Enum.Font.GothamBold
loading.TextSize = 24
loading.Parent = frame

local dots = Instance.new("TextLabel")
dots.Size = UDim2.new(1, 0, 0, 40)
dots.Position = UDim2.new(0, 0, 0.58, 0)
dots.BackgroundTransparency = 1
dots.Text = "..."
dots.TextColor3 = Color3.fromRGB(255, 100, 100)
dots.Font = Enum.Font.GothamBold
dots.TextSize = 32
dots.Parent = frame

print(">>> InstantLoadingScreen: GUI CREATED AND VISIBLE")

-- Animate
local count = 0
local conn = RunService.RenderStepped:Connect(function(dt)
	count = (count + dt * 3) % 4
	dots.Text = string.rep(".", math.floor(count) + 1)
end)

-- Hide function
local hidden = false
local function hide(reason)
	if hidden then return end
	hidden = true
	print(">>> InstantLoadingScreen: HIDING because:", reason)
	if conn then conn:Disconnect() end
	local tween = TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
	TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
	TweenService:Create(loading, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
	TweenService:Create(dots, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
	tween:Play()
	tween.Completed:Wait()
	gui:Destroy()
	print(">>> InstantLoadingScreen: DESTROYED")
end

-- Wait for game ready in background
task.spawn(function()
	local RS = game:GetService("ReplicatedStorage")

	-- Wait for IsGameServer - THIS IS KEY
	print(">>> InstantLoadingScreen: Waiting for IsGameServer...")
	local isGame = RS:WaitForChild("IsGameServer", 30)

	if not isGame then
		print(">>> InstantLoadingScreen: IsGameServer NOT FOUND after 30s")
		-- Still on loading/connecting, keep showing
		task.delay(10, function()
			hide("IsGameServer timeout")
		end)
		return
	end

	print(">>> InstantLoadingScreen: IsGameServer =", isGame.Value)

	if isGame.Value == true then
		-- GAME SERVER - wait for actual ready signal
		loading.Text = "Preparing game..."
		print(">>> InstantLoadingScreen: This is GAME SERVER, waiting for ready signal...")

		-- Listen for ready signals
		local gameReady = RS:WaitForChild("GameReady", 30)
		if gameReady then
			print(">>> InstantLoadingScreen: Found GameReady event, listening...")
			gameReady.OnClientEvent:Connect(function()
				print(">>> InstantLoadingScreen: GameReady EVENT FIRED")
				hide("GameReady event")
			end)
		end

		-- Also check/watch flag
		task.spawn(function()
			local flag = RS:WaitForChild("GameReadyFlag", 30)
			if flag then
				print(">>> InstantLoadingScreen: Found GameReadyFlag, value =", flag.Value)
				if flag.Value == true then
					print(">>> InstantLoadingScreen: Flag already true!")
					hide("GameReadyFlag already true")
				else
					flag.Changed:Connect(function(v)
						print(">>> InstantLoadingScreen: GameReadyFlag changed to", v)
						if v then
							hide("GameReadyFlag changed to true")
						end
					end)
				end
			end
		end)

		-- Safety timeout - but make it long
		task.delay(30, function()
			hide("30 second timeout")
		end)
	else
		-- LOBBY SERVER
		print(">>> InstantLoadingScreen: This is LOBBY, hiding in 1 second")
		task.delay(1, function()
			hide("Lobby server")
		end)
	end
end)
