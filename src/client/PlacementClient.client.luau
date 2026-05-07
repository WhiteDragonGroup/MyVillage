-- PlacementClient.client.luau
-- 상태머신 기반 빌드 오케스트레이터
-- 상태: Idle → BuildMode → Selected / PlacingNew → Moving → BuildMode

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
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
local MainHUD = require(clientScript:WaitForChild("build"):WaitForChild("MainHUD"))
local ShopUI = require(clientScript:WaitForChild("build"):WaitForChild("ShopUI"))
local CollectionUI = require(clientScript:WaitForChild("build"):WaitForChild("CollectionUI"))
local GiftUI = require(clientScript:WaitForChild("build"):WaitForChild("GiftUI"))
local SettingsUI = require(clientScript:WaitForChild("build"):WaitForChild("SettingsUI"))
local PetDetailUI = require(clientScript:WaitForChild("build"):WaitForChild("PetDetailUI"))
local AdminUI = require(clientScript:WaitForChild("build"):WaitForChild("AdminUI"))
local DialogUI = require(clientScript:WaitForChild("build"):WaitForChild("DialogUI"))
local PetSellUI = require(clientScript:WaitForChild("build"):WaitForChild("PetSellUI"))
local EggInfoUI = require(clientScript:WaitForChild("build"):WaitForChild("EggInfoUI"))
local EggShopUI = require(clientScript:WaitForChild("build"):WaitForChild("EggShopUI"))

local HighlightSystem = require(clientScript:WaitForChild("systems"):WaitForChild("HighlightSystem"))
local CollisionDetector = require(clientScript:WaitForChild("systems"):WaitForChild("CollisionDetector"))
local GridSnap = require(clientScript:WaitForChild("systems"):WaitForChild("GridSnap"))
local DragHandler = require(clientScript:WaitForChild("systems"):WaitForChild("DragHandler"))
local UpgradeDisplay = require(clientScript:WaitForChild("systems"):WaitForChild("UpgradeDisplay"))
local PetVisuals = require(clientScript:WaitForChild("systems"):WaitForChild("PetVisuals"))
local LevelBadge = require(clientScript:WaitForChild("systems"):WaitForChild("LevelBadge"))
local WeatherVFX = require(clientScript:WaitForChild("systems"):WaitForChild("WeatherVFX"))
local CameraManager = require(clientScript:WaitForChild("systems"):WaitForChild("CameraManager"))
local ClockTowerVisual = require(clientScript:WaitForChild("systems"):WaitForChild("ClockTowerVisual"))
ClockTowerVisual.init()
local WorkBuildingDisplay = require(clientScript:WaitForChild("systems"):WaitForChild("WorkBuildingDisplay"))
WorkBuildingDisplay.init()
local UpgradeVisual = require(clientScript:WaitForChild("systems"):WaitForChild("UpgradeVisual"))
UpgradeVisual.init()
local BuffUI = require(clientScript:WaitForChild("build"):WaitForChild("BuffUI"))
BuffUI.init()
local BuildingInfoUI = require(clientScript:WaitForChild("build"):WaitForChild("BuildingInfoUI"))

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
local petUpdateEvent = remotes:WaitForChild("PetUpdate")
local upgradeStateChangedEvent = remotes:WaitForChild("UpgradeStateChanged")
local currencyUpdateEvent = remotes:WaitForChild("CurrencyUpdate")
local getCurrencyFunc = remotes:WaitForChild("GetCurrency")
local getShopFunc = remotes:WaitForChild("GetShop")
local buyItemEvent = remotes:WaitForChild("BuyItem")
local shopUpdateEvent = remotes:WaitForChild("ShopUpdate")
local sendGiftEvent = remotes:WaitForChild("SendGift")
local giftReceivedEvent = remotes:WaitForChild("GiftReceived")
local buyEggEvent = remotes:WaitForChild("BuyEgg")
local placeEggEvent = remotes:WaitForChild("PlaceEgg")
local hatchEggEvent = remotes:WaitForChild("HatchEgg")
local getEggsFunc = remotes:WaitForChild("GetEggs")
local getPlacedEggsFunc = remotes:WaitForChild("GetPlacedEggs")
local eggUpdateEvent = remotes:WaitForChild("EggUpdate")
local showEggBuyPopup = remotes:WaitForChild("ShowEggBuyPopup")

local itemsFolder = ReplicatedStorage:WaitForChild("Items")

-- Close all popup UIs (mutual exclusion)
local function closeAllPopups()
	ShopUI.hide()
	SettingsUI.hide()
	PetSellUI.hide()
	EggInfoUI.hide()
	if PetDetailUI.isVisible() then PetDetailUI.hide() end
	DialogUI.hide()
	EggShopUI.hide()
end

-- 선택된 펫 흰색 하이라이트 (PetDetailUI show/hide에 후크)
local _selectedPetPart: BasePart? = nil
local _origPetDetailShow = PetDetailUI.show
local _origPetDetailHide = PetDetailUI.hide

local function findPetPartByPetId(petId: string): BasePart?
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end
	for _, plot in plotsFolder:GetChildren() do
		for _, desc in plot:GetDescendants() do
			if desc:IsA("BasePart") and desc:GetAttribute("PetId") == petId then
				return desc
			end
		end
	end
	return nil
end

local function clearSelectedPetHighlight()
	if _selectedPetPart and _selectedPetPart.Parent then
		HighlightSystem.removeFrom(_selectedPetPart)
	end
	_selectedPetPart = nil
end

PetDetailUI.show = function(pet)
	clearSelectedPetHighlight()
	if pet and pet.petId then
		local part = findPetPartByPetId(pet.petId)
		if part then
			HighlightSystem.applyTo(part, Color3.new(1, 1, 1), 0.7)
			_selectedPetPart = part
		end
	end
	return _origPetDetailShow(pet)
end

PetDetailUI.hide = function()
	clearSelectedPetHighlight()
	return _origPetDetailHide()
end

-- NPC interaction distance
local NPC_MAX_DISTANCE = 15

-- 상태
local BuildState = Constants.BuildState
local currentState = BuildState.Idle

-- 선택/이동 관련 변수
local selectedBuilding = nil       -- 선택된 건물 (BasePart)
local selectedBuildingId = nil     -- 선택된 건물 ID
local previewPart = nil            -- 배치/이동 프리뷰 파트
local previewItemName = nil        -- 배치 중인 아이템 이름
local previewLevel = 1             -- 배치 중인 아이템 레벨
local currentRotationY = 0         -- 현재 Y 회전 (라디안)
local originalCFrame = nil         -- 이동 전 원래 CFrame (Cancel 복원용)
local hoveredPart = nil            -- 현재 호버 중인 파트
local currentBuildZone = nil       -- 현재 드래그 중인 BuildZone
local hasCollision = false         -- 현재 충돌 상태
local _lastCollisionDebug = nil    -- 디버그 출력 쓰로틀
local inventory = {}               -- 로컬 인벤토리 캐시
local _dragPaused = false          -- 드래그 일시 정지 (클릭으로 토글)
local _mainToPivotOffset = CFrame.new() -- mainPart→Pivot 오프셋 (createPreview에서 저장)

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

-- 이동/프리뷰 시작 시 투명도 저장 후 반투명 처리
local function setMovePreviewPart(part: BasePart)
	if part:GetAttribute("IsCollisionBox") then return end
	if part:GetAttribute("_OrigT") == nil then
		part:SetAttribute("_OrigT", part.Transparency)
	end
	part.Transparency = math.max(0.5, part.Transparency)
	part.CanCollide = false
end

-- 이동/프리뷰 종료 시 원본 투명도 복원
local function restoreMovePreviewPart(part: BasePart)
	if part:GetAttribute("IsCollisionBox") then return end
	local orig = part:GetAttribute("_OrigT")
	if orig ~= nil then
		part.Transparency = orig
		part:SetAttribute("_OrigT", nil)
	end
	part.CanCollide = true
end

-- 건물의 부모가 건물 Model인지 판정 (플롯 Model 제외)
local function getBuildingModel(building: BasePart): Model?
	local parent = building.Parent
	if not parent or not parent:IsA("Model") then return nil end
	-- 플롯(Owner 속성 있음)이면 건물 Model 아님
	if parent:GetAttribute("Owner") ~= nil then return nil end
	-- Plots 직속 Model이면 플롯
	if parent.Parent and parent.Parent.Name == "Plots" then return nil end
	return parent
end

-- 건물의 최상위 Model 찾기 (플롯까지 올라가서 가장 높은 Model 반환)
local function getParentModel(building: BasePart): Model?
	local topModel = nil
	local current = building.Parent
	while current and current ~= workspace do
		-- 플롯에 도달하면 중단
		if current:GetAttribute("Owner") ~= nil then break end
		if current.Name == "Plots" then break end
		if current:IsA("Model") then
			topModel = current
		end
		current = current.Parent
	end
	return topModel
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

