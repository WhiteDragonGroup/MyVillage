-- UpgradeManager.luau
-- 건물 업그레이드 로직 (ModuleScript)
-- startUpgrade, cancelUpgrade, addProgress, completeUpgrade

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local UpgradeCfg = BalanceConfig.Upgrade
local PetCfg = BalanceConfig.Pet
local WeatherCfg = BalanceConfig.Weather

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local upgradeStateChanged = remotes:WaitForChild("UpgradeStateChanged")

local UpgradeManager = {}

-- 지연 로드 모듈 (순환 참조 방지)
local _WeatherState = nil
local _PetManager = nil

local function getWeatherState()
	if not _WeatherState then
		_WeatherState = require(ServerScriptService:WaitForChild("Server"):WaitForChild("WeatherState"))
	end
	return _WeatherState
end

local function getPetManager()
	if not _PetManager then
		_PetManager = require(ServerScriptService:WaitForChild("Server"):WaitForChild("PetManager"))
	end
	return _PetManager
end

-- 활성 업그레이드 루프 { [buildingId] = true }
local _activeLoops = {}

-- 외부 콜백
local _onCompleteCallback = nil  -- (Player, petId) → 펫 해제
local _spendCoinsFunc = nil      -- (Player, amount) → boolean
local _hasCoinsFunc = nil        -- (Player, amount) → boolean
local _addCoinsFunc = nil        -- (Player, amount) → boolean

function UpgradeManager.setOnCompleteCallback(callback: (Player, string) -> ())
	_onCompleteCallback = callback
end

function UpgradeManager.setCurrencyFunctions(hasCoins, spendCoins, addCoins)
	_hasCoinsFunc = hasCoins
	_spendCoinsFunc = spendCoins
	_addCoinsFunc = addCoins
end

----------------------------------------------------------------
-- upgrade started
----------------------------------------------------------------
function UpgradeManager.startUpgrade(player: Player, building: BasePart): (boolean, string?)
	local level = building:GetAttribute("Level") or 1
	if level >= UpgradeCfg.MAX_LEVEL then
		return false, "Max level"
	end

	local state = building:GetAttribute("UpgradeState") or ""
	if state == Constants.UpgradeState.Upgrading then
		return false, "Already upgrading"
	end

	-- 비용 체크
	local cost = UpgradeCfg.COST[level] or 0
	if cost > 0 then
		if not _hasCoinsFunc or not _hasCoinsFunc(player, cost) then
			return false, "Not enough coins (" .. cost .. " needed)"
		end
		if not _spendCoinsFunc(player, cost) then
			return false, "Coin deduction failed"
		end
	end

	-- 상태 변경
	building:SetAttribute("UpgradeState", Constants.UpgradeState.Upgrading)
	building:SetAttribute("UpgradeProgress", 0)

	local buildingId = building:GetAttribute("BuildingId")

	-- 진행도 루프 시작
	UpgradeManager._startProgressLoop(player, building, buildingId)

	-- 클라이언트 알림
	upgradeStateChanged:FireClient(player, buildingId, "started", level)

	print(player.Name .. " - " .. (building:GetAttribute("ItemName") or "?") .. " upgrade started (Lv." .. level .. ")")
	return true
end

----------------------------------------------------------------
-- upgrade cancelled
----------------------------------------------------------------
function UpgradeManager.cancelUpgrade(player: Player, building: BasePart): (boolean, string?)
	local state = building:GetAttribute("UpgradeState") or ""
	if state ~= Constants.UpgradeState.Upgrading then
		return false, "Not upgrading"
	end

	local buildingId = building:GetAttribute("BuildingId")
	local level = building:GetAttribute("Level") or 1

	-- 루프 중단
	_activeLoops[buildingId] = nil

	-- coins 환불
	local cost = UpgradeCfg.COST[level] or 0
	if cost > 0 and _addCoinsFunc then
		_addCoinsFunc(player, cost)
		print(player.Name .. " - upgrade cancelled, refund: " .. cost .. " coins")
	end

	-- 상태 복원
	building:SetAttribute("UpgradeState", Constants.UpgradeState.None)
	building:SetAttribute("UpgradeProgress", 0)
	building:SetAttribute("AssignedPetId", "")

	-- 클라이언트 알림
	upgradeStateChanged:FireClient(player, buildingId, "cancelled")

	print(player.Name .. " - " .. (building:GetAttribute("ItemName") or "?") .. " upgrade cancelled")
	return true
