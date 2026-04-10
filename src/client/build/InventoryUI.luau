-- InventoryUI.luau
-- 하단 인벤토리 바 (슬라이드 애니메이션)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local InventoryUI = {}

local screenGui = nil
local barFrame = nil
local contentFrame = nil
local exitButton = nil
local filterFrame = nil
local _onItemSelected = nil  -- 콜백: (itemName, level) -> ()
local _onExit = nil          -- 콜백: () -> ()
local _visible = false
local _inventory = {}  -- { {itemName, count, level} }
local _activeFilter = "전체" -- 현재 필터
local _filterButtons = {}

local SLOT_SIZE = 70
local SLOT_PADDING = 8
local BAR_HEIGHT = 100
local SLIDE_TIME = 0.25
local FILTER_WIDTH = 70

local FILTER_DEFS = {
	{ id = "전체", label = "전체" },
	{ id = "일터", label = "일터" },
	{ id = "쉼터", label = "쉼터" },
	{ id = "지원", label = "지원" },
	{ id = "장식", label = "장식" },
}

function InventoryUI.init(onItemSelected: (string, number) -> (), onExit: (() -> ())?)
	_onItemSelected = onItemSelected
	_onExit = onExit

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InventoryUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	-- Exit Building 버튼 (상단 중앙, 빌드모드 시 표시)
	exitButton = Instance.new("TextButton")
	exitButton.Name = "ExitBuildButton"
	exitButton.Size = UDim2.new(0, 140, 0, 36)
	exitButton.Position = UDim2.new(0.5, -70, 0, 60)
	exitButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	exitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	exitButton.TextSize = 14
	exitButton.Font = Enum.Font.GothamBold
	exitButton.Text = "Exit Building"
	exitButton.AutoButtonColor = true
	exitButton.Visible = false
	exitButton.Parent = screenGui

	local exitCorner = Instance.new("UICorner")
	exitCorner.CornerRadius = UDim.new(0, 8)
	exitCorner.Parent = exitButton

	local exitStroke = Instance.new("UIStroke")
	exitStroke.Color = Color3.fromRGB(220, 80, 80)
	exitStroke.Thickness = 2
	exitStroke.Parent = exitButton

	exitButton.MouseButton1Click:Connect(function()
		if _onExit then
			_onExit()
		end
	end)

	-- 바 프레임 (하단, 처음엔 숨김)
	barFrame = Instance.new("Frame")
	barFrame.Name = "InventoryBar"
	barFrame.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
	barFrame.Position = UDim2.new(0, 0, 1, BAR_HEIGHT) -- 화면 아래 숨김
	barFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	barFrame.BackgroundTransparency = 0.15
	barFrame.BorderSizePixel = 0
	barFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = barFrame

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.fromRGB(80, 80, 100)
	topStroke.Thickness = 1
	topStroke.Parent = barFrame

	-- 필터 탭 (좌측)
	filterFrame = Instance.new("Frame")
	filterFrame.Name = "FilterFrame"
	filterFrame.Size = UDim2.new(0, FILTER_WIDTH, 1, -6)
	filterFrame.Position = UDim2.new(0, 4, 0, 3)
	filterFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	filterFrame.BackgroundTransparency = 0.3
	filterFrame.BorderSizePixel = 0
	filterFrame.Parent = barFrame

	local filterCorner = Instance.new("UICorner")
	filterCorner.CornerRadius = UDim.new(0, 8)
	filterCorner.Parent = filterFrame

	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Vertical
	filterLayout.Padding = UDim.new(0, 2)
	filterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	filterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	filterLayout.Parent = filterFrame

	for i, def in FILTER_DEFS do
		local fBtn = Instance.new("TextButton")
		fBtn.Name = def.id
		fBtn.Size = UDim2.new(1, -6, 0, 16)
		fBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
		fBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
		fBtn.TextSize = 10
		fBtn.Font = Enum.Font.GothamBold
		fBtn.Text = def.label
		fBtn.AutoButtonColor = true
		fBtn.LayoutOrder = i
		fBtn.Parent = filterFrame

		local fCorner = Instance.new("UICorner")
		fCorner.CornerRadius = UDim.new(0, 4)
		fCorner.Parent = fBtn

		_filterButtons[def.id] = fBtn

		fBtn.MouseButton1Click:Connect(function()
			_activeFilter = def.id
			InventoryUI._updateFilterButtons()
			InventoryUI._renderSlots()
		end)
	end
	InventoryUI._updateFilterButtons()

	-- 스크롤 가능한 콘텐츠 (필터 오른쪽)
	contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -(FILTER_WIDTH + 14), 1, -10)
	contentFrame.Position = UDim2.new(0, FILTER_WIDTH + 8, 0, 5)
	contentFrame.BackgroundTransparency = 1
	contentFrame.ScrollBarThickness = 0
	contentFrame.ScrollingDirection = Enum.ScrollingDirection.X
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentFrame.Parent = barFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, SLOT_PADDING)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = contentFrame
end

-- 필터 버튼 업데이트
function InventoryUI._updateFilterButtons()
	for id, btn in _filterButtons do
		if id == _activeFilter then
			btn.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
			btn.TextColor3 = Color3.fromRGB(200, 200, 210)
		end
	end
end

