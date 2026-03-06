-- PetManager.luau
-- 펫 관리: 초기화, 조회, 배치, 회수, 행동 AI 상태머신 (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local TimeState = require(ServerScriptService:WaitForChild("Server"):WaitForChild("TimeState"))

local PetCfg = BalanceConfig.Pet
local WeatherCfg = BalanceConfig.Weather

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local petUpdateEvent = remotes:WaitForChild("PetUpdate")
local petsFolder = ReplicatedStorage:WaitForChild("Pets")

local PetManager = {}

-- 플레이어별 펫 데이터 { [Player]: { [petId]: petData } }
local _playerPets = {}

-- 행동 루프 활성 상태 { [petId]: true }
local _behaviorLoops = {}

-- 일터 점유 관리 { [buildingId]: { petId1, ... } }
local _workplaceOccupancy = {}

----------------------------------------------------------------
-- 유틸리티
----------------------------------------------------------------

local function getPlayerPlot(player: Player)
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == player.Name then
			return plot
		end
	end
	return nil
end

local function findBuildingById(plot, buildingId: string): BasePart?
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") == buildingId then
			return child
		end
	end
	return nil
end

local function getAllBuildings(plot): { BasePart }
	local buildings = {}
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") ~= nil then
			table.insert(buildings, child)
		end
	end
	return buildings
end

local function getPlayerFromPetData(petData): Player?
	for player, pets in _playerPets do
		if pets[petData.petId] then
			return player
		end
	end
	return nil
end

----------------------------------------------------------------
-- 펫 상태 변경 (Attribute + 클라이언트 알림)
----------------------------------------------------------------
local function setPetState(petData, newState: string)
	petData.state = newState
	if petData.model and petData.model.Parent then
		petData.model:SetAttribute("PetState", newState)
	end
	local player = getPlayerFromPetData(petData)
	if player then
		petUpdateEvent:FireClient(player, "stateChanged", {
			petId = petData.petId,
			state = newState,
		})
	end
end

----------------------------------------------------------------
-- 펫 모델 생성
----------------------------------------------------------------
local function createPetModel(petData, position: Vector3): BasePart
	local template = petsFolder:FindFirstChild("ConstructionPet")
	local pet
	if template then
		pet = template:Clone()
	else
		pet = Instance.new("Part")
		pet.Size = PetCfg.PET_SIZE
		pet.Material = PetCfg.PET_MATERIAL
		pet.Shape = Enum.PartType.Ball
	end

	pet.Name = "Pet_" .. petData.petId
	pet.Anchored = true
	pet.CanCollide = false
	pet.CanQuery = false
	pet.CanTouch = false
	pet.Position = position + Vector3.new(0, PetCfg.PET_HEIGHT, 0)

	-- 무게 배율에 따른 크기 조정
	local scale = math.clamp(petData.weightMult or 1.0, 0.7, 2.0)
	pet.Size = PetCfg.PET_SIZE * scale

	-- 등급별 색상
	local rarityColor = PetCfg.RARITY_COLORS[petData.rarity]
	if rarityColor then
		pet.Color = rarityColor
	end

	-- 속성 설정
	pet:SetAttribute("PetId", petData.petId)
	pet:SetAttribute("PetName", petData.petName)
	pet:SetAttribute("PetType", petData.petType)
	pet:SetAttribute("PetRarity", petData.rarity)
	pet:SetAttribute("OwnerId", petData.ownerId)
	pet:SetAttribute("AssignedBuildingId", petData.assignedBuildingId or "")
	pet:SetAttribute("PetState", petData.state or "Idle")
	pet:SetAttribute("PetLevel", petData.level or 1)
	pet:SetAttribute("PetWeight", petData.weight or 5)
	pet:SetAttribute("PetSize", petData.size or "Small")
	pet:SetAttribute("PetRace", petData.race or "인간")

	return pet
end

----------------------------------------------------------------
-- 부드러운 이동 (목표 위치로)
----------------------------------------------------------------
local function movePetTo(petData, targetPos: Vector3): boolean
	local model = petData.model
	if not model or not model.Parent then return false end

	local startPos = model.Position
	local distance = (targetPos - startPos).Magnitude
	local duration = distance / PetCfg.MOVE_SPEED

	if duration < 0.1 then
		model.Position = targetPos
		return true
	end

	local elapsed = 0
	while elapsed < duration and _behaviorLoops[petData.petId] do
		local dt = task.wait()
		elapsed = elapsed + dt
		local alpha = math.min(1, elapsed / duration)
		if model.Parent then
			model.Position = startPos:Lerp(targetPos, alpha)
		else
			return false
		end
	end
	return _behaviorLoops[petData.petId] ~= nil
end

----------------------------------------------------------------
-- 일터 탐색 (petType과 building.workTypes 매칭)
----------------------------------------------------------------
local function findWorkplace(plot, petData): BasePart?
	local buildings = getAllBuildings(plot)
	local petTypeKor = Constants.PetType[petData.petType]
	if not petTypeKor then return nil end

	local candidates = {}

	for _, building in buildings do
		local itemName = building:GetAttribute("ItemName")
		if not itemName then continue end

		local buildingInfo = Constants.BUILDINGS[itemName]
		if not buildingInfo or not buildingInfo.workTypes then continue end

		-- petType 매칭 확인
		local canWork = false
		for _, wt in buildingInfo.workTypes do
			if wt == petTypeKor then
				canWork = true
				break
			end
		end
		if not canWork then continue end

		-- 점유 확인 (일터당 최대 1마리)
		local buildingId = building:GetAttribute("BuildingId")
		local occupants = _workplaceOccupancy[buildingId]
		if occupants and #occupants >= 1 then continue end

		table.insert(candidates, building)
	end

	if #candidates == 0 then return nil end

	-- 이전 일터 선호
	if petData.previousWorkId ~= "" and math.random() < PetCfg.PREV_WORK_PREFERENCE then
		for _, b in candidates do
			if b:GetAttribute("BuildingId") == petData.previousWorkId then
				return b
			end
		end
	end

	return candidates[math.random(#candidates)]
end

----------------------------------------------------------------
-- 쉼터 탐색
----------------------------------------------------------------
local function findRestPlace(plot): BasePart?
	local buildings = getAllBuildings(plot)
	local candidates = {}

	for _, building in buildings do
		local itemName = building:GetAttribute("ItemName")
		if not itemName then continue end

		local buildingInfo = Constants.BUILDINGS[itemName]
		if not buildingInfo then continue end

		-- 쉼터 유형 체크
		local isRest = false
		for _, t in buildingInfo.types do
			if t == "쉼터" then
				isRest = true
				break
			end
		end
		if isRest then
			table.insert(candidates, building)
		end
	end

	if #candidates == 0 then return nil end
	return candidates[math.random(#candidates)]
end

----------------------------------------------------------------
-- 일터 점유 등록/해제
----------------------------------------------------------------
local function occupyWorkplace(buildingId: string, petId: string)
	if not _workplaceOccupancy[buildingId] then
		_workplaceOccupancy[buildingId] = {}
	end
	table.insert(_workplaceOccupancy[buildingId], petId)
end

local function vacateWorkplace(buildingId: string, petId: string)
	local occupants = _workplaceOccupancy[buildingId]
	if not occupants then return end
	for i, id in occupants do
		if id == petId then
			table.remove(occupants, i)
			break
		end
	end
	if #occupants == 0 then
		_workplaceOccupancy[buildingId] = nil
	end
end

----------------------------------------------------------------
-- 산책 중 대화 상대 탐색
----------------------------------------------------------------
local function findChatPartner(petData, plot): { any }?
	if not petData.model or not petData.model.Parent then return nil end
	local myPos = petData.model.Position

	-- 같은 플롯의 모든 펫 중 산책(Wandering) 상태인 펫 탐색
	local player = getPlayerFromPetData(petData)
	if not player then return nil end
	local pets = _playerPets[player]
	if not pets then return nil end

	for _, otherPet in pets do
		if otherPet.petId == petData.petId then continue end
		if otherPet.state ~= "Wandering" then continue end
		if not otherPet.model or not otherPet.model.Parent then continue end

		local dist = (otherPet.model.Position - myPos).Magnitude
		if dist <= PetCfg.CHAT_DISTANCE then
			return otherPet
		end
	end

	return nil
end

----------------------------------------------------------------
-- 배회 (산책 모드)
----------------------------------------------------------------
local function doWander(petData, buildZone: BasePart, duration: number)
	local elapsed = 0
	while elapsed < duration and _behaviorLoops[petData.petId] do
		-- 랜덤 목표
		local center = buildZone.Position
		local halfSize = buildZone.Size / 2
		local targetX = center.X + (math.random() * 2 - 1) * math.min(halfSize.X, PetCfg.WANDER_RADIUS)
		local targetZ = center.Z + (math.random() * 2 - 1) * math.min(halfSize.Z, PetCfg.WANDER_RADIUS)
		local targetPos = Vector3.new(targetX, center.Y + PetCfg.PET_HEIGHT, targetZ)

		movePetTo(petData, targetPos)
		if not _behaviorLoops[petData.petId] then break end

		-- 대화 상대 탐색
		local plot = buildZone.Parent
		if plot then
			local partner = findChatPartner(petData, plot)
			if partner then
				setPetState(petData, "Chatting")
				setPetState(partner, "Chatting")
				task.wait(PetCfg.CHAT_DURATION)
				if _behaviorLoops[petData.petId] then
					setPetState(petData, "Wandering")
				end
				if _behaviorLoops[partner.petId] then
					setPetState(partner, "Wandering")
				end
				elapsed = elapsed + PetCfg.CHAT_DURATION
			end
		end

		local waitTime = PetCfg.WANDER_INTERVAL + math.random() * 2
		task.wait(waitTime)
		elapsed = elapsed + waitTime
	end
end

----------------------------------------------------------------
-- 행동 AI 상태머신
----------------------------------------------------------------
function PetManager._startBehaviorLoop(player: Player, petData, plot)
	local petId = petData.petId
	if _behaviorLoops[petId] then return end
	_behaviorLoops[petId] = true

	local buildZone = plot:FindFirstChild("BuildZone", true)
	if not buildZone then
		_behaviorLoops[petId] = nil
		return
	end

	task.spawn(function()
		-- XP 업데이트 타이머
		local xpUpdateTimer = 0

		while _behaviorLoops[petId] do
			if not petData.model or not petData.model.Parent then
				_behaviorLoops[petId] = nil
				break
			end

			-- 불면 특성 체크
			local hasSleepless = false
			if petData.traits then
				for _, trait in petData.traits do
					if trait == "불면" then
						hasSleepless = true
						break
					end
				end
			end

			-- 밤이고 불면 아닌 경우 → 수면
			if not TimeState.isDay() and not hasSleepless then
				setPetState(petData, "Sleeping")

				-- 쉼터로 이동 (있으면)
				local restPlace = findRestPlace(plot)
				if restPlace then
					local targetPos = restPlace.Position + Vector3.new(
						(math.random() * 2 - 1) * 2,
						PetCfg.PET_HEIGHT,
						(math.random() * 2 - 1) * 2
					)
					movePetTo(petData, targetPos)
				end

				-- 아침까지 대기
				while not TimeState.isDay() and _behaviorLoops[petId] do
					task.wait(1)
				end

				if not _behaviorLoops[petId] then break end
				continue
			end

			-- 1. 일터 탐색
			local workplace = findWorkplace(plot, petData)

			if workplace then
				local buildingId = workplace:GetAttribute("BuildingId")

				-- 일터로 이동
				local targetPos = workplace.Position + Vector3.new(
					(math.random() * 2 - 1) * 2,
					PetCfg.PET_HEIGHT,
					(math.random() * 2 - 1) * 2
				)

				if not movePetTo(petData, targetPos) then break end
				if not _behaviorLoops[petId] then break end

				-- 2. 작업 시작
				occupyWorkplace(buildingId, petId)
				petData.targetBuildingId = buildingId
				petData.previousWorkId = buildingId
				setPetState(petData, "Working")

				local workDuration = PetCfg.WORK_DURATION_MIN
					+ math.random() * (PetCfg.WORK_DURATION_MAX - PetCfg.WORK_DURATION_MIN)
				local workElapsed = 0
				xpUpdateTimer = 0

				while workElapsed < workDuration and _behaviorLoops[petId] do
					task.wait(1)
					workElapsed = workElapsed + 1

					-- 밤 전환 체크 (불면 아니면 중단)
					if not TimeState.isDay() and not hasSleepless then
						break
					end

					-- XP 획득
					petData.xp = petData.xp + PetCfg.XP_PER_SECOND
					local required = PetCfg.XP_REQUIRED[petData.level]
					if required and petData.xp >= required and petData.level < PetCfg.MAX_LEVEL then
						petData.level = petData.level + 1
						petData.xp = 0
						if petData.model and petData.model.Parent then
							petData.model:SetAttribute("PetLevel", petData.level)
						end
						petUpdateEvent:FireClient(player, "levelup", {
							petId = petId,
							newLevel = petData.level,
						})
					end

					-- XP 주기적 업데이트 (10초마다)
					xpUpdateTimer = xpUpdateTimer + 1
					if xpUpdateTimer >= 10 then
						xpUpdateTimer = 0
						petUpdateEvent:FireClient(player, "xpUpdate", {
							petId = petId,
							xp = petData.xp,
							level = petData.level,
						})
					end
				end

				-- 작업 종료 → 점유 해제
				vacateWorkplace(buildingId, petId)
				petData.targetBuildingId = ""

				if not _behaviorLoops[petId] then break end

				-- 밤 전환 시 수면으로 돌아감
				if not TimeState.isDay() and not hasSleepless then
					continue
				end

				-- 3. 피로 상태
				setPetState(petData, "Fatigued")
				task.wait(PetCfg.FATIGUE_DURATION)
				if not _behaviorLoops[petId] then break end

				-- 4. 휴식 또는 산책
				local restDuration = PetCfg.REST_DURATION_MIN
					+ math.random() * (PetCfg.REST_DURATION_MAX - PetCfg.REST_DURATION_MIN)

				local doWalk = math.random() < PetCfg.WALK_CHANCE
				local restPlace = nil
				if not doWalk then
					restPlace = findRestPlace(plot)
				end

				if restPlace then
					-- 쉼터 이동 → 휴식
					local restPos = restPlace.Position + Vector3.new(
						(math.random() * 2 - 1) * 2,
						PetCfg.PET_HEIGHT,
						(math.random() * 2 - 1) * 2
					)
					if not movePetTo(petData, restPos) then break end
					if not _behaviorLoops[petId] then break end

					setPetState(petData, "Resting")
					task.wait(restDuration)
				else
					-- 산책
					setPetState(petData, "Wandering")
					doWander(petData, buildZone, restDuration)
				end
			else
				-- 일터 없음 → 산책
				setPetState(petData, "Wandering")
				local wanderDuration = PetCfg.REST_DURATION_MIN
					+ math.random() * (PetCfg.REST_DURATION_MAX - PetCfg.REST_DURATION_MIN)
				doWander(petData, buildZone, wanderDuration)
			end

			if not _behaviorLoops[petId] then break end
			task.wait(1) -- 루프 간 짧은 대기
		end
	end)
end

----------------------------------------------------------------
-- 효율 계산
----------------------------------------------------------------
function PetManager.getEfficiency(petData): number
	local base = 1.0
	base = base * (PetCfg.LEVEL_EFFICIENCY[petData.level] or 1.0)
	base = base * (1 + (petData.weightMult or 1.0)) / 2
	base = base * (PetCfg.RARITY_MULTIPLIER[petData.rarity] or 1.0)
	base = base * (PetCfg.TYPE_MULTIPLIER[petData.petType] or 1.0)

	-- mutations 보너스
	if petData.mutations then
		for mut, _ in petData.mutations do
			local bonus = WeatherCfg.MUTATION_SPEED_BONUS[mut]
			if bonus then
				base = base * (1 + bonus)
			end
		end
	end

	return base
end

----------------------------------------------------------------
-- 플레이어 초기화 (저장된 데이터가 있으면 복원)
----------------------------------------------------------------
function PetManager.initPlayer(player: Player, savedPets: { any }?)
	-- 기존 펫 모델 제거 (리셋 시 월드에 남아있는 모델 정리)
	local existingPets = _playerPets[player]
	if existingPets then
		for petId, petData in existingPets do
			_behaviorLoops[petId] = nil
			if petData.targetBuildingId and petData.targetBuildingId ~= "" then
				vacateWorkplace(petData.targetBuildingId, petId)
			end
			if petData.model and petData.model.Parent then
				petData.model:Destroy()
			end
		end
	end

	_playerPets[player] = {}

	if savedPets and #savedPets > 0 then
		-- 저장된 펫 복원
		for _, savedPet in savedPets do
			local petId = savedPet.petId or HttpService:GenerateGUID(false)
			local restoredMutations = {}
			if savedPet.mutations then
				for _, m in savedPet.mutations do
					restoredMutations[m] = true
				end
			end

			local size = savedPet.size or "Small"
			local stdWeight = PetCfg.SIZE_STANDARD_WEIGHT[size] or 5
			local weightMult = savedPet.weightMult
			if not weightMult then
				weightMult = PetCfg.WEIGHT_MIN_MULT + math.random() * (PetCfg.WEIGHT_MAX_MULT - PetCfg.WEIGHT_MIN_MULT)
			end

			local petData = {
				petId = petId,
				petName = savedPet.petName or "???",
				petType = savedPet.petType or "Construction",
				rarity = savedPet.rarity or "일반",
				ownerId = player.UserId,
				assignedBuildingId = "",
				model = nil,
				mutations = restoredMutations,
				-- 신규 필드
				size = size,
				race = savedPet.race or "인간",
				traits = savedPet.traits or {},
				weight = savedPet.weight or (stdWeight * weightMult),
				weightMult = weightMult,
				level = savedPet.level or 1,
				xp = savedPet.xp or 0,
				state = "Idle",
				targetBuildingId = "",
				previousWorkId = "",
			}
			_playerPets[player][petId] = petData
		end
	else
		-- 기본 펫 지급
		for _, defaultPet in PetCfg.DEFAULT_PETS do
			local petId = HttpService:GenerateGUID(false)
			local size = defaultPet.size or "Small"
			local stdWeight = PetCfg.SIZE_STANDARD_WEIGHT[size] or 5
			local weightMult = PetCfg.WEIGHT_MIN_MULT + math.random() * (PetCfg.WEIGHT_MAX_MULT - PetCfg.WEIGHT_MIN_MULT)

			local petData = {
				petId = petId,
				petName = defaultPet.petName,
				petType = defaultPet.petType,
				rarity = defaultPet.rarity,
				ownerId = player.UserId,
				assignedBuildingId = "",
				model = nil,
				mutations = {},
				size = size,
				race = defaultPet.race or "인간",
				traits = defaultPet.traits or {},
				weight = stdWeight * weightMult,
				weightMult = weightMult,
				level = 1,
				xp = 0,
				state = "Idle",
				targetBuildingId = "",
				previousWorkId = "",
			}
			_playerPets[player][petId] = petData
		end
	end

	-- 펫 모델 스폰 (플롯이 배정된 뒤)
	task.spawn(function()
		task.wait(1) -- 플롯 배정 대기
		PetManager._spawnAllPets(player)
	end)
end

----------------------------------------------------------------
-- 펫 모델 스폰 (플롯 위)
----------------------------------------------------------------
function PetManager._spawnAllPets(player: Player)
	local plot = getPlayerPlot(player)
	if not plot then return end

	local buildZone = plot:FindFirstChild("BuildZone", true)
	if not buildZone then return end

	local pets = _playerPets[player]
	if not pets then return end

	for petId, petData in pets do
		if not petData.model or not petData.model.Parent then
			local pet = createPetModel(petData, buildZone.Position)
			pet.Parent = plot
			petData.model = pet

			-- 건물에 배치되지 않은 펫은 행동 AI 시작
			if petData.assignedBuildingId == "" then
				PetManager._startBehaviorLoop(player, petData, plot)
			end
		end
	end
end

----------------------------------------------------------------
-- 펫 목록 조회
----------------------------------------------------------------
function PetManager.getPets(player: Player): { any }
	local pets = _playerPets[player]
	if not pets then return {} end

	local result = {}
	for _, petData in pets do
		-- mutations를 배열로 변환
		local mutationsList = {}
		if petData.mutations then
			for mutationType, _ in petData.mutations do
				table.insert(mutationsList, mutationType)
			end
		end
		table.insert(result, {
			petId = petData.petId,
			petName = petData.petName,
			petType = petData.petType,
			rarity = petData.rarity,
			assignedBuildingId = petData.assignedBuildingId,
			size = petData.size,
			race = petData.race,
			traits = petData.traits,
			weight = petData.weight,
			level = petData.level,
			xp = petData.xp,
			state = petData.state,
			mutations = mutationsList,
		})
	end
	return result
end

----------------------------------------------------------------
-- 펫 배치 (건물에 할당 — 업그레이드용)
----------------------------------------------------------------
function PetManager.assignPet(player: Player, petId: string, buildingId: string): (boolean, string?)
	local pets = _playerPets[player]
	if not pets or not pets[petId] then
		return false, "펫을 찾을 수 없음"
	end

	local petData = pets[petId]

	-- 이미 다른 건물에 배치된 경우
	if petData.assignedBuildingId ~= "" then
		return false, "이미 배치된 펫"
	end

	-- 건물 확인
	local plot = getPlayerPlot(player)
	if not plot then return false, "플롯 없음" end

	local building = findBuildingById(plot, buildingId)
	if not building then return false, "건물 찾을 수 없음" end

	-- 건물이 수리중인지 확인
	local state = building:GetAttribute("UpgradeState") or ""
	if state ~= Constants.UpgradeState.Upgrading then
		return false, "수리중이 아닌 건물"
	end

	-- 이미 다른 펫이 배치된 경우
	local existingPetId = building:GetAttribute("AssignedPetId") or ""
	if existingPetId ~= "" then
		return false, "이미 펫이 배치된 건물"
	end

	-- 행동 루프 중단
	_behaviorLoops[petId] = nil
	if petData.targetBuildingId and petData.targetBuildingId ~= "" then
		vacateWorkplace(petData.targetBuildingId, petId)
		petData.targetBuildingId = ""
	end

	-- 배치
	petData.assignedBuildingId = buildingId
	building:SetAttribute("AssignedPetId", petId)
	setPetState(petData, "Assigned")

	-- 펫 모델을 건물 옆으로 이동
	if petData.model and petData.model.Parent then
		local targetPos = building.Position + Vector3.new(building.Size.X / 2 + 1.5, PetCfg.PET_HEIGHT, 0)
		petData.model.Position = targetPos
		petData.model:SetAttribute("AssignedBuildingId", buildingId)
	end

	-- 클라이언트 알림
	petUpdateEvent:FireClient(player, "assigned", {
		petId = petId,
		buildingId = buildingId,
	})

	print(player.Name .. " - 펫 '" .. petData.petName .. "' → 건물 " .. buildingId .. " 배치")
	return true
end

----------------------------------------------------------------
-- 펫 회수 (건물에서 해제)
----------------------------------------------------------------
function PetManager.unassignPet(player: Player, petId: string): (boolean, string?)
	local pets = _playerPets[player]
	if not pets or not pets[petId] then
		return false, "펫을 찾을 수 없음"
	end

	local petData = pets[petId]
	if petData.assignedBuildingId == "" then
		return false, "배치되지 않은 펫"
	end

	local buildingId = petData.assignedBuildingId

	-- 건물에서 펫 해제
	local plot = getPlayerPlot(player)
	if plot then
		local building = findBuildingById(plot, buildingId)
		if building then
			building:SetAttribute("AssignedPetId", "")
		end
	end

	-- 펫 데이터 업데이트
	petData.assignedBuildingId = ""

	-- 펫 모델 속성 업데이트
	if petData.model and petData.model.Parent then
		petData.model:SetAttribute("AssignedBuildingId", "")
	end

	-- 행동 AI 재개
	if plot then
		PetManager._startBehaviorLoop(player, petData, plot)
	end

	-- 클라이언트 알림
	petUpdateEvent:FireClient(player, "unassigned", {
		petId = petId,
		buildingId = buildingId,
	})

	print(player.Name .. " - 펫 '" .. petData.petName .. "' 회수")
	return true
end

----------------------------------------------------------------
-- 돌연변이 관리
----------------------------------------------------------------
function PetManager.addMutation(player: Player, petId: string, mutationType: string): boolean
	local pets = _playerPets[player]
	if not pets or not pets[petId] then return false end

	local petData = pets[petId]
	if not petData.mutations then
		petData.mutations = {}
	end
	if petData.mutations[mutationType] then return false end -- 이미 보유

	petData.mutations[mutationType] = true
	print(player.Name .. " - 펫 '" .. petData.petName .. "' 돌연변이 획득: " .. mutationType)

	-- 클라이언트 알림
	petUpdateEvent:FireClient(player, "mutation", {
		petId = petId,
		mutationType = mutationType,
	})
	return true
end

function PetManager.hasMutation(player: Player, petId: string, mutationType: string): boolean
	local pets = _playerPets[player]
	if not pets or not pets[petId] then return false end
	local petData = pets[petId]
	if not petData.mutations then return false end
	return petData.mutations[mutationType] == true
end

function PetManager.getPetData(player: Player, petId: string): { any }?
	local pets = _playerPets[player]
	if not pets then return nil end
	return pets[petId]
end

----------------------------------------------------------------
-- 업그레이드 완료 시 펫 자동 해제
----------------------------------------------------------------
function PetManager.onUpgradeComplete(player: Player, petId: string)
	if petId == "" then return end
	PetManager.unassignPet(player, petId)
end

----------------------------------------------------------------
-- 저장용 데이터 반환
----------------------------------------------------------------
function PetManager.getSaveData(player: Player): { any }
	local pets = _playerPets[player]
	if not pets then return {} end

	local result = {}
	for _, petData in pets do
		-- mutations를 배열로 변환 (저장용)
		local mutationsList = {}
		if petData.mutations then
			for mutationType, _ in petData.mutations do
				table.insert(mutationsList, mutationType)
			end
		end
		table.insert(result, {
			petId = petData.petId,
			petName = petData.petName,
			petType = petData.petType,
			rarity = petData.rarity,
			mutations = mutationsList,
			size = petData.size,
			race = petData.race,
			traits = petData.traits,
			weight = petData.weight,
			weightMult = petData.weightMult,
			level = petData.level,
			xp = petData.xp,
		})
	end
	return result
end

----------------------------------------------------------------
-- 정리
----------------------------------------------------------------
function PetManager.removePlayer(player: Player)
	local pets = _playerPets[player]
	if pets then
		for petId, petData in pets do
			_behaviorLoops[petId] = nil
			if petData.targetBuildingId and petData.targetBuildingId ~= "" then
				vacateWorkplace(petData.targetBuildingId, petId)
			end
			if petData.model and petData.model.Parent then
				petData.model:Destroy()
			end
		end
	end
	_playerPets[player] = nil
end

return PetManager
