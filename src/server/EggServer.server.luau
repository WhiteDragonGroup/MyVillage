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
local eggHatchEffectEvent = remotes:WaitForChild("EggHatchEffect")
local skipHatchEvent = remotes:WaitForChild("SkipHatch")

-- 클라이언트의 Skip 요청 처리
skipHatchEvent.OnServerEvent:Connect(function(player, eggId)
	if typeof(eggId) ~= "string" then return end
	local ok, msg = EggManager.skipHatch(player, eggId)
	if not ok then
		warn(player.Name .. " - skip 실패: " .. msg)
	end
end)

local serverScript = script.Parent
local EggManager = require(serverScript:WaitForChild("EggManager"))
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local PetManager = require(serverScript:WaitForChild("PetManager"))

local HttpService = game:GetService("HttpService")
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local PetCfg = BalanceConfig.Pet

-- EggManager에 코인/다이아/펫 함수 연결
EggManager.setCurrencyFunctions(
	function(player, amount) return CurrencyManager.hasCoins(player, amount) end,
	function(player, amount) return CurrencyManager.spendCoins(player, amount) end
)
EggManager.setGemFunctions(
	function(player, amount) return CurrencyManager.hasGems(player, amount) end,
	function(player, amount) return CurrencyManager.spendGems(player, amount) end
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

	-- 부화 직후: 펫을 플레이어 손(Tool 슬롯)에 들리도록
	-- PetServer가 _G에 등록한 hold 함수 호출 (서버 내부 통신)
	if _G.PetServer_HoldPet then
		task.defer(_G.PetServer_HoldPet, player, petId)
	end
end)

-- 중복 ShowEggBuyPopup 인스턴스가 있을 수 있으니 모두에 fire
EggManager.setShowEggBuyPopup(function(player, slotName, eggName)
	for _, child in remotes:GetChildren() do
		if child.Name == "ShowEggBuyPopup" and child:IsA("RemoteEvent") then
			child:FireClient(player, slotName, eggName)
		end
	end
end)

-- ProximityPrompt에서 부화 트리거 → hatchEggEvent와 동일 처리
EggManager.setHatchTriggerHandler(function(player, eggId)
	local success, msg, result = EggManager.hatchEgg(player, eggId)
	if success and result then
		eggUpdateEvent:FireClient(player, "hatched", result)
		if result.hatchPos then
			eggHatchEffectEvent:FireAllClients(result.hatchPos, result.rarity)
		end
	else
		warn(player.Name .. " - 부화 실패: " .. (msg or ""))
	end
	eggUpdateEvent:FireClient(player, "inventory", EggManager.getEggInventory(player))
end)

----------------------------------------------------------------
-- Remote 핸들러
----------------------------------------------------------------

-- 알 구매
-- 모든 BuyEgg RemoteFunction 인스턴스에 핸들러 바인딩 (rojo 클래스 변경/중복 인스턴스 대응)
local function _buyEggHandler(player, slotName, eggName)
	if typeof(slotName) ~= "string" then return "Invalid slot" end
	local success, msg = EggManager.buyEgg(player, slotName, eggName)
	if success then
		print(player.Name .. " - 알 구매: " .. slotName)
		if _G.SyncEggTools then _G.SyncEggTools(player) end
	else
		warn(player.Name .. " - 알 구매 실패: " .. tostring(msg))
	end
	eggUpdateEvent:FireClient(player, "inventory", EggManager.getEggInventory(player))
	return msg
end

local function bindBuyEggInstance(rf: RemoteFunction)
	rf.OnServerInvoke = _buyEggHandler
	buyEggEvent = rf
end

do
	local anyFound = false
	for _, child in remotes:GetChildren() do
		if child.Name == "BuyEgg" and child:IsA("RemoteFunction") then
			anyFound = true
			bindBuyEggInstance(child)
		end
	end
	if not anyFound then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "BuyEgg"
		rf.Parent = remotes
		bindBuyEggInstance(rf)
	end
end

remotes.ChildAdded:Connect(function(child)
	if child.Name == "BuyEgg" and child:IsA("RemoteFunction") then
		bindBuyEggInstance(child)
	end
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
	if _G.SyncEggTools then _G.SyncEggTools(player) end
end)

-- 부화
hatchEggEvent.OnServerEvent:Connect(function(player, eggId)
	if typeof(eggId) ~= "string" then return end

	local success, msg, result = EggManager.hatchEgg(player, eggId)
	if success and result then
		eggUpdateEvent:FireClient(player, "hatched", result)
		-- 부화 이펙트는 모든 클라이언트에 broadcast (다른 플레이어도 봄)
		if result.hatchPos then
			eggHatchEffectEvent:FireAllClients(result.hatchPos, result.rarity)
		end
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

-- 알 Tool 자동 동기화: 인벤토리에 있는 알을 Backpack에 Tool 형태로 유지 (스택)
local function buildEggTool(eggType: string): Tool
	local tool = Instance.new("Tool")
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("EggType", eggType)
	tool:SetAttribute("IsEggTool", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(2, 2, 2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local eggFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Egg")
	local template = eggFolder and eggFolder:FindFirstChild(eggType)
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

	return tool
end

local function getDisplayName(eggType: string, count: number): string
	local info = BalanceConfig.Egg.EGGS[eggType]
	local base = (info and info.name) or eggType
	if count > 1 then
		return string.format("%s x%d", base, count)
	end
	return base
end

local function syncEggTools(player: Player)
	if not player or not player.Parent then return end

	local inv = EggManager.getEggInventory(player)
	local desired: { [string]: number } = {}
	for _, e in inv do
		if e.count > 0 then
			desired[e.eggType] = e.count
		end
	end

	-- 기존 Tool 수집 (Backpack + Character)
	local existing: { [string]: Tool } = {}
	local function scan(parent)
		if not parent then return end
		for _, child in parent:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("IsEggTool") then
				local et = child:GetAttribute("EggType")
				if et then existing[et] = child end
			end
		end
	end
	scan(player:FindFirstChild("Backpack"))
	scan(player.Character)

	-- 필요없는 Tool 제거
	for et, tool in existing do
		if not desired[et] then
			tool:Destroy()
		end
	end

	-- 필요한 Tool 생성/업데이트
	for et, count in desired do
		local tool = existing[et]
		if not tool or not tool.Parent then
			tool = buildEggTool(et)
			tool.Parent = player.Backpack
		end
		tool.Name = getDisplayName(et, count)
		tool:SetAttribute("Count", count)
	end
end

-- 외부 노출
_G.SyncEggTools = syncEggTools

-- 알을 Tool로 들기 Remote (수동 트리거 - 자동 동기화로 거의 불필요)
local equipEggEvent = remotes:WaitForChild("EquipEgg")
equipEggEvent.OnServerEvent:Connect(function(player, eggType)
	if typeof(eggType) ~= "string" then return end
	syncEggTools(player)

	-- 해당 타입 Tool 자동 장착
	local tool
	for _, child in player.Backpack:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("EggType") == eggType then
			tool = child
			break
		end
	end
	if not tool then return end

	local humanoid = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
end)

-- 플레이어 접속 시 인벤토리 기반으로 Tool 동기화
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		syncEggTools(player)
	end)
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
