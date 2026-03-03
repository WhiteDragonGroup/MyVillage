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

-- 서버 충돌 체크 (CollisionBox 기반)
-- probeSize: 배치할 건물의 충돌 사이즈, probeCFrame: 배치 위치
local function checkServerCollision(probeCFrame: CFrame, probeSize: Vector3, ignoreParts: { Instance }?): boolean
	-- 임시 프로브 파트 생성
	local probe = Instance.new("Part")
	probe.Size = probeSize
	probe.CFrame = probeCFrame
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = true
	probe.Transparency = 1
	probe.Parent = workspace

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local combined = { probe }
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

	local touching = workspace:GetPartsInPart(probe, params)
	probe:Destroy()

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

	-- 6. 서버 충돌 체크 (CollisionBox 기반, 고정 사이즈)
	local collisionSize = Constants.getCollisionSize(itemName)
	if checkServerCollision(cframe, collisionSize) then
		warn(player.Name .. " - 충돌 감지, 배치 취소")
		return
	end

	-- 7. 인벤토리 차감
	InventoryManager.removeItem(player, itemName)

	-- 8. 건물 생성
	local item = template:Clone()
	item.CFrame = cframe
	item.Anchored = true
	item.CanCollide = true
	item.Parent = plot

	-- 9. 건물 속성 설정
	local buildingId = HttpService:GenerateGUID(false)
	item:SetAttribute("BuildingId", buildingId)
	item:SetAttribute("ItemName", itemName)
	item:SetAttribute("OwnerId", player.UserId)
	item:SetAttribute("Level", 1)
	item:SetAttribute("UpgradeState", "")
	item:SetAttribute("UpgradeProgress", 0)
	item:SetAttribute("AssignedPetId", "")

	-- 10. CollisionBox 생성 (고정 사이즈 충돌 판정용)
	createCollisionBox(item, itemName)

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

	-- 이동 적용
	building.CFrame = newCFrame
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