-- 파트 또는 조상에서 BuildingId를 가진 메인파트 찾기
-- Model 자식 파트 클릭 시에도 모델 내부에서 mainPart 탐색
local function findBuildingMainPart(part: BasePart): BasePart?
	if not part then return nil end
	local current = part
	while current and current ~= workspace do
		-- 플롯에 도달하면 탐색 중단 (플롯은 Owner 속성이 있음)
		if current:GetAttribute("Owner") ~= nil then
			break
		end
		if current:IsA("BasePart") and current:GetAttribute("BuildingId") ~= nil then
			return current
		end
		-- 건물 Model이면 그 안에서 BuildingId를 가진 파트 탐색
		if current:IsA("Model") then
			for _, desc in current:GetDescendants() do
				if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") ~= nil then
					return desc
				end
			end
		end
		current = current.Parent
	end
	return nil
end

-- 파트가 배치된 건물인지 확인 (BuildingId 속성으로 식별, 조상 탐색)
local function isBuildingPart(part: BasePart): boolean
	return findBuildingMainPart(part) ~= nil
end

-- 파트가 내 건물인지 확인 (조상 탐색)
local function isMyBuilding(part: BasePart): boolean
	local mainPart = findBuildingMainPart(part)
	if not mainPart then return false end
	return mainPart:GetAttribute("OwnerId") == player.UserId
end

-- 프리뷰 파트 생성 (Buildings 우선 → Items 폴백)
local function createPreview(itemName: string, level: number?): BasePart?
	local lvl = level or 1
	local template = nil

	-- Buildings 폴더에서 레벨별 모델 탐색
	local buildingsFolder = ReplicatedStorage:FindFirstChild("Buildings")
	if buildingsFolder then
		local itemFolder = buildingsFolder:FindFirstChild(itemName)
		if itemFolder then
			template = itemFolder:FindFirstChild(itemName .. "_" .. lvl)
				or itemFolder:FindFirstChild("Level" .. lvl)
			-- 못 찾으면 첫 번째 자식 사용
			if not template then
				for _, child in itemFolder:GetChildren() do
					if child:IsA("Model") or child:IsA("BasePart") then
						template = child
						break
					end
				end
			end
		end
	end

	-- Items 폴백
	if not template and itemsFolder then
		template = itemsFolder:FindFirstChild(itemName)
	end

	if not template then return nil end
	local item = template:Clone()

	-- BasePart vs Model 분기
	local mainPart: BasePart
	if item:IsA("BasePart") then
		item.Name = "PlacementPreview"
		item.Transparency = math.max(0.5, item.Transparency)
		item.CanCollide = false
		item.Anchored = true
		item.CanQuery = false
		item.CanTouch = false
		item:SetAttribute("ItemName", itemName)
		item.Parent = workspace
		mainPart = item
	elseif item:IsA("Model") then
		item.Name = "PlacementPreview"
		item.Parent = workspace
		mainPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
		if not mainPart then
			-- 자손에서 찾기
			for _, desc in item:GetDescendants() do
				if desc:IsA("BasePart") then
					mainPart = desc
					break
				end
			end
		end
		if not mainPart then
			item:Destroy()
			return nil
		end
		-- 모든 파트를 프리뷰 상태로 (원본 투명도 유지)
		for _, desc in item:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Transparency = math.max(0.5, desc.Transparency)
				desc.CanCollide = false
				desc.Anchored = true
				desc.CanQuery = false
				desc.CanTouch = false
			end
		end
		mainPart:SetAttribute("ItemName", itemName)
		-- mainPart→Pivot 위치 오프셋만 저장 (회전 제외)
		local pivotPos = item:GetPivot().Position
		local mainPos = mainPart.Position
		_mainToPivotOffset = CFrame.new(pivotPos - mainPos)
	end

	return mainPart
end

-- 최상위 PlacementPreview Model 찾기
local function getPreviewModel(part: BasePart): Model?
	local current = part
	while current and current ~= workspace do
		if current.Name == "PlacementPreview" and current:IsA("Model") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- 프리뷰 제거
local function removePreview()
	if previewPart then
		HighlightSystem.removeFrom(previewPart)
		-- 최상위 PlacementPreview Model 찾기 (중첩 구조 대응)
		local toDestroy = previewPart
		local current = previewPart
		while current and current ~= workspace do
			if current.Name == "PlacementPreview" then
				toDestroy = current
				break
			end
			current = current.Parent
		end
		toDestroy:Destroy()
		previewPart = nil
		_mainToPivotOffset = CFrame.new()
	end
end

