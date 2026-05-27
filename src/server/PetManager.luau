-- PetManager.luau
-- 펫 관리: 초기화, 조회, 배치, 회수, 행동 AI 상태머신 (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local TimeState = require(ServerScriptService:WaitForChild("Server"):WaitForChild("TimeState"))
local WeatherState = require(ServerScriptService:WaitForChild("Server"):WaitForChild("WeatherState"))
local BuffManager = require(ServerScriptService:WaitForChild("Server"):WaitForChild("BuffManager"))

local PetCfg = BalanceConfig.Pet
local WeatherCfg = BalanceConfig.Weather
local BuffCfg = BalanceConfig.Buff

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local petUpdateEvent = remotes:WaitForChild("PetUpdate")
local petsFolder = ReplicatedStorage:FindFirstChild("Pets")
local serverPetsFolder = game:GetService("ServerStorage"):FindFirstChild("Pets")

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

-- 펫의 활성 버프 중 특정 effect의 합산 % 반환 (예: workEfficiency 10 = +10%)
local function getPetBuffPercent(petData, effectName: string): number
	if not petData or not petData.petId then return 0 end
	local active = BuffManager.getPetActiveBuffs(petData.petId)
	return BuffCfg.computeEffect(active, effectName)
end

----------------------------------------------------------------
-- 펫 상태 → 애니메이션 이름 매핑
-- 모델의 ServerStorage/Pets/{Name}/Animations 폴더 안 Animation 인스턴스 이름과 매칭.
-- 없으면 Idle로 폴백.
----------------------------------------------------------------
-- 애니메이션은 "{petName}_{action}" 형식 (예: Imp_Construction, sunflowie_Plant, IceGolem_idle).
-- 키는 소문자로 정규화하여 대소문자 무시 매칭.
local STATE_TO_ANIM = {
	Idle = "idle",
	Wandering = "move",
	Walking = "move",
	Working = "work",
	Mining = "mine",
	Farming = "plant",
	Construction = "construction",
	Sleeping = "sleep",
	Resting = "rest",
	Chatting = "greeting",
	Fatigued = "idle",
	Assigned = "idle",
	Held = "pet",
	SearchingForWork = "move",
}

-- 액션 폴백 순서 (지정 액션이 없으면 차례로 시도). 모두 소문자.
-- 실제 보유 키 예: idle, move, make, field, pet, greeting (펫별로 일부만 존재).
local ACTION_FALLBACK = {
	mine         = { "mining", "make", "work", "idle" },
	plant        = { "farming", "field", "fields", "make", "work", "idle" },
	construction = { "build", "make", "work", "idle" },
	work         = { "make", "magic", "idle" },
	move         = { "walk", "walking", "run", "idle" },
	sleep        = { "sleeping", "rest", "field", "idle" },
	rest         = { "resting", "field", "idle" },
	greeting     = { "greet", "greetin", "idle" },
	pet          = { "petting", "idle" },
}

local function playAnimationForState(petData, newState: string)
	local tracks = petData._animTracks
	if not tracks then return end
	local action = STATE_TO_ANIM[newState] or "idle"
	-- Working은 펫 타입에 따라 구체 액션으로 치환 (Farming/Mining/Construction)
	if newState == "Working" and petData.petType then
		action = STATE_TO_ANIM[petData.petType] or action
	end
	local target = tracks[action]
	if not target then
		local fallback = ACTION_FALLBACK[action]
		if fallback then
			for _, name in fallback do
				target = tracks[name]
				if target then break end
			end
		end
		target = target or tracks["idle"]
	end
	if not target then return end
	if petData._currentTrack == target then return end
	if petData._currentTrack then
		pcall(function() petData._currentTrack:Stop(0.2) end)
	end
	pcall(function() target:Play(0.2) end)
	petData._currentTrack = target
end

----------------------------------------------------------------
-- 펫 상태 변경 (Attribute + 클라이언트 알림)
----------------------------------------------------------------
local function setPetState(petData, newState: string)
	petData.state = newState
	if petData.model and petData.model.Parent then
		petData.model:SetAttribute("PetState", newState)
	end
	playAnimationForState(petData, newState)
	local player = getPlayerFromPetData(petData)
	if player then
		petUpdateEvent:FireClient(player, "stateChanged", {
			petId = petData.petId,
			state = newState,
		})
	end
end

----------------------------------------------------------------
-- 펫 기준점(피벗/중심)에서 모델 바닥까지 거리 + 설정 높이.
-- PET_HEIGHT=0이면 모델 바닥이 지면에 딱 닿고, 양수면 그만큼 떠오른다.
-- _pivotToBottom은 createPetModel에서 모델 크기에 맞춰 계산해 둔다.
----------------------------------------------------------------
local function petYOffset(petData): number
	return (petData._pivotToBottom or 0) + PetCfg.PET_HEIGHT
end

----------------------------------------------------------------
-- 펫 모델 생성
----------------------------------------------------------------
local function createPetModel(petData, position: Vector3): BasePart
	-- 펫 이름으로 모델 탐색: ServerStorage/Pets > 펫이름 > Model
	local petName = petData.petName
	local template = nil

	-- 1. ServerStorage/Pets에서 찾기
	-- 구조: Pets > {펫이름} > Model(Folder) > {실제Model}
	if not serverPetsFolder then
		serverPetsFolder = game:GetService("ServerStorage"):FindFirstChild("Pets")
			or workspace:FindFirstChild("Pets")
	end
	if serverPetsFolder then
		local petFolder = serverPetsFolder:FindFirstChild(petName)
		if petFolder then
			local modelFolder = petFolder:FindFirstChild("Model")
			if modelFolder and modelFolder:IsA("Folder") then
				-- Folder 안의 실제 Model 찾기
				template = modelFolder:FindFirstChildWhichIsA("Model") or modelFolder:FindFirstChildWhichIsA("BasePart")
			elseif modelFolder and modelFolder:IsA("Model") then
				template = modelFolder
			else
				-- Model 폴더 없으면 직접 탐색
				template = petFolder:FindFirstChildWhichIsA("Model") or petFolder:FindFirstChildWhichIsA("BasePart")
			end
		end
	end

	-- 2. ReplicatedStorage/Pets에서 찾기 (폴백)
	if not template and petsFolder then
		local petFolder = petsFolder:FindFirstChild(petName)
		if petFolder then
			template = petFolder:FindFirstChild("Model") or petFolder:FindFirstChildWhichIsA("Model")
		end
		-- 기존 ConstructionPet 폴백
		if not template then
			template = petsFolder:FindFirstChild("ConstructionPet")
		end
	end

	local pet
	if template then
		pet = template:Clone()
		print("[PetModel] " .. petName .. " → " .. template:GetFullName() .. " (" .. template.ClassName .. ")")
	else
		-- 최종 폴백: 기본 Ball
		warn("[PetModel] " .. petName .. " → FALLBACK (no template found)")
		if serverPetsFolder then
			local pf = serverPetsFolder:FindFirstChild(petName)
			if pf then
				warn("[PetModel] Folder found, children:")
				for _, c in pf:GetChildren() do
					warn("  " .. c.Name .. " (" .. c.ClassName .. ")")
				end
			else
				warn("[PetModel] No folder: " .. petName)
			end
		else
			warn("[PetModel] serverPetsFolder is nil!")
		end
		pet = Instance.new("Part")
		pet.Size = PetCfg.PET_SIZE
		pet.Material = PetCfg.PET_MATERIAL
		pet.Shape = Enum.PartType.Ball
	end

	-- Motor6D 있으면 리그드 모델로 간주 (weld 스킵, 애니메이션이 파츠 위치 구동)
	local hasMotor6D = false
	if pet:IsA("Model") then
		for _, desc in pet:GetDescendants() do
			if desc:IsA("Motor6D") then
				hasMotor6D = true
				break
			end
		end
	end

	-- Model이면 mainPart 찾기 + 모든 파트 weld
	local mainPart
	if pet:IsA("Model") then
		-- 1. 직접 BasePart들로부터 평균 위치 계산 (모델 중심 추정)
		local sum = Vector3.zero
		local count = 0
		local firstPart
		for _, desc in pet:GetDescendants() do
			if desc:IsA("BasePart") then
				sum = sum + desc.Position
				count = count + 1
				if not firstPart then firstPart = desc end
			end
		end

		-- 원본 모델의 PrimaryPart가 있으면 그대로 사용 (디자이너가 설정한 회전 보존)
		if pet.PrimaryPart then
			mainPart = pet.PrimaryPart
		elseif count > 0 then
			-- PrimaryPart 미설정 시에만 바운딩박스 중심에 가까운 파트 자동 선택
			local center = sum / count
			local bestDist = math.huge
			for _, desc in pet:GetDescendants() do
				if desc:IsA("BasePart") then
					local d = (desc.Position - center).Magnitude
					if d < bestDist then
						bestDist = d
						mainPart = desc
					end
				end
			end
			if mainPart then
				pet.PrimaryPart = mainPart
			end
		end

		mainPart = mainPart or firstPart

		if mainPart then
			-- 2. 최종 위치로 이동 (회전은 ServerStorage 템플릿 PrimaryPart 기준 정자세).
			-- 누어있는 모델은 Constants.PET_ORIENTATION_OFFSET[petName]로 보정.
			petData._modelRotation = Constants.getPetOrientationOffset and Constants.getPetOrientationOffset(petName) or CFrame.new()
			-- 회전 먼저 적용 후 바운딩박스로 피벗→바닥 거리 측정 (모델마다 키가 달라 동적 계산).
			pet:PivotTo(CFrame.new(position) * petData._modelRotation)
			local bboxCF, bboxSize = pet:GetBoundingBox()
			petData._pivotToBottom = pet:GetPivot().Position.Y - (bboxCF.Position.Y - bboxSize.Y / 2)
			-- 모델 바닥이 지면(+PET_HEIGHT)에 오도록 최종 배치.
			pet:PivotTo(CFrame.new(position + Vector3.new(0, petYOffset(petData), 0)) * petData._modelRotation)

			-- 3. 모든 파트 weld + Anchored 처리 (리그드면 weld 스킵)
			for _, desc in pet:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.CanCollide = false
					desc.CanQuery = true
					desc.CanTouch = false
					desc.CollisionGroup = "Pets"
					-- HumanoidRootPart는 애니메이션으로 안 움직여서 몸이 움직이면 드러남 → 항상 투명.
					if desc.Name == "HumanoidRootPart" then
						desc.Transparency = 1
					end
					if desc ~= mainPart then
						desc.Anchored = false
						if not hasMotor6D and not desc:FindFirstChildOfClass("WeldConstraint") then
							local weld = Instance.new("WeldConstraint")
							weld.Part0 = mainPart
							weld.Part1 = desc
							weld.Parent = desc
						end
					end
				end
			end
			mainPart.Anchored = true

			mainPart:SetAttribute("PetId", petData.petId)
			pet.Name = "Pet_" .. petData.petId
			petData._petModel = pet
		end
	end

	if pet:IsA("BasePart") then
		mainPart = pet
		pet.Name = "Pet_" .. petData.petId
		pet.Anchored = true
		pet.CanCollide = false
		pet.CanQuery = true
		pet.CanTouch = false
		pet.CollisionGroup = "Pets"

		-- 무게 배율에 따른 크기 조정
		local scale = math.clamp(petData.weightMult or 1.0, 0.7, 2.0)
		pet.Size = PetCfg.PET_SIZE * scale
		petData._pivotToBottom = pet.Size.Y / 2
		pet.Position = position + Vector3.new(0, petYOffset(petData), 0)

		-- 등급별 색상
		local rarityColor = PetCfg.RARITY_COLORS[petData.rarity]
		if rarityColor then
			pet.Color = rarityColor
		end
	end

	local target = mainPart or pet

	-- 속성 설정 (mainPart에 부여)
	target:SetAttribute("PetId", petData.petId)
	target:SetAttribute("PetName", petData.petName)
	target:SetAttribute("PetType", petData.petType)
	target:SetAttribute("PetRarity", petData.rarity)
	target:SetAttribute("OwnerId", petData.ownerId)
	target:SetAttribute("AssignedBuildingId", petData.assignedBuildingId or "")
	target:SetAttribute("PetState", petData.state or "Idle")
	target:SetAttribute("PetLevel", petData.level or 1)
	target:SetAttribute("PetWeight", petData.weight or 5)
	target:SetAttribute("PetSize", petData.size or "Small")
	target:SetAttribute("PetRace", petData.race or "Human")

	-- 돌연변이 (쉼표 구분 문자열)
	local mutList = {}
	if petData.mutations then
		for mutType, _ in petData.mutations do
			table.insert(mutList, mutType)
		end
	end
	target:SetAttribute("Mutations", table.concat(mutList, ","))

	-- 리그드 모델: Animator + 애니메이션 트랙 로드
	-- 애니메이션 소스: ServerStorage/Pets/{PetName}/Animations/*
	if hasMotor6D and pet:IsA("Model") then
		-- 컨트롤러는 하나만 사용 (Humanoid + AnimationController 공존 시 충돌해 애니 안 먹힘).
		-- Humanoid가 있으면 그걸 쓰고(Roblox 권장), 없으면 AnimationController 생성.
		local controller = pet:FindFirstChildOfClass("Humanoid")
		if controller then
			local strayAC = pet:FindFirstChildOfClass("AnimationController")
			if strayAC then strayAC:Destroy() end
		else
			controller = pet:FindFirstChildOfClass("AnimationController")
			if not controller then
				controller = Instance.new("AnimationController")
				controller.Parent = pet
			end
		end
		local animator = controller:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = controller
		end

		local animFolder = nil
		if serverPetsFolder then
			local petFolder = serverPetsFolder:FindFirstChild(petName)
			if petFolder then
				animFolder = petFolder:FindFirstChild("Animations")
			end
		end

		if animFolder then
			-- "{petName}_Action" → tracks[lower("Action")] 로 저장 (대소문자 무시).
			local tracks = {}
			for _, anim in animFolder:GetChildren() do
				if anim:IsA("Animation") then
					local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
					if ok and track then
						track.Looped = true
						local key = anim.Name:match("^[^_]+_(.+)$") or anim.Name
						tracks[key:lower()] = track
					end
				end
			end
			petData._animTracks = tracks
			petData._animator = animator
			-- 즉시 Idle 시동
			local idle = tracks["idle"]
			if idle then
				pcall(function() idle:Play(0) end)
				petData._currentTrack = idle
			end
		end
	end

	-- HumanoidRootPart(몸 가운데 박스)는 부모 설정 후 Humanoid가 다시 드러내거나
	-- 이름이 달라 못 숨기는 경우가 있어, 다음 프레임에 루트 파트를 확실히 투명 처리.
	if pet:IsA("Model") then
		task.defer(function()
			if not pet or not pet.Parent then return end
			for _, d in pet:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "HumanoidRootPart" then
					d.Transparency = 1
				end
			end
			local hum = pet:FindFirstChildOfClass("Humanoid")
			if hum and hum.RootPart then
				hum.RootPart.Transparency = 1
			end
		end)
	end

	return target
end

----------------------------------------------------------------
-- 부드러운 이동 (목표 위치로)
----------------------------------------------------------------
local function movePetTo(petData, targetPos: Vector3): boolean
	local mainPart = petData.model
	if not mainPart or not mainPart.Parent then return false end

	-- 최상위 Model 찾기 (전체를 이동)
	local wholeModel = petData._petModel
	local useModel = wholeModel and wholeModel.Parent

	local startPos = mainPart.Position
	local distance = (targetPos - startPos).Magnitude
	-- Haste 버프: 이동 속도 증가
	local moveSpeed = PetCfg.MOVE_SPEED * (1 + getPetBuffPercent(petData, "moveSpeed") / 100)
	local duration = distance / moveSpeed

	local rotation = petData._modelRotation or CFrame.new()

	-- 이동 방향(수평) 바라보기. lookAt은 -Z를 방향에 맞추고, 펫별 정면 보정각을 더함.
	-- 보정각은 Constants.PET_FACING_YAW (기본 90 = 정면 +X).
	local FACE_YAW = math.rad(Constants.getPetFacingYaw(petData.petName))
	local flatDir = Vector3.new(targetPos.X - startPos.X, 0, targetPos.Z - startPos.Z)
	local faceRot = nil
	if flatDir.Magnitude > 0.05 then
		faceRot = CFrame.lookAt(Vector3.zero, flatDir.Unit) * CFrame.Angles(0, FACE_YAW, 0)
	end
	local function poseAt(pos: Vector3): CFrame
		if faceRot then
			return CFrame.new(pos) * faceRot * rotation
		end
		return CFrame.new(pos) * rotation
	end

	if duration < 0.1 then
		if useModel then
			wholeModel:PivotTo(poseAt(targetPos))
		else
			mainPart.Position = targetPos
		end
		return true
	end

	local elapsed = 0
	while elapsed < duration and _behaviorLoops[petData.petId] do
		local dt = task.wait()
		elapsed = elapsed + dt
		local alpha = math.min(1, elapsed / duration)
		if mainPart.Parent then
			local newPos = startPos:Lerp(targetPos, alpha)
			if useModel then
				wholeModel:PivotTo(poseAt(newPos))
			else
				mainPart.Position = newPos
			end
		else
			return false
		end
	end
	return _behaviorLoops[petData.petId] ~= nil
end

----------------------------------------------------------------
-- 건물별 펫 자세(작업/쉼) 위치 + 바라볼 방향 (Constants.BUILDINGS[name].petPose)
-- kind: "work" | "rest". config 없으면 nil 반환 → 호출부가 기존 랜덤 위치로 폴백.
----------------------------------------------------------------
local function computeBuildingPose(petData, building: BasePart, kind: string): (Vector3?, Vector3?)
	local itemName = building:GetAttribute("ItemName")
	local info = itemName and Constants.BUILDINGS[itemName]
	local pose = info and info.petPose and info.petPose[kind]
	if not pose then return nil, nil end

	local offset = pose.offset or Vector3.zero
	-- 수평(x,z)은 건물 yaw 따라 회전, Y는 건물 바닥 기준 + 펫 키
	local horiz = building.CFrame:PointToWorldSpace(Vector3.new(offset.X, 0, offset.Z))
	local baseY = building.Position.Y - building.Size.Y / 2
	local pos = Vector3.new(horiz.X, baseY + offset.Y + petYOffset(petData), horiz.Z)

	local faceDir = nil
	local f = pose.face
	if typeof(f) == "number" then
		faceDir = Vector3.new(math.sin(math.rad(f)), 0, math.cos(math.rad(f)))
	elseif f == "in" then
		faceDir = Vector3.new(building.Position.X - pos.X, 0, building.Position.Z - pos.Z)
	elseif f == "out" then
		faceDir = Vector3.new(pos.X - building.Position.X, 0, pos.Z - building.Position.Z)
	end
	if faceDir and faceDir.Magnitude < 0.05 then faceDir = nil end
	return pos, faceDir
end

-- 펫이 dir(수평 방향)을 바라보게 모델 회전 (이동 없이 자세만). movePetTo와 동일한 facing 규칙.
local function facePet(petData, dir: Vector3?)
	if not dir or dir.Magnitude < 0.05 then return end
	local mainPart = petData.model
	if not mainPart or not mainPart.Parent then return end
	local rotation = petData._modelRotation or CFrame.new()
	local FACE_YAW = math.rad(Constants.getPetFacingYaw(petData.petName))
	local faceRot = CFrame.lookAt(Vector3.zero, dir.Unit) * CFrame.Angles(0, FACE_YAW, 0)
	local wholeModel = petData._petModel
	if wholeModel and wholeModel.Parent then
		wholeModel:PivotTo(CFrame.new(wholeModel:GetPivot().Position) * faceRot * rotation)
	else
		mainPart.CFrame = CFrame.new(mainPart.Position) * faceRot * rotation
	end
end

----------------------------------------------------------------
-- 행동 루프 중단 (외부에서 호출)
----------------------------------------------------------------
function PetManager.stopBehaviorLoop(petId: string)
	_behaviorLoops[petId] = nil
end

----------------------------------------------------------------
-- 일터 탐색 (petType과 building.workTypes 매칭)
----------------------------------------------------------------
local function findWorkplace(plot, petData): BasePart?
	local buildings = getAllBuildings(plot)

	-- 펫이 Construction 가능한지 판정
	local canConstruct = false
	local petCatalog = Constants.PETS[petData.petName]
	if petCatalog and petCatalog.petTypes then
		for _, pt in petCatalog.petTypes do
			if pt == "Construction" then canConstruct = true; break end
		end
	elseif petData.petType == "Construction" then
		canConstruct = true
	end

	-- workTypes 매칭용 (한글 키)
	local petTypeKor = Constants.PetType[petData.petType]

	local upgradeCandidates = {}
	local workCandidates = {}

	for _, building in buildings do
		local itemName = building:GetAttribute("ItemName")
		if not itemName then continue end

		local buildingInfo = Constants.BUILDINGS[itemName]
		if not buildingInfo then continue end

		local buildingId = building:GetAttribute("BuildingId")
		local upState = building:GetAttribute("UpgradeState") or ""
		local isUpgrading = upState == Constants.UpgradeState.Upgrading
		local occupants = _workplaceOccupancy[buildingId]
		local occupantCount = occupants and #occupants or 0

		-- 본인이 이미 점유 중이면 스킵
		if occupants then
			local already = false
			for _, pid in occupants do
				if pid == petData.petId then already = true; break end
			end
			if already then continue end
		end

		-- (1) 업그레이드 중 건물 (Construction 가능 펫만, 건물당 최대 3마리)
		if isUpgrading then
			if canConstruct and occupantCount < 3 then
				table.insert(upgradeCandidates, building)
			end
			-- 업그레이드 중인 건물에서는 일반 작업 불가
			continue
		end

		-- 일반 일터 점유 (1마리 한도)
		if occupantCount >= 1 then continue end

		-- 다른 펫이 이미 배정된 일반 일터 스킵 (legacy)
		local assignedPetId = building:GetAttribute("AssignedPetId") or ""
		if assignedPetId ~= "" and assignedPetId ~= petData.petId then continue end

		-- (2) Farm/Mine 등 workTypes 매칭
		if petTypeKor and buildingInfo.workTypes then
			for _, wt in buildingInfo.workTypes do
				if wt == petTypeKor then
					table.insert(workCandidates, building)
					break
				end
			end
		end
	end

	-- 업그레이드 후보 우선
	local candidates = if #upgradeCandidates > 0 then upgradeCandidates else workCandidates
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
local function findRestPlace(plot, petData): BasePart?
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
			if t == "Rest" then
				isRest = true
				break
			end
		end
		if not isRest then continue end

		-- 점유 확인 (쉼터당 1마리)
		local buildingId = building:GetAttribute("BuildingId")
		local occupants = _workplaceOccupancy[buildingId]
		local occupantCount = occupants and #occupants or 0
		-- 본인이 이미 점유 중이면 스킵
		if occupants and petData then
			local already = false
			for _, pid in occupants do
				if pid == petData.petId then already = true; break end
			end
			if already then continue end
		end
		if occupantCount >= 1 then continue end

		table.insert(candidates, building)
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

-- 인사(Chatting) 시 발동하는 버프. 같은 종끼리 인사하면 kin 버프를 임시로 부여.
-- (PetAbilityConfig의 buff_kin 능력. 프록시미티가 아닌 실제 인사 시점에 적용.)
local function applyGreetingBuffs(petA, petB)
	local AbilityCfg = BalanceConfig.PetAbility
	local function tryKin(selfPet, otherPet)
		local cfg = AbilityCfg.ABILITIES[selfPet.petName]
		if cfg and cfg.kind == "buff_kin" and cfg.buffId and otherPet.petName == selfPet.petName then
			BuffManager.applyPetBuff(selfPet.petId, cfg.buffId, cfg.duration or 30)
		end
	end
	tryKin(petA, petB)
	tryKin(petB, petA)
end

----------------------------------------------------------------
-- 배회 (산책 모드)
----------------------------------------------------------------
local function doWander(petData, buildZone: BasePart, duration: number, hasSleepless: boolean?)
	-- 호출자가 지정한 이동 상태(Wandering / SearchingForWork). 이동 중에만 적용.
	local moveState = petData.state
	local elapsed = 0
	while elapsed < duration and _behaviorLoops[petData.petId] do
		-- 밤이 되면(불면 아니면) 배회 중단 → 행동 루프 상단에서 수면 처리.
		if not TimeState.isDay() and not hasSleepless then break end
		-- 랜덤 목표
		local center = buildZone.Position
		local halfSize = buildZone.Size / 2
		local targetX = center.X + (math.random() * 2 - 1) * math.min(halfSize.X, PetCfg.WANDER_RADIUS)
		local targetZ = center.Z + (math.random() * 2 - 1) * math.min(halfSize.Z, PetCfg.WANDER_RADIUS)
		-- 지면 = BuildZone 윗면 (center는 중심이므로 halfSize.Y 더함).
		local targetPos = Vector3.new(targetX, center.Y + halfSize.Y + petYOffset(petData), targetZ)

		-- 이동 시작 → move 애니
		if petData.state ~= moveState then setPetState(petData, moveState) end
		movePetTo(petData, targetPos)
		if not _behaviorLoops[petData.petId] then break end
		-- 이동 직후 밤 체크 → 곧장 잠자리로 (도착 후 더 배회하지 않음).
		if not TimeState.isDay() and not hasSleepless then break end

		-- 대화 상대 탐색
		local plot = buildZone.Parent
		if plot then
			local partner = findChatPartner(petData, plot)
			if partner then
				setPetState(petData, "Chatting")
				setPetState(partner, "Chatting")
				applyGreetingBuffs(petData, partner) -- 같은 종끼리 인사 시 kin 버프
				task.wait(PetCfg.CHAT_DURATION)
				if _behaviorLoops[partner.petId] then
					setPetState(partner, "Wandering")
				end
				elapsed = elapsed + PetCfg.CHAT_DURATION
			end
		end

		-- 도착 후 정지하는 동안은 Idle 애니 (looped move가 제자리에서 계속 도는 것 방지)
		setPetState(petData, "Idle")
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

	-- 글로벌 XP 틱 (모든 펫이 매초 +1 XP, 쉼터에서 배율 적용 가능)
	-- petData._xpMultiplier가 nil이면 1.0으로 간주
	task.spawn(function()
		local xpClientTimer = 0
		while _behaviorLoops[petId] do
			task.wait(1)
			if not _behaviorLoops[petId] then break end
			local mult = petData._xpMultiplier or 1
			petData.xp = petData.xp + PetCfg.XP_PER_SECOND * mult
			local req = PetCfg.XP_REQUIRED[petData.level]
			if req and petData.xp >= req and petData.level < PetCfg.MAX_LEVEL then
				petData.level = petData.level + 1
				petData.xp = 0
				if petData.model and petData.model.Parent then
					petData.model:SetAttribute("PetLevel", petData.level)
				end
				petUpdateEvent:FireClient(player, "levelup", {
					petId = petId,
					petName = petData.petName,
					newLevel = petData.level,
				})
			end
			-- 클라 10초마다 동기화
			xpClientTimer = xpClientTimer + 1
			if xpClientTimer >= 10 then
				xpClientTimer = 0
				petUpdateEvent:FireClient(player, "xpUpdate", {
					petId = petId,
					xp = petData.xp,
					level = petData.level,
				})
			end
		end
	end)

	task.spawn(function()
		-- (기존 work-loop의 클라 xp 동기화 변수는 더 이상 필요 없음)
		local xpUpdateTimer = 0

		while _behaviorLoops[petId] do
			if not petData.model or not petData.model.Parent then
				_behaviorLoops[petId] = nil
				break
			end

			-- 불면 특성 체크 (+ Energy 버프 활성 시 잠 안 잠)
			local hasSleepless = false
			if petData.traits then
				for k, v in petData.traits do
					if v == "Insomnia" or k == "Insomnia" or (typeof(v) == "boolean" and v and k == "Insomnia") then
						hasSleepless = true
						break
					end
				end
			end
			if not hasSleepless and getPetBuffPercent(petData, "sleepless") > 0 then
				hasSleepless = true
			end

			-- 밤이고 불면 아닌 경우 → 수면
			if not TimeState.isDay() and not hasSleepless then
				print("[Pet] " .. petData.petName .. " sleeping (isDay=" .. tostring(TimeState.isDay()) .. ", insomnia=" .. tostring(hasSleepless) .. ")")
				setPetState(petData, "Sleeping")

				-- 쉼터로 이동 (있으면, 1마리 한도라 점유 즉시 잠금)
				local restPlace = findRestPlace(plot, petData)
				local restBuildingId = nil
				if restPlace then
					restBuildingId = restPlace:GetAttribute("BuildingId")
					occupyWorkplace(restBuildingId, petId)
					-- 건물별 휴식 위치(petPose.rest) 있으면 그 자리+방향, 없으면 랜덤
					local restPosePos, restPoseFace = computeBuildingPose(petData, restPlace, "rest")
					local targetPos = restPosePos or (restPlace.Position + Vector3.new(
						(math.random() * 2 - 1) * 2,
						petYOffset(petData),
						(math.random() * 2 - 1) * 2
					))
					movePetTo(petData, targetPos)
					facePet(petData, restPoseFace)
				else
					-- 쉼터 없으면 빌드존 안 랜덤 위치로 흩어져 잠 (센터에 몰리지 않게, 펫마다 랜덤)
					local center = buildZone.Position
					local half = buildZone.Size / 2
					local sleepPos = Vector3.new(
						center.X + (math.random() * 2 - 1) * math.max(0, half.X - 2),
						center.Y + half.Y + petYOffset(petData),
						center.Z + (math.random() * 2 - 1) * math.max(0, half.Z - 2)
					)
					movePetTo(petData, sleepPos)
				end

				-- 아침까지 대기
				while not TimeState.isDay() and _behaviorLoops[petId] do
					task.wait(1)
				end

				-- 수면 종료 → 점유 해제
				if restBuildingId then
					vacateWorkplace(restBuildingId, petId)
				end

				if not _behaviorLoops[petId] then break end
				continue
			end

			-- 1. 일터 탐색
			local workplace = findWorkplace(plot, petData)

			if workplace then
				local buildingId = workplace:GetAttribute("BuildingId")

				-- 즉시 점유 예약 (이동 중 다른 펫이 같은 일터를 잡지 못하게)
				occupyWorkplace(buildingId, petId)
				petData.targetBuildingId = buildingId

				-- 일터로 이동 (이동 중엔 move 애니). 건물별 작업 위치(petPose) 있으면 그 자리, 없으면 랜덤.
				local poseFace = nil
				local posePos
				posePos, poseFace = computeBuildingPose(petData, workplace, "work")
				local targetPos = posePos or (workplace.Position + Vector3.new(
					(math.random() * 2 - 1) * 2,
					petYOffset(petData),
					(math.random() * 2 - 1) * 2
				))

				setPetState(petData, "Walking")
				if not movePetTo(petData, targetPos) then
					vacateWorkplace(buildingId, petId)
					petData.targetBuildingId = ""
					break
				end
				if not _behaviorLoops[petId] then
					vacateWorkplace(buildingId, petId)
					petData.targetBuildingId = ""
					break
				end

				-- 2. 작업 시작 (지정 방향 있으면 그 방향 바라봄)
				petData.previousWorkId = buildingId
				facePet(petData, poseFace)
				setPetState(petData, "Working")

				-- 업그레이드 건물이면 작업자 카운트 증가 (UpgradeManager 진행도 트리거)
				local isUpgradeWork = workplace:GetAttribute("UpgradeState") == Constants.UpgradeState.Upgrading
				if isUpgradeWork then
					local cur = workplace:GetAttribute("UpgradeWorkers") or 0
					workplace:SetAttribute("UpgradeWorkers", cur + 1)
				end

				local workDuration = PetCfg.WORK_DURATION_MIN
					+ math.random() * (PetCfg.WORK_DURATION_MAX - PetCfg.WORK_DURATION_MIN)
				-- Serenity 버프: 휴식 전까지 더 오래 일함
				workDuration = workDuration * (1 + getPetBuffPercent(petData, "workDuration") / 100)
				local workElapsed = 0
				xpUpdateTimer = 0

				while workElapsed < workDuration and _behaviorLoops[petId] do
					task.wait(1)
					workElapsed = workElapsed + 1

					-- 일터가 사라졌으면(저장/철거) 즉시 중단
					if not workplace or not workplace.Parent then
						break
					end

					-- 밤 전환 체크 (불면 아니면 중단)
					if not TimeState.isDay() and not hasSleepless then
						break
					end

					-- 광산/농장 등 Work 건물에 코인 누적 (capacity 한도까지) + Mine은 보석 확률
					-- 업그레이드 중인 건물은 코인/보석 누적 안 함 (업그레이드 진행도만 올림)
					do
						local itemName = workplace:GetAttribute("ItemName")
						local buildingInfo = itemName and Constants.BUILDINGS[itemName]
						if not isUpgradeWork and buildingInfo and buildingInfo.types then
							local isWork = false
							for _, t in buildingInfo.types do
								if t == "Work" then isWork = true; break end
							end
							if isWork then
								local BCfg = BalanceConfig.Building
								local AbilityCfg = BalanceConfig.PetAbility
								local incomeCfg = (BCfg.WORK_INCOME and BCfg.WORK_INCOME[itemName]) or { rate = 1, gemChance = 0 }
								local level = workplace:GetAttribute("Level") or 1
								local caps = BCfg.WORK_CAPACITY_BY_LEVEL or {}
								local cap = caps[level] or caps[1] or 100

								-- 펫 효율 보너스 (수동 능력)
								local effMult = 1
								local passive = AbilityCfg.PASSIVE[petData.petName]
								if passive then
									if passive.snowEfficiencyBonus and WeatherState.get and WeatherState.get() == "Frost" then
										effMult = effMult * (1 + passive.snowEfficiencyBonus)
									end
									if passive.nightWorkBonus and not TimeState.isDay() then
										effMult = effMult * (1 + passive.nightWorkBonus)
									end
								end
								-- 활성 버프: 일 효율 증가 (Vitality/Blessing/AllyEncouragement 등)
								effMult = effMult * (1 + getPetBuffPercent(petData, "workEfficiency") / 100)

								local incomeAmount = math.ceil(incomeCfg.rate * effMult)
								local stored = workplace:GetAttribute("StoredCoins") or 0
								if stored < cap then
									workplace:SetAttribute("StoredCoins", math.min(cap, stored + incomeAmount))
								end

								-- 보석 (Mine 등) + 크리스탈 골렘 보너스 + Fortune 버프
								local effectiveGemChance = incomeCfg.gemChance
								if passive and passive.gemChanceBonus then
									effectiveGemChance = effectiveGemChance * (1 + passive.gemChanceBonus)
								end
								effectiveGemChance = effectiveGemChance * (1 + getPetBuffPercent(petData, "gemChance") / 100)
								if effectiveGemChance > 0 and math.random() < effectiveGemChance then
									local storedGems = workplace:GetAttribute("StoredGems") or 0
									workplace:SetAttribute("StoredGems", storedGems + 1)
								end
							end
						end
					end

					-- XP는 글로벌 XP 틱이 처리
				end

				-- 작업 종료 → 점유 해제
				vacateWorkplace(buildingId, petId)
				petData.targetBuildingId = ""
				-- 업그레이드 작업자 카운트 감소
				if isUpgradeWork and workplace.Parent then
					local cur = workplace:GetAttribute("UpgradeWorkers") or 0
					workplace:SetAttribute("UpgradeWorkers", math.max(0, cur - 1))
				end

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
					restPlace = findRestPlace(plot, petData)
				end

				if restPlace then
					-- 쉼터 점유 즉시 잠금 (1마리 한도)
					local restBuildingId = restPlace:GetAttribute("BuildingId")
					occupyWorkplace(restBuildingId, petId)

					-- 쉼터 이동 → 휴식 (이동 중엔 move 애니). 건물별 휴식 위치(petPose.rest) 우선.
					local restPosePos, restPoseFace = computeBuildingPose(petData, restPlace, "rest")
					local restPos = restPosePos or (restPlace.Position + Vector3.new(
						(math.random() * 2 - 1) * 2,
						petYOffset(petData),
						(math.random() * 2 - 1) * 2
					))
					setPetState(petData, "Walking")
					if not movePetTo(petData, restPos) then
						vacateWorkplace(restBuildingId, petId)
						break
					end
					if not _behaviorLoops[petId] then
						vacateWorkplace(restBuildingId, petId)
						break
					end

					facePet(petData, restPoseFace)
					setPetState(petData, "Resting")

					-- 휴식 건물별 버프 적용
					local restItemName = restPlace:GetAttribute("ItemName")
					local restLevel = restPlace:GetAttribute("Level") or 1
					local restCfg = restItemName and BalanceConfig.Buff.REST_BUILDING_BUFFS[restItemName]
					if restCfg then
						-- 버프 적용 (BuffManager 외부 모듈)
						local ok, BuffManager = pcall(require, script.Parent:WaitForChild("BuffManager"))
						if ok and restCfg.buffId and BuffManager.applyBuff then
							BuffManager.applyBuff(player, restCfg.buffId, restCfg.durationSec or 60)
						end
						-- 휴식 시간 단축 배율
						if restCfg.restDecayMultiplier and restCfg.restDecayMultiplier > 0 then
							restDuration = restDuration / restCfg.restDecayMultiplier
						end
						-- TreeOfGrowth XP 배율: 글로벌 XP 틱이 자동 적용
						if restCfg.xpMultiplier and restCfg.xpMultiplier > 1 then
							petData._xpMultiplier = restCfg.xpMultiplier
							task.wait(restDuration)
							petData._xpMultiplier = 1
						else
							task.wait(restDuration)
						end
					else
						task.wait(restDuration)
					end

					-- 휴식 종료 → 점유 해제
					vacateWorkplace(restBuildingId, petId)
				else
					-- 산책
					setPetState(petData, "Wandering")
					doWander(petData, buildZone, restDuration, hasSleepless)
				end
			else
				-- 일터 없음 → 일자리 찾기 모드 (Wandering과 구분)
				setPetState(petData, Constants.PetState.SearchingForWork)
				local wanderDuration = PetCfg.REST_DURATION_MIN
					+ math.random() * (PetCfg.REST_DURATION_MAX - PetCfg.REST_DURATION_MIN)
				doWander(petData, buildZone, wanderDuration, hasSleepless)
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
				rarity = savedPet.rarity or "Common",
				ownerId = player.UserId,
				assignedBuildingId = "",
				model = nil,
				mutations = restoredMutations,
				-- 신규 필드
				size = size,
				race = savedPet.race or "Human",
				traits = savedPet.traits or {},
				weight = savedPet.weight or (stdWeight * weightMult),
				weightMult = weightMult,
				level = savedPet.level or 1,
				xp = savedPet.xp or 0,
				state = "Idle",
				targetBuildingId = "",
				previousWorkId = "",
				inInventory = savedPet.inInventory or false,
			}

			-- Ensure FarmerNewbie always has Insomnia
			if petData.petName == "FarmerNewbie" then
				local hasIns = false
				for _, t in petData.traits do
					if t == "Insomnia" then hasIns = true; break end
				end
				if not hasIns then table.insert(petData.traits, "Insomnia") end
			end

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
				race = defaultPet.race or "Human",
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
		-- 인벤토리 보관 펫은 월드 스폰 안 함 (PetServer가 별도로 Tool 생성)
		if petData.inInventory then
			petData.state = "Held"
			continue
		end
		if not petData.model or not petData.model.Parent then
			-- 지면 = BuildZone 윗면
			local groundPos = buildZone.Position + Vector3.new(0, buildZone.Size.Y / 2, 0)
			local pet = createPetModel(petData, groundPos)
			-- Model이면 _petModel을 plot에 배치
			if petData._petModel then
				petData._petModel.Parent = plot
				petData.model = pet -- mainPart
			else
				pet.Parent = plot
				petData.model = pet
			end

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
			inInventory = petData.inInventory or false,
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
		return false, "Pet not found"
	end

	local petData = pets[petId]

	-- 이미 다른 건물에 배치된 경우
	if petData.assignedBuildingId ~= "" then
		return false, "Pet already assigned"
	end

	-- 건물 확인
	local plot = getPlayerPlot(player)
	if not plot then return false, "No plot" end

	local building = findBuildingById(plot, buildingId)
	if not building then return false, "Building not found" end

	-- 건물이 수리중인지 확인
	local state = building:GetAttribute("UpgradeState") or ""
	if state ~= Constants.UpgradeState.Upgrading then
		return false, "Not upgrading"
	end

	-- 이미 다른 펫이 배치된 경우
	local existingPetId = building:GetAttribute("AssignedPetId") or ""
	if existingPetId ~= "" then
		return false, "Pet already assigned to building"
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
		local targetPos = building.Position + Vector3.new(building.Size.X / 2 + 1.5, petYOffset(petData), 0)
		local rotation = petData._modelRotation or CFrame.new()
		if petData._petModel and petData._petModel:IsA("Model") then
			petData._petModel:PivotTo(CFrame.new(targetPos) * rotation)
		else
			petData.model.Position = targetPos
		end
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
		return false, "Pet not found"
	end

	local petData = pets[petId]
	if petData.assignedBuildingId == "" then
		return false, "Pet not assigned"
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

-- 외부에서 펫 직접 추가 (알 부화 등)
function PetManager.addPetDirect(player: Player, petData)
	local pets = _playerPets[player]
	if not pets then
		_playerPets[player] = {}
		pets = _playerPets[player]
	end

	pets[petData.petId] = petData

	-- 모델 스폰
	local plot = getPlayerPlot(player)
	if plot then
		local buildZone = plot:FindFirstChild("BuildZone", true)
		if buildZone then
			-- 지면 = BuildZone 윗면
			local groundPos = buildZone.Position + Vector3.new(0, buildZone.Size.Y / 2, 0)
			local pet = createPetModel(petData, groundPos)
			-- Model이면 wrapping Model을 plot에 넣어야 모든 파트가 함께 보임
			if petData._petModel then
				petData._petModel.Parent = plot
			else
				pet.Parent = plot
			end
			petData.model = pet

			-- 행동 AI 시작
			PetManager._startBehaviorLoop(player, petData, plot)
		end
	end
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
			inInventory = petData.inInventory or false,
		})
	end
	return result
end

----------------------------------------------------------------
-- Pet sell price calculation
----------------------------------------------------------------
function PetManager.getSellPrice(petData): number
	local rarity = petData.rarity or "Common"
	local basePrice = PetCfg.SELL_BASE_PRICE[rarity] or 100

	-- Weight multiplier (0.8 ~ 1.2)
	local weightMult = petData.weightMult or 1.0
	local weightRange = PetCfg.WEIGHT_MAX_MULT - PetCfg.WEIGHT_MIN_MULT
	local weightRatio = if weightRange > 0 then math.clamp((weightMult - PetCfg.WEIGHT_MIN_MULT) / weightRange, 0, 1) else 0.5
	local sellWeightMult = PetCfg.SELL_WEIGHT_MULT_MIN + weightRatio * (PetCfg.SELL_WEIGHT_MULT_MAX - PetCfg.SELL_WEIGHT_MULT_MIN)

	-- Level multiplier (1.0 ~ 2.0)
	local level = petData.level or 1
	local levelRatio = math.clamp((level - 1) / (PetCfg.MAX_LEVEL - 1), 0, 1)
	local sellLevelMult = PetCfg.SELL_LEVEL_MULT_MIN + levelRatio * (PetCfg.SELL_LEVEL_MULT_MAX - PetCfg.SELL_LEVEL_MULT_MIN)

	-- Mutation multiplier (sum of all mutation bonuses)
	local mutationTotal = 0
	if petData.mutations then
		if typeof(petData.mutations) == "table" then
			-- Handle both dict {Shocked=true} and array {"Shocked"}
			for k, v in petData.mutations do
				local mutName = if typeof(k) == "string" then k else v
				local bonus = PetCfg.SELL_MUTATION_BONUS[mutName] or 0
				mutationTotal = mutationTotal + bonus
			end
		end
	end
	local mutMult = if mutationTotal > 0 then mutationTotal else 1

	return math.floor(basePrice * sellWeightMult * sellLevelMult * mutMult)
end

----------------------------------------------------------------
-- Remove a pet (for selling)
----------------------------------------------------------------
function PetManager.removePet(player: Player, petId: string): (boolean, string?)
	local pets = _playerPets[player]
	if not pets or not pets[petId] then
		return false, "Pet not found"
	end

	local petData = pets[petId]

	-- Cannot sell assigned/placed pets
	if petData.assignedBuildingId and petData.assignedBuildingId ~= "" then
		return false, "Pet is assigned to a building"
	end

	-- Stop behavior loop
	_behaviorLoops[petId] = nil

	-- Destroy model
	if petData._petModel and petData._petModel.Parent then
		petData._petModel:Destroy()
	elseif petData.model and petData.model.Parent then
		petData.model:Destroy()
	end

	-- Remove from data
	pets[petId] = nil

	-- Notify client
	local petUpdateEvent = remotes:FindFirstChild("PetUpdate")
	if petUpdateEvent then
		petUpdateEvent:FireClient(player, "removed", { petId = petId })
	end

	return true
end

----------------------------------------------------------------
-- Return held pet to world (re-spawn and restart behavior)
----------------------------------------------------------------
function PetManager.returnPetToWorld(player: Player, petId: string, requestedPos: Vector3?)
	local pets = _playerPets[player]
	if not pets or not pets[petId] then
		warn("[ReturnPet] Pet not found: " .. tostring(petId))
		return
	end

	local petData = pets[petId]
	print("[ReturnPet] Returning: " .. petData.petName)
	petData.state = "Idle"
	petData.inInventory = false

	local plot = getPlayerPlot(player)
	if not plot then
		warn("[ReturnPet] No plot")
		return
	end

	local buildZone = plot:FindFirstChild("BuildZone", true)
	if not buildZone then
		warn("[ReturnPet] No BuildZone")
		return
	end

	-- Clear old model refs
	petData.model = nil
	petData._petModel = nil

	-- Spawn at BuildZone surface
	local bzTop = buildZone.Position.Y + buildZone.Size.Y / 2
	local spawnPos = Vector3.new(buildZone.Position.X, bzTop, buildZone.Position.Z)

	-- requestedPos가 BuildZone 안이면 그 자리에 배치
	local placedAtRequested = false
	if requestedPos then
		local local2 = buildZone.CFrame:PointToObjectSpace(requestedPos)
		local half = buildZone.Size / 2
		if math.abs(local2.X) <= half.X and math.abs(local2.Z) <= half.Z then
			spawnPos = Vector3.new(requestedPos.X, bzTop, requestedPos.Z)
			placedAtRequested = true
		end
	end

	if not placedAtRequested then
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				spawnPos = Vector3.new(
					hrp.Position.X + math.random(-3, 3),
					bzTop,
					hrp.Position.Z + math.random(-3, 3)
				)
			end
		end
	end

	local pet = createPetModel(petData, spawnPos)
	if petData._petModel then
		petData._petModel.Parent = plot
		petData.model = pet
	else
		pet.Parent = plot
		petData.model = pet
	end

	-- Restart behavior
	if petData.assignedBuildingId == "" then
		PetManager._startBehaviorLoop(player, petData, plot)
	end
	print("[ReturnPet] " .. petData.petName .. " returned")
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
