-- PlacementClient.client.luau
-- 상태머신 기반 빌드 오케스트레이터
-- 상태: Idle → BuildMode → Selected / PlacingNew → Moving → BuildMode

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- 모듈 로드
local shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(shared:WaitForChild("Constants"))
local BalanceConfig = require(shared:WaitForChild("BalanceConfig"))

local clientScript = script.Parent
local BuildUI = require(clientScript:WaitForChild("build"):WaitForChild("BuildUI"))
local InventoryUI = require(clientScript:WaitForChild("build"):WaitForChild("InventoryUI"))
local SelectionUI = require(clientScript:WaitForChild("build"):WaitForChild("SelectionUI"))
local MoveHandleUI = require(clientScript:WaitForChild("build"):WaitForChild("MoveHandleUI"))
local UpgradeUI = require(clientScript:WaitForChild("build"):WaitForChild("UpgradeUI"))
local PetListUI = require(clientScript:WaitForChild("build"):WaitForChild("PetListUI"))
local CurrencyUI = require(clientScript:WaitForChild("build"):WaitForChild("CurrencyUI"))

local HighlightSystem = require(clientScript:WaitForChild("systems"):WaitForChild("HighlightSystem"))
local CollisionDetector = require(clientScript:WaitForChild("systems"):WaitForChild("CollisionDetector"))
local GridSnap = require(clientScript:WaitForChild("systems"):WaitForChild("GridSnap"))
local DragHandler = require(clientScript:WaitForChild("systems"):WaitForChild("DragHandler"))
local UpgradeDisplay = require(clientScript:WaitForChild("systems"):WaitForChild("UpgradeDisplay"))
local PetVisuals = require(clientScript:WaitForChild("systems"):WaitForChild("PetVisuals"))
local LevelBadge = require(clientScript:WaitForChild("systems"):WaitForChild("LevelBadge"))
local WeatherVFX = require(clientScript:WaitForChild("systems"):WaitForChild("WeatherVFX"))

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placeBuildingEvent = remotes:WaitForChild("PlaceBuilding")
local moveBuildingEvent = remotes:WaitForChild("MoveBuilding")
local storeBuildingEvent = remotes:WaitForChild("StoreBuilding")
local getInventoryFunc = remotes:WaitForChild("GetInventory")
local inventoryUpdateEvent = remotes:WaitForChild("InventoryUpdate")
local startUpgradeEvent = remotes:WaitForChild("StartUpgrade")
local cancelUpgradeEvent = remotes:WaitForChild("CancelUpgrade")
local assignPetEvent = remotes:WaitForChild("AssignPet")
local unassignPetEvent = remotes:WaitForChild("UnassignPet")
local getPetsFunc = remotes:WaitForChild("GetPets")
local upgradeStateChangedEvent = remotes:WaitForChild("UpgradeStateChanged")
local currencyUpdateEvent = remotes:WaitForChild("CurrencyUpdate")
local getCurrencyFunc = remotes:WaitForChild("GetCurrency")

local itemsFolder = ReplicatedStorage:WaitForChild("Items")

-- 상태
local BuildState = Constants.BuildState
local currentState = BuildState.Idle

-- 선택/이동 관련 변수
local selectedBuilding = nil       -- 선택된 건물 (BasePart)
local selectedBuildingId = nil     -- 선택된 건물 ID
local previewPart = nil            -- 배치/이동 프리뷰 파트
local previewItemName = nil        -- 배치 중인 아이템 이름
local currentRotationY = 0         -- 현재 Y 회전 (라디안)
local originalCFrame = nil         -- 이동 전 원래 CFrame (Cancel 복원용)
local originalColor = nil          -- 프리뷰 원래 색상 (충돌 표시 복원용)
local hoveredPart = nil            -- 현재 호버 중인 파트
local currentBuildZone = nil       -- 현재 드래그 중인 BuildZone
local hasCollision = false         -- 현재 충돌 상태
local inventory = {}               -- 로컬 인벤토리 캐시

