local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local KodoAI = {}

-- Settings
local CHASE_RANGE = 300
local BASE_MOVE_SPEED = 16
local WANDER_DISTANCE = 50
local STRUCTURE_ATTACK_DAMAGE = 25
local STRUCTURE_ATTACK_COOLDOWN = 1
local PLAYER_KILL_RANGE = 5
local RAYCAST_DISTANCE = 15
local PATH_CACHE_TIME = 3

-- Setup collision groups
local collisionGroupsSetup = false
local function setupCollisionGroups()
	if collisionGroupsSetup then return end

	pcall(function()
		PhysicsService:RegisterCollisionGroup("Kodos")
		PhysicsService:CollisionGroupSetCollidable("Kodos", "Kodos", false)
	end)

	collisionGroupsSetup = true
end

-- Create health bar
local function createHealthBar(kodo)
	local humanoid = kodo:FindFirstChild("Humanoid")
	local rootPart = kodo:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.new(4, 0, 0.5, 0)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = rootPart
	billboard.Parent = rootPart

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	background.BorderSizePixel = 2
	background.BorderColor3 = Color3.new(0, 0, 0)
	background.Parent = billboard

	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.BackgroundColor3 = Color3.new(0, 1, 0)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = background

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = humanoid.Health .. " / " .. humanoid.MaxHealth
	healthText.TextColor3 = Color3.new(1, 1, 1)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.GothamBold
	healthText.TextStrokeTransparency = 0.5
	healthText.Parent = background

	humanoid.HealthChanged:Connect(function(health)
		local healthPercent = health / humanoid.MaxHealth
		healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
		healthText.Text = math.floor(health) .. " / " .. humanoid.MaxHealth

		if healthPercent > 0.6 then
			healthBar.BackgroundColor3 = Color3.new(0, 1, 0)
		elseif healthPercent > 0.3 then
			healthBar.BackgroundColor3 = Color3.new(1, 1, 0)
		else
			healthBar.BackgroundColor3 = Color3.new(1, 0, 0)
		end
	end)
end

function KodoAI.spawnKodo(kodoTemplate, spawnPosition, customSpeed)
	setupCollisionGroups()

	local kodo = kodoTemplate:Clone()
	kodo.Parent = workspace

	local rootPart = kodo:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 5, 0))
	end

	local humanoid = kodo:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = customSpeed or BASE_MOVE_SPEED

		-- Connect Died event IMMEDIATELY after creating Kodo
		humanoid.Died:Connect(function()
			print("KodoAI: Humanoid.Died event fired for", kodo.Name)
			KodoAI.handleDeath(kodo)
		end)

		print("KodoAI: Connected Died event for", kodo.Name)
	end

	for _, part in ipairs(kodo:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = "Kodos"
			end)
		end
	end

	createHealthBar(kodo)
	KodoAI.runAI(kodo)

	return kodo
end