-- 인벤토리 데이터 업데이트
function InventoryUI.updateInventory(inventory: { { itemName: string, count: number } })
	_inventory = inventory
	if _visible then
		InventoryUI._renderSlots()
	end
end

-- 슬롯 렌더링 (필터 적용)
function InventoryUI._renderSlots()
	if not contentFrame then return end

	-- 기존 슬롯 제거
	for _, child in contentFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local filteredIndex = 0
	for i, item in _inventory do
		local isEgg = item.isEgg == true
		local building = if not isEgg then Constants.BUILDINGS[item.itemName] else nil
		local eggInfo = if isEgg then (BalanceConfig.Egg and BalanceConfig.Egg.EGGS[item.itemName]) else nil

		if not building and not eggInfo then continue end

		-- 필터 적용 (알은 "전체"에서만 표시)
		if not isEgg and _activeFilter ~= "전체" then
			local matchesFilter = false
			for _, t in building.types do
				if t == _activeFilter then
					matchesFilter = true
					break
				end
			end
			if not matchesFilter then continue end
		end

		filteredIndex = filteredIndex + 1

		local slot = Instance.new("TextButton")
		slot.Name = item.itemName
		slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
		slot.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
		slot.AutoButtonColor = true
		slot.LayoutOrder = i
		slot.Text = ""
		slot.Parent = contentFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 10)
		slotCorner.Parent = slot

		-- 등급 테두리
		local displayName = if building then building.name elseif eggInfo then eggInfo.name else item.itemName
		local displayRarity = if building then building.rarity elseif eggInfo then eggInfo.rarity else "일반"
		local rarityColor = Constants.RARITY_COLORS[displayRarity] or Color3.fromRGB(180, 180, 180)
		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = rarityColor
		slotStroke.Thickness = 2
		slotStroke.Parent = slot

		-- 건물 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -4, 0, 30)
		nameLabel.Position = UDim2.new(0, 2, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = displayName
		nameLabel.TextWrapped = true
		nameLabel.Parent = slot

		-- 수량 표시
		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0, 24, 0, 18)
		countLabel.Position = UDim2.new(1, -26, 1, -20)
		countLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		countLabel.BackgroundTransparency = 0.3
		countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		countLabel.TextSize = 12
		countLabel.Font = Enum.Font.GothamBold
		countLabel.Text = tostring(item.count)
		countLabel.Parent = slot

		local countCorner = Instance.new("UICorner")
		countCorner.CornerRadius = UDim.new(0, 6)
		countCorner.Parent = countLabel

		-- 단축키 번호 표시 (오른쪽 위)
		if i <= 9 then
			local keyLabel = Instance.new("TextLabel")
			keyLabel.Size = UDim2.new(0, 18, 0, 16)
			keyLabel.Position = UDim2.new(1, -20, 0, 2)
			keyLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			keyLabel.BackgroundTransparency = 0.3
			keyLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
			keyLabel.TextSize = 11
			keyLabel.Font = Enum.Font.GothamBold
			keyLabel.Text = tostring(i)
			keyLabel.Parent = slot

			local keyCorner = Instance.new("UICorner")
			keyCorner.CornerRadius = UDim.new(0, 4)
			keyCorner.Parent = keyLabel
		end

		-- 레벨 뱃지 (Lv2 이상)
		local itemLevel = item.level or 1
		if itemLevel > 1 then
			local lvlLabel = Instance.new("TextLabel")
			lvlLabel.Size = UDim2.new(0, 26, 0, 16)
			lvlLabel.Position = UDim2.new(0, 2, 1, -18)
			lvlLabel.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
			lvlLabel.BackgroundTransparency = 0.15
			lvlLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			lvlLabel.TextSize = 10
			lvlLabel.Font = Enum.Font.GothamBold
			lvlLabel.Text = "Lv" .. itemLevel
			lvlLabel.Parent = slot

			local lvlCorner = Instance.new("UICorner")
			lvlCorner.CornerRadius = UDim.new(0, 4)
			lvlCorner.Parent = lvlLabel
		end

		-- 클릭 이벤트
		slot.MouseButton1Click:Connect(function()
			if _onItemSelected then
				_onItemSelected(item.itemName, itemLevel)
			end
		end)
	end

	-- 캔버스 크기 업데이트
	local totalWidth = filteredIndex * (SLOT_SIZE + SLOT_PADDING)
	contentFrame.CanvasSize = UDim2.new(0, totalWidth, 0, 0)
end

-- 슬라이드 인 (표시)
function InventoryUI.show()
	if _visible or not barFrame then return end
	_visible = true

	InventoryUI._renderSlots()

	TweenService:Create(barFrame, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 1, -BAR_HEIGHT)
	}):Play()
end

-- 슬라이드 아웃 (숨김)
function InventoryUI.hide()
	if not _visible or not barFrame then return end
	_visible = false

	local tween = TweenService:Create(barFrame, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0, 0, 1, BAR_HEIGHT)
	})
	tween:Play()
end

-- 숫자키로 아이템 선택
function InventoryUI.selectByIndex(index: number)
	if not _visible or not _onItemSelected then return end
	local item = _inventory[index]
	if item then
		_onItemSelected(item.itemName, item.level or 1)
	end
end

function InventoryUI.isVisible(): boolean
	return _visible
end

function InventoryUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return InventoryUI
