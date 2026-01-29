local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("ResurrectionShrine: Starting...")

-- Settings
local RESURRECTION_COOLDOWN = 30 -- Seconds before shrine can be used again
local SHRINE_RADIUS = 15 -- How close player needs to be to activate

-- State
local lastResurrectionTime = 0
local shrineActive = true

-- Wait for RoundManager
wait(2)
local RoundManager = _G.RoundManager

-- Find the shrine in workspace
local shrine = workspace:FindFirstChild("ResurrectionShrine")
if not shrine then
	warn("ResurrectionShrine: No ResurrectionShrine found in workspace!")
	return
end

local shrinePosition = shrine.Position or shrine:GetPivot().Position

-- Get notification event
local showNotification = ReplicatedStorage:WaitForChild("ShowNotification", 10)

-- Create visual indicator for shrine
local function createShrineIndicator()
	local existingIndicator = shrine:FindFirstChild("ShrineIndicator")
	if existingIndicator then
		existingIndicator:Destroy()
	end

	local indicator = Instance.new("Part")
	indicator.Name = "ShrineIndicator"
	indicator.Shape = Enum.PartType.Cylinder
	indicator.Size = Vector3.new(1, SHRINE_RADIUS * 2, SHRINE_RADIUS * 2)
	indicator.CFrame = CFrame.new(shrinePosition) * CFrame.Angles(0, 0, math.rad(90))
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.Material = Enum.Material.Neon
	indicator.Color = Color3.new(0, 1, 0.5)
	indicator.Transparency = 0.8
	indicator.Parent = shrine

	return indicator
end

local shrineIndicator = createShrineIndicator()

-- Update indicator color based on state
local function updateIndicator()
	if not shrineIndicator then return end

	if not shrineActive then
		shrineIndicator.Color = Color3.new(0.5, 0.5, 0.5)
		shrineIndicator.Transparency = 0.9
	elseif RoundManager and #RoundManager.deadPlayers > 0 then
		-- Dead players exist - shrine glows green
		shrineIndicator.Color = Color3.new(0, 1, 0.5)
		shrineIndicator.Transparency = 0.7
	else
		-- No dead players - shrine is dim
		shrineIndicator.Color = Color3.new(0.2, 0.5, 0.4)
		shrineIndicator.Transparency = 0.85
	end
end

-- Check if player is alive
local function isPlayerAlive(player)
	if not RoundManager or not RoundManager.alivePlayers then return false end
	for _, p in ipairs(RoundManager.alivePlayers) do
		if p == player then
			return true
		end
	end
	return false
end

-- Resurrect all dead players
local function resurrectDeadPlayers(activator)
	if not RoundManager then
		warn("ResurrectionShrine: RoundManager not available")
		return false
	end

	-- Check cooldown
	if tick() - lastResurrectionTime < RESURRECTION_COOLDOWN then
		local remaining = math.ceil(RESURRECTION_COOLDOWN - (tick() - lastResurrectionTime))
		if showNotification then
			showNotification:FireClient(activator, "Shrine on cooldown: " .. remaining .. "s", Color3.new(1, 0.5, 0))
		end
		return false
	end

	-- Check if there are dead players
	local deadPlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if RoundManager.playerStats[player.Name] then
			local isAlive = isPlayerAlive(player)
			if not isAlive and player ~= activator then
				table.insert(deadPlayers, player)
			end
		end
	end

	if #deadPlayers == 0 then
		if showNotification then
			showNotification:FireClient(activator, "No dead players to resurrect!", Color3.new(1, 1, 0))
		end
		return false
	end

	-- Resurrect dead players
	lastResurrectionTime = tick()
	shrineActive = false
	updateIndicator()

	local resurrectedCount = 0
	for _, deadPlayer in ipairs(deadPlayers) do
		-- Remove from dead list
		for i, p in ipairs(RoundManager.deadPlayers or {}) do
			if p == deadPlayer then
				table.remove(RoundManager.deadPlayers, i)
				break
			end
		end

		-- Spawn the player
		deadPlayer:LoadCharacter()
		local character = deadPlayer.Character or deadPlayer.CharacterAdded:Wait()
		wait(0.1)

		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				-- Spawn near the shrine
				local angle = math.random() * math.pi * 2
				local spawnOffset = Vector3.new(math.cos(angle) * 10, 3, math.sin(angle) * 10)
				humanoidRootPart.CFrame = CFrame.new(shrinePosition + spawnOffset)
			end

			-- Add to alive list
			table.insert(RoundManager.alivePlayers, deadPlayer)

			-- Update saves stat for activator
			if RoundManager.playerStats[activator.Name] then
				RoundManager.playerStats[activator.Name].saves = RoundManager.playerStats[activator.Name].saves + 1
			end

			-- Connect death handler
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				local deathConnection
				deathConnection = humanoid.Died:Connect(function()
					if _G.RoundManager then
						-- Handle death through RoundManager
						for i, p in ipairs(RoundManager.alivePlayers) do
							if p == deadPlayer then
								table.remove(RoundManager.alivePlayers, i)
								break
							end
						end
						table.insert(RoundManager.deadPlayers, deadPlayer)
						RoundManager.playerStats[deadPlayer.Name].deaths = RoundManager.playerStats[deadPlayer.Name].deaths + 1

						if showNotification then
							showNotification:FireAllClients(deadPlayer.Name .. " was killed by a Kodo!", Color3.new(1, 0, 0))
						end

						RoundManager.broadcastGameState()
						RoundManager.broadcastPlayerStats()
					end
					if deathConnection then
						deathConnection:Disconnect()
					end
				end)
			end

			resurrectedCount = resurrectedCount + 1
			print("ResurrectionShrine: Resurrected", deadPlayer.Name)
		end
	end

	-- Notify everyone
	if showNotification and resurrectedCount > 0 then
		showNotification:FireAllClients(activator.Name .. " resurrected " .. resurrectedCount .. " player(s)!", Color3.new(0, 1, 0.5))
	end

	RoundManager.broadcastGameState()
	RoundManager.broadcastPlayerStats()

	-- Cooldown timer
	task.spawn(function()
		wait(RESURRECTION_COOLDOWN)
		shrineActive = true
		updateIndicator()
		if showNotification then
			showNotification:FireAllClients("Resurrection Shrine is ready!", Color3.new(0, 1, 0.5))
		end
	end)

	return true
end

-- Main detection loop
task.spawn(function()
	while true do
		wait(0.5)

		-- Update indicator
		updateIndicator()

		-- Only check if shrine is active
		if not shrineActive then continue end
		if not RoundManager then continue end

		-- Check for alive players near shrine
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character and isPlayerAlive(player) then
				local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
				if humanoidRootPart then
					local distance = (humanoidRootPart.Position - shrinePosition).Magnitude
					if distance <= SHRINE_RADIUS then
						-- Player is in shrine zone - attempt resurrection
						resurrectDeadPlayers(player)
						break
					end
				end
			end
		end
	end
end)

print("ResurrectionShrine: Loaded! Radius:", SHRINE_RADIUS, "Cooldown:", RESURRECTION_COOLDOWN)
