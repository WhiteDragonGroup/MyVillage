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

-- 펫 Tool은 Backpack/Character의 PetId 속성으로 식별 (별도 레지스트리 없음)
local function findPetTool(player: Player, petId: string): Tool?
	local containers = { player:FindFirstChild("Backpack"), player.Character }
	for _, c in containers do
		if not c then continue end
		for _, child in c:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("PetId") == petId then
				return child
			end
		end
	end
	return nil
end

holdPetEvent.OnServerEvent:Connect(function(player, petId)
	if typeof(petId) ~= "string" then return end

	-- 이미 같은 펫 Tool이 있으면 무시 (다른 펫 Tool들은 그대로 유지)
	if findPetTool(player, petId) then
		return
	end

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
	PetManager.stopBehaviorLoop(petId)

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

	-- Tool이 백팩/캐릭터에서 빠짐(소실/캐릭터 리스폰) → 펫을 월드로 복귀
	-- 같은 Tool이 그냥 destroy되는 경우엔 dropPetEvent가 명시적으로 호출하여 복귀 처리
	tool.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil and not tool:GetAttribute("_DroppedExplicit") then
			-- 캐릭터 리스폰 등으로 Tool이 사라진 경우만 자동 복귀
			PetManager.returnPetToWorld(player, petId)
		end
	end)
end)

dropPetEvent.OnServerEvent:Connect(function(player, position, petIdParam)
	-- petIdParam이 들어오면 그 펫만 드롭, 없으면 캐릭터에 장착된 펫 Tool 자동 탐지
	local tool: Tool? = nil
	local petId: string? = nil

	if typeof(petIdParam) == "string" and petIdParam ~= "" then
		tool = findPetTool(player, petIdParam)
		petId = petIdParam
	else
		local character = player.Character
		if character then
			for _, child in character:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("PetId") then
					tool = child
					petId = child:GetAttribute("PetId")
					break
				end
			end
		end
	end

	if not tool or not petId then return end

	-- 명시적 드롭 표시 → AncestryChanged 자동 복귀 막음
	tool:SetAttribute("_DroppedExplicit", true)
	if tool.Parent then tool:Destroy() end

	local validPos = if typeof(position) == "Vector3" then position else nil
	PetManager.returnPetToWorld(player, petId, validPos)
end)

-- Cleanup: 플레이어 나갈 때 들고 있던 펫 모두 월드로 복귀
game:GetService("Players").PlayerRemoving:Connect(function(player)
	local containers = { player:FindFirstChild("Backpack"), player.Character }
	for _, c in containers do
		if not c then continue end
		for _, child in c:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("PetId") then
				local pid = child:GetAttribute("PetId")
				child:Destroy()
				if pid then
					PetManager.returnPetToWorld(player, pid)
				end
			end
		end
	end
end)

print("PetServer 로드됨")
