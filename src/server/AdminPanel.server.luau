-- AdminPanel.server.luau
-- 어드민 테스트 패널: 재화/알/건물/펫 추가, 시간 설정, 상점 Restock
-- 채팅 명령어로 실행 (/admin 접두사)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local serverScript = script.Parent
local InventoryManager = require(serverScript:WaitForChild("InventoryManager"))
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local PetManager = require(serverScript:WaitForChild("PetManager"))
local EggManager = require(serverScript:WaitForChild("EggManager"))
local ShopManager = require(serverScript:WaitForChild("ShopManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local HttpService = game:GetService("HttpService")

-- 어드민 유저 ID 목록 (여기에 추가)
local ADMIN_IDS = {
	-- 본인 UserId 추가
}

-- 모든 플레이어 어드민 허용 (테스트용)
local ALLOW_ALL = true

local function isAdmin(player: Player): boolean
	if ALLOW_ALL then return true end
	for _, id in ADMIN_IDS do
		if player.UserId == id then return true end
	end
	return false
end

local function notify(player: Player, msg: string)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	-- 간단한 방법: 기존 GiftReceived 이벤트를 재활용해서 알림
	local giftEvent = remotes:FindFirstChild("GiftReceived")
	if giftEvent then
		giftEvent:FireClient(player, "[Admin]", msg)
	end
end

-- 채팅 명령어 처리
local function onPlayerChatted(player: Player, message: string)
	if not isAdmin(player) then return end

	local args = string.split(message, " ")
	local cmd = args[1]

	if cmd == "/addcoins" then
		local amount = tonumber(args[2]) or 1000
		CurrencyManager.addCoins(player, amount)
		notify(player, amount .. " coins added")

	elseif cmd == "/addgems" then
		-- TODO: 보석 시스템 구현 후 연결
		notify(player, "Gem system not implemented")

	elseif cmd == "/setcoins" then
		local amount = tonumber(args[2]) or 200
		CurrencyManager.setCoins(player, amount)
		notify(player, "Coins set to: " .. amount)

	elseif cmd == "/addegg" then
		local eggType = args[2] or "Egg_Common"
		local count = tonumber(args[3]) or 1
		for _ = 1, count do
			EggManager.addEgg(player, eggType, 1)
		end
		notify(player, eggType .. " x" .. count .. " added")

	elseif cmd == "/addbuilding" then
		local itemName = args[2]
		local count = tonumber(args[3]) or 1
		if itemName and Constants.BUILDINGS[itemName] then
			InventoryManager.addItem(player, itemName, count, 1)
			notify(player, itemName .. " x" .. count .. " added")
		else
			notify(player, "Building not found: " .. tostring(itemName))
		end

	elseif cmd == "/addpet" then
		local petName = args[2] or "FarmerNewbie"
		local petInfo = Constants.PETS[petName]
		if petInfo then
			local petId = HttpService:GenerateGUID(false)
			local size = petInfo.size or "Small"
			local stdWeight = BalanceConfig.Pet.SIZE_STANDARD_WEIGHT[size] or 5
			local weightMult = BalanceConfig.Pet.WEIGHT_MIN_MULT + math.random() * (BalanceConfig.Pet.WEIGHT_MAX_MULT - BalanceConfig.Pet.WEIGHT_MIN_MULT)

			local petData = {
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
			}
			PetManager.addPetDirect(player, petData)
			notify(player, petName .. " pet added")
		else
			notify(player, "Pet not found: " .. tostring(petName))
		end

	elseif cmd == "/settime" then
		local hour = tonumber(args[2]) or 12
		Lighting.ClockTime = math.clamp(hour, 0, 24)
		notify(player, "Time set to: " .. hour)

	elseif cmd == "/restock" then
		ShopManager.initPlayer(player)
		notify(player, "Shop restocked")

	elseif cmd == "/reset" then
		-- 기존 /reset과 동일
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local resetEvent = remotes:FindFirstChild("ResetData")
			if resetEvent then
				resetEvent:FireServer() -- 서버에서 직접 호출 불가, 클라이언트가 해야 함
			end
		end
		notify(player, "Use /reset from client")

	elseif cmd == "/adminhelp" then
		notify(player, "/addcoins [n] /addegg [type] [n] /addbuilding [name] [n] /addpet [name] /settime [h] /restock")
	end
end

-- 플레이어 채팅 감지
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		onPlayerChatted(player, message)
	end)
end)

-- 이미 접속한 플레이어
for _, player in Players:GetPlayers() do
	player.Chatted:Connect(function(message)
		onPlayerChatted(player, message)
	end)
end

print("AdminPanel loaded - /adminhelp for commands")