-- 렌더 연결
local renderConnection = nil

-- 이동 종료 시 CollisionBox 복원
local function restoreCollisionBox(building: BasePart)
	local box = building:FindFirstChild("CollisionBox")
	if box then
		box.CanQuery = true
		box.CFrame = building.CFrame
	end
end

----------------------------------------------------------------
-- 유틸리티 함수
----------------------------------------------------------------

-- 플레이어의 BuildZone 찾기
local function getMyBuildZone(): BasePart?
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end

	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == player.Name then
			local bz = plot:FindFirstChild("BuildZone", true)
			if bz then return bz end
		end
	end
	return nil
end

-- 플레이어 플롯 찾기
local function getMyPlot()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == player.Name then
			return plot
		end
	end
	return nil
end

-- 파트가 배치된 건물인지 확인 (BuildingId 속성으로 식별)
local function isBuildingPart(part: BasePart): boolean
	if not part then return false end
	return part:GetAttribute("BuildingId") ~= nil
end

-- 파트가 내 건물인지 확인
local function isMyBuilding(part: BasePart): boolean
	if not part then return false end
	local ownerId = part:GetAttribute("OwnerId")
	return ownerId == player.UserId
end

-- 프리뷰 파트 생성
local function createPreview(itemName: string): BasePart?
	local template = itemsFolder:FindFirstChild(itemName)
	if not template then return nil end

	local part = template:Clone()
	part.Name = "PlacementPreview"
	part.Transparency = 0.5
	part.CanCollide = false
	part.Anchored = true
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute("ItemName", itemName) -- CollisionDetector에서 collisionSize 조회용
	part.Parent = workspace
	return part
end

-- 프리뷰 제거
local function removePreview()
	if previewPart then
		HighlightSystem.removeFrom(previewPart)
		previewPart:Destroy()
		previewPart = nil
	end
	originalColor = nil
end

-- 충돌 상태 업데이트 (프리뷰 파트 기준, CollisionBox 기반)
local function updateCollisionState()
	if not previewPart then
		hasCollision = false
		return
	end

	-- 이동 중인 건물의 CollisionBox를 무시 목록에 추가
	local ignoreParts = { previewPart }
	if currentState == BuildState.Moving and selectedBuilding then
		local myBox = selectedBuilding:FindFirstChild("CollisionBox")
		if myBox then
			table.insert(ignoreParts, myBox)
		end
	end

	local colliding = CollisionDetector.checkCollision(previewPart, ignoreParts)

	hasCollision = colliding

	if colliding then
		if not originalColor then
			originalColor = previewPart.Color
		end
		previewPart.Color = Color3.fromRGB(255, 50, 50)
		MoveHandleUI.setPlaceEnabled(false)
	else
		if originalColor then
			previewPart.Color = originalColor
		end
		MoveHandleUI.setPlaceEnabled(true)
	end
end

----------------------------------------------------------------
-- 상태 전환 함수
----------------------------------------------------------------

local function setState(newState: string)
	currentState = newState
end

-- Idle 상태로 전환
local function toIdle()
	setState(BuildState.Idle)

	-- UI 숨기기
	BuildUI.setBuildMode(false)
	InventoryUI.hide()
	SelectionUI.hide()
	MoveHandleUI.hide()
	UpgradeUI.hide()
	PetListUI.hide()
	HighlightSystem.clear()
	DragHandler.stopDrag()
	removePreview()

	selectedBuilding = nil
	selectedBuildingId = nil
	hoveredPart = nil
	currentBuildZone = nil

	-- 렌더 연결 해제
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

