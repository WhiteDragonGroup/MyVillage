-- EggServer.server.luau
-- 알 Remote 핸들러: 구매, 배치, 부화, 조회

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyEggEvent = remotes:WaitForChild("BuyEgg")
local placeEggEvent = remotes:WaitForChild("PlaceEgg")
local hatchEggEvent = remotes:WaitForChild("HatchEgg")
local getEggsFunc = remotes:WaitForChild("GetEggs")
local getPlacedEggsFunc = remotes:WaitForChild("GetPlacedEggs")
local eggUpdateEvent = remotes:WaitForChild("EggUpdate")

local serverScript = script.Parent
local EggManager = require(serverScript:WaitForChild("EggManager"))
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local PetManager = require(serverScript:WaitForChild("PetManager"))

local HttpService = game:GetService("HttpService")
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local PetCfg = BalanceConfig.Pet

-- EggManager에 코인/펫 함수 연결
EggManager.setCurrencyFunctions(
	function(player, amount) return CurrencyManager.hasCoins(player, amount) end,
	function(player, amount) return CurrencyManager.spendCoins(player, amount) end
)

EggManager.setPetFunction(function(player, petData)
	-- PetManager에 펫 추가
	local petId = HttpService:GenerateGUID(false)
	local size = petData.size or "Small"
	local stdWeight = PetCfg.SIZE_STANDARD_WEIGHT[size] or 5
	local weightMult = PetCfg.WEIGHT_MIN_MULT + math.random() * (PetCfg.WEIGHT_MAX_MULT - PetCfg.WEIGHT_MIN_MULT)

	local mutations = {}
	if petData.mutations then
		for _, m in petData.mutations do
			mutations[m] = true
		end
	end

	-- PetManager 내부에 직접 추가
	local fullPetData = {
		petId = petId,
		petName = petData.petName,
		petType = petData.petType,
		rarity = petData.rarity,
		ownerId = player.UserId,
		assignedBuildingId = "",
		model = nil,
		mutations = mutations,
		size = size,
		race = petData.race or "Human",
		traits = {},
		weight = stdWeight * weightMult,
		weightMult = weightMult,
		level = 1,
		xp = 0,
		state = "Idle",
		targetBuildingId = "",
		previousWorkId = "",
	}

	-- PetManager._playerPets에 접근해야 하므로 addPetDirect 사용
	PetManager.addPetDirect(player, fullPetData)
end)

----------------------------------------------------------------
-- Remote 핸들러
----------------------------------------------------------------

-- 알 구매
buyEggEvent.OnServerEvent:Connect(function(player, eggType)
	if typeof(eggType) ~= "string" then return end

	local success, msg = EggManager.buyEgg(player, eggType)
	if success then
		print(player.Name .. " - 알 구매: " .. eggType)
	else
		warn(player.Name .. " - 알 구매 실패: " .. msg)
	end

	-- 클라이언트에 알 인벤토리 갱신
	eggUpdateEvent:FireClient(player, "inventory", EggManager.getEggInventory(player))
end)

-- 알 배치
placeEggEvent.OnServerEvent:Connect(function(player, eggType, position)
	if typeof(eggType) ~= "string" then return end
	if typeof(position) ~= "Vector3" then return end

	local success, msg = EggManager.placeEgg(player, eggType, position)
	if success then
		-- msg = eggId
		eggUpdateEvent:FireClient(player, "placed", {
			eggId = msg,
			eggType = eggType,
		})
	else
		warn(player.Name .. " - 알 배치 실패: " .. msg)
	end

	eggUpdateEvent:FireClient(player, "inventory", EggManager.getEggInventory(player))
end)

-- 부화
hatchEggEvent.OnServerEvent:Connect(function(player, eggId)
	if typeof(eggId) ~= "string" then return end

	local success, msg, result = EggManager.hatchEgg(player, eggId)
	if success and result then
		eggUpdateEvent:FireClient(player, "hatched", result)
	else
		warn(player.Name .. " - 부화 실패: " .. msg)
	end

	eggUpdateEvent:FireClient(player, "inventory", EggManager.getEggInventory(player))
end)

-- 알 인벤토리 조회
getEggsFunc.OnServerInvoke = function(player)
	return EggManager.getEggInventory(player)
end

-- 배치된 알 조회
getPlacedEggsFunc.OnServerInvoke = function(player)
	return EggManager.getPlacedEggs(player)
end

print("EggServer 로드됨 - 알 부화 시스템")
