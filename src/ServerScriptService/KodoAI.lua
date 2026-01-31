local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local KodoAI = {}

-- Kodo Types with resistances and weaknesses
-- Multipliers: < 1 = resistant, > 1 = weak, 0 = immune
KodoAI.KODO_TYPES = {
	Normal = {
		name = "Kodo",
		color = Color3.fromRGB(139, 90, 43), -- Brown
		resistances = {},
		speedMult = 1.0,
		healthMult = 1.0
	},
	Armored = {
		name = "Armored Kodo",
		color = Color3.fromRGB(100, 100, 110), -- Gray
		resistances = {
			physical = 0.5,    -- 50% physical resistance
			poison = 1.5,      -- 50% extra poison damage
			aoe = 1.5          -- 50% extra AOE damage
		},
		speedMult = 0.85,
		healthMult = 1.3
	},
	Swift = {
		name = "Swift Kodo",
		color = Color3.fromRGB(220, 220, 230), -- White
		resistances = {
			poison = 0.7,      -- 30% poison resistance (fast metabolism)
			frost = 1.5        -- 50% more effective slows
		},
		speedMult = 1.4,
		healthMult = 0.7
	},
	Frostborn = {
		name = "Frostborn Kodo",
		color = Color3.fromRGB(100, 180, 255), -- Ice Blue
		resistances = {
			frost = 0,         -- Immune to frost
			physical = 1.3     -- 30% extra physical damage
		},
		speedMult = 0.95,
		healthMult = 1.1
	},
	Venomous = {
		name = "Venomous Kodo",
		color = Color3.fromRGB(50, 180, 50), -- Green
		resistances = {
			poison = 0,        -- Immune to poison
			frost = 1.3        -- 30% extra frost damage
		},
		speedMult = 1.0,
		healthMult = 1.0
	},
	Horde = {
		name = "Horde Kodo",
		color = Color3.fromRGB(180, 60, 60), -- Dark Red
		resistances = {
			physical = 0.8,    -- 20% physical resistance
			aoe = 2.0,         -- Double AOE damage
			multishot = 2.0    -- Double multishot damage
		},
		speedMult = 1.2,
		healthMult = 0.5,
		sizeMult = 0.7         -- Smaller
	}
}

-- Settings
local CHASE_RANGE = 300
local BASE_MOVE_SPEED = 16
local WANDER_DISTANCE = 50
local STRUCTURE_ATTACK_DAMAGE = 25
local STRUCTURE_ATTACK_COOLDOWN = 1
local PLAYER_KILL_RANGE = 5
local RAYCAST_DISTANCE = 15
local PATH_CACHE_TIME = 3

-- Maze mechanics settings
-- Kodos are larger than players - they can't fit through small gaps
local KODO_AGENT_RADIUS = 3.5    -- Kodos need 7+ stud gaps to pass
local KODO_AGENT_HEIGHT = 8      -- Taller to prevent jumping over walls
local PLAYER_FIT_GAP = 3         -- Players can fit through 3 stud gaps
-- This creates tactical gap sizes: 3-6 studs = player only, 7+ = both can pass

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

-- Get damage multiplier based on kodo type and damage type
function KodoAI.getDamageMultiplier(kodo, damageType)
	local typeValue = kodo:FindFirstChild("KodoType")
	local kodoType = typeValue and typeValue.Value or "Normal"
	local typeConfig = KodoAI.KODO_TYPES[kodoType]

	if not typeConfig or not typeConfig.resistances then
		return 1.0
	end

	return typeConfig.resistances[damageType] or 1.0
end