-- BuildMode 상태로 전환
local function toBuildMode()
	setState(BuildState.BuildMode)

	BuildUI.setBuildMode(true)
	SelectionUI.hide()
	MoveHandleUI.hide()
	UpgradeUI.hide()
	PetListUI.hide()
	DragHandler.stopDrag()
	removePreview()

	selectedBuilding = nil
	selectedBuildingId = nil
	hoveredPart = nil

	-- 인벤토리 표시
	InventoryUI.show()

	-- 호버 렌더링 시작
	if renderConnection then
		renderConnection:Disconnect()
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		if currentState ~= BuildState.BuildMode then return end

		local target = mouse.Target
		if target and isBuildingPart(target) and isMyBuilding(target) then
			if hoveredPart ~= target then
				HighlightSystem.clear()
				hoveredPart = target
				HighlightSystem.setHover(target)
			end
		else
			if hoveredPart then
				HighlightSystem.clear()
				hoveredPart = nil
			end
		end
	end)
end

-- Selected 상태로 전환
local function toSelected(building: BasePart)
	setState(BuildState.Selected)

	selectedBuilding = building
	selectedBuildingId = building:GetAttribute("BuildingId")

	-- 하이라이트
	HighlightSystem.clear()
	HighlightSystem.setSelected(building)

	-- UI
	InventoryUI.hide()
	MoveHandleUI.hide()
	UpgradeUI.hide()
	PetListUI.hide()

	-- 건물 상태에 따라 동적 버튼 표시
	local upgradeState = building:GetAttribute("UpgradeState") or ""
	if upgradeState == Constants.UpgradeState.Upgrading then
		SelectionUI.showUpgrading()
	else
		local level = building:GetAttribute("Level") or 1
		SelectionUI.showNormal(level, BalanceConfig.Upgrade.MAX_LEVEL)
	end
	SelectionUI.show()

	-- 호버 렌더링 중지
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

-- Moving 상태로 전환 (기존 건물 이동)
local function toMoving(building: BasePart)
	setState(BuildState.Moving)

	selectedBuilding = building
	selectedBuildingId = building:GetAttribute("BuildingId")
	originalCFrame = building.CFrame
	previewItemName = building:GetAttribute("ItemName")
	originalColor = nil -- 이전 색상 초기화

	-- 건물을 투명하게 (이동 프리뷰로 전환)
	building.Transparency = 0.5
	building.CanCollide = false
	previewPart = building -- 기존 건물을 프리뷰로 사용

	-- 이동 중 CollisionBox 비활성화 (자기 자신과 충돌 방지)
	local myBox = building:FindFirstChild("CollisionBox")
	if myBox then
		myBox.CanQuery = false
	end

	-- BuildZone 찾기
	currentBuildZone = getMyBuildZone()

	-- 현재 회전값 추출 (BuildZone 기준 상대 회전)
	local _, bzYRot, _ = currentBuildZone.CFrame:ToEulerAnglesYXZ()
	local _, yRot, _ = building.CFrame:ToEulerAnglesYXZ()
	currentRotationY = GridSnap.snapRotation(yRot - bzYRot)

	-- UI
	SelectionUI.hide()
	InventoryUI.hide()
	MoveHandleUI.show()

	-- 드래그 시작
	if currentBuildZone then
		DragHandler.init(GridSnap)
		DragHandler.startDrag(currentBuildZone, previewPart, currentRotationY, function(newCFrame)
			if previewPart then
				previewPart.CFrame = newCFrame
				updateCollisionState()
			end
		end)
	end
end

