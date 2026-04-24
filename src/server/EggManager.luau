-- EggManager.luau
-- 서버 알 관리: 인벤토리, 배치, 부화, 펫 생성

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local EggCfg = BalanceConfig.Egg
local PetCfg = BalanceConfig.Pet

local EggManager = {}

-- 플레이어별 알 인벤토리 { [Player]: { {eggType, count} } }
local _eggInventories = {}

-- 플레이어별 배치된 알 { [Player]: { [eggId]: { eggType, placedTime, position } } }
local _placedEggs = {}

-- 펫 추가 함수 (외부 주입)
local _addPet = nil
function EggManager.setPetFunction(addFn)
	_addPet = addFn
end

-- 코인 함수 (외부 주입)
local _hasCoins = nil
local _spendCoins = nil
function EggManager.setCurrencyFunctions(hasFn, spendFn)
	_hasCoins = hasFn
	_spendCoins = spendFn
end

----------------------------------------------------------------
-- 초기화
----------------------------------------------------------------
function EggManager.initPlayer(player: Player, savedEggs: { any }?)
	_eggInventories[player] = {}
	_placedEggs[player] = {}

	if savedEggs then
		for _, egg in savedEggs do
			if egg.eggType and egg.count then
				table.insert(_eggInventories[player], {
					eggType = egg.eggType,
					count = egg.count,
				})
			end
		end
	end
end

function EggManager.removePlayer(player: Player)
	-- 배치된 알 모델 제거
	local placed = _placedEggs[player]
	if placed then
		for eggId, data in placed do
			if data.model and data.model.Parent then
				data.model:Destroy()
			end
		end
	end
	_eggInventories[player] = nil
	_placedEggs[player] = nil
end

----------------------------------------------------------------
-- 알 인벤토리
----------------------------------------------------------------
function EggManager.getEggInventory(player: Player): { any }
	local inv = _eggInventories[player]
	if not inv then return {} end

	local result = {}
	for _, egg in inv do
		if egg.count > 0 then
			table.insert(result, { eggType = egg.eggType, count = egg.count })
		end
	end
	return result
end

function EggManager.addEgg(player: Player, eggType: string, count: number?): boolean
	local inv = _eggInventories[player]
	if not inv then return false end

	count = count or 1

	-- 기존 항목 찾기
	for _, egg in inv do
		if egg.eggType == eggType then
			egg.count = egg.count + count
			return true
		end
	end

	-- 새 항목
	table.insert(inv, { eggType = eggType, count = count })
	return true
end

function EggManager.removeEgg(player: Player, eggType: string, count: number?): boolean
	local inv = _eggInventories[player]
	if not inv then return false end

	count = count or 1

	for i, egg in inv do
		if egg.eggType == eggType then
			if egg.count < count then return false end
			egg.count = egg.count - count
			if egg.count <= 0 then
				table.remove(inv, i)
			end
			return true
		end
	end
	return false
end

----------------------------------------------------------------
-- 상점 구매
----------------------------------------------------------------
function EggManager.buyEgg(player: Player, eggType: string): (boolean, string)
	local eggInfo = EggCfg.EGGS[eggType]
	if not eggInfo then return false, "존재하지 않는 알" end

	if not _hasCoins or not _spendCoins then return false, "코인 시스템 미연결" end
	if not _hasCoins(player, eggInfo.price) then return false, "코인 부족" end
	if not _spendCoins(player, eggInfo.price) then return false, "코인 차감 실패" end

	EggManager.addEgg(player, eggType, 1)
	return true, "구매 완료"
end

----------------------------------------------------------------
-- 알 배치 (마을에 설치)
----------------------------------------------------------------
function EggManager.placeEgg(player: Player, eggType: string, position: Vector3): (boolean, string)
	local eggInfo = EggCfg.EGGS[eggType]
	if not eggInfo then return false, "존재하지 않는 알" end

	-- 인벤토리 확인
	local hasEgg = false
	local inv = _eggInventories[player]
	if inv then
		for _, egg in inv do
			if egg.eggType == eggType and egg.count > 0 then
				hasEgg = true
				break
			end
		end
	end
	if not hasEgg then return false, "알이 없음" end

	-- 동시 배치 제한
	local placed = _placedEggs[player]
	if not placed then placed = {}; _placedEggs[player] = placed end

	local placedCount = 0
	for _ in placed do placedCount = placedCount + 1 end
	if placedCount >= EggCfg.MAX_PLACED_EGGS then
		return false, "최대 " .. EggCfg.MAX_PLACED_EGGS .. "개까지 설치 가능"
	end

	-- 인벤토리에서 차감
	EggManager.removeEgg(player, eggType, 1)

	-- 알 모델 생성
	local eggFolder = ReplicatedStorage:FindFirstChild("Egg")
	local template = eggFolder and eggFolder:FindFirstChild(eggType)

	local eggModel
	if template then
		eggModel = template:Clone()
	else
		-- 폴백: 기본 파트
		eggModel = Instance.new("Part")
		eggModel.Size = Vector3.new(2, 3, 2)
		eggModel.Shape = Enum.PartType.Ball
		eggModel.Color = Color3.fromRGB(255, 230, 180)
		eggModel.Material = Enum.Material.SmoothPlastic
	end

	local eggId = HttpService:GenerateGUID(false)

	-- 위치 설정
	local mainPart
	if eggModel:IsA("Model") then
		mainPart = eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart")
		if mainPart then
			eggModel:PivotTo(CFrame.new(position))
		end
	elseif eggModel:IsA("BasePart") then
		eggModel.CFrame = CFrame.new(position)
		mainPart = eggModel
	end

	if mainPart then
		mainPart.Anchored = true
		mainPart.CanCollide = false
		mainPart.CanQuery = true
	end

	-- 속성 설정
	local target = mainPart or eggModel
	target:SetAttribute("EggId", eggId)
	target:SetAttribute("EggType", eggType)
	target:SetAttribute("OwnerId", player.UserId)
	target:SetAttribute("PlacedTime", tick())
	target:SetAttribute("HatchTime", eggInfo.hatchTime)
	target:SetAttribute("HatchProgress", 0)
	target:SetAttribute("IsEgg", true)

	-- 플롯에 배치
	local plot = EggManager._getPlayerPlot(player)
	if plot then
		eggModel.Parent = plot
	else
		eggModel.Parent = workspace
	end

	-- 배치 데이터 저장
	placed[eggId] = {
		eggType = eggType,
		placedTime = tick(),
		model = mainPart or eggModel,
		eggId = eggId,
	}

	-- 부화 타이머 시작
	EggManager._startHatchTimer(player, eggId)

	print(player.Name .. " - 알 설치: " .. eggType .. " (ID: " .. eggId .. ")")
	return true, eggId
