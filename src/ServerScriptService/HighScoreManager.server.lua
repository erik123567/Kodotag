-- HIGH SCORE MANAGER
-- Tracks and saves player's best wave reached using DataStore

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run on game servers (reserved servers)
local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

print("HighScoreManager: Starting... (Reserved:", isReservedServer, ")")

-- DataStore setup
local highScoreStore = DataStoreService:GetDataStore("KodoTagHighScores_v1")

-- Cache of loaded high scores
local playerHighScores = {}

-- Create RemoteEvents
local getHighScore = Instance.new("RemoteFunction")
getHighScore.Name = "GetHighScore"
getHighScore.Parent = ReplicatedStorage

local highScoreUpdated = Instance.new("RemoteEvent")
highScoreUpdated.Name = "HighScoreUpdated"
highScoreUpdated.Parent = ReplicatedStorage

-- Load player's high score from DataStore
local function loadHighScore(player)
	local success, data = pcall(function()
		return highScoreStore:GetAsync("player_" .. player.UserId)
	end)

	if success and data then
		playerHighScores[player.Name] = {
			bestWave = data.bestWave or 0,
			bestWaveDate = data.bestWaveDate or 0,
			totalGames = data.totalGames or 0,
			totalKills = data.totalKills or 0
		}
		print("HighScoreManager: Loaded high score for", player.Name, "- Best Wave:", data.bestWave or 0)
	else
		playerHighScores[player.Name] = {
			bestWave = 0,
			bestWaveDate = 0,
			totalGames = 0,
			totalKills = 0
		}
		print("HighScoreManager: No existing data for", player.Name, "- starting fresh")
	end

	return playerHighScores[player.Name]
end

-- Save player's high score to DataStore
local function saveHighScore(player, newWave, kodoKills)
	local currentData = playerHighScores[player.Name]
	if not currentData then
		currentData = { bestWave = 0, bestWaveDate = 0, totalGames = 0, totalKills = 0 }
	end

	local isNewRecord = newWave > currentData.bestWave

	-- Update stats
	currentData.totalGames = currentData.totalGames + 1
	currentData.totalKills = currentData.totalKills + (kodoKills or 0)

	if isNewRecord then
		currentData.bestWave = newWave
		currentData.bestWaveDate = os.time()
		print("HighScoreManager: NEW RECORD for", player.Name, "- Wave", newWave)
	end

	-- Save to DataStore
	local success, err = pcall(function()
		highScoreStore:SetAsync("player_" .. player.UserId, currentData)
	end)

	if success then
		playerHighScores[player.Name] = currentData
		print("HighScoreManager: Saved data for", player.Name)
	else
		warn("HighScoreManager: Failed to save for", player.Name, "-", err)
	end

	return isNewRecord, currentData
end

-- Handle client requesting their high score
getHighScore.OnServerInvoke = function(player)
	local data = playerHighScores[player.Name]
	if not data then
		data = loadHighScore(player)
	end
	return data
end

-- Load high scores when players join
Players.PlayerAdded:Connect(function(player)
	loadHighScore(player)
end)

-- Clean up when players leave
Players.PlayerRemoving:Connect(function(player)
	-- Data is already saved during game over, just clean cache
	playerHighScores[player.Name] = nil
end)

-- Load for existing players (in case script loads late)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadHighScore(player)
	end)
end

-- Expose functions globally for RoundManager to use
_G.HighScoreManager = {
	saveHighScore = saveHighScore,
	getHighScore = function(playerName)
		return playerHighScores[playerName]
	end,
	getAllHighScores = function()
		return playerHighScores
	end
}

print("HighScoreManager: Loaded!")