-- PlacingNew 상태로 전환 (인벤토리에서 새 건물 배치)
local function toPlacingNew(itemName: string)
	setState(BuildState.PlacingNew)

	previewItemName = itemName

	-- BuildZone 찾기
	currentBuildZone = getMyBuildZone()
	if not currentBuildZone then
		print("BuildZone 없음!")
		toBuildMode()
		return
	end

	-- 프리뷰 생성
	removePreview()
	previewPart = createPreview(itemName)
	if not previewPart then
		print("아이템 템플릿 없음:", itemName)
		toBuildMode()
		return
	end

	-- 캐릭터 눈앞에 초기 배치 (그리드 클램핑에 collisionSize 사용)
	currentRotationY = 0
	local collisionSize = Constants.getCollisionSize(itemName)
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local frontPos = hrp.Position + hrp.CFrame.LookVector * BalanceConfig.Building.PLACEMENT_PREVIEW_DISTANCE
			local snappedCFrame = GridSnap.snapToGrid(currentBuildZone, frontPos, collisionSize)
			previewPart.CFrame = snappedCFrame
		end
	end

	-- 하이라이트
	HighlightSystem.applyTo(previewPart, Constants.HIGHLIGHT_COLORS.Selected, 0.6)

	-- UI
	InventoryUI.hide()
	SelectionUI.hide()
	MoveHandleUI.show()

	-- 드래그 시작
	DragHandler.init(GridSnap)
	DragHandler.startDrag(currentBuildZone, previewPart, currentRotationY, function(newCFrame)
		if previewPart then
			previewPart.CFrame = newCFrame
			updateCollisionState()
		end
	end)
end

----------------------------------------------------------------
-- UI 콜백 초기화
----------------------------------------------------------------

-- BuildUI: 빌드 모드 토글
BuildUI.init(function()
	if currentState == BuildState.Idle then
		toBuildMode()
	elseif currentState == BuildState.BuildMode then
		toIdle()
	elseif currentState == BuildState.Selected or currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
		-- 빌드모드에서 나가기
		if currentState == BuildState.Moving and selectedBuilding and originalCFrame then
			-- 이동 취소: 원래 위치 복원
			selectedBuilding.CFrame = originalCFrame
			selectedBuilding.Transparency = 0
			selectedBuilding.CanCollide = true
			restoreCollisionBox(selectedBuilding)
			DragHandler.stopDrag()
			previewPart = nil
		elseif currentState == BuildState.PlacingNew then
			DragHandler.stopDrag()
			removePreview()
		end
		toIdle()
	end
end)

-- InventoryUI: 아이템 선택
InventoryUI.init(function(itemName: string)
	if currentState == BuildState.BuildMode then
		toPlacingNew(itemName)
	end
end)

-- SelectionUI: 동적 버튼 콜백
SelectionUI.init({
	onStore = function()
		if currentState == BuildState.Selected and selectedBuilding then
			local buildingId = selectedBuilding:GetAttribute("BuildingId")
			if buildingId then
				storeBuildingEvent:FireServer(buildingId)
			end
			HighlightSystem.clear()
			toBuildMode()
		end
	end,

	onCancel = function()
		if currentState == BuildState.Selected then
			HighlightSystem.clear()
			toBuildMode()
		end
	end,

	onMove = function()
		if currentState == BuildState.Selected and selectedBuilding then
			toMoving(selectedBuilding)
		end
	end,

	onUpgrade = function()
		if currentState == BuildState.Selected and selectedBuilding then
			local level = selectedBuilding:GetAttribute("Level") or 1
			local itemName = selectedBuilding:GetAttribute("ItemName")
			local buildingInfo = Constants.BUILDINGS[itemName]
			local displayName = buildingInfo and buildingInfo.name or itemName
			UpgradeUI.show(level, displayName)
		end
	end,

	onCancelUpgrade = function()
		if currentState == BuildState.Selected and selectedBuilding then
			local buildingId = selectedBuilding:GetAttribute("BuildingId")
			if buildingId then
				cancelUpgradeEvent:FireServer(buildingId)
			end
			HighlightSystem.clear()
			toBuildMode()
		end
	end,

	onAssignPet = function()
		if currentState == BuildState.Selected and selectedBuilding then
			local buildingId = selectedBuilding:GetAttribute("BuildingId")
			-- 서버에서 펫 목록 가져오기
			task.spawn(function()
				local pets = getPetsFunc:InvokeServer()
				if pets and #pets > 0 then
					PetListUI.show(pets, buildingId)
				else
					PetListUI.show({}, buildingId)
				end
			end)
		end
	end,
})

