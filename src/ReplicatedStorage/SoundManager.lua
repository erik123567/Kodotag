-- SOUND MANAGER
-- Handles all game sounds with easy-to-use API

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SoundManager = {}

-- Sound IDs (Roblox library sounds)
local SOUNDS = {
	-- Building
	build_place = "rbxassetid://3398628452",      -- Placement click
	build_complete = "rbxassetid://4612373815",   -- Construction done
	build_destroy = "rbxassetid://5743125871",    -- Structure destroyed

	-- Turrets
	turret_shoot = "rbxassetid://1905364532",     -- Basic turret shot
	turret_fast = "rbxassetid://1905364532",      -- Fast turret (same, faster)
	turret_slow = "rbxassetid://168586621",       -- Slow turret (heavy)
	turret_frost = "rbxassetid://2785493",        -- Frost turret (ice)
	turret_poison = "rbxassetid://4817245778",    -- Poison turret (acid)
	turret_cannon = "rbxassetid://168513088",     -- Cannon turret (explosion)
	turret_multi = "rbxassetid://1905364532",     -- Multi-shot

	-- Kodos
	kodo_hit = "rbxassetid://4458825455",         -- Kodo takes damage
	kodo_death = "rbxassetid://2801263",          -- Kodo dies
	kodo_attack = "rbxassetid://4458825455",      -- Kodo attacks structure

	-- Player
	player_death = "rbxassetid://2801263",        -- Player dies
	player_revive = "rbxassetid://6042053626",    -- Player respawns

	-- Pickups
	gold_pickup = "rbxassetid://138081500",       -- Gold/coins
	powerup_pickup = "rbxassetid://6042053626",   -- Power-up collected
	vein_spawn = "rbxassetid://4612373815",       -- Bonus vein appears

	-- UI/Feedback
	ui_click = "rbxassetid://6895079853",         -- Button click
	ui_hover = "rbxassetid://6895079853",         -- Button hover
	notification = "rbxassetid://6042053626",     -- Notification pop

	-- Round/Game
	round_start = "rbxassetid://1837390508",      -- Round begins
	wave_incoming = "rbxassetid://1837390508",    -- Wave warning
	game_over = "rbxassetid://1843317619",        -- Game over
	victory = "rbxassetid://1843317619",          -- Victory (if we add it)

	-- Abilities
	ability_slow = "rbxassetid://2785493",        -- Slow aura
	ability_lightning = "rbxassetid://3747329924", -- Lightning strike
	ability_speed = "rbxassetid://6042053626",    -- Speed boost
	ability_revive = "rbxassetid://6042053626",   -- Quick revive

	-- Ambient
	mining = "rbxassetid://5743125871",           -- Mining gold
}

-- Volume presets
local VOLUMES = {
	build_place = 0.5,
	build_complete = 0.6,
	build_destroy = 0.7,
	turret_shoot = 0.3,
	turret_fast = 0.25,
	turret_slow = 0.5,
	turret_frost = 0.4,
	turret_poison = 0.35,
	turret_cannon = 0.6,
	turret_multi = 0.3,
	kodo_hit = 0.4,
	kodo_death = 0.5,
	kodo_attack = 0.4,
	player_death = 0.6,
	player_revive = 0.5,
	gold_pickup = 0.5,
	powerup_pickup = 0.6,
	vein_spawn = 0.5,
	ui_click = 0.3,
	ui_hover = 0.2,
	notification = 0.4,
	round_start = 0.7,
	wave_incoming = 0.6,
	game_over = 0.7,
	victory = 0.7,
	ability_slow = 0.5,
	ability_lightning = 0.6,
	ability_speed = 0.5,
	ability_revive = 0.5,
	mining = 0.3,
}

-- Pitch variations for variety
local PITCH_VARIATION = {
	turret_shoot = 0.1,
	turret_fast = 0.15,
	kodo_hit = 0.2,
	kodo_death = 0.15,
	gold_pickup = 0.1,
}

-- Create a sound folder in SoundService
local soundFolder = Instance.new("Folder")
soundFolder.Name = "GameSounds"
soundFolder.Parent = SoundService

-- Preload sounds
local preloadedSounds = {}
for name, id in pairs(SOUNDS) do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = VOLUMES[name] or 0.5
	sound.Parent = soundFolder
	preloadedSounds[name] = sound
end

-- Play a sound globally (2D, everyone hears same volume)
function SoundManager.play(soundName, pitchOverride)
	local template = preloadedSounds[soundName]
	if not template then
		warn("SoundManager: Unknown sound:", soundName)
		return nil
	end

	local sound = template:Clone()
	sound.Parent = soundFolder

	-- Apply pitch variation
	local variation = PITCH_VARIATION[soundName] or 0
	if variation > 0 then
		sound.PlaybackSpeed = 1 + (math.random() - 0.5) * 2 * variation
	end

	if pitchOverride then
		sound.PlaybackSpeed = pitchOverride
	end

	sound:Play()

	-- Clean up after playing
	sound.Ended:Connect(function()
		sound:Destroy()
	end)

	return sound
end

-- Play a sound at a 3D position (volume decreases with distance)
function SoundManager.playAt(soundName, position, parent)
	local template = preloadedSounds[soundName]
	if not template then
		warn("SoundManager: Unknown sound:", soundName)
		return nil
	end

	-- Create an attachment for 3D sound
	local part = parent
	if not part or not part:IsA("BasePart") then
		-- Create temporary part at position
		part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.new(0.1, 0.1, 0.1)
		part.Position = position
		part.Parent = workspace
		Debris:AddItem(part, 3)
	end

	local sound = template:Clone()
	sound.Parent = part

	-- 3D sound settings
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 100

	-- Apply pitch variation
	local variation = PITCH_VARIATION[soundName] or 0
	if variation > 0 then
		sound.PlaybackSpeed = 1 + (math.random() - 0.5) * 2 * variation
	end

	sound:Play()

	-- Clean up after playing
	sound.Ended:Connect(function()
		sound:Destroy()
	end)

	return sound
end

-- Play a looping sound (returns sound object for stopping)
function SoundManager.playLoop(soundName, parent)
	local template = preloadedSounds[soundName]
	if not template then
		warn("SoundManager: Unknown sound:", soundName)
		return nil
	end

	local sound = template:Clone()
	sound.Looped = true
	sound.Parent = parent or soundFolder
	sound:Play()

	return sound
end

-- Stop a looping sound with fade out
function SoundManager.stopLoop(sound, fadeTime)
	if not sound then return end

	fadeTime = fadeTime or 0.5

	local tween = TweenService:Create(sound, TweenInfo.new(fadeTime), {
		Volume = 0
	})
	tween:Play()
	tween.Completed:Connect(function()
		sound:Stop()
		sound:Destroy()
	end)
end

-- Set master volume (0-1)
function SoundManager.setMasterVolume(volume)
	SoundService:SetSoundEnabled(volume > 0)
	for _, sound in pairs(preloadedSounds) do
		local basevolume = VOLUMES[sound.Name] or 0.5
		sound.Volume = basevolume * volume
	end
end

-- Get sound IDs (for external use)
function SoundManager.getSoundId(soundName)
	return SOUNDS[soundName]
end

return SoundManager
