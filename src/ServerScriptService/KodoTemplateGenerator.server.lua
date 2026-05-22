-- KodoTemplateGenerator.server.lua
-- Generates a working R6-style Kodo NPC template on server start
-- This replaces the need for custom imported models until animations are sorted out

local ServerStorage = game:GetService("ServerStorage")

-- Only run on game servers (not lobby)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
if not isReservedServer then
	print("KodoTemplateGenerator: Lobby - skipped")
	return
end

local function createKodoTemplate()
	-- Create KodoStorage folder if needed
	local kodoStorage = ServerStorage:FindFirstChild("KodoStorage")
	if not kodoStorage then
		kodoStorage = Instance.new("Folder")
		kodoStorage.Name = "KodoStorage"
		kodoStorage.Parent = ServerStorage
	end

	-- Remove old template if exists
	local existingKodo = kodoStorage:FindFirstChild("Kodo")
	if existingKodo then
		existingKodo:Destroy()
	end

	-- Create Kodo model
	local kodo = Instance.new("Model")
	kodo.Name = "Kodo"

	-- HumanoidRootPart - the core physics part
	-- Size: wider and longer than player for proper hitbox
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(4, 4, 6)  -- Wide, tall, long (beast shape)
	rootPart.Transparency = 1  -- Invisible, just for physics
	rootPart.CanCollide = true
	rootPart.Anchored = false
	rootPart.CFrame = CFrame.new(0, 10, 0)  -- Position BEFORE parenting
	rootPart.Parent = kodo

	-- Torso/Body - the visible main body
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(5, 4, 7)  -- Bulky beast body
	torso.CanCollide = false
	torso.Anchored = false
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = Color3.fromRGB(139, 90, 43)  -- Brown (will be overridden by type)
	torso.CFrame = rootPart.CFrame  -- Same position as root
	torso.Parent = kodo

	-- RootJoint Motor6D - REQUIRED for Humanoid:MoveTo() to work
	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "RootJoint"
	rootJoint.Part0 = rootPart
	rootJoint.Part1 = torso
	rootJoint.C0 = CFrame.new(0, 0, 0)
	rootJoint.C1 = CFrame.new(0, 0, 0)
	rootJoint.Parent = rootPart

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(3, 2.5, 3)
	head.CanCollide = false
	head.Anchored = false
	head.Material = Enum.Material.SmoothPlastic
	head.Color = Color3.fromRGB(139, 90, 43)
	head.CFrame = torso.CFrame * CFrame.new(0, 0.5, -4)  -- Position BEFORE weld
	head.Parent = kodo

	-- Weld head to torso
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.Parent = head

	-- Horns (optional visual flair)
	local function createHorn(offset, angle)
		local horn = Instance.new("Part")
		horn.Name = "Horn"
		horn.Size = Vector3.new(0.4, 2, 0.4)
		horn.CanCollide = false
		horn.Anchored = false
		horn.Material = Enum.Material.SmoothPlastic
		horn.Color = Color3.fromRGB(200, 180, 150)  -- Bone color
		horn.CFrame = head.CFrame * CFrame.new(offset, 1, -0.5) * CFrame.Angles(math.rad(angle), 0, 0)  -- Position BEFORE weld
		horn.Parent = kodo

		local hornWeld = Instance.new("WeldConstraint")
		hornWeld.Part0 = head
		hornWeld.Part1 = horn
		hornWeld.Parent = horn

		return horn
	end
	createHorn(-0.8, -30)  -- Left horn
	createHorn(0.8, -30)   -- Right horn

	-- Legs (4 legs for beast) - using Motor6D for animation
	local function createLeg(xOffset, zOffset, name)
		local leg = Instance.new("Part")
		leg.Name = name
		leg.Size = Vector3.new(1, 3, 1)
		leg.CanCollide = false
		leg.Anchored = false
		leg.Material = Enum.Material.SmoothPlastic
		leg.Color = Color3.fromRGB(120, 75, 35)  -- Slightly darker
		leg.Parent = kodo

		-- Use Motor6D for animatable joints
		local motor = Instance.new("Motor6D")
		motor.Name = name .. "Motor"
		motor.Part0 = torso
		motor.Part1 = leg
		-- C0 is the attachment point on torso, C1 is on leg
		motor.C0 = CFrame.new(xOffset, -2, zOffset)  -- Hip position on torso
		motor.C1 = CFrame.new(0, 1.5, 0)  -- Top of leg
		motor.Parent = torso

		return leg, motor
	end

	local leftFrontLeg, leftFrontMotor = createLeg(-1.8, -2, "LeftFrontLeg")
	local rightFrontLeg, rightFrontMotor = createLeg(1.8, -2, "RightFrontLeg")
	local leftBackLeg, leftBackMotor = createLeg(-1.8, 2, "LeftBackLeg")
	local rightBackLeg, rightBackMotor = createLeg(1.8, 2, "RightBackLeg")

	-- Tail
	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.8, 0.8, 3)
	tail.CanCollide = false
	tail.Anchored = false
	tail.Material = Enum.Material.SmoothPlastic
	tail.Color = Color3.fromRGB(139, 90, 43)
	tail.CFrame = torso.CFrame * CFrame.new(0, 0, 5)  -- Position BEFORE weld
	tail.Parent = kodo

	local tailWeld = Instance.new("WeldConstraint")
	tailWeld.Part0 = torso
	tailWeld.Part1 = tail
	tailWeld.Parent = tail

	-- Set PrimaryPart
	kodo.PrimaryPart = rootPart

	-- Create Humanoid (required for pathfinding and MoveTo)
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None  -- Hide name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff  -- We have custom health bars
	humanoid.WalkSpeed = 16
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.HipHeight = 2  -- Lift body off ground
	humanoid.Parent = kodo

	-- Parent to storage (parts already positioned)
	kodo.Parent = kodoStorage

	print("KodoTemplateGenerator: Created Kodo template")
	print("  - Body size: 5x4x7 studs")
	print("  - Root hitbox: 4x4x6 studs")
	print("  - HipHeight: 2 (elevated off ground)")

	return kodo
end

-- Generate template
local template = createKodoTemplate()

-- Verify it works
if template and template:FindFirstChild("Humanoid") and template:FindFirstChild("HumanoidRootPart") then
	print("KodoTemplateGenerator: Template ready!")
else
	warn("KodoTemplateGenerator: Template creation failed!")
end