-- 충돌 상태 업데이트 (프리뷰 파트 기준, CollisionBox 기반)
local function updateCollisionState()
	if not previewPart then
		hasCollision = false
		return
	end

	-- 이동 중인 건물의 CollisionBox를 무시 목록에 추가
	local ignoreParts = { previewPart }
	-- Model 프리뷰의 모든 파트도 무시
	local parentModel = previewPart.Parent
	if parentModel and parentModel:IsA("Model") then
		table.insert(ignoreParts, parentModel)
	end
	if currentState == BuildState.Moving and selectedBuilding then
		local myBox = selectedBuilding:FindFirstChild("CollisionBox")
		if myBox then
			table.insert(ignoreParts, myBox)
		end
	end

	-- 올바른 아이템 이름으로 충돌 사이즈 사용
	local itemName = previewItemName or previewPart:GetAttribute("ItemName") or ""
	local colliding, collidingParts = CollisionDetector.checkCollisionBySize(previewPart.CFrame, itemName, ignoreParts)

	-- 디버그: 충돌 체크 결과 (1초마다)
	if not _lastCollisionDebug or (tick() - _lastCollisionDebug) > 1 then
		_lastCollisionDebug = tick()
		local collisionSize = Constants.getCollisionSize(itemName)
		print("[CollisionDebug] item=" .. itemName
			.. " | pos=" .. tostring(previewPart.CFrame.Position)
			.. " | size=" .. tostring(collisionSize)
			.. " | colliding=" .. tostring(colliding)
			.. " | hits=" .. (#collidingParts))
	end

	hasCollision = colliding

	-- Highlight + Place button state based on drag state
	if colliding then
		-- Collision: always red highlight + red button
		HighlightSystem.applyTo(previewPart, Constants.HIGHLIGHT_COLORS.Collision, 0.5)
		MoveHandleUI.setPlaceState("collision")
	elseif _dragPaused then
		-- Fixed, no collision: no highlight, Place enabled
		HighlightSystem.removeFrom(previewPart)
		MoveHandleUI.setPlaceState("ready")
	else
		-- Moving (dragging): blue highlight, Place disabled (semi-transparent)
		HighlightSystem.applyTo(previewPart, Constants.HIGHLIGHT_COLORS.Moving, 0.6)
		MoveHandleUI.setPlaceState("moving")
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

	-- 빌드모드 종료: Backpack UI 복원
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end)

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

	-- 빌드모드 UI 복원
	MainHUD.restoreBuildModeUI()

	-- 렌더 연결 해제
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

-- BuildMode 상태로 전환
local function toBuildMode()
	setState(BuildState.BuildMode)

	-- 빌드모드 진입: 들고있는 Tool 내려놓기 + 기본 Backpack UI 숨기기
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildWhichIsA("Humanoid")
			if humanoid then humanoid:UnequipTools() end
			-- 펫 Tool은 백팩에 그대로 보관 (월드로 복귀시키지 않음)
		end
	end

	BuildUI.setBuildMode(true)
	SelectionUI.hide()
	MoveHandleUI.hide()
	UpgradeUI.hide()
	PetListUI.hide()
	if PetDetailUI.isVisible() then PetDetailUI.hide() end
	-- 건물 상세 페이지도 숨기고 하이라이트 제거 (빌드모드 UI와 중복 방지)
	if BuildingInfoUI.isVisible() then
		local prevId = BuildingInfoUI.getCurrentBuildingId()
		if prevId then
			local plotsFolder = workspace:FindFirstChild("Plots")
			if plotsFolder then
				for _, p in plotsFolder:GetDescendants() do
					if p:IsA("BasePart") and p:GetAttribute("BuildingId") == prevId then
						HighlightSystem.removeFrom(p)
						break
					end
				end
			end
		end
		BuildingInfoUI.hide()
	end
	DragHandler.stopDrag()
	removePreview()

	selectedBuilding = nil
	selectedBuildingId = nil
	hoveredPart = nil

	-- 인벤토리 표시
	InventoryUI.show()

	-- 빌드모드 시 다른 UI 숨김 (사이드바 제외)
	MainHUD.hideBuildModeUI()

	-- 호버 렌더링 시작
	if renderConnection then
		renderConnection:Disconnect()
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		if currentState ~= BuildState.BuildMode then return end

		-- 마을 벗어나면 자동 종료
		local bz = getMyBuildZone()
		if bz then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local localPos = bz.CFrame:PointToObjectSpace(hrp.Position)
				local halfSize = bz.Size / 2
				if math.abs(localPos.X) > halfSize.X + 15 or math.abs(localPos.Z) > halfSize.Z + 15 then
					toIdle()
					MainHUD.setActiveTab(nil)
					return
				end
			end
		end

		local target = mouse.Target
		local mainTarget = findBuildingMainPart(target)
		if mainTarget and isMyBuilding(mainTarget) then
			if hoveredPart ~= mainTarget then
				HighlightSystem.clear()
				hoveredPart = mainTarget
				HighlightSystem.setHover(mainTarget)
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
		local itemName = building:GetAttribute("ItemName") or ""
		local canStore = itemName ~= "ClockTower"
		SelectionUI.showNormal(level, BalanceConfig.Upgrade.MAX_LEVEL, canStore)
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

	-- 건물을 투명하게 (이동 프리뷰로 전환)
	local bModel = getParentModel(building)
	if bModel then
		for _, d in bModel:GetDescendants() do
			if d:IsA("BasePart") then setMovePreviewPart(d) end
		end
	else
		setMovePreviewPart(building)
	end
	previewPart = building -- mainPart를 프리뷰로 사용

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
	MoveHandleUI.setPlaceState("moving")
	_dragPaused = false

	-- Blue highlight while moving
	HighlightSystem.applyTo(building, Constants.HIGHLIGHT_COLORS.Moving, 0.6)

	-- 드래그 시작
	if currentBuildZone then
		DragHandler.init(GridSnap)
		DragHandler.startDrag(currentBuildZone, previewPart, currentRotationY, function(newCFrame)
			if previewPart then
				-- 최상위 건물 Model 찾기
				local moveParent = getParentModel(previewPart)
				if moveParent then
					-- newCFrame = mainPart가 있어야 할 위치+회전 → Pivot 위치로 변환
					moveParent:PivotTo(newCFrame * _mainToPivotOffset)
					GridSnap.adjustModelY(moveParent, previewPart, currentBuildZone)
				else
					-- 단순 Part: Y를 BuildZone 상단 + Part 높이 절반으로 보정
					local bzTop = currentBuildZone.Position.Y + currentBuildZone.Size.Y / 2
					local correctedY = bzTop + previewPart.Size.Y / 2
					previewPart.CFrame = CFrame.new(newCFrame.Position.X, correctedY, newCFrame.Position.Z) * (newCFrame - newCFrame.Position)
				end
				updateCollisionState()
			end
		end)
	end
end

-- PlacingNew 상태로 전환 (인벤토리에서 새 건물 배치)
local function toPlacingNew(itemName: string, level: number?)
	setState(BuildState.PlacingNew)

	previewItemName = itemName
	previewLevel = level or 1

	-- BuildZone 찾기
	currentBuildZone = getMyBuildZone()
	if not currentBuildZone then
		print("No BuildZone!")
		toBuildMode()
		return
	end

	-- 프리뷰 생성
	removePreview()
	previewPart = createPreview(itemName, previewLevel)
	if not previewPart then
		print("Item template not found:", itemName)
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
			-- 위치만 사용, 회전은 모델 원본 유지
			local pModel = getPreviewModel(previewPart)
			if pModel then
				local posOnly = CFrame.new(snappedCFrame.Position)
				pModel:PivotTo(posOnly)
				GridSnap.adjustModelY(pModel, previewPart, currentBuildZone)
			else
				previewPart.CFrame = CFrame.new(snappedCFrame.Position)
			end
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
			-- Model이면 PivotTo 보정 (mainPart가 정확히 newCFrame에 오도록)
			local parentModel = getPreviewModel(previewPart)
			if parentModel then
				parentModel:PivotTo(newCFrame * _mainToPivotOffset)
				GridSnap.adjustModelY(parentModel, previewPart, currentBuildZone)
			else
				-- 단순 Part: Y를 BuildZone 상단 + Part 높이 절반으로 보정
				local bzTop = currentBuildZone.Position.Y + currentBuildZone.Size.Y / 2
				local correctedY = bzTop + previewPart.Size.Y / 2
				previewPart.CFrame = CFrame.new(newCFrame.Position.X, correctedY, newCFrame.Position.Z) * (newCFrame - newCFrame.Position)
			end
			updateCollisionState()
		end
	end)
end

----------------------------------------------------------------
-- UI 콜백 초기화
----------------------------------------------------------------