end

----------------------------------------------------------------
-- 진행도 루프 (펫이 배치되어 있을 때만 진행)
----------------------------------------------------------------
function UpgradeManager._startProgressLoop(player: Player, building: BasePart, buildingId: string)
	if _activeLoops[buildingId] then
		print("[UpgradeLoop] " .. buildingId .. " 이미 실행 중")
		return
	end
	_activeLoops[buildingId] = true
	print("[UpgradeLoop] " .. buildingId .. " 시작")

	task.spawn(function()
		while _activeLoops[buildingId] do
			task.wait(UpgradeCfg.PROGRESS_TICK)

			-- 건물이 아직 존재하는지 확인
			if not building or not building.Parent then
				print("[UpgradeLoop] " .. buildingId .. " 건물 사라짐 → 중단")
				_activeLoops[buildingId] = nil
				break
			end

			-- 수리중 상태인지 확인
			local state = building:GetAttribute("UpgradeState") or ""
			if state ~= Constants.UpgradeState.Upgrading then
				print("[UpgradeLoop] " .. buildingId .. " 상태=" .. state .. " → 중단")
				_activeLoops[buildingId] = nil
				break
			end

			-- 펫이 배치되어 있는지 확인 (작업자 수 또는 legacy AssignedPetId)
			local workers = building:GetAttribute("UpgradeWorkers") or 0
			local assignedPetId = building:GetAttribute("AssignedPetId") or ""
			if workers <= 0 and assignedPetId == "" then
				continue
			end

			-- 필요 작업량 조회
			local level = building:GetAttribute("Level") or 1
			local requiredWork = UpgradeCfg.REQUIRED_WORK[level] or 1500

			-- 진행도 증가 (작업자 수만큼 가속)
			local progress = building:GetAttribute("UpgradeProgress") or 0
			local workerMult = math.max(1, workers)
			local increment = PetCfg.BUILD_SPEED * workerMult

			-- Rain 날씨 보너스 (+50%)
			if getWeatherState().get() == "Rain" then
				increment *= 1.5
			end

			-- 펫 돌연변이 보너스 (legacy 단일 펫 기준)
			if assignedPetId ~= "" then
				local pm = getPetManager()
				local petData = pm.getPetData(player, assignedPetId)
				if petData and petData.mutations then
					for mutationType, _ in petData.mutations do
						local bonus = WeatherCfg.MUTATION_SPEED_BONUS[mutationType]
						if bonus then
							increment *= (1 + bonus)
						end
					end
				end
			end

			progress = math.min(requiredWork, progress + increment)
			building:SetAttribute("UpgradeProgress", progress)
			-- 진행 진단 (5초 간격)
			if math.floor(progress) % (math.floor(increment * 5)) < math.floor(increment) then
				print(string.format("[UpgradeLoop] %s progress=%d/%d (+%d)",
					buildingId, math.floor(progress), requiredWork, math.floor(increment)))
			end

			-- 작업량 도달 시 완료
			if progress >= requiredWork then
				UpgradeManager._completeUpgrade(player, building, buildingId)
				break
			end
		end
	end)
end