function KodoAI.handleDeath(kodo)
	print("KodoAI.handleDeath called for:", kodo.Name)

	local rootPart = kodo:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local showNotification = ReplicatedStorage:FindFirstChild("ShowNotification")
	if showNotification then
		showNotification:FireAllClients("Kodo eliminated!", Color3.new(0, 1, 0))
	end

	local explosion = Instance.new("Explosion")
	explosion.Position = rootPart.Position
	explosion.BlastRadius = 8
	explosion.BlastPressure = 0
	explosion.Parent = workspace

	for _, part in ipairs(kodo:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	task.spawn(function()
		for i = 0, 1, 0.1 do
			for _, part in ipairs(kodo:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = i
				end
			end
			wait(0.05)
		end
		wait(0.5)
		kodo:Destroy()
	end)
end

-- Check if path to target is clear with raycast
local function isPathClear(startPos, targetPos, ignoreList)
	local direction = (targetPos - startPos)
	local distance = direction.Magnitude

	if distance > RAYCAST_DISTANCE then
		direction = direction.Unit * RAYCAST_DISTANCE
		distance = RAYCAST_DISTANCE
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = ignoreList
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(startPos, direction, rayParams)

	if result then
		local hit = result.Instance
		local structureNames = {
			Wall = true, Turret = true, FastTurret = true, SlowTurret = true,
			FrostTurret = true, PoisonTurret = true, MultiShotTurret = true, CannonTurret = true,
			Farm = true, Workshop = true
		}
		if structureNames[hit.Name] or structureNames[hit.Parent.Name] then
			return false, hit.Parent or hit
		end
	end

	return true, nil
end

-- Find blocking structure
local function findBlockingStructure(position)
	local nearestStructure = nil
	local nearestDistance = 10

	local structureNames = {
		Wall = true, Turret = true, FastTurret = true, SlowTurret = true,
		FrostTurret = true, PoisonTurret = true, MultiShotTurret = true, CannonTurret = true,
		Farm = true, Workshop = true
	}

	for _, obj in ipairs(workspace:GetChildren()) do
		if structureNames[obj.Name] then
			local objPos = nil
			if obj:IsA("Model") and obj.PrimaryPart then
				objPos = obj.PrimaryPart.Position
			elseif obj:IsA("BasePart") then
				objPos = obj.Position
			end

			if objPos then
				local distance = (objPos - position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestStructure = obj
				end
			end
		end
	end

	return nearestStructure
end

-- Attack structure
local function attackStructure(structure)
	local structureHealth = structure:FindFirstChild("Health")
	if not structureHealth then
		structureHealth = Instance.new("IntValue")
		structureHealth.Name = "Health"
		structureHealth.Value = structure.Name == "Wall" and 200 or 100
		structureHealth.Parent = structure
	end

	structureHealth.Value = structureHealth.Value - STRUCTURE_ATTACK_DAMAGE

	if structureHealth.Value <= 0 then
		structure:Destroy()
		return true
	end
	return false
end

function KodoAI.runAI(kodo)
	local humanoid = kodo:FindFirstChild("Humanoid")
	local rootPart = kodo:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then return end

	-- State variables
	local usingPathfinding = false
	local currentPath = nil
	local currentWaypointIndex = 1
	local pathCreatedTime = 0
	local lastPosition = rootPart.Position
	local lastMoveTime = tick()
	local lastAttackTime = 0

	-- Movement reached connection
	local moveConnection = humanoid.MoveToFinished:Connect(function(reached)
		if usingPathfinding and currentPath then
			if reached then
				currentWaypointIndex = currentWaypointIndex + 1
				local waypoints = currentPath:GetWaypoints()

				if currentWaypointIndex <= #waypoints then
					humanoid:MoveTo(waypoints[currentWaypointIndex].Position)
				else
					usingPathfinding = false
					currentPath = nil
				end
			end
		end
	end)

	-- Main AI loop
	task.spawn(function()
		while kodo and kodo.Parent and humanoid.Health > 0 do
			-- Find nearest player
			local nearestPlayer = nil
			local nearestDistance = CHASE_RANGE

			for _, player in ipairs(Players:GetPlayers()) do
				if player.Character then
					local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
					local playerHumanoid = player.Character:FindFirstChild("Humanoid")

					if humanoidRootPart and playerHumanoid and playerHumanoid.Health > 0 then
						local distance = (rootPart.Position - humanoidRootPart.Position).Magnitude
						if distance < nearestDistance then
							nearestDistance = distance
							nearestPlayer = player
						end
					end
				end
			end

			-- Check if stuck
			local distanceMoved = (rootPart.Position - lastPosition).Magnitude
			local isStuck = distanceMoved < 1 and tick() - lastMoveTime > 1.5

			if distanceMoved > 1 then
				lastMoveTime = tick()
			end
			lastPosition = rootPart.Position

			if nearestPlayer and nearestPlayer.Character then
				local targetRoot = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")

				if targetRoot then
					local targetPos = targetRoot.Position

					-- If stuck, attack nearest structure
					if isStuck then
						local nearestStructure = findBlockingStructure(rootPart.Position)
						if nearestStructure then
							if tick() - lastAttackTime >= STRUCTURE_ATTACK_COOLDOWN then
								local destroyed = attackStructure(nearestStructure)
								lastAttackTime = tick()
								if destroyed then
									lastMoveTime = tick()
									usingPathfinding = false
								end
							end
						else
							lastMoveTime = tick()
							usingPathfinding = false
						end
					else
						-- Not stuck - try movement
						if not usingPathfinding or tick() - pathCreatedTime > PATH_CACHE_TIME then
							local pathClear, blockingStructure = isPathClear(rootPart.Position, targetPos, {kodo, nearestPlayer.Character})

							if pathClear then
								usingPathfinding = false
								humanoid:MoveTo(targetPos)
							else
								-- Try pathfinding
								local path = PathfindingService:CreatePath({
									AgentRadius = 2,
									AgentHeight = 6,
									AgentCanJump = false,
									WaypointSpacing = 5
								})

								local success = pcall(function()
									path:ComputeAsync(rootPart.Position, targetPos)
								end)

								if success and path.Status == Enum.PathStatus.Success then
									currentPath = path
									currentWaypointIndex = 1
									usingPathfinding = true
									pathCreatedTime = tick()

									local waypoints = path:GetWaypoints()
									if waypoints[1] then
										humanoid:MoveTo(waypoints[1].Position)
									end
								else
									-- No path - attack structures
									local nearestStructure = findBlockingStructure(rootPart.Position)
									if nearestStructure then
										if tick() - lastAttackTime >= STRUCTURE_ATTACK_COOLDOWN then
											attackStructure(nearestStructure)
											lastAttackTime = tick()
										end
									else
										humanoid:MoveTo(targetPos)
									end
								end
							end
						end
					end
				end
			else
				-- No player - wander
				usingPathfinding = false
				local angle = math.random() * math.pi * 2
				local distance = math.random(WANDER_DISTANCE * 0.5, WANDER_DISTANCE)
				local wanderTarget = rootPart.Position + Vector3.new(
					math.cos(angle) * distance,
					0,
					math.sin(angle) * distance
				)
				humanoid:MoveTo(wanderTarget)
			end

			wait(0.3)
		end

		if moveConnection then
			moveConnection:Disconnect()
		end
	end)

	-- Player kill detection
	task.spawn(function()
		while kodo and kodo.Parent and humanoid.Health > 0 do
			for _, player in ipairs(Players:GetPlayers()) do
				if player.Character then
					local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
					local playerHumanoid = player.Character:FindFirstChild("Humanoid")

					if humanoidRootPart and playerHumanoid and playerHumanoid.Health > 0 then
						local distance = (rootPart.Position - humanoidRootPart.Position).Magnitude
						if distance < PLAYER_KILL_RANGE then
							playerHumanoid.Health = 0
						end
					end
				end
			end
			wait(0.1)
		end
	end)

	-- Touch-based kill
	for _, part in ipairs(kodo:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				local character = hit.Parent
				if character then
					local hitHumanoid = character:FindFirstChild("Humanoid")
					if hitHumanoid and Players:GetPlayerFromCharacter(character) then
						hitHumanoid.Health = 0
					end
				end
			end)
		end
	end
end

return KodoAI