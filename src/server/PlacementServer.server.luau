-- PlacementServer.server.luau
-- 서버: PlaceBuilding, MoveBuilding, StoreBuilding 핸들러
-- 소유권 검증 → BuildZone 범위 체크 → 충돌 체크 → 인벤토리 연동

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placeBuildingEvent = remotes:WaitForChild("PlaceBuilding")
local moveBuildingEvent = remotes:WaitForChild("MoveBuilding")
local storeBuildingEvent = remotes:WaitForChild("StoreBuilding")
local getInventoryFunc = remotes:WaitForChild("GetInventory")

local itemsFolder = ReplicatedStorage:WaitForChild("Items")
local plotsFolder = workspace:WaitForChild("Plots")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local serverScript = script.Parent
local InventoryManager = require(serverScript:WaitForChild("InventoryManager"))
local UpgradeManager = require(serverScript:WaitForChild("UpgradeManager"))

----------------------------------------------------------------
-- 유틸리티
----------------------------------------------------------------

-- 플레이어의 플롯 찾기
local function getPlayerPlot(player: Player)
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == player.Name then
			return plot
		end
	end
	return nil
end

-- 위치가 BuildZone 안에 있는지 확인
local function isInsideBuildZone(buildZone: BasePart, position: Vector3): boolean
	local localPos = buildZone.CFrame:PointToObjectSpace(position)
	local halfSize = buildZone.Size / 2
	return math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Z) <= halfSize.Z
end

-- BuildingId로 건물 찾기 (특정 플롯 내)
local function findBuildingById(plot, buildingId: string): BasePart?
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") == buildingId then
			return child
		end
	end
	return nil
end

-- 건물 전체 제거 (Model이면 Model 통째로, BasePart이면 그것만)
local function destroyBuilding(mainPart: BasePart)
	local parent = mainPart.Parent
	if parent and parent:IsA("Model") then
		parent:Destroy()
	else
		mainPart:Destroy()
	end
end

-- CollisionBox 생성 (건물의 자식으로 추가, 투명 충돌 판정용)
local function createCollisionBox(parent: BasePart, itemName: string): BasePart
	local collisionSize = Constants.getCollisionSize(itemName)

	local box = Instance.new("Part")
	box.Name = "CollisionBox"
	box.Size = collisionSize
	box.Transparency = 1
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = true
	box.CanTouch = false
	box.CFrame = parent.CFrame
	box:SetAttribute("IsCollisionBox", true)
	box.Parent = parent

	-- 건물 이동 시 CollisionBox도 따라가도록 CFrame 동기화는
	-- 부모-자식 관계로 자동 처리됨 (Weld 불필요 — 서버에서 건물 CFrame 직접 조작)

	return box
end

-- CollisionBox CFrame 동기화 (건물 CFrame 변경 후 호출)
local function syncCollisionBox(building: BasePart)
	local box = building:FindFirstChild("CollisionBox")
	if box then
		box.CFrame = building.CFrame
	end
end

-- 서버 충돌 체크 (CollisionBox 기반, GetPartBoundsInBox 사용)
-- probeSize: 배치할 건물의 충돌 사이즈, probeCFrame: 배치 위치
local function checkServerCollision(probeCFrame: CFrame, probeSize: Vector3, ignoreParts: { Instance }?): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local combined = {}
	if ignoreParts then
		for _, p in ignoreParts do
			table.insert(combined, p)
		end
	end

	-- 모든 플레이어 캐릭터 무시
	for _, plr in game:GetService("Players"):GetPlayers() do
		if plr.Character then
			table.insert(combined, plr.Character)
		end
	end

	params.FilterDescendantsInstances = combined

	local touching = workspace:GetPartBoundsInBox(probeCFrame, probeSize, params)

	-- CollisionBox 파트만 충돌로 판정
	for _, p in touching do
		if p:GetAttribute("IsCollisionBox") == true then
			return true
		end
	end

	return false
end

