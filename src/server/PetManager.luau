-- PetManager.luau
-- 펫 관리: 초기화, 조회, 배치, 회수, 배회 AI (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local PetCfg = BalanceConfig.Pet

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local petUpdateEvent = remotes:WaitForChild("PetUpdate")
local petsFolder = ReplicatedStorage:WaitForChild("Pets")

local PetManager = {}

-- 플레이어별 펫 데이터 { [Player]: { [petId]: petData } }
-- petData = { petId, petName, petType, rarity, assignedBuildingId, model }
local _playerPets = {}

-- 배회 루프 활성 상태 { [petId]: true }
local _wanderLoops = {}

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

	return pet
end

----------------------------------------------------------------
-- 플레이어 초기화 (저장된 데이터가 있으면 복원)
----------------------------------------------------------------
function PetManager.initPlayer(player: Player, savedPets: { any }?)
	_playerPets[player] = {}

	if savedPets and #savedPets > 0 then
		-- 저장된 펫 복원
		for _, savedPet in savedPets do
			local petId = savedPet.petId or HttpService:GenerateGUID(false)
			local petData = {
				petId = petId,
				petName = savedPet.petName or "???",
				petType = savedPet.petType or "Construction",
				rarity = savedPet.rarity or "일반",
				ownerId = player.UserId,
				assignedBuildingId = "", -- 접속 시 배치 해제 (건물 복원 후 재배치 필요)
				model = nil,
			}
			_playerPets[player][petId] = petData
		end
	else
		-- 기본 펫 지급
		for _, defaultPet in PetCfg.DEFAULT_PETS do
			local petId = HttpService:GenerateGUID(false)
			local petData = {
				petId = petId,
				petName = defaultPet.petName,
				petType = defaultPet.petType,
				rarity = defaultPet.rarity,
				ownerId = player.UserId,
				assignedBuildingId = "",
				model = nil,
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

			-- 배회 시작 (건물에 배치되지 않은 펫만)
			if petData.assignedBuildingId == "" then
				PetManager._startWander(petData, buildZone)
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
		table.insert(result, {
			petId = petData.petId,
			petName = petData.petName,
			petType = petData.petType,
			rarity = petData.rarity,
			assignedBuildingId = petData.assignedBuildingId,
		})
	end
	return result
end

----------------------------------------------------------------
-- 펫 배치 (건물에 할당)
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

	-- 배치
	petData.assignedBuildingId = buildingId
	building:SetAttribute("AssignedPetId", petId)

	-- 배회 중단
	_wanderLoops[petId] = nil

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

	-- 배회 재개
	if plot then
		local buildZone = plot:FindFirstChild("BuildZone", true)
		if buildZone then
			PetManager._startWander(petData, buildZone)
		end
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
-- 업그레이드 완료 시 펫 자동 해제
----------------------------------------------------------------
function PetManager.onUpgradeComplete(player: Player, petId: string)
	if petId == "" then return end
	PetManager.unassignPet(player, petId)
end

----------------------------------------------------------------
-- 배회 AI
----------------------------------------------------------------
function PetManager._startWander(petData, buildZone: BasePart)
	local petId = petData.petId
	if _wanderLoops[petId] then return end
	_wanderLoops[petId] = true

	task.spawn(function()
		while _wanderLoops[petId] do
			task.wait(PetCfg.WANDER_INTERVAL + math.random() * 2)

			if not _wanderLoops[petId] then break end

			local model = petData.model
			if not model or not model.Parent then
				_wanderLoops[petId] = nil
				break
			end

			-- 랜덤 목표 위치 (BuildZone 내)
			local center = buildZone.Position
			local halfSize = buildZone.Size / 2
			local targetX = center.X + (math.random() * 2 - 1) * math.min(halfSize.X, PetCfg.WANDER_RADIUS)
			local targetZ = center.Z + (math.random() * 2 - 1) * math.min(halfSize.Z, PetCfg.WANDER_RADIUS)
			local targetPos = Vector3.new(targetX, center.Y + PetCfg.PET_HEIGHT, targetZ)

			-- 부드럽게 이동
			local startPos = model.Position
			local distance = (targetPos - startPos).Magnitude
			local duration = distance / PetCfg.WANDER_SPEED

			if duration < 0.1 then continue end

			local elapsed = 0
			while elapsed < duration and _wanderLoops[petId] do
				local dt = task.wait()
				elapsed = elapsed + dt
				local alpha = math.min(1, elapsed / duration)
				model.Position = startPos:Lerp(targetPos, alpha)
			end
		end
	end)
end

----------------------------------------------------------------
-- 저장용 데이터 반환
----------------------------------------------------------------
function PetManager.getSaveData(player: Player): { any }
	local pets = _playerPets[player]
	if not pets then return {} end

	local result = {}
	for _, petData in pets do
		table.insert(result, {
			petId = petData.petId,
			petName = petData.petName,
			petType = petData.petType,
			rarity = petData.rarity,
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
			_wanderLoops[petId] = nil
			if petData.model and petData.model.Parent then
				petData.model:Destroy()
			end
		end
	end
	_playerPets[player] = nil
end

return PetManager
