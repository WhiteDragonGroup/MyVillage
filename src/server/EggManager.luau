-- EggManager.luau
-- 서버 알 관리: 인벤토리, 배치, 부화, 펫 생성

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local EggModels = ReplicatedStorage:WaitForChild("Egg")

local EggCfg = BalanceConfig.Egg
local PetCfg = BalanceConfig.Pet

local EggManager = {}

-- 플레이어별 알 인벤토리 { [Player]: { {eggType, count} } }
local _eggInventories = {}

-- 플레이어별 배치된 알 { [Player]: { [eggId]: { eggType, placedTime, position } } }
local _placedEggs = {}

-- 저장된 배치 알 복원 대기 큐 (PlotManager가 플롯 배정 후 restorePlacedEggs로 소비)
local _pendingPlacedEggs = {}

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

local _showEggBuyPopup = nil
function EggManager.setShowEggBuyPopup(showFn)
	_showEggBuyPopup = showFn
end

local _onHatchTrigger = nil
function EggManager.setHatchTriggerHandler(fn)
	_onHatchTrigger = fn
end

----------------------------------------------------------------
-- 초기화
----------------------------------------------------------------
function EggManager.initPlayer(player: Player, savedEggs: any?)
	_eggInventories[player] = {}
	_placedEggs[player] = {}
	_pendingPlacedEggs[player] = nil

	if not savedEggs then return end

	-- 구 형식: 배열({eggType,count}...) / 신 형식: {inventory={...}, placed={...}}
	local inventory, placed
	if savedEggs.inventory ~= nil or savedEggs.placed ~= nil then
		inventory = savedEggs.inventory
		placed = savedEggs.placed
	else
		inventory = savedEggs
	end

	if inventory then
		for _, egg in inventory do
			if egg.eggType and egg.count then
				table.insert(_eggInventories[player], {
					eggType = egg.eggType,
					count = egg.count,
				})
			end
		end
	end

	if placed and #placed > 0 then
		_pendingPlacedEggs[player] = placed
	end
end

function EggManager.removePlayer(player: Player)
	-- 배치된 알 모델 제거
	local placed = _placedEggs[player]
	if placed then
		for eggId, data in placed do
			local model = data.eggModel or data.model
			if model and model.Parent then
				model:Destroy()
			end
		end
	end
	_eggInventories[player] = nil
	_placedEggs[player] = nil
	_pendingPlacedEggs[player] = nil
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
-- 상점 판매 진열 변경
----------------------------------------------------------------
local _totalWeight = 0
local _shopSlotItems = {} :: { [string]: { pickedEggName: string, model: Model } }
local _shopEmergeTable = {} :: { eggName: string, weight: number }
for eggName, egg in EggCfg.EGGS do
	_totalWeight += egg.shopEmergeWeight
	table.insert(_shopEmergeTable, {
		eggName = eggName,
		weight = egg.shopEmergeWeight,
	})
end
table.sort(_shopEmergeTable, function(a, b) return a.weight > b.weight end)
local eggPlaces = workspace:FindFirstChild("Map"):FindFirstChild("EggPlaces")
function EggManager._pickShopEgg(rand: Random): string
	local pick = rand:NextInteger(0, _totalWeight - 1)
	local cumulative = 0

	for _, emergeInfo in _shopEmergeTable do
		cumulative += emergeInfo.weight
		if pick < cumulative then
			return emergeInfo.eggName
		end
	end
end
function EggManager._initShopEgg(slot: Folder, eggModel: Model, place: Model)
	-- 이전 모델 제거
	for _, child in slot:GetChildren() do
		if child.Name == "EggPlace" then
			continue
		end
		child:Destroy()
	end

	-- 새 모델 배치
	eggModel = eggModel:Clone()
	eggModel.Parent = slot
	eggModel:PivotTo(place:GetPivot() * CFrame.new(Vector3.new(0, 0.5, 0)))

	-- 프롬프트 부착 대상: PrimaryPart 우선, 없으면 첫 BasePart 폴백
	local promptHost: Instance? = eggModel.PrimaryPart
	if not promptHost then
		if eggModel:IsA("BasePart") then
			promptHost = eggModel
		else
			promptHost = eggModel:FindFirstChildWhichIsA("BasePart", true)
		end
	end
	if not promptHost then
		warn("[EggShop] PrimaryPart/BasePart 없음: " .. tostring(eggModel.Name))
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy Egg"
	prompt.ObjectText = eggModel.Name
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = promptHost
	prompt.Triggered:Connect(function(player)
		if _showEggBuyPopup then
			_showEggBuyPopup(player, slot.Name, eggModel.Name)
		end
	end)

	-- 모델 등록
	_shopSlotItems[slot.Name] = {
		pickedEggName = eggModel.Name;
		model = eggModel;
	}
