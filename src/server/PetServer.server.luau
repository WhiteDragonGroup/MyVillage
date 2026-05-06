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

----------------------------------------------------------------
-- HoldPet: 펫을 Tool로 만들어 플레이어가 들 수 있게
----------------------------------------------------------------
local holdPetEvent = remotes:FindFirstChild("HoldPet")
if not holdPetEvent then
	holdPetEvent = Instance.new("RemoteEvent")
	holdPetEvent.Name = "HoldPet"
	holdPetEvent.Parent = remotes
end

local dropPetEvent = remotes:FindFirstChild("DropPet")
if not dropPetEvent then
	dropPetEvent = Instance.new("RemoteEvent")
	dropPetEvent.Name = "DropPet"
	dropPetEvent.Parent = remotes
end

-- Track held pets: { [Player] = { petId, tool } }
local _heldPets = {}

holdPetEvent.OnServerEvent:Connect(function(player, petId)
	if typeof(petId) ~= "string" then return end

	-- 기존 펫 Tool 전부 정리 (Backpack + Character 모두 검사하여 누락 방지)
	local function cleanupExisting()
		local containers = { player:FindFirstChild("Backpack"), player.Character }
		for _, c in containers do
			if not c then continue end
			for _, child in c:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("PetId") then
					local oldPetId = child:GetAttribute("PetId")
					child:Destroy()
					if oldPetId then
						PetManager.returnPetToWorld(player, oldPetId)
					end
				end
			end
		end
		_heldPets[player] = nil
	end
	cleanupExisting()

	local petData = PetManager.getPetData(player, petId)
	if not petData then
		warn("[HoldPet] Pet not found: " .. petId)
		return
	end

	-- Can't hold assigned pets (e.g., 업그레이드/작업 중)
	if petData.assignedBuildingId and petData.assignedBuildingId ~= "" then
		warn("[HoldPet] Pet is assigned")
		holdPetEvent:FireClient(player, "error", "Pet is busy with a building.")
		return
	end

	print("[HoldPet] Holding: " .. petData.petName)

	-- Stop behavior loop
	petData.state = "Held"

	-- Hide the world model
	if petData._petModel and petData._petModel.Parent then
		petData._petModel.Parent = nil
	elseif petData.model and petData.model.Parent then
		petData.model.Parent = nil
	end

	-- Create Tool
	local tool = Instance.new("Tool")
	tool.Name = "Pet_" .. petData.petName
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	-- Create handle from pet model clone
	local petInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants")).PETS[petData.petName]
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(2, 2, 2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- Clone pet visual into tool
	local serverPetsFolder = game:GetService("ServerStorage"):FindFirstChild("Pets")
	if serverPetsFolder then
		local petFolder = serverPetsFolder:FindFirstChild(petData.petName)
		if petFolder then
			local modelFolder = petFolder:FindFirstChild("Model")
			if modelFolder then
				local petModel = modelFolder:FindFirstChildWhichIsA("Model")
					or modelFolder:FindFirstChildWhichIsA("BasePart")
				if petModel then
					local clone = petModel:Clone()
					if clone:IsA("Model") then
						clone:PivotTo(CFrame.new(0, 0, 0))
						for _, part in clone:GetDescendants() do
							if part:IsA("BasePart") then
								part.CanCollide = false
								part.Massless = true
								part.Anchored = false
								local weld = Instance.new("WeldConstraint")
								weld.Part0 = handle
								weld.Part1 = part
								weld.Parent = part
							end
						end
					elseif clone:IsA("BasePart") then
						clone.CanCollide = false
						clone.Massless = true
						clone.Anchored = false
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = handle
						weld.Part1 = clone
						weld.Parent = clone
					end
					clone.Parent = tool
				end
			end
		end
	end

	tool:SetAttribute("PetId", petId)
	tool:SetAttribute("PetName", petData.petName)
	tool.Parent = player.Backpack

	_heldPets[player] = { petId = petId, tool = tool }

	-- Auto-equip
	local humanoid = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end

	-- When tool is removed (unequipped to backpack or destroyed), drop the pet
	tool.AncestryChanged:Connect(function(_, newParent)
		if not newParent or (newParent ~= player.Backpack and newParent ~= player.Character) then
			-- Tool was removed
			if _heldPets[player] and _heldPets[player].petId == petId then
				PetManager.returnPetToWorld(player, petId)
				_heldPets[player] = nil
			end
		end
	end)
end)

dropPetEvent.OnServerEvent:Connect(function(player, position)
	local held = _heldPets[player]
	if not held then return end

	local petId = held.petId
	-- Clear first to prevent AncestryChanged double trigger
	_heldPets[player] = nil

	-- Destroy tool
	if held.tool and held.tool.Parent then
		held.tool:Destroy()
	end

	-- Return pet to world (optional position validated by PetManager)
	local validPos = if typeof(position) == "Vector3" then position else nil
	PetManager.returnPetToWorld(player, petId, validPos)
end)

-- Get held pet info
local getHeldPetFunc = remotes:FindFirstChild("GetHeldPet")
if not getHeldPetFunc then
	getHeldPetFunc = Instance.new("RemoteFunction")
	getHeldPetFunc.Name = "GetHeldPet"
	getHeldPetFunc.Parent = remotes
end

getHeldPetFunc.OnServerInvoke = function(player)
	local held = _heldPets[player]
	if held then return held.petId end
	return nil
end

-- Cleanup
game:GetService("Players").PlayerRemoving:Connect(function(player)
	local held = _heldPets[player]
	if held then
		if held.tool and held.tool.Parent then held.tool:Destroy() end
		PetManager.returnPetToWorld(player, held.petId)
		_heldPets[player] = nil
	end
end)

print("PetServer 로드됨")
