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
local showEggBuyPopup = remotes:WaitForChild("ShowEggBuyPopup")

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

EggManager.setShowEggBuyPopup(function(player, slotName, eggName)
	showEggBuyPopup:FireClient(player, slotName, eggName)
end)

-- ProximityPrompt에서 부화 트리거 → hatchEggEvent와 동일 처리
EggManager.setHatchTriggerHandler(function(player, eggId)
	local success, msg, result = EggManager.hatchEgg(player, eggId)
	if success and result then
		eggUpdateEvent:FireClient(player, "hatched", result)
	else
		warn(player.Name .. " - 부화 실패: " .. (msg or ""))
	end
	eggUpdateEvent:FireClient(player, "inventory", EggManager.getEggInventory(player))
end)

----------------------------------------------------------------
-- Remote 핸들러
----------------------------------------------------------------

-- 알 구매
-- Remotes 폴더의 BuyEgg 인스턴스 확인 (중복 체크)
do
	local count = 0
	for _, child in remotes:GetChildren() do
		if child.Name == "BuyEgg" then
			count = count + 1
			print("[EggServer] BuyEgg 인스턴스 #" .. count .. ": " .. child:GetFullName() .. " class=" .. child.ClassName .. " same=" .. tostring(child == buyEggEvent))
		end
	end
end
print("[EggServer] BuyEgg class=" .. buyEggEvent.ClassName .. " 핸들러 설정")
buyEggEvent.OnServerInvoke = function(player, slotName, eggName)
	print("[EggServer] OnServerInvoke 호출 - player=" .. player.Name .. " slot=" .. tostring(slotName) .. " egg=" .. tostring(eggName))
	if typeof(slotName) ~= "string" then
		warn("[EggServer] slotName not string: " .. typeof(slotName))
		return "Invalid slot"
	end

	local success, msg = EggManager.buyEgg(player, slotName, eggName)
	if success then
		print(player.Name .. " - 알 구매 성공: " .. slotName)
	else
		warn(player.Name .. " - 알 구매 실패: " .. tostring(msg))
	end

	-- 클라이언트에 알 인벤토리 갱신
	eggUpdateEvent:FireClient(player, "inventory", EggManager.getEggInventory(player))

	return msg
end

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

-- 알을 Tool로 들기 (인벤토리에 있는 알을 들고 다닐 수 있도록)
local equipEggEvent = remotes:WaitForChild("EquipEgg")
local _heldEggs: { [Player]: Tool } = {}

equipEggEvent.OnServerEvent:Connect(function(player, eggType)
	if typeof(eggType) ~= "string" then return end

	-- 인벤토리에 알 있는지 확인
	local inv = EggManager.getEggInventory(player)
	local hasEgg = false
	for _, e in inv do
		if e.eggType == eggType and e.count > 0 then
			hasEgg = true
			break
		end
	end
	if not hasEgg then
		warn(player.Name .. " - EquipEgg: no egg " .. eggType)
		return
	end

	-- 기존에 들고 있던 알 Tool 제거
	if _heldEggs[player] and _heldEggs[player].Parent then
		_heldEggs[player]:Destroy()
	end

	-- Tool 생성
	local tool = Instance.new("Tool")
	tool.Name = "Egg_" .. eggType
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("EggType", eggType)
	tool:SetAttribute("IsEggTool", true)

	-- Handle (model from ReplicatedStorage.Egg)
	local eggFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Egg")
	local template = eggFolder and eggFolder:FindFirstChild(eggType)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(2, 2, 2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	if template then
		local clone = template:Clone()
		if clone:IsA("Model") then
			clone:PivotTo(CFrame.new(0, 0, 0))
			for _, p in clone:GetDescendants() do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.Massless = true
					p.Anchored = false
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = p
					weld.Parent = p
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

	tool.Parent = player.Backpack
	_heldEggs[player] = tool

	-- 자동 장착
	local humanoid = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end

	-- Tool 사라지면 트래킹 해제
	tool.AncestryChanged:Connect(function(_, newParent)
		if not newParent then
			if _heldEggs[player] == tool then
				_heldEggs[player] = nil
			end
		end
	end)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	if _heldEggs[player] and _heldEggs[player].Parent then
		_heldEggs[player]:Destroy()
	end
	_heldEggs[player] = nil
end)

-- 상점 판매 목록 업데이트
local updateResolution = 60 * 5 -- 5분 마다 업데이트
local lastQuantization = 0
task.spawn(function ()
	while true do
		local currentQuantization = tick() // updateResolution
		if currentQuantization ~= lastQuantization then
			EggManager.updateShopEggs(currentQuantization)
			lastQuantization = currentQuantization
			print("EggServer 상점 목록 업데이트")
		end
		task.wait(1)
	end 
end)

print("EggServer 로드됨 - 알 부화 시스템")