end
function EggManager.updateShopEggs(seed: number)
	local rand = Random.new(seed)

	for _, slot in eggPlaces:GetChildren() do
		local pickedEggName = EggManager._pickShopEgg(rand)
		local eggModel = EggModels:FindFirstChild(pickedEggName)
		local place = slot:FindFirstChild("EggPlace")

		if (not eggModel) or (not place) then
			continue
		end

		EggManager._initShopEgg(slot, eggModel, place)
	end
end

----------------------------------------------------------------
-- 상점 구매
----------------------------------------------------------------
function EggManager.buyEgg(player: Player, slotName: string, eggName: string): (boolean, string)
	local item = _shopSlotItems[slotName]
	if not item then
		return false, "Already sold"
	end
	
	if item.pickedEggName ~= eggName then
		return false, "No longer available for purchase"
	end

	local eggInfo = EggCfg.EGGS[item.pickedEggName]
	if not eggInfo then return false, "Egg not found" end

	if not _hasCoins or not _spendCoins then return false, "Coin system not connected" end
	if not _hasCoins(player, eggInfo.price) then return false, "Not enough coins" end
	if not _spendCoins(player, eggInfo.price) then return false, "Coin deduction failed" end

	EggManager.addEgg(player, item.pickedEggName, 1)
	_shopSlotItems[slotName] = nil

	-- 구매한 알 모델은 다음 리젠 시점까지 완전히 제거
	if item.model and item.model.Parent then
		item.model:Destroy()
	end

	return true, "Purchase complete"
end

----------------------------------------------------------------
-- 알 배치 (마을에 설치)
----------------------------------------------------------------
-- 알 모델 생성 + 배치 (인벤토리/제한 검사 없음). placeEgg와 restorePlacedEggs에서 공용.
-- restorePivotCF가 주어지면 그 CFrame으로 직접 PivotTo (바닥 높이 보정 스킵).
-- 그렇지 않으면 groundPos.Y에 모델 높이/2를 더해 중심을 올림.
local function _spawnPlacedEgg(player: Player, eggType: string, groundPos: Vector3?, restorePivotCF: CFrame?): string?
	local eggInfo = EggCfg.EGGS[eggType]
	if not eggInfo then return nil end

	local eggFolder = ReplicatedStorage:FindFirstChild("Egg")
	local template = eggFolder and eggFolder:FindFirstChild(eggType)

	local eggModel
	if template then
		eggModel = template:Clone()
	else
		eggModel = Instance.new("Part")
		eggModel.Size = Vector3.new(2, 3, 2)
		eggModel.Shape = Enum.PartType.Ball
		eggModel.Color = Color3.fromRGB(255, 230, 180)
		eggModel.Material = Enum.Material.SmoothPlastic
	end

	-- 크기 4배 확대
	local SCALE = 4
	if eggModel:IsA("Model") then
		eggModel:ScaleTo(SCALE)
	elseif eggModel:IsA("BasePart") then
		eggModel.Size = eggModel.Size * SCALE
	end

	local eggId = HttpService:GenerateGUID(false)

	-- 위치 설정
	local mainPart
	if eggModel:IsA("Model") then
		mainPart = eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart")
	elseif eggModel:IsA("BasePart") then
		mainPart = eggModel
	end

	local pivotCF: CFrame
	if restorePivotCF then
		pivotCF = restorePivotCF
	else
		local pos = groundPos or Vector3.zero
		local height = 0
		if eggModel:IsA("Model") then
			local _, sz = eggModel:GetBoundingBox()
			height = sz.Y
		elseif eggModel:IsA("BasePart") then
			height = eggModel.Size.Y
		end
		pivotCF = CFrame.new(pos.X, pos.Y + height / 2, pos.Z)
	end

	if eggModel:IsA("Model") then
		eggModel:PivotTo(pivotCF)
	elseif eggModel:IsA("BasePart") then
		eggModel.CFrame = pivotCF
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
	local placed = _placedEggs[player]
	if not placed then placed = {}; _placedEggs[player] = placed end

	placed[eggId] = {
		eggType = eggType,
		placedTime = tick(),
		model = mainPart or eggModel,
		eggModel = eggModel, -- 저장 시 GetPivot 호출용
		eggId = eggId,
	}

	return eggId
end

