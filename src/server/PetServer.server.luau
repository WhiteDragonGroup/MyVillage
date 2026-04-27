-- PetServer.server.luau
-- AssignPet / UnassignPet / GetPets Remote 핸들러

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local assignPetEvent = remotes:WaitForChild("AssignPet")
local unassignPetEvent = remotes:WaitForChild("UnassignPet")
local getPetsFunc = remotes:WaitForChild("GetPets")

local serverScript = script.Parent
local PetManager = require(serverScript:WaitForChild("PetManager"))
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))

-- SellPet / SellAllPets / GetPetSellPrice remotes
local sellPetEvent = remotes:FindFirstChild("SellPet")
if not sellPetEvent then
	sellPetEvent = Instance.new("RemoteFunction")
	sellPetEvent.Name = "SellPet"
	sellPetEvent.Parent = remotes
end

local sellAllPetsEvent = remotes:FindFirstChild("SellAllPets")
if not sellAllPetsEvent then
	sellAllPetsEvent = Instance.new("RemoteFunction")
	sellAllPetsEvent.Name = "SellAllPets"
	sellAllPetsEvent.Parent = remotes
end

local getPetSellPriceFunc = remotes:FindFirstChild("GetPetSellPrice")
if not getPetSellPriceFunc then
	getPetSellPriceFunc = Instance.new("RemoteFunction")
	getPetSellPriceFunc.Name = "GetPetSellPrice"
	getPetSellPriceFunc.Parent = remotes
end

----------------------------------------------------------------
-- AssignPet: 펫을 건물에 배치
----------------------------------------------------------------
assignPetEvent.OnServerEvent:Connect(function(player, petId, buildingId)
	if typeof(petId) ~= "string" or typeof(buildingId) ~= "string" then
		warn(player.Name .. " - AssignPet 잘못된 요청 형식")
		return
	end

	local ok, reason = PetManager.assignPet(player, petId, buildingId)
	if not ok then
		warn(player.Name .. " - 펫 배치 실패: " .. (reason or ""))
	end
end)

----------------------------------------------------------------
-- UnassignPet: 펫 회수
----------------------------------------------------------------
unassignPetEvent.OnServerEvent:Connect(function(player, petId)
	if typeof(petId) ~= "string" then
		warn(player.Name .. " - UnassignPet 잘못된 요청 형식")
		return
	end

	local ok, reason = PetManager.unassignPet(player, petId)
	if not ok then
		warn(player.Name .. " - 펫 회수 실패: " .. (reason or ""))
	end
end)

----------------------------------------------------------------
-- GetPets: 펫 목록 조회
----------------------------------------------------------------
getPetsFunc.OnServerInvoke = function(player)
	return PetManager.getPets(player)
end

----------------------------------------------------------------
-- SellPet: sell a single pet
----------------------------------------------------------------
sellPetEvent.OnServerInvoke = function(player, petId)
	if typeof(petId) ~= "string" then return false, "Invalid petId" end

	local petData = PetManager.getPetData(player, petId)
	if not petData then return false, "Pet not found" end

	local price = PetManager.getSellPrice(petData)
	local ok, reason = PetManager.removePet(player, petId)
	if not ok then return false, reason end

	CurrencyManager.addCoins(player, price)
	return true, price
end

----------------------------------------------------------------
-- SellAllPets: sell all unassigned pets
----------------------------------------------------------------
sellAllPetsEvent.OnServerInvoke = function(player)
	local pets = PetManager.getPets(player)
	local totalPrice = 0
	local soldCount = 0

	for _, pet in pets do
		if pet.assignedBuildingId == "" or pet.assignedBuildingId == nil then
			local petData = PetManager.getPetData(player, pet.petId)
			if petData then
				local price = PetManager.getSellPrice(petData)
				local ok = PetManager.removePet(player, pet.petId)
				if ok then
					totalPrice = totalPrice + price
					soldCount = soldCount + 1
				end
			end
		end
	end

	if totalPrice > 0 then
		CurrencyManager.addCoins(player, totalPrice)
	end

	return soldCount, totalPrice
end

----------------------------------------------------------------
-- GetPetSellPrice: get sell price of a specific pet
----------------------------------------------------------------
getPetSellPriceFunc.OnServerInvoke = function(player, petId)
	if typeof(petId) ~= "string" then return 0 end

	local petData = PetManager.getPetData(player, petId)
	if not petData then return 0 end

	return PetManager.getSellPrice(petData)
end

print("PetServer 로드됨")
