-- BuildableItemsSync.server.lua
-- Automatically copies BuildableItems from ServerStorage to ReplicatedStorage
-- Only runs in Studio, not in live games

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Only run in Studio (not in published games)
if not RunService:IsStudio() then
	return
end

local SOURCE_FOLDER = "BuildableItems"

local function clearFolder(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			child:Destroy()
		elseif child:IsA("Folder") then
			clearFolder(child)
		end
	end
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function syncFolder(sourceFolder, destFolder)
	local count = 0

	for _, item in ipairs(sourceFolder:GetChildren()) do
		if item:IsA("Folder") then
			-- Recursively sync subfolders
			local destSubfolder = ensureFolder(destFolder, item.Name)
			count = count + syncFolder(item, destSubfolder)
		elseif item:IsA("Model") or item:IsA("BasePart") then
			-- Clone models and parts
			local clone = item:Clone()
			clone.Parent = destFolder
			count = count + 1
		end
	end

	return count
end

local function sync()
	local source = ServerStorage:FindFirstChild(SOURCE_FOLDER)
	if not source then
		warn("[BuildableItemsSync] ServerStorage." .. SOURCE_FOLDER .. " not found")
		return
	end

	-- Create or get destination folder
	local dest = ensureFolder(ReplicatedStorage, SOURCE_FOLDER)

	-- Clear existing models (but keep folder structure from Rojo)
	clearFolder(dest)

	-- Copy everything
	local count = syncFolder(source, dest)

	print("[BuildableItemsSync] Synced " .. count .. " items from ServerStorage to ReplicatedStorage")
end

-- Run sync immediately on startup
sync()