-- Create health bar
local function createHealthBar(kodo, isBoss, typeName)
	local humanoid = kodo:FindFirstChild("Humanoid")
	local rootPart = kodo:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = isBoss and UDim2.new(6, 0, 0.8, 0) or UDim2.new(4, 0, 0.5, 0)
	billboard.StudsOffset = Vector3.new(0, isBoss and 12 or 8, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = rootPart
	billboard.Parent = rootPart

	-- Type/Boss label
	local showLabel = isBoss or (typeName and typeName ~= "Kodo")
	if showLabel then
		local typeLabel = Instance.new("TextLabel")
		typeLabel.Name = "TypeLabel"
		typeLabel.Size = UDim2.new(1, 0, 0.6, 0)
		typeLabel.Position = UDim2.new(0, 0, -0.7, 0)
		typeLabel.BackgroundTransparency = 1
		typeLabel.Text = isBoss and "BOSS" or (typeName or "Kodo")
		typeLabel.TextScaled = true
		typeLabel.Font = Enum.Font.GothamBold
		typeLabel.TextStrokeTransparency = 0
		typeLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		typeLabel.Parent = billboard

		-- Color based on type
		if isBoss then
			typeLabel.TextColor3 = Color3.new(1, 0.2, 0.2)
			typeLabel.Font = Enum.Font.GothamBlack
		elseif typeName == "Armored Kodo" then
			typeLabel.TextColor3 = Color3.new(0.7, 0.7, 0.8)
		elseif typeName == "Swift Kodo" then
			typeLabel.TextColor3 = Color3.new(1, 1, 1)
		elseif typeName == "Frostborn Kodo" then
			typeLabel.TextColor3 = Color3.new(0.5, 0.8, 1)
		elseif typeName == "Venomous Kodo" then
			typeLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
		elseif typeName == "Horde Kodo" then
			typeLabel.TextColor3 = Color3.new(1, 0.4, 0.4)
		else
			typeLabel.TextColor3 = Color3.new(1, 1, 1)
		end
	end

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = isBoss and Color3.new(0.3, 0, 0) or Color3.new(0.2, 0.2, 0.2)
	background.BorderSizePixel = isBoss and 3 or 2
	background.BorderColor3 = isBoss and Color3.new(1, 0.8, 0) or Color3.new(0, 0, 0)
	background.Parent = billboard

	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.BackgroundColor3 = isBoss and Color3.new(1, 0.3, 0) or Color3.new(0, 1, 0)
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

		if isBoss then
			-- Boss uses orange/red gradient
			if healthPercent > 0.5 then
				healthBar.BackgroundColor3 = Color3.new(1, 0.3, 0)
			else
				healthBar.BackgroundColor3 = Color3.new(0.8, 0, 0)
			end
		else
			if healthPercent > 0.6 then
				healthBar.BackgroundColor3 = Color3.new(0, 1, 0)
			elseif healthPercent > 0.3 then
				healthBar.BackgroundColor3 = Color3.new(1, 1, 0)
			else
				healthBar.BackgroundColor3 = Color3.new(1, 0, 0)
			end
		end
	end)
end