----------------------------------------------------------------
-- 업그레이드 완료
----------------------------------------------------------------
function UpgradeManager._completeUpgrade(player: Player, building: BasePart, buildingId: string)
	_activeLoops[buildingId] = nil

	local level = building:GetAttribute("Level") or 1
	local newLevel = level + 1

	-- 레벨 업
	building:SetAttribute("Level", newLevel)
	building:SetAttribute("UpgradeState", Constants.UpgradeState.None)
	building:SetAttribute("UpgradeProgress", 0)

	-- 펫 해제 (PetManager가 처리)
	local assignedPetId = building:GetAttribute("AssignedPetId") or ""
	building:SetAttribute("AssignedPetId", "")

	-- 외형 변화 적용 (모델 스왑 또는 크기/색상 변경)
	local newBuilding = UpgradeManager.applyVisualUpgrade(building, newLevel)

	-- 펫 자동 해제 콜백
	if _onCompleteCallback and assignedPetId ~= "" then
		_onCompleteCallback(player, assignedPetId)
	end

	-- 클라이언트 알림
	upgradeStateChanged:FireClient(player, buildingId, "completed", newLevel)

	local itemName = (newBuilding or building):GetAttribute("ItemName") or "?"
	print(player.Name .. " - " .. itemName .. " level up! Lv." .. newLevel)

	return assignedPetId
end

----------------------------------------------------------------
-- 모델 스왑 (ServerStorage에 레벨별 모델이 있을 때)
-- ServerStorage/Buildings/{ItemName}/Level{N} 구조
----------------------------------------------------------------
function UpgradeManager._swapModel(oldBuilding: BasePart, template: Instance): BasePart?
	local parent = oldBuilding.Parent
	local cframe = oldBuilding.CFrame
	local itemName = oldBuilding:GetAttribute("ItemName") or ""

	-- 기존 속성 전부 복사
	local attrs = {}
	for _, key in {"BuildingId", "ItemName", "OwnerId", "Level", "UpgradeState", "UpgradeProgress", "AssignedPetId"} do
		attrs[key] = oldBuilding:GetAttribute(key)
	end

	-- 새 모델 클론
	local newModel = template:Clone()
	local newBuilding: BasePart

	if newModel:IsA("BasePart") then
		-- Part 템플릿: 바로 사용
		newBuilding = newModel
		newBuilding.CFrame = cframe
	elseif newModel:IsA("Model") then
		newBuilding = newModel.PrimaryPart or newModel:FindFirstChildWhichIsA("BasePart", true)
		if not newBuilding then
			-- 자손에서도 찾기
			for _, desc in newModel:GetDescendants() do
				if desc:IsA("BasePart") then
					newBuilding = desc
					break
				end
			end
		end
		if not newBuilding then
			warn("Model swap failed: no BasePart found - " .. itemName)
			newModel:Destroy()
			return nil
		end
		-- PrimaryPart 자동 설정
		if not newModel.PrimaryPart then
			newModel.PrimaryPart = newBuilding
		end
		-- mainPart→Pivot 오프셋으로 배치 (PlotManager와 동일)
		local mainToPivot = newBuilding.CFrame:ToObjectSpace(newModel:GetPivot())
		newModel:PivotTo(cframe * mainToPivot)
	else
		newModel:Destroy()
		return nil
	end

	-- Anchor all parts
	if newModel:IsA("Model") then
		for _, desc in newModel:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
			end
		end
	else
		newBuilding.Anchored = true
	end

	-- 바닥 보정 (보이는 파트 기준, CollisionBox/투명 제외)
	if newModel:IsA("Model") and parent then
		local plot = parent
		local buildZone = plot:FindFirstChild("BuildZone", true)
		if buildZone then
			local buildZoneTop = buildZone.Position.Y + buildZone.Size.Y / 2
			local minY = math.huge
			-- Farm은 PrimaryPart(밭) 바닥만 기준 (호미 등 아래로 삐져나온 장식 무시)
			local snapParts = (itemName == "Farm" and newModel.PrimaryPart)
				and { newModel.PrimaryPart } or newModel:GetDescendants()
			for _, part in snapParts do
				if not part:IsA("BasePart") then continue end
				if part:GetAttribute("IsCollisionBox") then continue end
				if part.Transparency >= 0.99 then continue end
				local cf, s = part.CFrame, part.Size
				for sx = -1, 1, 2 do
					for sy = -1, 1, 2 do
						for sz = -1, 1, 2 do
							local p = cf:PointToWorldSpace(Vector3.new(sx*s.X/2, sy*s.Y/2, sz*s.Z/2))
							if p.Y < minY then minY = p.Y end
						end
					end
				end
			end
			if minY < math.huge then
				local yAdjust = buildZoneTop - minY
				if math.abs(yAdjust) > 0.01 then
					newModel:PivotTo(newModel:GetPivot() + Vector3.new(0, yAdjust, 0))
				end
			end
		end
	end

	-- 속성 적용
	for key, value in attrs do
		newBuilding:SetAttribute(key, value)
	end

	-- CollisionBox 생성
	local collisionSize = Constants.getCollisionSize(itemName)
	local box = Instance.new("Part")
	box.Name = "CollisionBox"
	box.Size = collisionSize
	box.Transparency = 1
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = true
	box.CanTouch = false
	box.CFrame = newBuilding.CFrame
	box:SetAttribute("IsCollisionBox", true)
	box.Parent = newBuilding

	-- 부모 설정 & 기존 건물 제거
	newModel.Parent = parent
	oldBuilding:Destroy()

	return newBuilding