-- BuildUI: 빌드 모드 토글
BuildUI.init(function()
	-- 상점/도감 닫기
	ShopUI.hide()
	EggShopUI.hide()
	CollectionUI.hide()
	GiftUI.hide()
	if currentState == BuildState.Idle then
		MainHUD.setActiveTab("build")
		toBuildMode()
	elseif currentState == BuildState.BuildMode then
		MainHUD.setActiveTab(nil)
		toIdle()
	elseif currentState == BuildState.Selected or currentState == BuildState.Moving or currentState == BuildState.PlacingNew then
		-- 빌드모드에서 나가기
		if currentState == BuildState.Moving and selectedBuilding and originalCFrame then
			-- 이동 취소: 원래 위치/투명도 복원 (Model 지원)
			local rModel = getParentModel(selectedBuilding)
			if rModel then
				rModel:PivotTo(originalCFrame)
				for _, d in rModel:GetDescendants() do
					if d:IsA("BasePart") then restoreMovePreviewPart(d) end
				end
			else
				selectedBuilding.CFrame = originalCFrame
				restoreMovePreviewPart(selectedBuilding)
			end
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

-- InventoryUI: 아이템 선택 (레벨 포함) + Exit 콜백
InventoryUI.init(function(itemName: string, level: number)
	if currentState == BuildState.BuildMode then
		-- 알인지 확인
		local EggCfg = BalanceConfig.Egg
		if EggCfg and EggCfg.EGGS and EggCfg.EGGS[itemName] then
			-- 알 배치: 건물과 동일한 배치 흐름, 하지만 확정 시 PlaceEgg 전송
			previewItemName = itemName
			previewLevel = 1

			-- BuildZone 찾기
			currentBuildZone = getMyBuildZone()
			if not currentBuildZone then
				print("No BuildZone!")
				return
			end

			-- 알 프리뷰 생성
			setState(BuildState.PlacingNew)
			removePreview()

			local eggFolder = ReplicatedStorage:FindFirstChild("Egg")
			local eggTemplate = eggFolder and eggFolder:FindFirstChild(itemName)
			if eggTemplate then
				local preview = eggTemplate:Clone()
				preview.Name = "PlacementPreview"
				preview.Parent = workspace

				if preview:IsA("Model") then
					local mp = preview.PrimaryPart or preview:FindFirstChildWhichIsA("BasePart")
					if mp then
						for _, desc in preview:GetDescendants() do
							if desc:IsA("BasePart") then
								desc.Transparency = math.max(0.5, desc.Transparency)
								desc.CanCollide = false
								desc.Anchored = true
								desc.CanQuery = false
							end
						end
						mp:SetAttribute("ItemName", itemName)
						mp:SetAttribute("IsEggPreview", true)
						previewPart = mp

						local character = player.Character
						if character then
							local hrp = character:FindFirstChild("HumanoidRootPart")
							if hrp then
								local frontPos = hrp.Position + hrp.CFrame.LookVector * 8
								preview:PivotTo(CFrame.new(frontPos))
								GridSnap.adjustModelY(preview, mp, currentBuildZone)
							end
						end
					end
				elseif preview:IsA("BasePart") then
					preview.Transparency = math.max(0.5, preview.Transparency)
					preview.CanCollide = false
					preview.Anchored = true
					preview.CanQuery = false
					preview:SetAttribute("ItemName", itemName)
					preview:SetAttribute("IsEggPreview", true)
					previewPart = preview

					local bzTop = currentBuildZone.Position.Y + currentBuildZone.Size.Y / 2
					preview.CFrame = CFrame.new(0, bzTop + preview.Size.Y / 2, 0)
				end
			end

			if not previewPart then
				toBuildMode()
				return
			end

			HighlightSystem.applyTo(previewPart, Constants.HIGHLIGHT_COLORS.Selected, 0.6)
			InventoryUI.hide()
			SelectionUI.hide()
			MoveHandleUI.show()

			currentRotationY = 0
			DragHandler.init(GridSnap)
			DragHandler.startDrag(currentBuildZone, previewPart, currentRotationY, function(newCFrame)
				if previewPart then
					local pModel = previewPart.Parent
					if pModel then
						local mainToPivot = previewPart.CFrame:ToObjectSpace(pModel:GetPivot())
						pModel:PivotTo(newCFrame * mainToPivot)
						GridSnap.adjustModelY(pModel, previewPart, currentBuildZone)
					else
						local bzTop = currentBuildZone.Position.Y + currentBuildZone.Size.Y / 2
						local correctedY = bzTop + previewPart.Size.Y / 2
						previewPart.CFrame = CFrame.new(newCFrame.Position.X, correctedY, newCFrame.Position.Z) * (newCFrame - newCFrame.Position)
					end
				end
			end)
		else
			toPlacingNew(itemName, level)
		end
	end
end, function()
	-- Exit Building 버튼 콜백
	MainHUD.setActiveTab(nil)
	toIdle()
end)

-- SelectionUI: 동적 버튼 콜백
SelectionUI.init({
	onStore = function()
		if currentState == BuildState.Selected and selectedBuilding then
			local itemName = selectedBuilding:GetAttribute("ItemName") or ""
			if itemName == "ClockTower" then
				MainHUD.showMessage("Clock Tower cannot be stored.", 2)
				return
			end
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
	_dragPaused = false

	if currentState == BuildState.PlacingNew and previewPart then
		local isEggPreview = previewPart:GetAttribute("IsEggPreview") == true
		local mainCFrame = previewPart.CFrame
		-- BuildZone 로컬 좌표로 변환 (PlotManager 저장과 동일)
		local localCFrame = mainCFrame
		if currentBuildZone then
			localCFrame = currentBuildZone.CFrame:ToObjectSpace(mainCFrame)
		end
		DragHandler.stopDrag()
		removePreview()

		if isEggPreview then
			placeEggEvent:FireServer(previewItemName, mainCFrame.Position)
		else
			-- BuildZone 로컬 CFrame으로 전송
			placeBuildingEvent:FireServer(previewItemName, localCFrame, previewLevel)
		end
		toBuildMode()

	elseif currentState == BuildState.Moving and selectedBuilding then
		local finalCFrame = selectedBuilding.CFrame
		local buildingId = selectedBuilding:GetAttribute("BuildingId")
		DragHandler.stopDrag()

		-- 투명도/충돌 복원 (Model 지원)
		local cpModel = getParentModel(selectedBuilding)
		if cpModel then
			for _, d in cpModel:GetDescendants() do
				if d:IsA("BasePart") then restoreMovePreviewPart(d) end
			end
		else
			restoreMovePreviewPart(selectedBuilding)
		end
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
		_dragPaused = false
		if currentState == BuildState.Moving and selectedBuilding and originalCFrame then
			local rpModel = getParentModel(selectedBuilding)
			if rpModel then
				rpModel:PivotTo(originalCFrame)
				for _, d in rpModel:GetDescendants() do
					if d:IsA("BasePart") then restoreMovePreviewPart(d) end
				end
			else
				selectedBuilding.CFrame = originalCFrame
				restoreMovePreviewPart(selectedBuilding)
			end
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
	-- 다이얼로그가 열려 있으면 입력 무시 (PetDetail은 클릭으로 닫을 수 있게 제외)
	if UpgradeUI.isVisible() or PetListUI.isVisible() then return end

	-- 마우스 클릭: 배치 확정 / BuildMode에서 건물 선택 / 펫 클릭
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
		-- 펫 Tool을 들고 있고 마을 안 클릭 → 그 자리에 펫 배치
		do
			local character = player.Character
			local equippedPetId: string? = nil
			if character then
				for _, child in character:GetChildren() do
					if child:IsA("Tool") and child:GetAttribute("PetId") then
						equippedPetId = child:GetAttribute("PetId")
						break
					end
				end
			end
			if equippedPetId then
				local bz = getMyBuildZone()
				if bz then
					local clickPos = mouse.Hit.Position
					local localPos = bz.CFrame:PointToObjectSpace(clickPos)
					local half = bz.Size / 2
					if math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z then
						local dropEvent = remotes:FindFirstChild("DropPet")
						if dropEvent then
							dropEvent:FireServer(clickPos, equippedPetId)
							MainHUD.showMessage("Pet placed!", 1)
							return
						end
					end
				end
			end

			-- 알 Tool을 들고 있고 마을 안 클릭 → 그 자리에 알 배치
			local heldEggType = nil
			if character then
				for _, child in character:GetChildren() do
					if child:IsA("Tool") and child:GetAttribute("IsEggTool") then
						heldEggType = child:GetAttribute("EggType")
						break
					end
				end
			end
			if heldEggType then
				local bz = getMyBuildZone()
				if bz then
					local clickPos = mouse.Hit.Position
					local localPos = bz.CFrame:PointToObjectSpace(clickPos)
					local half = bz.Size / 2
					if math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z then
						placeEggEvent:FireServer(heldEggType, clickPos)
						-- 서버가 syncEggTools로 알 Tool 카운트 갱신/제거 처리
						MainHUD.showMessage("Egg placed!", 1)
						return
					end
				end
			end
		end

		if currentState == BuildState.PlacingNew or currentState == BuildState.Moving then
			if _dragPaused then
				-- Fixed: click the building to resume
				local target = mouse.Target
				if target and previewPart then
					local previewModel = getParentModel(previewPart)
					local clickedModel = getParentModel(target)
					local isPreview = (target == previewPart)
						or (previewModel and (target:IsDescendantOf(previewModel) or clickedModel == previewModel))
					if isPreview then
						_dragPaused = false
						DragHandler.resume()
						updateCollisionState()
					end
				end
			else
				-- Moving: click anywhere to fix in place
				_dragPaused = true
				DragHandler.pause()
				updateCollisionState()
			end
		elseif currentState == BuildState.BuildMode then
			local target = mouse.Target
			local mainPart = findBuildingMainPart(target)
			if mainPart and isMyBuilding(mainPart) then
				toSelected(mainPart)
			end
		elseif currentState == BuildState.Idle then
			-- NPC 클릭 감지
			local target = mouse.Target
			if target then
				local npcFolder = workspace:FindFirstChild("NPC")
				if npcFolder then
					local current = target
					while current and current ~= workspace do
						if current.Parent == npcFolder then
							-- NPC 클릭됨 → OpenShop 이벤트와 동일 처리
							local npcName = current.Name
							local shopType = if npcName == "BuildingDealer" then "buildings" else "eggs"
							local openShopEvent = remotes:FindFirstChild("OpenShop")
							if openShopEvent then
								openShopEvent:FireServer(shopType, npcName)
							end
							-- 거리 체크
							local npcPart = current:FindFirstChild("HumanoidRootPart")
								or current:FindFirstChildWhichIsA("BasePart", true)
							local character = player.Character
							local hrp = character and character:FindFirstChild("HumanoidRootPart")
							if hrp and npcPart then
								local dist = (hrp.Position - npcPart.Position).Magnitude
								if dist > NPC_MAX_DISTANCE then
									return -- too far
								end
							end
							-- Trigger same as ProximityPrompt
							if shopType == "buildings" then
								closeAllPopups()
								local npcHead = current:FindFirstChild("Head")
								local greeting = PIERRE_GREETINGS[math.random(#PIERRE_GREETINGS)]
								DialogUI.show("Pierre", greeting, {}, function() end, npcHead or npcPart)
								task.delay(1.5, function() DialogUI.hide() end)
								ShopUI.showBuildingsShop()
								if npcPart then startNpcDistanceCheck(npcPart) end
							elseif shopType == "eggs" then
								local npcHead = current:FindFirstChild("Head")
								local greeting = HAILEY_GREETINGS[math.random(#HAILEY_GREETINGS)]
								DialogUI.show("Hailey", greeting, HAILEY_CHOICES, function(choiceId)
									if choiceId == "sellpet" then
										DialogUI.showResponse("Let me see what you've got!", 1.5)
										task.delay(1.5, function()
											DialogUI.hide()
											PetSellUI.show()
										end)
									elseif choiceId == "petworth" then
										local heldId = nil
										local ch = player.Character
										if ch then
											for _, c in ch:GetChildren() do
												if c:IsA("Tool") and c:GetAttribute("PetId") then
													heldId = c:GetAttribute("PetId")
													break
												end
											end
										end
										if not heldId then
											for _, c in player.Backpack:GetChildren() do
												if c:IsA("Tool") and c:GetAttribute("PetId") then
													heldId = c:GetAttribute("PetId")
													break
												end
											end
										end
										if heldId then
											local getPriceFunc = remotes:FindFirstChild("GetPetSellPrice")
											if getPriceFunc then
												local price = getPriceFunc:InvokeServer(heldId)
												DialogUI.showResponse("Hmm, let me take a look...", 1)
												task.delay(1, function()
													DialogUI.showResponse("This one's worth $" .. price .. ".", 3)
												end)
											end
										else
											DialogUI.showResponse("I can't see anything...", 2)
										end
									elseif choiceId == "petinfo" then
										DialogUI.showResponse("Here's what we have!", 1)
										task.delay(1, function()
											DialogUI.hide()
											EggInfoUI.show()
										end)
									elseif choiceId == "nevermind" then
										DialogUI.showResponse("See you around!", 1.5)
									end
								end, npcHead or npcPart)
								if npcPart then startNpcDistanceCheck(npcPart) end
							end
							return
						end
						current = current.Parent
					end
				end
			end

			-- Idle 상태에서 펫/알/건물 클릭
			target = mouse.Target
			-- 클릭한 파트 또는 조상에서 PetId/IsEgg/BuildingId 찾기
			local petTarget = nil
			local eggTarget = nil
			local buildingTarget = nil
			local current = target
			while current and current ~= workspace do
				if current:IsA("BasePart") then
					if current:GetAttribute("PetId") then
						petTarget = current
						break
					elseif current:GetAttribute("IsEgg") then
						eggTarget = current
						break
					elseif current:GetAttribute("BuildingId") then
						buildingTarget = current
						break
					end
				elseif current:IsA("Model") then
					-- 모델 내부에서 BuildingId 가진 mainPart 찾기 (다중 파트 건물)
					if current:GetAttribute("Owner") == nil and current.Name ~= "Plots" then
						for _, desc in current:GetDescendants() do
							if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") then
								buildingTarget = desc
								break
							end
						end
						if buildingTarget then break end
					end
				end
				current = current.Parent
			end

			-- 다른 선택을 풀고 새 선택 적용 (건물 우선)
			if buildingTarget then
				-- 펫 선택 풀기
				if PetDetailUI.isVisible() then PetDetailUI.hide() end
				-- 이전 건물 하이라이트 풀기
				local prevId = BuildingInfoUI.getCurrentBuildingId()
				if prevId then
					local plotsFolder = workspace:FindFirstChild("Plots")
					if plotsFolder then
						for _, plot in plotsFolder:GetDescendants() do
							if plot:IsA("BasePart") and plot:GetAttribute("BuildingId") == prevId then
								HighlightSystem.removeFrom(plot)
								break
							end
						end
					end
				end
				-- 새 건물 하이라이트 + 정보 표시
				HighlightSystem.applyTo(buildingTarget, Color3.new(1, 1, 1), 0.7)
				BuildingInfoUI.show(buildingTarget)
				return
			end

			if petTarget then
				-- 펫 클릭 → 건물 인포 닫기 + 하이라이트 제거
				if BuildingInfoUI.isVisible() then
					local prevId = BuildingInfoUI.getCurrentBuildingId()
					if prevId then
						local plotsFolder = workspace:FindFirstChild("Plots")
						if plotsFolder then
							for _, p in plotsFolder:GetDescendants() do
								if p:IsA("BasePart") and p:GetAttribute("BuildingId") == prevId then
									HighlightSystem.removeFrom(p)
									break
								end
							end
						end
					end
					BuildingInfoUI.hide()
				end
				-- Toggle pet detail
				if PetDetailUI.isVisible() then
					PetDetailUI.hide()
				else
					task.spawn(function()
						local pets = getPetsFunc:InvokeServer()
						if pets then
							local petId = petTarget:GetAttribute("PetId")
							for _, pet in pets do
								if pet.petId == petId then
									PetDetailUI.show(pet)
									break
								end
							end
						end
					end)
				end
			elseif eggTarget then
				local eggId = eggTarget:GetAttribute("EggId")
				local readyToHatch = eggTarget:GetAttribute("ReadyToHatch")
				if eggId and readyToHatch then
					hatchEggEvent:FireServer(eggId)
				end
			elseif target then
				-- 펫/건물 아닌 곳 클릭 → 모든 상세 UI 닫기 + 하이라이트 제거
				if BuildingInfoUI.isVisible() then
					local prevId = BuildingInfoUI.getCurrentBuildingId()
					if prevId then
						local plotsFolder = workspace:FindFirstChild("Plots")
						if plotsFolder then
							for _, p in plotsFolder:GetDescendants() do
								if p:IsA("BasePart") and p:GetAttribute("BuildingId") == prevId then
									HighlightSystem.removeFrom(p)
									break
								end
							end
						end
					end
					BuildingInfoUI.hide()
					return
				end
				if PetDetailUI.isVisible() then
					PetDetailUI.hide()
					-- 근처 펫 감지 건너뜀
				else
					-- 근처 펫 자동 감지 (10 stud 이내)
					local clickPos = mouse.Hit.Position
					local plotsFolder = workspace:FindFirstChild("Plots")
					if plotsFolder then
						for _, plot in plotsFolder:GetChildren() do
							if plot:GetAttribute("Owner") == player.Name then
								local closestPet = nil
								local closestDist = 10
								for _, desc in plot:GetDescendants() do
									if desc:IsA("BasePart") and desc:GetAttribute("PetId") then
										local dist = (desc.Position - clickPos).Magnitude
										if dist < closestDist then
											closestDist = dist
											closestPet = desc
										end
									end
								end
								if closestPet then
									task.spawn(function()
										local pets = getPetsFunc:InvokeServer()
										if pets then
											local petId = closestPet:GetAttribute("PetId")
											for _, pet in pets do
												if pet.petId == petId then
													PetDetailUI.show(pet)
													break
												end
											end
										end
									end)
								end
								break
							end
						end
					end
				end -- else
			end -- elseif target
		end -- elseif Idle
	end -- MouseButton1


	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Escape then
		_dragPaused = false
		if currentState == BuildState.PlacingNew then
			DragHandler.stopDrag()
			removePreview()
			toBuildMode()
		elseif currentState == BuildState.Moving and selectedBuilding and originalCFrame then
			local epModel = getParentModel(selectedBuilding)
			if epModel then
				epModel:PivotTo(originalCFrame)
				for _, d in epModel:GetDescendants() do
					if d:IsA("BasePart") then restoreMovePreviewPart(d) end
				end
			else
				selectedBuilding.CFrame = originalCFrame
				restoreMovePreviewPart(selectedBuilding)
			end
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
				local bpModel = getParentModel(selectedBuilding)
				if bpModel then
					bpModel:PivotTo(originalCFrame)
					for _, d in bpModel:GetDescendants() do
						if d:IsA("BasePart") then restoreMovePreviewPart(d) end
					end
				else
					selectedBuilding.CFrame = originalCFrame
					restoreMovePreviewPart(selectedBuilding)
				end
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
-- 인벤토리 동기화 (건물 + 알 통합)
----------------------------------------------------------------

local eggInventory = {} -- 알 인벤토리 캐시

local function mergeInventory()
	local merged = {}
	-- 건물
	for _, item in inventory do
		table.insert(merged, item)
	end
	-- 알 (isEgg 플래그 추가)
	for _, egg in eggInventory do
		if egg.count > 0 then
			table.insert(merged, {
				itemName = egg.eggType,
				count = egg.count,
				level = 1,
				isEgg = true,
			})
		end
	end
	InventoryUI.updateInventory(merged)
end

inventoryUpdateEvent.OnClientEvent:Connect(function(inv)
	inventory = inv
	mergeInventory()
end)

eggUpdateEvent.OnClientEvent:Connect(function(eventType, data)
	if eventType == "inventory" and data then
		eggInventory = data
		mergeInventory()
	end
end)

task.spawn(function()
	local inv
	for _ = 1, 5 do
		inv = getInventoryFunc:InvokeServer()
		if inv and #inv > 0 then break end
		task.wait(1)
	end
	if inv then
		inventory = inv
	end

	-- 알 인벤토리도 로드
	local eggs = getEggsFunc:InvokeServer()
	if eggs then
		eggInventory = eggs
	end

	mergeInventory()
end)

----------------------------------------------------------------
-- 코인 동기화 (CurrencyUI + MainHUD 재화 표시)
----------------------------------------------------------------

-- CurrencyUI 제거됨 (MainHUD 하단에 통합)

currencyUpdateEvent.OnClientEvent:Connect(function(coins, gems)
	MainHUD.updateCoins(coins)
	if gems ~= nil then MainHUD.updateGems(gems) end
end)

task.spawn(function()
	local coins, gems = getCurrencyFunc:InvokeServer()
	if coins then MainHUD.updateCoins(coins) end
	if gems then MainHUD.updateGems(gems) end
end)

----------------------------------------------------------------
-- 업그레이드/펫 이벤트 수신
----------------------------------------------------------------

upgradeStateChangedEvent.OnClientEvent:Connect(function(buildingId, action, data)
	if action == "error" then
		MainHUD.showMessage(tostring(data or "Upgrade failed"), 3)
		return
	end
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

	-- 마을 표지판 업데이트 (StarterGui/VillageSigns)
	local villageSigns = playerGui:FindFirstChild("VillageSigns")
	if villageSigns then
		-- 모든 플롯 표지판 업데이트
		for _, plot in plotsFolder:GetChildren() do
			local owner = plot:GetAttribute("Owner") or ""
			local plotSign = villageSigns:FindFirstChild(plot.Name)
			if plotSign then
				local nameGui = plotSign:FindFirstChild("Name")
				if nameGui then
					local textLabel = nameGui:FindFirstChild("TextLabel") or nameGui:FindFirstChildWhichIsA("TextLabel")
					if textLabel then
						textLabel.Text = if owner ~= "" then owner else ""
					end
				end
				-- 프로필 아이콘
				local profileIcon = plotSign:FindFirstChild("ProfileIcon")
				if profileIcon then
					local isVisible = owner ~= ""
					-- SurfaceGui uses Enabled, GuiObject uses Visible
					if profileIcon:IsA("SurfaceGui") or profileIcon:IsA("BillboardGui") then
						profileIcon.Enabled = isVisible
					elseif profileIcon:IsA("GuiObject") then
						profileIcon.Visible = isVisible
					end
					if isVisible then
						local imageLabel = profileIcon:FindFirstChildWhichIsA("ImageLabel")
						if imageLabel then
							local success, result = pcall(function()
								return Players:GetUserThumbnailAsync(
									Players:GetUserIdFromNameAsync(owner),
									Enum.ThumbnailType.HeadShot,
									Enum.ThumbnailSize.Size100x100
								)
							end)
							if success and result then
								imageLabel.Image = result
							end
						end
					end
				end
			end
		end

		-- Owner 변경 감지 (다른 플레이어 접속/퇴장)
		for _, plot in plotsFolder:GetChildren() do
			plot:GetAttributeChangedSignal("Owner"):Connect(function()
				local owner = plot:GetAttribute("Owner") or ""
				local plotSign = villageSigns:FindFirstChild(plot.Name)
				if plotSign then
					local nameGui = plotSign:FindFirstChild("Name")
					if nameGui then
						local textLabel = nameGui:FindFirstChild("TextLabel") or nameGui:FindFirstChildWhichIsA("TextLabel")
						if textLabel then
							textLabel.Text = if owner ~= "" then owner else ""
						end
					end
				end
			end)
		end
	end
end)

-- 펫 VFX 이벤트 수신 초기화
PetVisuals.init()

-- 날씨 VFX 초기화
WeatherVFX.init()

-- 날씨 상태를 MainHUD에 동기화
local weatherChangedRemote = remotes:FindFirstChild("WeatherChanged")
if weatherChangedRemote then
	weatherChangedRemote.OnClientEvent:Connect(function(weatherType)
		MainHUD.updateWeather(weatherType)
	end)
end
-- 즉시 현재 날씨 가져와서 적용 (디자인 디폴트 아이콘 노출 방지)
task.spawn(function()
	local getWeatherFunc = remotes:FindFirstChild("GetWeather")
	if getWeatherFunc then
		local ok, weather = pcall(function() return getWeatherFunc:InvokeServer() end)
		if ok and typeof(weather) == "string" then
			MainHUD.updateWeather(weather)
		end
	end
end)

----------------------------------------------------------------
-- 메인 HUD + 상점 + 도감 + 선물 시스템
----------------------------------------------------------------

-- 상점/도감 패널 닫기 헬퍼
local function closeAllPanels()
	ShopUI.hide()
	CollectionUI.hide()
end

-- 상점 데이터 로드
local function loadShopData()
	task.spawn(function()
		local shopData, restockTime = getShopFunc:InvokeServer()
		if shopData then
			ShopUI.updateShop(shopData, restockTime)
		end
	end)
end

-- 도감 초기화
CollectionUI.init()

-- 선물 UI 초기화
local _giftFromShop = nil -- "buildings" or "eggs"

GiftUI.init({
	onSelectPlayer = function(itemName, targetPlayer)
		sendGiftEvent:FireServer(itemName, targetPlayer.Name)
		GiftUI.hide()
		if _giftFromShop == "buildings" then
			ShopUI.showBuildingsShop()
		elseif _giftFromShop == "eggs" then
			ShopUI.show()
		end
		_giftFromShop = nil
		loadShopData()
	end,
	onClose = function()
		GiftUI.hide()
		if _giftFromShop == "buildings" then
			ShopUI.showBuildingsShop()
		elseif _giftFromShop == "eggs" then
			ShopUI.show()
		end
		_giftFromShop = nil
	end,
})

-- 상점 UI 초기화
ShopUI.init({
	onBuy = function(itemName)
		buyItemEvent:FireServer(itemName)
	end,
	onBuyGem = function(itemName)
		-- Robux purchase via Developer Product
		local buyRobuxEvent = remotes:FindFirstChild("BuyRobux")
		if buyRobuxEvent then
			buyRobuxEvent:FireServer("building", itemName)
		end
	end,
	onGift = function(itemName)
		-- 어떤 상점에서 열었는지 저장
		if ShopUI.isBuildingsShopVisible() then
			_giftFromShop = "buildings"
		else
			_giftFromShop = "eggs"
		end
		ShopUI.hide()
		GiftUI.show(itemName)
	end,
	onBuyEgg = function(eggType)
		-- NPC DialogUI와 동일 스타일: 캐릭터 머리 위 말풍선
		local eggCfg = BalanceConfig.Egg and BalanceConfig.Egg.EGGS[eggType]
		local eggName = eggCfg and eggCfg.name or eggType
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if head then
			-- 기존 말풍선 제거
			local old = playerGui:FindFirstChild("_PlayerBubble")
			if old then old:Destroy() end

			local bubble = Instance.new("BillboardGui")
			bubble.Name = "_PlayerBubble"
			bubble.Size = UDim2.new(0, 200, 0, 40)
			bubble.StudsOffset = Vector3.new(0, 1.5, 0)
			bubble.AlwaysOnTop = true
			bubble.Adornee = head
			bubble.Parent = playerGui

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextSize = 13
			label.Font = Enum.Font.GothamBold
			label.Text = "I'll take a " .. eggName .. "!"
			label.TextWrapped = true
			label.TextStrokeTransparency = 0.5
			label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			label.Parent = bubble

			task.delay(2, function()
				if bubble.Parent then bubble:Destroy() end
			end)
		end
		buyEggEvent:FireServer(eggType)
	end,
	onOpen = function()
		-- 열고 닫을 때 리프레시
		loadShopData()
	end,
	onReloadRequest = function()
		-- restock 시간이 0이 되면 리프레시
		loadShopData()
	end,
})

-- 알 상점 UI 초기화
EggShopUI.init({
	onConfirm = function(slotName: string, eggName: string)
		EggShopUI.hide()
		local ok, msg = pcall(function()
			return buyEggEvent:InvokeServer(slotName, eggName)
		end)
		if not ok then
			MainHUD.showMessage("Purchase error", 3)
		else
			MainHUD.showMessage(msg or "Purchase done", 3)
		end
	end,

	onCancel = function()
		EggShopUI.hide()
	end,
})
showEggBuyPopup.OnClientEvent:Connect(function(slotName, eggName)
	EggShopUI.show(slotName, eggName)
end)

-- 메인 HUD 초기화 (탭 전환)
MainHUD.init({
	onTabChanged = function(tabId)
		if tabId == "build" then
			-- 마을 안에 있는지 체크
			local bz = getMyBuildZone()
			if not bz then
				MainHUD.showMessage("You need to be in your village to use Build Mode.")
				MainHUD.setActiveTab(nil)
				return
			end
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local localPos = bz.CFrame:PointToObjectSpace(hrp.Position)
				local halfSize = bz.Size / 2
				if math.abs(localPos.X) > halfSize.X + 10 or math.abs(localPos.Z) > halfSize.Z + 10 then
					MainHUD.showMessage("You need to be in your village to use Build Mode.")
					MainHUD.setActiveTab(nil)
					return
				end
			end

			closeAllPanels()
			if currentState == BuildState.Idle then
				toBuildMode()
			end
		elseif tabId == "shop" then
			-- Shop = 알 상점 (BuildingsShop은 NPC)
			closeAllPanels()
			closeAllPopups()
			if currentState == BuildState.BuildMode then
				toIdle()
			end
			ShopUI.show()
			loadShopData()
		else
			-- nil (탭 해제)
			closeAllPanels()
			if currentState == BuildState.BuildMode then
				toIdle()
			end
		end
	end,

	onTeleport = function(destination)
		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		if destination == "village" then
			-- Plot > Sign 위치로 텔레포트 (입구)
			local plotsFolder = workspace:FindFirstChild("Plots")
			local teleported = false
			if plotsFolder then
				for _, plot in plotsFolder:GetChildren() do
					if plot:GetAttribute("Owner") == player.Name then
						local sign = plot:FindFirstChild("Sign")
						local vs = sign and sign:FindFirstChild("VillageSign")
						if vs then sign = vs end
						if sign then
							local part = if sign:IsA("BasePart") then sign
								else sign:FindFirstChildWhichIsA("BasePart", true)
							if part then
								-- 표지판 XZ 위치, Y는 BuildZone 높이
								local bz = getMyBuildZone()
								local groundY = if bz then bz.Position.Y + bz.Size.Y / 2 + 3 else part.Position.Y
								hrp.CFrame = CFrame.new(part.Position.X, groundY, part.Position.Z)
								teleported = true
							end
						end
						break
					end
				end
			end
			if not teleported then
				local bz = getMyBuildZone()
				if bz then
					hrp.CFrame = bz.CFrame + Vector3.new(0, 5, 0)
				end
			end
		elseif destination == "buildings" then
			local pos = Vector3.new(113.7, 10.8, 10.3)
			local npcFolder = workspace:FindFirstChild("NPC")
			local npc = npcFolder and npcFolder:FindFirstChild("BuildingDealer")
			local npcPart = npc and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true))
			if npcPart then
				local target = Vector3.new(npcPart.Position.X, pos.Y, npcPart.Position.Z)
				hrp.CFrame = CFrame.lookAt(pos, target)
			else
				hrp.CFrame = CFrame.new(pos)
			end
		elseif destination == "eggs" then
			local pos = Vector3.new(95.9, 11.0, 26.7)
			local npcFolder = workspace:FindFirstChild("NPC")
			local npc = npcFolder and npcFolder:FindFirstChild("PetDealer")
			local npcPart = npc and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true))
			if npcPart then
				local target = Vector3.new(npcPart.Position.X, pos.Y, npcPart.Position.Z)
				hrp.CFrame = CFrame.lookAt(pos, target)
			else
				hrp.CFrame = CFrame.new(pos)
			end
		end
	end,

	onSettings = function()
		if SettingsUI.isVisible() then
			SettingsUI.hide()
		else
			closeAllPopups()
			SettingsUI.show()
		end
	end,
})

-- 상점 데이터 서버 동기화
shopUpdateEvent.OnClientEvent:Connect(function(shopData, restockTime)
	ShopUI.updateShop(shopData, restockTime)
end)

-- 구매 결과 알림
local buyResultEvent = remotes:FindFirstChild("BuyResult")
if buyResultEvent then
	buyResultEvent.OnClientEvent:Connect(function(success, message)
		if success then
			MainHUD.showMessage(message, 3)
		else
			-- Error messages
			if message == "Not enough coins" then
				MainHUD.showMessage("Not enough coins!", 2)
			elseif message == "Out of stock" then
				MainHUD.showMessage("Out of stock!", 2)
			else
				MainHUD.showMessage(message or "Purchase failed", 2)
			end
		end
		loadShopData()
	end)
end

-- 서버에서 HoldPet 에러 메시지 받으면 표시
do
	local holdEvt = remotes:FindFirstChild("HoldPet")
	if holdEvt then
		holdEvt.OnClientEvent:Connect(function(eventType, message)
			if eventType == "error" and typeof(message) == "string" then
				MainHUD.showMessage(message, 3)
			end
		end)
	end
end

-- 펫 Hold ProximityPrompt → HoldPet 서버 전송
local function connectPetHoldPrompt()
	local evt = remotes:FindFirstChild("PetHoldPrompt")
	if evt then
		evt.OnClientEvent:Connect(function(petId)
			print("[Client] PetHoldPrompt received: " .. petId)
			local holdPetEvent = remotes:FindFirstChild("HoldPet")
			if holdPetEvent then
				holdPetEvent:FireServer(petId)
			end
		end)
		return true
	end
	return false
end
if not connectPetHoldPrompt() then
	remotes.ChildAdded:Connect(function(child)
		if child.Name == "PetHoldPrompt" then
			connectPetHoldPrompt()
		end
	end)
end

-- 선물 수신 알림
giftReceivedEvent.OnClientEvent:Connect(function(senderName, itemDisplayName)
	MainHUD.showMessage(senderName .. " sent you " .. itemDisplayName .. "!", 3)
end)

-- Robux 구매 완료 알림
local purchaseNotifyEvent = remotes:FindFirstChild("PurchaseNotify")
if purchaseNotifyEvent then
	purchaseNotifyEvent.OnClientEvent:Connect(function(purchaseType, data)
		if purchaseType == "building" then
			MainHUD.showMessage(data.itemName .. " added to inventory!", 3)
		elseif purchaseType == "egg" then
			MainHUD.showMessage("Egg added to inventory!", 3)
		elseif purchaseType == "gift" then
			MainHUD.showMessage(data.buyer .. " gifted " .. data.itemName .. " to " .. data.receiver .. "!", 3)
		end
	end)
end

-- 초기 상점 데이터 로드
loadShopData()

----------------------------------------------------------------
-- 설정 UI + 펫 상세 UI
----------------------------------------------------------------

SettingsUI.init({
	onCodeSubmit = function(code)
		local redeemFunc = remotes:FindFirstChild("RedeemCode")
		if not redeemFunc then
			MainHUD.showMessage("Code system unavailable", 2)
			return
		end
		local ok, message = redeemFunc:InvokeServer(code)
		if ok then
			MainHUD.showMessage(message, 3)
		else
			if message == "Code already used" then
				MainHUD.showMessage("You already used this code!", 2)
			elseif message == "Invalid code" then
				MainHUD.showMessage("Invalid code.", 2)
			else
				MainHUD.showMessage(message or "Failed to redeem", 2)
			end
		end
	end,
})
PetDetailUI.init({
	onHold = function(petId)
		local holdPetEvent = remotes:FindFirstChild("HoldPet")
		if holdPetEvent then
			holdPetEvent:FireServer(petId)
		end
	end,
})

-- PetListUI에 펫 상세 보기 연동 (PetUpdate 이벤트로 mutation 표시)
petUpdateEvent.OnClientEvent:Connect(function(eventType, data)
	if eventType == "xpUpdate" or eventType == "levelup" then
		-- PetDetailUI가 열려있고, 같은 펫을 보고 있을 때만 갱신
		if PetDetailUI.isVisible() and data and data.petId and PetDetailUI.getCurrentPetId() == data.petId then
			task.spawn(function()
				local pets = getPetsFunc:InvokeServer()
				if pets then
					for _, pet in pets do
						if pet.petId == data.petId then
							PetDetailUI.show(pet)
							break
						end
					end
				end
			end)
		end
		if eventType == "levelup" then
			local name = data.petName or "Pet"
			local level = data.newLevel or data.level or "?"
			MainHUD.showMessage(name .. " leveled up! Lv." .. level, 3)
		end
	elseif eventType == "mutation" then
		-- 돌연변이 추가 시 알림
		local mutName = Constants.MUTATION_NAMES[data.mutationType] or data.mutationType
		local notifGui = Instance.new("ScreenGui")
		notifGui.Name = "MutationNotif"
		notifGui.ResetOnSpawn = false
		notifGui.DisplayOrder = 40
		notifGui.Parent = playerGui

		local notifFrame = Instance.new("Frame")
		notifFrame.Size = UDim2.new(0, 260, 0, 44)
		notifFrame.Position = UDim2.new(0.5, -130, 0, -50)
		notifFrame.BackgroundColor3 = Constants.MUTATION_COLORS[data.mutationType] or Color3.fromRGB(150, 150, 200)
		notifFrame.BorderSizePixel = 0
		notifFrame.Parent = notifGui

		local nCorner = Instance.new("UICorner")
		nCorner.CornerRadius = UDim.new(0, 10)
		nCorner.Parent = notifFrame

		local nLabel = Instance.new("TextLabel")
		nLabel.Size = UDim2.new(1, -12, 1, 0)
		nLabel.Position = UDim2.new(0, 6, 0, 0)
		nLabel.BackgroundTransparency = 1
		nLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nLabel.TextSize = 13
		nLabel.Font = Enum.Font.GothamBold
		nLabel.Text = "Mutation acquired: " .. mutName .. "!"
		nLabel.Parent = notifFrame

		TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			Position = UDim2.new(0.5, -130, 0, 20)
		}):Play()

		task.delay(3, function()
			if notifGui.Parent then notifGui:Destroy() end
		end)
	end
end)

----------------------------------------------------------------
-- 알(Egg) 시스템
----------------------------------------------------------------

-- 알 이벤트 수신
eggUpdateEvent.OnClientEvent:Connect(function(eventType, data)
	if eventType == "hatched" and data then
		-- 부화 알림 토스트
		local notifGui = Instance.new("ScreenGui")
		notifGui.Name = "HatchNotif"
		notifGui.ResetOnSpawn = false
		notifGui.DisplayOrder = 40
		notifGui.Parent = playerGui

		local rarityColor = Constants.RARITY_COLORS[data.rarity] or Color3.fromRGB(255, 200, 100)

		local notifFrame = Instance.new("Frame")
		notifFrame.Size = UDim2.new(0, 280, 0, 56)
		notifFrame.Position = UDim2.new(0.5, -140, 0, -60)
		notifFrame.BackgroundColor3 = rarityColor
		notifFrame.BorderSizePixel = 0
		notifFrame.Parent = notifGui

		local nCorner = Instance.new("UICorner")
		nCorner.CornerRadius = UDim.new(0, 12)
		nCorner.Parent = notifFrame

		local nLabel = Instance.new("TextLabel")
		nLabel.Size = UDim2.new(1, -12, 1, 0)
		nLabel.Position = UDim2.new(0, 6, 0, 0)
		nLabel.BackgroundTransparency = 1
		nLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nLabel.TextSize = 14
		nLabel.Font = Enum.Font.GothamBold
		nLabel.Text = "Hatched! " .. data.petName .. " (" .. data.rarity .. ")"
		nLabel.TextWrapped = true
		nLabel.Parent = notifFrame

		TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			Position = UDim2.new(0.5, -140, 0, 20)
		}):Play()

		task.delay(3, function()
			if notifGui.Parent then notifGui:Destroy() end
		end)
	end
