local RollService = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependenices
local DataService = require(script.Parent.DataService)
local Pickaxes = require(ReplicatedStorage.Shared.DataModules.Pickaxes)
local GlobalConfigurations = require(ReplicatedStorage.Shared.DataModules.GlobalConfigurations)
local AnalyticsService = require(script.Parent.AnalyticsService)

-- Variables
local RollEvent = ReplicatedStorage.RemoteEvents.Roll
local NotificationEvent = ReplicatedStorage.RemoteEvents.Notification

-- Dynamic Variables
local Rolls = {}

-- Functions

-- This function will roll a pickaxe
function RollService.Roll(StartLuck: number, Depth: number?)
	-- We set the current depth to the provided depth or 1 if not provided
	local currentDepth = Depth or 1
	local currentLuck = StartLuck

	-- Global configurations, double luck chances are defined in the GlobalConfigurations module,
	-- we check if the current depth has a double luck chance defined,
	-- if so we roll a random number and if its less than or equal to the chance we call the Roll
	-- function again with double the luck and increment the depth by 1
	local nextChanceThreshold = GlobalConfigurations.DoubleLuckChances[currentDepth]
	if nextChanceThreshold and math.random() <= nextChanceThreshold then
		return RollService.Roll(currentLuck * 2, currentDepth + 1)
	end

	-- We create a roll table with the pickaxes and their chances
	local rollTable = {}
	for PickaxeName, PickaxeData in Pickaxes do
		table.insert(rollTable, {
			Name = PickaxeName,
			Chance = PickaxeData.Chance,
		})
	end

	-- We sort the roll table by chance in descending order, so that the pickaxes with higher chances are rolled first
	table.sort(rollTable, function(a, b)
		return a.Chance > b.Chance
	end)

	-- We iterate through the roll table and roll for each pickaxe, we modify the chance by dividing it by the current luck,
	-- and if the random number is 1 we return the current depth and the pickaxe
	for _, entry in rollTable do
		local modifiedChance = math.max(1, entry.Chance / currentLuck)

		if math.random(1, math.floor(modifiedChance)) == 1 then
			return { currentDepth, entry.Name }
		end
	end

	return { 1, GlobalConfigurations.DefaultPickaxe }
end

-- This function will handle when players requests to roll
function RollService.OnRollRequest(Player: Player, LuckyRoll: boolean)
	-- First we gathe profile made inisde DataService
	local Profile = DataService.Profiles[Player.UserId]
	if not Profile then
		-- If it isnt loaded yet we return and fire notification event
		NotificationEvent:FireClient(Player, { 1, "Player data not found." })
		return
	end

	-- Check if player is in tutorial step 1, if so we set it to 2 and track the analytics
	if Profile.Profile.Data.TutorialStep == 1 then
		Profile.Replica:SetValue({ "Profile", "TutorialStep" }, 2)
		AnalyticsService.trackTutorialStep(Player, 1, "Roll pickaxe")
	end

	-- We gathe info from the profile
	local RollSpeed = Profile.Profile.Data.RollSpeed
	-- Calculate the roll length based on the player's roll speed and global configuration
	local RollLength = GlobalConfigurations.RollLength / RollSpeed
	-- Calculate the base luck based on the player's base luck and rebirth count, applying the rebirth luck multiplier
	local BaseLuck = Profile.Profile.Data.BaseLuck
	BaseLuck += Profile.Profile.Data.Rebirth * GlobalConfigurations.RebirthLuckMultiplier

	-- Check for gamepasses and apply their effects
	if Profile.Profile.Gamepasses["Lucky"] then
		BaseLuck *= 2
	end
	if Profile.Profile.Gamepasses["x10 Luck"] then
		BaseLuck *= 10
	end
	if Profile.Profile.Gamepasses["Quick Roll"] then
		RollLength /= 2
	end

	-- We have to validate request whenever user is firing it too fast
	local currentTime = tick()
	-- We just check current time minus the last roll time, if its less than the roll length we return and do nothing
	if Rolls[Player.UserId] and currentTime - Rolls[Player.UserId] < RollLength then
		return
	end

	-- Check if user wants to use his lucky roll, if so we check if he has any left, if he does we subtract one and multiply the base luck by 500
	if LuckyRoll then
		if Profile.Profile.Data.LuckyRolls > 0 then
			Profile.Replica:SetValue({ "Profile", "LuckyRolls" }, Profile.Profile.Data.LuckyRolls - 1)
			BaseLuck *= 500
		else
			NotificationEvent:FireClient(Player, { 1, "You don't have any lucky rolls left." })
			return
		end
	end

	-- Process roll and save roll time
	Rolls[Player.UserId] = currentTime
	local RollResult = RollService.Roll(BaseLuck)

	-- Update data in profile, we add one to the amount of pickaxes rolled and add one to the rolls count
	local OldPickaxeAmount = Profile.Profile.Data.Pickaxes[RollResult[2]] or 0
	Profile.Replica:SetValue({ "Profile", "Pickaxes", RollResult[2] }, OldPickaxeAmount + 1)
	Profile.Replica:SetValue({ "Profile", "Rolls" }, Profile.Profile.Data.Rolls + 1)

	-- Fire the roll event to the client with the result
	RollEvent:FireClient(Player, RollResult, LuckyRoll)
	return
end

-- This function will clear all entries in cooldown table
function RollService.ClearRolls(OlderThan: number)
	-- This is used to clear memory leaks, we check if the roll time is older than the specified time and if so we remove it from the table
	local currentTime = tick()
	for key, rollTime in Rolls do
		if currentTime - rollTime >= OlderThan then
			Rolls[key] = nil
		end
	end
end

-- Init
function RollService.init()
	-- We connect the event to the function that will handle the roll request
	RollEvent.OnServerEvent:Connect(RollService.OnRollRequest)

	-- Start cleaner
	while task.wait(50) do
		RollService.ClearRolls(50)
	end
end

return RollService