-- UpgradeUI: 업그레이드 확인 다이얼로그
UpgradeUI.init({
	onConfirm = function()
		if selectedBuilding then
			local buildingId = selectedBuilding:GetAttribute("BuildingId")
			if buildingId then
				startUpgradeEvent:FireServer(buildingId)
			end
		end
		UpgradeUI.hide()
		HighlightSystem.clear()
		toBuildMode()
	end,

	onCancel = function()
		UpgradeUI.hide()
	end,
})

-- PetListUI: 펫 배치/회수
PetListUI.init({
	onAssign = function(petId, buildingId)
		assignPetEvent:FireServer(petId, buildingId)
		PetListUI.hide()
		HighlightSystem.clear()
		toBuildMode()
	end,

	onUnassign = function(petId)
		unassignPetEvent:FireServer(petId)
		PetListUI.hide()
		HighlightSystem.clear()
		toBuildMode()
	end,

	onClose = function()
		PetListUI.hide()
	end,
})

-- 배치 확정 (UI 버튼 + 마우스 클릭 공용)
local function confirmPlace()
	if hasCollision then return end

	if currentState == BuildState.PlacingNew and previewPart then
		local finalCFrame = previewPart.CFrame
		DragHandler.stopDrag()
		removePreview()
		placeBuildingEvent:FireServer(previewItemName, finalCFrame)
		toBuildMode()

	elseif currentState == BuildState.Moving and selectedBuilding then
		local finalCFrame = selectedBuilding.CFrame
		local buildingId = selectedBuilding:GetAttribute("BuildingId")
		DragHandler.stopDrag()

		selectedBuilding.Transparency = 0
		selectedBuilding.CanCollide = true
		HighlightSystem.removeFrom(selectedBuilding)
		restoreCollisionBox(selectedBuilding)
		previewPart = nil

		if buildingId then
			moveBuildingEvent:FireServer(buildingId, finalCFrame)
		end
		toBuildMode()
	end
end

-- MoveHandleUI: Place/Rotate/Cancel
MoveHandleUI.init({
	onPlace = confirmPlace,

	onRotateLeft = function()
		if currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
			DragHandler.rotate(-1)
		end
	end,

	onRotateRight = function()
		if currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
			DragHandler.rotate(1)
		end
	end,

	onCancel = function()
		if currentState == BuildState.Moving and selectedBuilding and originalCFrame then
			selectedBuilding.CFrame = originalCFrame
			selectedBuilding.Transparency = 0
			selectedBuilding.CanCollide = true
			restoreCollisionBox(selectedBuilding)
			HighlightSystem.removeFrom(selectedBuilding)
			DragHandler.stopDrag()
			previewPart = nil
			toBuildMode()
		elseif currentState == BuildState.PlacingNew then
			DragHandler.stopDrag()
			removePreview()
			toBuildMode()
		end
	end,
})

----------------------------------------------------------------
-- 입력 처리
----------------------------------------------------------------