end)

-- Idle 상태에서 알 클릭 → 부화 시도
-- (InputBegan에서 펫 클릭과 함께 처리)

-- /pos 명령어: 현재 위치 출력
player.Chatted:Connect(function(msg)
	if msg == "/pos" then
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local pos = hrp.Position
				print(string.format("[POS] X=%.1f, Y=%.1f, Z=%.1f", pos.X, pos.Y, pos.Z))
			end
		end
	end
end)

-- Admin Panel UI
AdminUI.init()

-- NPC 상점 열기 (ProximityPrompt E키)
local openShopEvent = remotes:FindFirstChild("OpenShop")
if not openShopEvent then
	openShopEvent = remotes:WaitForChild("OpenShop", 5)
end
-- Pierre (BuildingDealer) greetings
local PIERRE_GREETINGS = {
	"Welcome! Looking for any structures?",
	"Ready to upgrade your village?",
	"I've got the best structures for you!",
	"Feel free to look around!",
	"Fresh structures just arrived!",
}

-- Hailey (PetDealer) greetings
local HAILEY_GREETINGS = {
	"Hi there! Need any help?",
	"Welcome! What kind of buddy are you looking for?",
	"Oh, hey! Feel free to look around!",
	"You might find one you really like!",
	"We've got lots of cute little friends!",
}