end

----------------------------------------------------------------
-- 부화 타이머
----------------------------------------------------------------
function EggManager._startHatchTimer(player: Player, eggId: string)
	local placed = _placedEggs[player]
	if not placed or not placed[eggId] then return end

	local data = placed[eggId]
	local eggInfo = EggCfg.EGGS[data.eggType]
	if not eggInfo then return end

	task.spawn(function()
		local elapsed = 0
		while elapsed < eggInfo.hatchTime do
			task.wait(1)
			elapsed = elapsed + 1

			-- 모델이 제거됐으면 중단
			if not data.model or not data.model.Parent then return end
			if not _placedEggs[player] or not _placedEggs[player][eggId] then return end

			-- 진행도 업데이트
			data.model:SetAttribute("HatchProgress", elapsed / eggInfo.hatchTime)
		end

		-- 부화 완료
		if data.model and data.model.Parent then
			data.model:SetAttribute("HatchProgress", 1)
			data.model:SetAttribute("ReadyToHatch", true)
			print(player.Name .. " - 알 부화 준비 완료: " .. data.eggType)
		end
	end)
end

----------------------------------------------------------------
-- 부화 실행 (플레이어 상호작용)
----------------------------------------------------------------
function EggManager.hatchEgg(player: Player, eggId: string): (boolean, string, { any }?)
	local placed = _placedEggs[player]
	if not placed or not placed[eggId] then return false, "알을 찾을 수 없음", nil end

	local data = placed[eggId]
	local model = data.model

	-- 부화 완료 확인
	if not model or not model.Parent then return false, "알이 없음", nil end
	if not model:GetAttribute("ReadyToHatch") then return false, "아직 부화 중", nil end

	local eggInfo = EggCfg.EGGS[data.eggType]
	if not eggInfo then return false, "알 정보 없음", nil end

	-- 등급별 가중치로 펫 선택
	local selectedRarity = EggManager._rollRarity(eggInfo.rarityWeights)

	-- 해당 등급의 펫 후보 필터
	local candidates = {}
	for _, pet in eggInfo.petPool do
		if pet.rarity == selectedRarity then
			table.insert(candidates, pet)
		end
	end

	-- 후보가 없으면 전체에서 랜덤
	if #candidates == 0 then
		candidates = eggInfo.petPool
	end

	local selectedPet = candidates[math.random(#candidates)]

	-- 선천적 돌연변이 확인
	local mutations = {}
	for mutType, chance in EggCfg.MUTATION_CHANCE do
		if chance > 0 and math.random() < chance then
			table.insert(mutations, mutType)
		end
	end

	-- 펫 생성
	if _addPet then
		local petData = {
			petName = selectedPet.petName,
			petType = selectedPet.petType,
			rarity = selectedPet.rarity,
			size = selectedPet.size or "Small",
			race = selectedPet.race or "Human",
			mutations = mutations,
		}
		_addPet(player, petData)
	end

	-- 알 제거
	if model.Parent then
		local parent = model.Parent
		if parent:IsA("Model") then
			parent:Destroy()
		else
			model:Destroy()
		end
	end
	placed[eggId] = nil

	local result = {
		petName = selectedPet.petName,
		rarity = selectedPet.rarity,
		mutations = mutations,
	}

	print(player.Name .. " - 부화 완료! " .. selectedPet.petName .. " (" .. selectedPet.rarity .. ")")
	return true, "부화 완료", result
end

-- 등급 가중치 뽑기
function EggManager._rollRarity(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do
		total = total + w
	end

	local roll = math.random() * total
	local cumulative = 0
	for rarity, weight in weights do
		cumulative = cumulative + weight
		if roll <= cumulative then
			return rarity
		end
	end

	-- 폴백
	for rarity, _ in weights do
		return rarity
	end
	return "Common"
end

-- 배치된 알 목록
function EggManager.getPlacedEggs(player: Player): { any }
	local placed = _placedEggs[player]
	if not placed then return {} end

	local result = {}
	for eggId, data in placed do
		local progress = 0
		local ready = false
		if data.model and data.model.Parent then
			progress = data.model:GetAttribute("HatchProgress") or 0
			ready = data.model:GetAttribute("ReadyToHatch") == true
		end
		table.insert(result, {
			eggId = eggId,
			eggType = data.eggType,
			progress = progress,
			readyToHatch = ready,
		})
	end
	return result
end

-- 저장 데이터
function EggManager.getSaveData(player: Player): { any }
	return EggManager.getEggInventory(player)
end

-- 플레이어 플롯 찾기
function EggManager._getPlayerPlot(player: Player)
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == player.Name then
			return plot
		end
	end
	return nil
end

return EggManager
