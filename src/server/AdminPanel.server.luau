-- AdminPanel.server.luau
-- Admin commands via RemoteEvent (AdminCommand)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local serverScript = script.Parent
local InventoryManager = require(serverScript:WaitForChild("InventoryManager"))
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local PetManager = require(serverScript:WaitForChild("PetManager"))
local EggManager = require(serverScript:WaitForChild("EggManager"))
local ShopManager = require(serverScript:WaitForChild("ShopManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local WeatherState = require(serverScript:WaitForChild("WeatherState"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local adminEvent = remotes:WaitForChild("AdminCommand")
local weatherChangedEvent = remotes:WaitForChild("WeatherChanged")
local PetCfg = BalanceConfig.Pet

-- Allow all players (test mode)
local ALLOW_ALL = true

local function isAdmin(player: Player): boolean
	if ALLOW_ALL then return true end
	return false
end

local function notify(player: Player, msg: string)
	local giftEvent = remotes:FindFirstChild("GiftReceived")
	if giftEvent then
		giftEvent:FireClient(player, "[Admin]", msg)
	end
end

adminEvent.OnServerEvent:Connect(function(player, cmd, arg1, arg2)
	if not isAdmin(player) then return end

	if cmd == "addcoins" then
		local amount = tonumber(arg1) or 10000
		CurrencyManager.addCoins(player, amount)
		notify(player, amount .. " coins added")

	elseif cmd == "setcoins" then
		local amount = tonumber(arg1) or 200
		CurrencyManager.setCoins(player, amount)
		notify(player, "Coins set to: " .. amount)

	elseif cmd == "addallbuildings" then
		local count = 0
		for name, _ in Constants.BUILDINGS do
			InventoryManager.addItem(player, name, 1, 1)
			count = count + 1
		end
		notify(player, count .. " buildings added")

	elseif cmd == "addallpets" then
		local count = 0
		for petName, petInfo in Constants.PETS do
			local petId = HttpService:GenerateGUID(false)
			local size = petInfo.size or "Small"
			local stdWeight = PetCfg.SIZE_STANDARD_WEIGHT[size] or 5
			local weightMult = PetCfg.WEIGHT_MIN_MULT + math.random() * (PetCfg.WEIGHT_MAX_MULT - PetCfg.WEIGHT_MIN_MULT)
			PetManager.addPetDirect(player, {
				petId = petId,
				petName = petName,
				petType = petInfo.petTypes and petInfo.petTypes[1] or "Construction",
				rarity = petInfo.rarity or "Common",
				ownerId = player.UserId,
				assignedBuildingId = "",
				model = nil,
				mutations = {},
				size = size,
				race = "Human",
				traits = {},
				weight = stdWeight * weightMult,
				weightMult = weightMult,
				level = 1,
				xp = 0,
				state = "Idle",
				targetBuildingId = "",
				previousWorkId = "",
			})
			count = count + 1
		end
		notify(player, count .. " pets added")

	elseif cmd == "addalleggs" then
		for eggType, _ in BalanceConfig.Egg.EGGS do
			EggManager.addEgg(player, eggType, 3)
		end
		notify(player, "All eggs added (x3 each)")

	elseif cmd == "removeallbuildings" then
		-- 인벤토리 초기화
		InventoryManager.initPlayer(player, nil)
		notify(player, "All buildings removed from inventory")

	elseif cmd == "removeallpets" then
		PetManager.removePlayer(player)
		PetManager.initPlayer(player, nil)
		notify(player, "All pets removed")

	elseif cmd == "removealleggs" then
		EggManager.initPlayer(player, nil)
		notify(player, "All eggs removed")

	elseif cmd == "addbuilding" then
		local itemName = arg1 or "Mine"
		local count = tonumber(arg2) or 1
		if Constants.BUILDINGS[itemName] then
			InventoryManager.addItem(player, itemName, count, 1)
			notify(player, itemName .. " x" .. count .. " added")
		else
			notify(player, "Building not found: " .. tostring(itemName))
		end

	elseif cmd == "addpet" then
		local petName = arg1 or "FarmerNewbie"
		local petInfo = Constants.PETS[petName]
		if petInfo then
			local petId = HttpService:GenerateGUID(false)
			local size = petInfo.size or "Small"
			local stdWeight = PetCfg.SIZE_STANDARD_WEIGHT[size] or 5
			local weightMult = PetCfg.WEIGHT_MIN_MULT + math.random() * (PetCfg.WEIGHT_MAX_MULT - PetCfg.WEIGHT_MIN_MULT)
			PetManager.addPetDirect(player, {
				petId = petId,
				petName = petName,
				petType = petInfo.petTypes and petInfo.petTypes[1] or "Construction",
				rarity = petInfo.rarity or "Common",
				ownerId = player.UserId,
				assignedBuildingId = "",
				model = nil,
				mutations = {},
				size = size,
				race = "Human",
				traits = {},
				weight = stdWeight * weightMult,
				weightMult = weightMult,
				level = 1,
				xp = 0,
				state = "Idle",
				targetBuildingId = "",
				previousWorkId = "",
			})
			notify(player, petName .. " pet added")
		else
			notify(player, "Pet not found: " .. tostring(petName))
		end

	elseif cmd == "settime" then
		local hour = tonumber(arg1) or 14
		local TimeState = require(serverScript:WaitForChild("TimeState"))
		local isDay = (hour >= 6 and hour < 18)
		Lighting.ClockTime = hour
		TimeState.setOverride(isDay)
		notify(player, "Time set to: " .. hour .. " (" .. (if isDay then "Day" else "Night") .. ")")

	elseif cmd == "cleartime" then
		local TimeState = require(serverScript:WaitForChild("TimeState"))
		TimeState.clearOverride()
		notify(player, "Time override cleared")

	elseif cmd == "restock" then
		ShopManager.initPlayer(player)
		notify(player, "Shop restocked")

	elseif cmd == "weather" then
		local validWeathers = { Sunny = true, Rain = true, Frost = true, ThunderStorm = true }
		local weather = arg1 or "Sunny"
		if validWeathers[weather] then
			WeatherState.set(weather)
			weatherChangedEvent:FireAllClients(weather, "")
			notify(player, "Weather changed to: " .. weather)
		else
			notify(player, "Invalid weather. Use: Sunny, Rain, Frost, ThunderStorm")
		end
	end
end)

print("AdminPanel loaded - /admin to open panel")