local HAILEY_CHOICES = {
	{ text = "I want to sell my pet", id = "sellpet" },
	{ text = "How much is this pet worth?", id = "petworth" },
	{ text = "Show me pet info", id = "petinfo" },
	{ text = "Nevermind", id = "nevermind" },
}

DialogUI.init()
PetSellUI.init()
EggInfoUI.init()
BuildingInfoUI.init({
	onUpgrade = function(buildingId)
		local startUpgradeEvent = remotes:FindFirstChild("StartUpgrade")
		if startUpgradeEvent then
			startUpgradeEvent:FireServer(buildingId)
		end
	end,
})

local _npcDistanceConn = nil

local function stopNpcDistanceCheck()
	if _npcDistanceConn then
		_npcDistanceConn:Disconnect()
		_npcDistanceConn = nil
	end
end

local function startNpcDistanceCheck(npcPart: BasePart)
	stopNpcDistanceCheck()
	_npcDistanceConn = RunService.Heartbeat:Connect(function()
		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp or not npcPart or not npcPart.Parent then
			stopNpcDistanceCheck()
			DialogUI.hide()
			ShopUI.hide()
			return
		end
		local dist = (hrp.Position - npcPart.Position).Magnitude
		if dist > NPC_MAX_DISTANCE then
			stopNpcDistanceCheck()
			DialogUI.hide()
			ShopUI.hide()
		end
	end)
