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

local serverScript = script.Parent
local InventoryManager = require(serverScript:WaitForChild("InventoryManager"))

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

-- 서버 충돌 체크 (간단한 AABB)
local function checkServerCollision(part: BasePart, ignoreParts: { BasePart }?): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local filterList = ignoreParts or {}
	params.FilterDescendantsInstances = filterList

	local touching = workspace:GetPartsInPart(part, params)

	for _, p in touching do
		if p.Name ~= "BuildZone"
			and p.Name ~= "Baseplate"
			and p.Name ~= "Lobby"
			and not p:IsA("Terrain")
			and p.CanCollide then
			return true -- 충돌 있음
		end
	end

	return false
end

----------------------------------------------------------------
-- PlaceBuilding: 인벤토리에서 새 건물 배치
----------------------------------------------------------------
placeBuildingEvent.OnServerEvent:Connect(function(player, itemName, cframe)
	-- 1. 타입 검증
	if typeof(itemName) ~= "string" or typeof(cframe) ~= "CFrame" then
		warn(player.Name .. " - 잘못된 요청 형식")
		return
	end

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

	-- 5. 인벤토리 확인 & 차감
	if not InventoryManager.hasItem(player, itemName) then
		warn(player.Name .. " - 인벤토리에 " .. itemName .. " 없음")
		return
	end

	-- 6. 건물 생성 (충돌 체크용 임시 파트)
	local item = template:Clone()
	item.CFrame = cframe
	item.Anchored = true
	item.CanCollide = true
	item.Parent = plot

	-- 7. 서버 충돌 체크
	if checkServerCollision(item, { item }) then
		item:Destroy()
		warn(player.Name .. " - 충돌 감지, 배치 취소")
		return
	end

	-- 8. 인벤토리 차감
	InventoryManager.removeItem(player, itemName)

	-- 9. 건물 속성 설정
	local buildingId = HttpService:GenerateGUID(false)
	item:SetAttribute("BuildingId", buildingId)
	item:SetAttribute("ItemName", itemName)
	item:SetAttribute("OwnerId", player.UserId)

	print(player.Name .. " → " .. plot.Name .. "에 " .. itemName .. " 배치 완료 (ID: " .. buildingId .. ")")
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

	-- 5. BuildZone 범위 체크
	local buildZone = plot:FindFirstChild("BuildZone", true)
	if not buildZone or not isInsideBuildZone(buildZone, newCFrame.Position) then
		warn(player.Name .. " - BuildZone 밖으로 이동 시도")
		return
	end

	-- 6. 서버 충돌 체크 (자기 자신 제외)
	local oldCFrame = building.CFrame
	building.CFrame = newCFrame

	if checkServerCollision(building, { building }) then
		building.CFrame = oldCFrame -- 원래 위치로 복원
		warn(player.Name .. " - 충돌 감지, 이동 취소")
		return
	end

	print(player.Name .. " - " .. (building:GetAttribute("ItemName") or "?") .. " 이동 완료")
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

	-- 5. 인벤토리에 추가
	local itemName = building:GetAttribute("ItemName")
	if itemName then
		InventoryManager.addItem(player, itemName)
	end

	-- 6. 건물 제거
	building:Destroy()

	print(player.Name .. " - " .. (itemName or "?") .. " 저장 완료")
end)

----------------------------------------------------------------
-- GetInventory: 인벤토리 조회 (RemoteFunction)
----------------------------------------------------------------
getInventoryFunc.OnServerInvoke = function(player)
	return InventoryManager.getInventory(player)
end

print("PlacementServer 로드됨 - 빌드 시스템 v2")