function EggManager.placeEgg(player: Player, eggType: string, position: Vector3): (boolean, string)
	local eggInfo = EggCfg.EGGS[eggType]
	if not eggInfo then return false, "Egg not found" end

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
	if not hasEgg then return false, "No egg" end

	-- 동시 배치 제한
	local placed = _placedEggs[player]
	if not placed then placed = {}; _placedEggs[player] = placed end

	local placedCount = 0
	for _ in placed do placedCount = placedCount + 1 end
	if placedCount >= EggCfg.MAX_PLACED_EGGS then
		return false, "Max " .. EggCfg.MAX_PLACED_EGGS .. " placeable"
	end

	-- 인벤토리에서 차감
	EggManager.removeEgg(player, eggType, 1)

	local eggId = _spawnPlacedEgg(player, eggType, position, nil)
	if not eggId then return false, "Spawn failed" end

	-- 부화 타이머 시작
	EggManager._startHatchTimer(player, eggId, 0)

	print(player.Name .. " - egg placed: " .. eggType .. " (ID: " .. eggId .. ")")
	return true, eggId
end

----------------------------------------------------------------
-- 부화 타이머 BillboardGui 생성
----------------------------------------------------------------
function EggManager._createHatchBillboard(model: Instance): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HatchTimer"
	billboard.Size = UDim2.new(0, 140, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
	label.TextSize = 18
	label.Text = "..."
	label.Parent = billboard

	return label
end

local function formatTime(secs: number): string
	if secs <= 0 then return "Ready!" end
	local m = math.floor(secs / 60)
	local s = math.floor(secs % 60)
	if m > 0 then
		return string.format("%d:%02d", m, s)
	end
	return string.format("%ds", s)
end

----------------------------------------------------------------
-- 부화 타이머
----------------------------------------------------------------
-- 플레이어의 마을에 Laboratory가 있으면 부화 속도 증가율 반환
local function getLaboratoryHatchBoost(player: Player): number
	local plot = EggManager._getPlayerPlot(player)
	if not plot then return 0 end
	local boostCfg = BalanceConfig.Buff and BalanceConfig.Buff.LABORATORY_HATCH_BOOST or {}
	local maxBoost = 0
	for _, desc in plot:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("ItemName") == "Laboratory" then
			local lvl = desc:GetAttribute("Level") or 1
			local b = boostCfg[lvl] or 0
			if b > maxBoost then maxBoost = b end
		end
	end
	return maxBoost
end

-- initialProgress: 0..1 (이미 진행된 비율). 복원 시 사용.
function EggManager._startHatchTimer(player: Player, eggId: string, initialProgress: number?)
	local placed = _placedEggs[player]
	if not placed or not placed[eggId] then return end

	local data = placed[eggId]
	local eggInfo = EggCfg.EGGS[data.eggType]
	if not eggInfo then return end

	-- Laboratory 부화 속도 부스트 (실제 부화 시간 단축)
	local boost = getLaboratoryHatchBoost(player)
	local effectiveHatchTime = eggInfo.hatchTime / (1 + boost)
	local startProgress = math.clamp(initialProgress or 0, 0, 1)
	local startElapsed = effectiveHatchTime * startProgress

	-- 머리 위 타이머 BillboardGui 부착
	local timerLabel: TextLabel? = nil
	if data.model and data.model.Parent then
		local target = data.model
		if target:IsA("Model") and target.PrimaryPart then
			target = target.PrimaryPart
		end
		timerLabel = EggManager._createHatchBillboard(target)
		timerLabel.Text = formatTime(math.max(0, effectiveHatchTime - startElapsed))
	end

	task.spawn(function()
		local elapsed = startElapsed
		while elapsed < effectiveHatchTime do
			task.wait(1)
			elapsed = elapsed + 1

			-- 모델이 제거됐으면 중단
			if not data.model or not data.model.Parent then return end
			if not _placedEggs[player] or not _placedEggs[player][eggId] then return end

			-- 진행도 업데이트
			data.model:SetAttribute("HatchProgress", elapsed / effectiveHatchTime)

			if timerLabel and timerLabel.Parent then
				timerLabel.Text = formatTime(effectiveHatchTime - elapsed)
			end
		end

		-- hatched
		if data.model and data.model.Parent then
			data.model:SetAttribute("HatchProgress", 1)
			data.model:SetAttribute("ReadyToHatch", true)
			if timerLabel and timerLabel.Parent then
				timerLabel.Text = "Ready! [E]"
				timerLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
			end

			-- ReadyToHatch 시 ProximityPrompt 부착
			local promptParent = data.model
			if promptParent and not promptParent:FindFirstChildWhichIsA("ProximityPrompt") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "HatchPrompt"
				prompt.ActionText = "Hatch"
				prompt.ObjectText = data.eggType
				prompt.MaxActivationDistance = 10
				prompt.HoldDuration = 0
				prompt.RequiresLineOfSight = false
				prompt.Parent = promptParent
				prompt.Triggered:Connect(function(triggerPlayer)
					if triggerPlayer ~= player then return end
					if _onHatchTrigger then
						_onHatchTrigger(player, eggId)
					else
						EggManager.hatchEgg(player, eggId)
					end
				end)
			end

			print(player.Name .. " - egg ready to hatch: " .. data.eggType)
		end
	end)
end

----------------------------------------------------------------
-- 부화 실행 (플레이어 상호작용)
----------------------------------------------------------------
function EggManager.hatchEgg(player: Player, eggId: string): (boolean, string, { any }?)
	local placed = _placedEggs[player]
	if not placed or not placed[eggId] then return false, "Egg not found", nil end

	local data = placed[eggId]
	local model = data.model

	-- hatched 확인
	if not model or not model.Parent then return false, "No egg", nil end
	if not model:GetAttribute("ReadyToHatch") then return false, "Still hatching", nil end

	local eggInfo = EggCfg.EGGS[data.eggType]
	if not eggInfo then return false, "Egg info not found", nil end

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

	-- 선천적 돌연변이 확인 (프리미엄 레전더리 알은 확률 10배)
	local mutations = {}
	local mutMultiplier = 1
	if data.eggType == "Egg_Legendary" then
		mutMultiplier = EggCfg.PREMIUM_MUTATION_MULTIPLIER or 1
	end
	for mutType, chance in EggCfg.MUTATION_CHANCE do
		local effectiveChance = chance * mutMultiplier
		if effectiveChance > 0 and math.random() < effectiveChance then
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

	-- 알 위치 캡처 (이펙트용)
	local hatchPos: Vector3? = nil
	if model and model:IsA("BasePart") then
		hatchPos = model.Position
	elseif model and model:IsA("Model") then
		hatchPos = model:GetPivot().Position
	end

	-- 알 제거
	if model.Parent then
		local parent = model.Parent
		if parent:IsA("Model") then
			if not hatchPos then hatchPos = parent:GetPivot().Position end
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
		hatchPos = hatchPos,
	}

	print(player.Name .. " - hatched! " .. selectedPet.petName .. " (" .. selectedPet.rarity .. ")")
	return true, "hatched", result
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

