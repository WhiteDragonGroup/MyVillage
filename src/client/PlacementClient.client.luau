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

local clientScript = script.Parent
local BuildUI = require(clientScript:WaitForChild("build"):WaitForChild("BuildUI"))
local InventoryUI = require(clientScript:WaitForChild("build"):WaitForChild("InventoryUI"))
local SelectionUI = require(clientScript:WaitForChild("build"):WaitForChild("SelectionUI"))
local MoveHandleUI = require(clientScript:WaitForChild("build"):WaitForChild("MoveHandleUI"))

local HighlightSystem = require(clientScript:WaitForChild("systems"):WaitForChild("HighlightSystem"))
local CollisionDetector = require(clientScript:WaitForChild("systems"):WaitForChild("CollisionDetector"))
local GridSnap = require(clientScript:WaitForChild("systems"):WaitForChild("GridSnap"))
local DragHandler = require(clientScript:WaitForChild("systems"):WaitForChild("DragHandler"))

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placeBuildingEvent = remotes:WaitForChild("PlaceBuilding")
local moveBuildingEvent = remotes:WaitForChild("MoveBuilding")
local storeBuildingEvent = remotes:WaitForChild("StoreBuilding")
local getInventoryFunc = remotes:WaitForChild("GetInventory")
local inventoryUpdateEvent = remotes:WaitForChild("InventoryUpdate")

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
local hoveredPart = nil            -- 현재 호버 중인 파트
local currentBuildZone = nil       -- 현재 드래그 중인 BuildZone
local hasCollision = false         -- 현재 충돌 상태
local inventory = {}               -- 로컬 인벤토리 캐시

-- 렌더 연결
local renderConnection = nil

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
end

-- 충돌 상태 업데이트 (프리뷰 파트 기준)
local function updateCollisionState()
	if not previewPart then
		hasCollision = false
		return
	end

	-- 충돌 체크를 위해 임시로 CanCollide 활성화
	previewPart.CanCollide = true
	local colliding = CollisionDetector.checkCollision(previewPart, { previewPart })
	previewPart.CanCollide = false

	hasCollision = colliding

	if colliding then
		HighlightSystem.applyTo(previewPart, Constants.HIGHLIGHT_COLORS.Collision, 0.5)
		MoveHandleUI.setPlaceEnabled(false)
	else
		HighlightSystem.applyTo(previewPart, Constants.HIGHLIGHT_COLORS.Selected, 0.6)
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

	-- 건물을 투명하게 (이동 프리뷰로 전환)
	building.Transparency = 0.5
	building.CanCollide = false
	previewPart = building -- 기존 건물을 프리뷰로 사용

	-- BuildZone 찾기
	currentBuildZone = getMyBuildZone()

	-- 현재 회전값 추출
	local _, yRot, _ = building.CFrame:ToEulerAnglesYXZ()
	currentRotationY = GridSnap.snapRotation(yRot)

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

	-- 캐릭터 눈앞에 초기 배치
	currentRotationY = 0
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local frontPos = hrp.Position + hrp.CFrame.LookVector * 10
			local snappedCFrame = GridSnap.snapToGrid(currentBuildZone, frontPos, previewPart.Size.Y)
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

-- SelectionUI: Store/Cancel/Move
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
})

-- MoveHandleUI: Place/Rotate/Cancel
MoveHandleUI.init({
	onPlace = function()
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
			previewPart = nil

			if buildingId then
				moveBuildingEvent:FireServer(buildingId, finalCFrame)
			end
			toBuildMode()
		end
	end,

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

-- 마우스 클릭: BuildMode에서 건물 선택
mouse.Button1Down:Connect(function()
	if currentState == BuildState.BuildMode then
		local target = mouse.Target
		if target and isBuildingPart(target) and isMyBuilding(target) then
			toSelected(target)
		end
	end
end)

-- 키보드 입력
UserInputService.InputBegan:Connect(function(input, gameProcessed)
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

	elseif input.KeyCode == Enum.KeyCode.Q then
		if currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
			DragHandler.rotate(-1)
		end
	elseif input.KeyCode == Enum.KeyCode.E then
		if currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
			DragHandler.rotate(1)
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		if currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
			DragHandler.rotate(1)
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

print("PlacementClient 로드됨 - 빌드 시스템 v2")
