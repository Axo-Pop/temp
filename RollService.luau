local PlayerData = {}

-- Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Dependencies --
local Janitor = require(ReplicatedStorage.Shared.Packages.Janitor)
local ProfileStore = require(ReplicatedStorage.Shared.Packages.ProfileStore)
local ReplicaService = require(ReplicatedStorage.Shared.Packages.ReplicaService)
local GamepassesData = require(script.Gamepasses)

local DataTemplate = require(ReplicatedStorage.Shared.DataModules.DataTemplate)
local GlobalConfigurations = require(ReplicatedStorage.Shared.DataModules.GlobalConfigurations)

-- Variables
local ProfileDataStore = ProfileStore.New("Data", DataTemplate)
local ReplicaToken = ReplicaService.NewClassToken("PlayerData")

-- DynamicVariables
local IsStudio = RunService:IsStudio()
PlayerData.Profiles = {}

-- Helper functions

-- Deep copies table
local function DeepCopyTable(t)
	return HttpService:JSONDecode(HttpService:JSONEncode(t))
end

-- Functions --

-- Loads player data from the data store and sets up replication for user
function PlayerData.LoadPlayerData(Player: Player)
	-- Setup Data
	local Profile = ProfileDataStore:StartSessionAsync(tostring(Player.UserId), {
		Cancel = function()
			return Player.Parent == nil
		end,
	})

	-- If data somehow couldnt be created/loaded we kick user
	if not Profile then
		Player:Kick("Your data could not be loaded, please rejoin!")
		warn("PlayerData | Could not load data for user!")
		return
	end

	-- Create janitor for easier cleaning connections
	local ProfileJanitor = Janitor.new()
	ProfileJanitor:Add(function()
		PlayerData.Profiles[Player.UserId] = nil
		Profile:EndSession()
	end)

	-- Assign new table if DataKeyVersion has changed (complete reset)
	if Profile.Data.DataKeyVersion ~= GlobalConfigurations.DataKeyVersion then
		Profile.Data = DeepCopyTable(DataTemplate)
	end

	Profile:Reconcile()
	Profile:AddUserId(Player.UserId)

	-- Get gamepass data
	local UserGamepassesData = GamepassesData.getGamepassData(Player)
	Profile.Gamepasses = UserGamepassesData

	-- Setup Replication
	local ProfileReplica = ReplicaService.NewReplica({
		ClassToken = ReplicaToken,
		Data = { Profile = Profile.Data, Gamepasses = Profile.Gamepasses },
		Replication = { [Player] = true },
	})

	PlayerData.Profiles[Player.UserId] = {
		Profile = Profile,
		Replica = ProfileReplica,
		Janitor = ProfileJanitor,
	}

	ProfileJanitor:Add(function()
		ProfileReplica:Destroy()
	end)
end

-- Creates player data for studio by only using data template
function PlayerData.CreatePlayerData(Player: Player)
	local MockData = DeepCopyTable(DataTemplate)
	local UserGamepassesData = GamepassesData.getGamepassData(Player)

	local MockProfileObject = {
		Data = MockData,
		Gamepasses = UserGamepassesData,
	}

	-- Setup Replication
	local ProfileReplica = ReplicaService.NewReplica({
		ClassToken = ReplicaToken,
		Data = { Profile = MockProfileObject.Data, Gamepasses = MockProfileObject.Gamepasses },
		Replication = { [Player] = true },
	})

	PlayerData.Profiles[Player.UserId] = {
		Profile = MockProfileObject,
		Replica = ProfileReplica,
	}
end

-- Loads player data based on configurations and environment
function PlayerData.OnPlayerJoining(Player: Player)
	if IsStudio and not GlobalConfigurations.LoadDataInStudio then
		PlayerData.CreatePlayerData(Player)
	else
		PlayerData.LoadPlayerData(Player)
	end
end

-- Dissconnects player and cleans up their data when they leave the game
function PlayerData.DissconnectPlayer(Player)
	local ProfileData = PlayerData.Profiles[Player.UserId]
	if ProfileData then
		ProfileData.Janitor:Destroy()
	end
end

-- Handles player leaving based on configurations and environment
function PlayerData.OnPlayerLeaving(Player: Player)
	if IsStudio and not GlobalConfigurations.LoadDataInStudio then
		return
	else
		PlayerData.DissconnectPlayer(Player)
	end
end

-- Init
function PlayerData.init()
	GamepassesData.init(PlayerData.Profiles)

	Players.PlayerAdded:Connect(PlayerData.OnPlayerJoining)
	Players.PlayerRemoving:Connect(PlayerData.OnPlayerLeaving)

	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerData.OnPlayerJoining, Player)
	end

	game:BindToClose(function()
		if IsStudio and not GlobalConfigurations.LoadDataInStudio then
			return
		else
			for _, Player in Players:GetPlayers() do
				PlayerData.DissconnectPlayer(Player)
			end
		end

		task.wait(5)
	end)
end

return PlayerData
