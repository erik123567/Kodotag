local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Wait for remote event
local soloStartRequest = ReplicatedStorage:WaitForChild("SoloStartRequest", 10)

if not soloStartRequest then
	warn("SoloStartRequest not found!")
	return
end

-- Listen for E key press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.E then
		-- Request solo start from server
		soloStartRequest:FireServer()
		print("Requested solo start")
	end
end)

print("Solo start handler loaded")