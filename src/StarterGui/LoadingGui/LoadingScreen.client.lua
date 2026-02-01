-- LOADING SCREEN
-- Uses pre-existing LoadingFrame (visible by default)
-- Just hides it when game is ready

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local screenGui = script.Parent

-- Find the pre-existing LoadingFrame
local loadingFrame = screenGui:WaitForChild("LoadingFrame", 5)
if not loadingFrame then
	warn("LoadingScreen: LoadingFrame not found!")
	return
end

local loadingLabel = loadingFrame:FindFirstChild("LoadingText")
local dotsLabel = loadingFrame:FindFirstChild("Dots")

-- Animate the dots
local dotCount = 0
local spinConn = RunService.RenderStepped:Connect(function(dt)
	if dotsLabel then
		dotCount = (dotCount + dt * 3) % 4
		dotsLabel.Text = string.rep(".", math.floor(dotCount) + 1)
	end
end)

-- Hide loading screen function
local function hideLoading()
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end

	local fadeOut = TweenService:Create(loadingFrame, TweenInfo.new(0.5), {
		BackgroundTransparency = 1
	})

	-- Also fade children
	for _, child in ipairs(loadingFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		end
	end

	fadeOut:Play()
	fadeOut.Completed:Wait()
	loadingFrame.Visible = false
end

-- Check if this is a game server
local isGameServerValue = ReplicatedStorage:WaitForChild("IsGameServer", 10)

if isGameServerValue and isGameServerValue.Value then
	-- GAME SERVER
	if loadingLabel then
		loadingLabel.Text = "Preparing game..."
	end

	local ready = false

	-- Check if already ready
	local gameReadyFlag = ReplicatedStorage:FindFirstChild("GameReadyFlag")
	if gameReadyFlag and gameReadyFlag.Value then
		ready = true
		task.delay(0.3, hideLoading)
	else
		-- Wait for GameReady event
		local gameReady = ReplicatedStorage:WaitForChild("GameReady", 30)
		if gameReady then
			gameReady.OnClientEvent:Connect(function()
				if not ready then
					ready = true
					task.delay(0.3, hideLoading)
				end
			end)
		end

		-- Watch flag
		task.spawn(function()
			local flag = ReplicatedStorage:WaitForChild("GameReadyFlag", 30)
			if flag then
				if flag.Value and not ready then
					ready = true
					task.delay(0.3, hideLoading)
				end
				flag.Changed:Connect(function(v)
					if v and not ready then
						ready = true
						task.delay(0.3, hideLoading)
					end
				end)
			end
		end)

		-- Also listen for RoundStarted as fallback
		local roundStarted = ReplicatedStorage:WaitForChild("RoundStarted", 30)
		if roundStarted then
			roundStarted.OnClientEvent:Connect(function()
				if not ready then
					ready = true
					hideLoading()
				end
			end)
		end

		-- Safety timeout
		task.delay(15, function()
			if not ready then
				ready = true
				hideLoading()
			end
		end)
	end
else
	-- LOBBY SERVER - hide after short delay
	task.delay(0.5, hideLoading)
end

print("LoadingScreen: Active")