----------------------------------------------------------------
-- PlaceBuilding: 인벤토리에서 새 건물 배치
----------------------------------------------------------------
placeBuildingEvent.OnServerEvent:Connect(function(player, itemName, cframe, level)
	-- 1. 타입 검증
	if typeof(itemName) ~= "string" or typeof(cframe) ~= "CFrame" then
		warn(player.Name .. " - 잘못된 요청 형식")
		return
	end
	-- 레벨 검증
	if typeof(level) ~= "number" then level = 1 end
	level = math.clamp(math.floor(level), 1, 5)

	-- 2. 아이템 템플릿 확인
	local template = itemsFolder:FindFirstChild(itemName)
	if not template then
		warn("아이템 없음:", itemName)
		return
	end

	-- 3. 플레이어 플롯 찾기
	local plot = getPlayerPlot(player)
	if not plot then
		warn(player.Name .. " - 배정된 플롯 없음")
		return
	end

	-- 4. BuildZone 범위 체크
	local buildZone = plot:FindFirstChild("BuildZone", true)
	if not buildZone then
		warn(player.Name .. " - BuildZone 없음")
		return
	end

	if not isInsideBuildZone(buildZone, cframe.Position) then
		warn(player.Name .. " - BuildZone 밖에 배치 시도")
		return
	end

	-- 5. 인벤토리 확인 (레벨 포함)
	if not InventoryManager.hasItem(player, itemName, 1, level) then
		warn(player.Name .. " - 인벤토리에 " .. itemName .. " Lv" .. level .. " 없음")
		return
	end

	-- 6. 서버 충돌 체크 (CollisionBox 기반, 고정 사이즈)
	local collisionSize = Constants.getCollisionSize(itemName)
	if checkServerCollision(cframe, collisionSize) then
		warn(player.Name .. " - 충돌 감지, 배치 취소")
		return
	end

	-- 7. 인벤토리 차감
	InventoryManager.removeItem(player, itemName, 1, level)

	-- 8. 건물 생성 (레벨별 모델 확인)
	local buildingsFolder = ReplicatedStorage:FindFirstChild("Buildings")
	local useModel = nil

	if buildingsFolder then
		local itemFolder = buildingsFolder:FindFirstChild(itemName)
		if itemFolder then
			-- "Level1" 또는 "Mine_1" 형식 모두 지원
			useModel = itemFolder:FindFirstChild("Level" .. level)
				or itemFolder:FindFirstChild(itemName .. "_" .. level)
			-- 디버그: 모델 탐색 결과
			print("[PlaceBuilding] " .. itemName .. " Lv" .. level
				.. " | Buildings폴더=" .. tostring(buildingsFolder ~= nil)
				.. " | 아이템폴더=" .. tostring(itemFolder ~= nil)
				.. " | 모델=" .. tostring(useModel))
			if itemFolder then
				print("[PlaceBuilding] " .. itemName .. " 폴더 자식:")
				for _, c in itemFolder:GetChildren() do
					print("  → " .. c.Name .. " (" .. c.ClassName .. ")")
				end
			end
		else
			print("[PlaceBuilding] Buildings/" .. itemName .. " 폴더 없음")
		end
	else
		print("[PlaceBuilding] Buildings 폴더 없음!")
	end

	local item
	if useModel then
		item = useModel:Clone()
	else
		item = template:Clone()
	end

	-- 8.1. 위치/부모 설정 (BasePart vs Model 분기)
	local mainPart: BasePart
	if item:IsA("BasePart") then
		item.CFrame = cframe
		item.Anchored = true
		item.CanCollide = true
		item.Parent = plot
		mainPart = item
	elseif item:IsA("Model") then
		mainPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
		if not mainPart then
			warn(player.Name .. " - 모델에 BasePart 없음: " .. itemName)
			item:Destroy()
			InventoryManager.addItem(player, itemName, 1, level) -- 인벤토리 복구
			return
		end
		-- mainPart가 정확히 cframe에 오도록 모델 전체를 이동
		-- (클라이언트에서 이미 바닥 보정된 CFrame을 전송)
		local mainToPivot = mainPart.CFrame:ToObjectSpace(item:GetPivot())
		item:PivotTo(cframe * mainToPivot)
		item.Parent = plot
		mainPart.Anchored = true
	end

	-- 9. 건물 속성 설정 (mainPart에 부여)
	local buildingId = HttpService:GenerateGUID(false)
	mainPart:SetAttribute("BuildingId", buildingId)
	mainPart:SetAttribute("ItemName", itemName)
	mainPart:SetAttribute("OwnerId", player.UserId)
	mainPart:SetAttribute("Level", level)
	mainPart:SetAttribute("UpgradeState", "")
	mainPart:SetAttribute("UpgradeProgress", 0)
	mainPart:SetAttribute("AssignedPetId", "")

	-- 10. CollisionBox 생성 (고정 사이즈 충돌 판정용)
	createCollisionBox(mainPart, itemName)

	-- 11. 레벨별 외형 적용 (모델 스왑 없는 경우)
	if not useModel and level > 1 then
		UpgradeManager.applyVisualUpgrade(mainPart, level)
	end

	print(player.Name .. " → " .. plot.Name .. "에 " .. itemName .. " Lv" .. level .. " 배치 완료 (ID: " .. buildingId .. ")")
end)