end

if openShopEvent then
	openShopEvent.OnClientEvent:Connect(function(shopType, npcName)
		-- Find NPC parts
		local npcPart = nil
		local npcHead = nil
		local npcFolder = workspace:FindFirstChild("NPC")
		if npcFolder and npcName then
			local npc = npcFolder:FindFirstChild(npcName)
			if npc then
				npcHead = npc:FindFirstChild("Head")
				npcPart = npc:FindFirstChild("HumanoidRootPart")
					or npcHead
					or npc:FindFirstChildWhichIsA("BasePart", true)
			end
		end

		if shopType == "buildings" then
			closeAllPopups()
			-- Pierre greeting on NPC head
			local greeting = PIERRE_GREETINGS[math.random(#PIERRE_GREETINGS)]
			CameraManager.TweenFOV(TweenInfo.new(2.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), 60)
			DialogUI.show("Pierre", greeting, {}, function() end, npcHead or npcPart, 1, function ()
				DialogUI.hide()
				ShopUI.showBuildingsShop()
				CameraManager.TweenFOV(TweenInfo.new(1.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), 55)
			end)
			if npcPart then startNpcDistanceCheck(npcPart) end
		elseif shopType == "eggs" then
			closeAllPopups()
			local greeting = HAILEY_GREETINGS[math.random(#HAILEY_GREETINGS)]
			CameraManager.TweenFOV(TweenInfo.new(2.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), 60)
			DialogUI.show("Hailey", greeting, HAILEY_CHOICES, function(choiceId)
				if choiceId == "sellpet" then
					DialogUI.showResponse("Let me see what you've got!", 1.5)
					task.delay(1.5, function()
						DialogUI.hide()
						PetSellUI.show()
					end)
				elseif choiceId == "petworth" then
					-- 들고 있는 펫 체크 (Character + Backpack)
					local heldPetId = nil
					local character = player.Character
					if character then
						for _, child in character:GetChildren() do
							if child:IsA("Tool") and child:GetAttribute("PetId") then
								heldPetId = child:GetAttribute("PetId")
								break
							end
						end
					end
					if not heldPetId then
						for _, child in player.Backpack:GetChildren() do
							if child:IsA("Tool") and child:GetAttribute("PetId") then
								heldPetId = child:GetAttribute("PetId")
								break
							end
						end
					end

					if heldPetId then
						local getPriceFunc = remotes:FindFirstChild("GetPetSellPrice")
						if getPriceFunc then
							local price = getPriceFunc:InvokeServer(heldPetId)
							DialogUI.showResponse("Hmm, let me take a look...", 1)
							task.delay(1, function()
								DialogUI.showResponse("This one's worth $" .. price .. ".", 3)
							end)
						end
					else
						DialogUI.showResponse("I can't see anything...", 2)
					end
				elseif choiceId == "petinfo" then
					DialogUI.showResponse("Here's what we have!", 1)
					task.delay(1, function()
						DialogUI.hide()
						EggInfoUI.show()
					end)
				elseif choiceId == "nevermind" then
					DialogUI.showResponse("See you around!", 1.5)
				end
			end, npcHead or npcPart)
			if npcPart then startNpcDistanceCheck(npcPart) end
		end
	end)
end

-- Build button enable/disable based on village proximity
RunService.Heartbeat:Connect(function()
	if currentState ~= BuildState.Idle then return end
	local bz = getMyBuildZone()
	if not bz then
		MainHUD.setBuildButtonEnabled(false)
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local localPos = bz.CFrame:PointToObjectSpace(hrp.Position)
	local halfSize = bz.Size / 2
	local inVillage = math.abs(localPos.X) <= halfSize.X + 10 and math.abs(localPos.Z) <= halfSize.Z + 10
	MainHUD.setBuildButtonEnabled(inVillage)
end)

-- 펫 Tool을 들면 PetDetailUI를 닫음 (자동 노출 제거)
local function watchCharacterPetTools(character: Model)
	local function onChildAdded(child)
		if child:IsA("Tool") and child:GetAttribute("PetId") then
			if PetDetailUI.isVisible() then
				PetDetailUI.hide()
			end
		end
	end
	character.ChildAdded:Connect(onChildAdded)
	for _, child in character:GetChildren() do
		onChildAdded(child)
	end
end

player.CharacterAdded:Connect(watchCharacterPetTools)
if player.Character then
	watchCharacterPetTools(player.Character)
end

print("PlacementClient loaded - Build System v6")