-- 저장 데이터: 인벤토리 + 배치된 알 (BuildZone 기준 상대 CFrame + 부화 진행도)
function EggManager.getSaveData(player: Player): any
	local placedSave = {}
	local plot = EggManager._getPlayerPlot(player)
	local buildZone = plot and plot:FindFirstChild("BuildZone", true)
	local placed = _placedEggs[player]
	if placed then
		for _, data in placed do
			local model = data.eggModel or data.model
			if model and model.Parent then
				local cf: CFrame
				if model:IsA("Model") then
					cf = model:GetPivot()
				elseif model:IsA("BasePart") then
					cf = model.CFrame
				end
				if cf then
					local saveCF = if buildZone then buildZone.CFrame:ToObjectSpace(cf) else cf
					local progress = 0
					if data.model and data.model.Parent then
						progress = data.model:GetAttribute("HatchProgress") or 0
					end
					table.insert(placedSave, {
						eggType = data.eggType,
						cframe = { saveCF:GetComponents() },
						progress = progress,
					})
				end
			end
		end
	end

	return {
		inventory = EggManager.getEggInventory(player),
		placed = placedSave,
	}
end

-- PlotManager가 플롯 배정/건물 복원 후 호출. _pendingPlacedEggs를 소비해 알을 다시 스폰.
function EggManager.restorePlacedEggs(player: Player)
	local pending = _pendingPlacedEggs[player]
	_pendingPlacedEggs[player] = nil
	if not pending or #pending == 0 then return end

	local plot = EggManager._getPlayerPlot(player)
	local buildZone = plot and plot:FindFirstChild("BuildZone", true)

	for _, eggData in pending do
		local eggType = eggData.eggType
		if not eggType then continue end
		local eggInfo = EggCfg.EGGS[eggType]
		if not eggInfo then continue end

		local cf
		if eggData.cframe and #eggData.cframe >= 12 then
			local savedCF = CFrame.new(unpack(eggData.cframe))
			cf = if buildZone then buildZone.CFrame:ToWorldSpace(savedCF) else savedCF
		end
		if not cf then continue end

		local eggId = _spawnPlacedEgg(player, eggType, nil, cf)
		if not eggId then continue end

		local progress = math.clamp(eggData.progress or 0, 0, 1)
		EggManager._startHatchTimer(player, eggId, progress)

		print(player.Name .. " - egg restored: " .. eggType .. " (progress " .. math.floor(progress * 100) .. "%)")
	end
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