-- 마우스/키보드 입력 (gameProcessed로 UI 클릭과 구분)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- 다이얼로그가 열려 있으면 입력 무시
	if UpgradeUI.isVisible() or PetListUI.isVisible() then return end

	-- 마우스 클릭: 배치 확정 / BuildMode에서 건물 선택
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
		if currentState == BuildState.PlacingNew or currentState == BuildState.Moving then
			confirmPlace()
		elseif currentState == BuildState.BuildMode then
			local target = mouse.Target
			if target and isBuildingPart(target) and isMyBuilding(target) then
				toSelected(target)
			end
		end
	end

	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Escape then
		if currentState == BuildState.PlacingNew then
			DragHandler.stopDrag()
			removePreview()
			toBuildMode()
		elseif currentState == BuildState.Moving and selectedBuilding and originalCFrame then
			selectedBuilding.CFrame = originalCFrame
			selectedBuilding.Transparency = 0
			selectedBuilding.CanCollide = true
			restoreCollisionBox(selectedBuilding)
			HighlightSystem.removeFrom(selectedBuilding)
			DragHandler.stopDrag()
			previewPart = nil
			toBuildMode()
		elseif currentState == BuildState.Selected then
			HighlightSystem.clear()
			toBuildMode()
		elseif currentState == BuildState.BuildMode then
			toIdle()
		end

	elseif input.KeyCode == Enum.KeyCode.B then
		if currentState == BuildState.Idle then
			toBuildMode()
		elseif currentState == BuildState.BuildMode then
			toIdle()
		elseif currentState == BuildState.Selected or currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
			if currentState == BuildState.Moving and selectedBuilding and originalCFrame then
				selectedBuilding.CFrame = originalCFrame
				selectedBuilding.Transparency = 0
				selectedBuilding.CanCollide = true
				restoreCollisionBox(selectedBuilding)
				DragHandler.stopDrag()
				previewPart = nil
			elseif currentState == BuildState.PlacingNew then
				DragHandler.stopDrag()
				removePreview()
			end
			toIdle()
		end

	elseif input.KeyCode == Enum.KeyCode.Q then
		if currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
			DragHandler.rotate(-1)
		end
	elseif input.KeyCode == Enum.KeyCode.E then
		if currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
			DragHandler.rotate(1)
		end
	else
		-- 숫자키 1~9: 인벤토리 단축키
		local numberKeys = {
			[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
			[Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9,
		}
		local index = numberKeys[input.KeyCode]
		if index and currentState == BuildState.BuildMode then
			InventoryUI.selectByIndex(index)
		end
	end
end)

----------------------------------------------------------------
-- 인벤토리 동기화
----------------------------------------------------------------

inventoryUpdateEvent.OnClientEvent:Connect(function(inv)
	inventory = inv
	InventoryUI.updateInventory(inv)
end)

task.spawn(function()
	local inv = getInventoryFunc:InvokeServer()
	if inv then
		inventory = inv
		InventoryUI.updateInventory(inv)
	end
end)

----------------------------------------------------------------
-- 코인 동기화
----------------------------------------------------------------

CurrencyUI.init()

currencyUpdateEvent.OnClientEvent:Connect(function(coins)
	CurrencyUI.updateCoins(coins)
end)

task.spawn(function()
	local coins = getCurrencyFunc:InvokeServer()
	if coins then
		CurrencyUI.updateCoins(coins)
	end
end)

----------------------------------------------------------------
-- 업그레이드/펫 이벤트 수신
----------------------------------------------------------------

upgradeStateChangedEvent.OnClientEvent:Connect(function(buildingId, action, data)
	-- 업그레이드 완료/취소 시 선택 중이면 UI 갱신
	if currentState == BuildState.Selected and selectedBuilding then
		if selectedBuilding:GetAttribute("BuildingId") == buildingId then
			-- UI 갱신 (건물 상태 변경 반영)
			task.wait(0.1) -- 속성 반영 대기
			toSelected(selectedBuilding)
		end
	end
end)

----------------------------------------------------------------
-- 플롯 감시 (업그레이드 게이지 + 펫 비주얼)
----------------------------------------------------------------

task.spawn(function()
	-- 플롯이 배정될 때까지 대기
	local plotsFolder = workspace:WaitForChild("Plots")
	local myPlot = nil

	while not myPlot do
		task.wait(0.5)
		for _, plot in plotsFolder:GetChildren() do
			if plot:GetAttribute("Owner") == player.Name then
				myPlot = plot
				break
			end
		end
	end

	-- 업그레이드 게이지 + 펫 비주얼 + 레벨 뱃지 감시 시작
	UpgradeDisplay.scanPlot(myPlot)
	PetVisuals.scanPlot(myPlot)
	LevelBadge.scanPlot(myPlot)
end)

-- 날씨 VFX 초기화
WeatherVFX.init()

print("PlacementClient 로드됨 - 빌드 시스템 v3 (업그레이드 + 펫 + 날씨)")