end

----------------------------------------------------------------
-- 외형 변화 적용
-- 1순위: ServerStorage에 레벨별 모델이 있으면 스왑
-- 2순위: 없으면 크기 스케일 + 색상 밝기 변경 (폴백)
----------------------------------------------------------------
function UpgradeManager.applyVisualUpgrade(building: BasePart, level: number): BasePart
	local itemName = building:GetAttribute("ItemName") or ""

	-- 1. ReplicatedStorage/Buildings/{ItemName}/Level{N} 확인
	local buildingsFolder = ReplicatedStorage:FindFirstChild("Buildings")
	if buildingsFolder then
		local itemFolder = buildingsFolder:FindFirstChild(itemName)
		if itemFolder then
			local levelModel = itemFolder:FindFirstChild("Level" .. level)
				or itemFolder:FindFirstChild(itemName .. "_" .. level)
			if levelModel then
				local newBuilding = UpgradeManager._swapModel(building, levelModel)
				if newBuilding then
					print("Model swap complete: " .. itemName .. " → Level" .. level)
					return newBuilding
				end
			end
		end
	end

	-- 2. 폴백: 크기/색상 변경
	-- 원본 크기 저장 (최초 1회)
	local origSizeX = building:GetAttribute("OrigSizeX")
	if not origSizeX then
		building:SetAttribute("OrigSizeX", building.Size.X)
		building:SetAttribute("OrigSizeY", building.Size.Y)
		building:SetAttribute("OrigSizeZ", building.Size.Z)
		building:SetAttribute("OrigColorR", building.Color.R)
		building:SetAttribute("OrigColorG", building.Color.G)
		building:SetAttribute("OrigColorB", building.Color.B)
	end

	local origSize = Vector3.new(
		building:GetAttribute("OrigSizeX"),
		building:GetAttribute("OrigSizeY"),
		building:GetAttribute("OrigSizeZ")
	)
	local origColor = Color3.new(
		building:GetAttribute("OrigColorR"),
		building:GetAttribute("OrigColorG"),
		building:GetAttribute("OrigColorB")
	)

	-- 크기 스케일
	local scale = UpgradeCfg.SIZE_SCALE[level] or 1.0
	building.Size = origSize * scale

	-- 색상 밝기
	local brighten = UpgradeCfg.COLOR_BRIGHTEN[level] or 0
	building.Color = Color3.new(
		math.min(1, origColor.R + brighten),
		math.min(1, origColor.G + brighten),
		math.min(1, origColor.B + brighten)
	)

	return building
end

----------------------------------------------------------------
-- 건물이 수리중인지 확인 (외부 모듈 참조용)
----------------------------------------------------------------
function UpgradeManager.isUpgrading(building: BasePart): boolean
	local state = building:GetAttribute("UpgradeState") or ""
	return state == Constants.UpgradeState.Upgrading
end

-- 플레이어 퇴장 시 해당 건물들의 루프 정리
function UpgradeManager.cleanupPlayer(plot: Instance)
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") then
			local buildingId = child:GetAttribute("BuildingId")
			_activeLoops[buildingId] = nil
		end
	end
end

return UpgradeManager