function KodoAI.spawnKodo(kodoTemplate, spawnPosition, customSpeed, customHealth, customDamage, isBoss, kodoType)
	setupCollisionGroups()

	-- Get kodo type config (default to Normal)
	local typeConfig = KodoAI.KODO_TYPES[kodoType] or KodoAI.KODO_TYPES.Normal
	kodoType = kodoType or "Normal"

	local kodo = kodoTemplate:Clone()
	kodo.Parent = workspace

	-- Store kodo type for damage calculations
	local typeValue = Instance.new("StringValue")
	typeValue.Name = "KodoType"
	typeValue.Value = kodoType
	typeValue.Parent = kodo

	local rootPart = kodo:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 5, 0))
	end

	-- Apply type multipliers to stats
	local finalSpeed = (customSpeed or BASE_MOVE_SPEED) * typeConfig.speedMult
	local finalHealth = math.floor((customHealth or 100) * typeConfig.healthMult)

	local humanoid = kodo:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = finalSpeed
		humanoid.MaxHealth = finalHealth
		humanoid.Health = finalHealth

		-- Connect Died event IMMEDIATELY after creating Kodo
		humanoid.Died:Connect(function()
			print("KodoAI: Humanoid.Died event fired for", kodo.Name)
			KodoAI.handleDeath(kodo)
		end)

		print("KodoAI: Connected Died event for", kodo.Name)
	end

	-- Store custom damage for attackStructure
	local damageValue = Instance.new("NumberValue")
	damageValue.Name = "StructureDamage"
	damageValue.Value = customDamage or STRUCTURE_ATTACK_DAMAGE
	damageValue.Parent = kodo

	-- Apply type visuals (color and size)
	local sizeMult = typeConfig.sizeMult or 1.0
	for _, part in ipairs(kodo:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = typeConfig.color
			if sizeMult ~= 1.0 then
				part.Size = part.Size * sizeMult
			end
		end
	end

	-- Boss visuals (override type color with dark red, make bigger)
	if isBoss then
		local bossTag = Instance.new("BoolValue")
		bossTag.Name = "IsBoss"
		bossTag.Value = true
		bossTag.Parent = kodo

		for _, part in ipairs(kodo:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size = part.Size * 1.5
				part.Color = Color3.fromRGB(139, 0, 0)
			end
		end

		-- Adjust position after scaling
		if rootPart then
			rootPart.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 8, 0))
		end
	end

	for _, part in ipairs(kodo:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = "Kodos"
			end)
		end
	end

	-- Update kodo name to show type
	kodo.Name = typeConfig.name

	createHealthBar(kodo, isBoss, typeConfig.name)
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
			Barricade = true, Wall = true,
			Turret = true, FastTurret = true, SlowTurret = true,
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
		Barricade = true, Wall = true,
		Turret = true, FastTurret = true, SlowTurret = true,
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
local function attackStructure(kodo, structure)
	local structureHealth = structure:FindFirstChild("Health")
	if not structureHealth then
		structureHealth = Instance.new("IntValue")
		structureHealth.Name = "Health"
		-- Structure health values
		local healthValues = {
			Wall = 500,        -- Heavy defensive wall
			Barricade = 75,    -- Cheap maze obstacle
			Workshop = 250,
			Farm = 150
		}
		structureHealth.Value = healthValues[structure.Name] or 100
		structureHealth.Parent = structure
	end

	-- Get custom damage from kodo, fallback to default
	local damageValue = kodo and kodo:FindFirstChild("StructureDamage")
	local damage = damageValue and damageValue.Value or STRUCTURE_ATTACK_DAMAGE

	structureHealth.Value = structureHealth.Value - damage

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

	-- Maze navigation: Kodos try to find paths before attacking walls
	local pathfindAttempts = 0       -- How many times pathfinding failed
	local MAX_PATH_ATTEMPTS = 3      -- Try this many times before attacking
	local frustrationLevel = 0       -- Increases when stuck, decreases when moving
	local FRUSTRATION_THRESHOLD = 5  -- Attack walls after this much frustration

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

			-- Check if stuck (for maze navigation)
			local distanceMoved = (rootPart.Position - lastPosition).Magnitude
			local isStuck = distanceMoved < 1 and tick() - lastMoveTime > 1.5

			if distanceMoved > 1 then
				lastMoveTime = tick()
				-- Moving well - reduce frustration
				frustrationLevel = math.max(0, frustrationLevel - 1)
				pathfindAttempts = 0
			else
				-- Not moving - increase frustration
				if tick() - lastMoveTime > 1 then
					frustrationLevel = frustrationLevel + 1
				end
			end
			lastPosition = rootPart.Position

			if nearestPlayer and nearestPlayer.Character then
				local targetRoot = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")

				if targetRoot then
					local targetPos = targetRoot.Position

					-- Maze behavior: Only attack walls when truly frustrated
					-- This gives Kodos time to find alternate paths
					if isStuck and frustrationLevel >= FRUSTRATION_THRESHOLD then
						local nearestStructure = findBlockingStructure(rootPart.Position)
						if nearestStructure then
							if tick() - lastAttackTime >= STRUCTURE_ATTACK_COOLDOWN then
								local destroyed = attackStructure(kodo, nearestStructure)
								lastAttackTime = tick()
								if destroyed then
									lastMoveTime = tick()
									usingPathfinding = false
									frustrationLevel = 0
									pathfindAttempts = 0
								end
							end
						else
							lastMoveTime = tick()
							usingPathfinding = false
							frustrationLevel = 0
						end
					elseif isStuck then
						-- Stuck but not frustrated enough - try to find new path
						usingPathfinding = false
						pathfindAttempts = pathfindAttempts + 1
					else
						-- Not stuck - try movement
						if not usingPathfinding or tick() - pathCreatedTime > PATH_CACHE_TIME then
							local pathClear, blockingStructure = isPathClear(rootPart.Position, targetPos, {kodo, nearestPlayer.Character})

							if pathClear then
								usingPathfinding = false
								humanoid:MoveTo(targetPos)
							else
								-- Try pathfinding with Kodo-sized agent
							-- Kodos are larger than players, so they can't fit through small gaps
							local path = PathfindingService:CreatePath({
								AgentRadius = KODO_AGENT_RADIUS,
								AgentHeight = KODO_AGENT_HEIGHT,
								AgentCanJump = false,
								WaypointSpacing = 4,
								Costs = {
									-- Prefer open paths, avoid tight spaces
									Wall = math.huge  -- Cannot path through walls
								}
							})

								local success = pcall(function()
									path:ComputeAsync(rootPart.Position, targetPos)
								end)

								if success and path.Status == Enum.PathStatus.Success then
									currentPath = path
									currentWaypointIndex = 1
									usingPathfinding = true
									pathCreatedTime = tick()
									pathfindAttempts = 0  -- Reset on success

									local waypoints = path:GetWaypoints()
									if waypoints[1] then
										humanoid:MoveTo(waypoints[1].Position)
									end
								else
									-- No path found - increase frustration
									pathfindAttempts = pathfindAttempts + 1
									frustrationLevel = frustrationLevel + 1

									-- Only attack if we've tried enough times
									if pathfindAttempts >= MAX_PATH_ATTEMPTS then
										local nearestStructure = findBlockingStructure(rootPart.Position)
										if nearestStructure then
											if tick() - lastAttackTime >= STRUCTURE_ATTACK_COOLDOWN then
												attackStructure(kodo, nearestStructure)
												lastAttackTime = tick()
											end
										else
											-- No structure blocking - just move toward target
											humanoid:MoveTo(targetPos)
										end
									else
										-- Try moving toward target anyway (might find a gap)
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