----------------------------------------------------------------
-- MoveBuilding: 기존 건물 이동
----------------------------------------------------------------
moveBuildingEvent.OnServerEvent:Connect(function(player, buildingId, newCFrame)
	-- 1. 타입 검증
	if typeof(buildingId) ~= "string" or typeof(newCFrame) ~= "CFrame" then
		warn(player.Name .. " - 잘못된 이동 요청 형식")
		return
	end

	-- 2. 플레이어 플롯 찾기
	local plot = getPlayerPlot(player)
	if not plot then
		warn(player.Name .. " - 배정된 플롯 없음")
		return
	end

	-- 3. 건물 찾기
	local building = findBuildingById(plot, buildingId)
	if not building then
		warn(player.Name .. " - 건물 ID " .. buildingId .. " 찾을 수 없음")
		return
	end

	-- 4. 소유권 확인
	if building:GetAttribute("OwnerId") ~= player.UserId then
		warn(player.Name .. " - 소유하지 않은 건물 이동 시도")
		return
	end

	-- 4.5. 수리중 가드
	if UpgradeManager.isUpgrading(building) then
		warn(player.Name .. " - 수리중인 건물 이동 불가")
		return
	end

	-- 5. BuildZone 범위 체크
	local buildZone = plot:FindFirstChild("BuildZone", true)
	if not buildZone or not isInsideBuildZone(buildZone, newCFrame.Position) then
		warn(player.Name .. " - BuildZone 밖으로 이동 시도")
		return
	end

	-- 6. 서버 충돌 체크 (CollisionBox 기반, 자기 자신 제외)
	local itemName = building:GetAttribute("ItemName") or ""
	local collisionSize = Constants.getCollisionSize(itemName)
	local myCollisionBox = building:FindFirstChild("CollisionBox")
	local ignoreParts = {}
	if myCollisionBox then
		table.insert(ignoreParts, myCollisionBox)
	end

	if checkServerCollision(newCFrame, collisionSize, ignoreParts) then
		warn(player.Name .. " - 충돌 감지, 이동 취소")
		return
	end

	-- 이동 적용 (Model이면 PivotTo로 전체 이동, 보정 포함)
	local parentModel = building.Parent
	if parentModel and parentModel:IsA("Model") then
		local pivotCF = parentModel:GetPivot()
		local mainToPivot = building.CFrame:ToObjectSpace(pivotCF)
		parentModel:PivotTo(newCFrame * mainToPivot)

		-- Model 바닥 보정 (CollisionBox 임시 제거 후 GetBoundingBox)
		local buildZoneTop = buildZone.Position.Y + buildZone.Size.Y / 2
		local removed = {}
		for _, part in parentModel:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("IsCollisionBox") then
				table.insert(removed, { part = part, parent = part.Parent })
				part.Parent = nil
			end
		end
		local bbCF, bbSize = parentModel:GetBoundingBox()
		for _, info in removed do
			info.part.Parent = info.parent
		end
		local modelBottom = bbCF.Position.Y - bbSize.Y / 2
		local yAdjust = buildZoneTop - modelBottom
		if math.abs(yAdjust) > 0.01 then
			parentModel:PivotTo(parentModel:GetPivot() + Vector3.new(0, yAdjust, 0))
		end
	else
		building.CFrame = newCFrame
	end
	syncCollisionBox(building)

	print(player.Name .. " - " .. (itemName or "?") .. " 이동 완료")
end)

----------------------------------------------------------------
-- StoreBuilding: 건물을 인벤토리로 저장
----------------------------------------------------------------
storeBuildingEvent.OnServerEvent:Connect(function(player, buildingId)
	-- 1. 타입 검증
	if typeof(buildingId) ~= "string" then
		warn(player.Name .. " - 잘못된 저장 요청 형식")
		return
	end

	-- 2. 플레이어 플롯 찾기
	local plot = getPlayerPlot(player)
	if not plot then
		warn(player.Name .. " - 배정된 플롯 없음")
		return
	end

	-- 3. 건물 찾기
	local building = findBuildingById(plot, buildingId)
	if not building then
		warn(player.Name .. " - 건물 ID " .. buildingId .. " 찾을 수 없음")
		return
	end

	-- 4. 소유권 확인
	if building:GetAttribute("OwnerId") ~= player.UserId then
		warn(player.Name .. " - 소유하지 않은 건물 저장 시도")
		return
	end

	-- 4.5. 수리중 가드
	if UpgradeManager.isUpgrading(building) then
		warn(player.Name .. " - 수리중인 건물 보관 불가")
		return
	end

	-- 5. 인벤토리에 추가 (레벨 보존)
	local itemName = building:GetAttribute("ItemName")
	local level = building:GetAttribute("Level") or 1
	if itemName then
		InventoryManager.addItem(player, itemName, 1, level)
	end

	-- 6. 건물 제거 (Model이면 전체 제거)
	destroyBuilding(building)

	print(player.Name .. " - " .. (itemName or "?") .. " 저장 완료")
end)

----------------------------------------------------------------
-- GetInventory: 인벤토리 조회 (RemoteFunction)
----------------------------------------------------------------
getInventoryFunc.OnServerInvoke = function(player)
	return InventoryManager.getInventory(player)
end

print("PlacementServer 로드됨 - 빌드 시스템 v2")
