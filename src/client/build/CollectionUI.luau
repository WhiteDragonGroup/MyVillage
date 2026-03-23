-- CollectionUI.luau
-- 도감 UI: 카테고리 선택 (건물/펫), 검색, 아이템 그리드, 상세 정보

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CollectionUI = {}

local screenGui = nil
local mainFrame = nil
local contentFrame = nil
local detailFrame = nil
local searchBox = nil
local _visible = false
local _activeCategory = "건물"
local _categoryButtons = {}

local CATEGORIES = { "건물", "펫" }

local PANEL_WIDTH = 340
local PANEL_HEIGHT = 420
local ITEM_SIZE = 70
local ITEM_PADDING = 6

function CollectionUI.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CollectionUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 25
	screenGui.Parent = playerGui

	-- 메인 패널
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "CollectionPanel"
	mainFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
	mainFrame.Position = UDim2.new(0, 10, 0, 104)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	mainFrame.BackgroundTransparency = 0.05
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 120, 200)
	stroke.Thickness = 1.5
	stroke.Parent = mainFrame

	-- 제목
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.new(0, 8, 0, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Text = "도감"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = mainFrame

	-- 카테고리 바
	local catFrame = Instance.new("Frame")
	catFrame.Name = "Categories"
	catFrame.Size = UDim2.new(1, -16, 0, 30)
	catFrame.Position = UDim2.new(0, 8, 0, 40)
	catFrame.BackgroundTransparency = 1
	catFrame.Parent = mainFrame

	local catLayout = Instance.new("UIListLayout")
	catLayout.FillDirection = Enum.FillDirection.Horizontal
	catLayout.Padding = UDim.new(0, 6)
	catLayout.Parent = catFrame

	for i, cat in CATEGORIES do
		local catBtn = Instance.new("TextButton")
		catBtn.Name = cat
		catBtn.Size = UDim2.new(0, 60, 0, 28)
		catBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
		catBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
		catBtn.TextSize = 12
		catBtn.Font = Enum.Font.GothamBold
		catBtn.Text = cat
		catBtn.AutoButtonColor = true
		catBtn.LayoutOrder = i
		catBtn.Parent = catFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = catBtn

		_categoryButtons[cat] = catBtn

		catBtn.MouseButton1Click:Connect(function()
			_activeCategory = cat
			CollectionUI._updateCategoryButtons()
			CollectionUI._renderItems()
		end)
	end

	-- 검색 바
	searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.Size = UDim2.new(1, -16, 0, 28)
	searchBox.Position = UDim2.new(0, 8, 0, 76)
	searchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	searchBox.PlaceholderText = "검색..."
	searchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
	searchBox.TextSize = 12
	searchBox.Font = Enum.Font.Gotham
	searchBox.ClearTextOnFocus = false
	searchBox.Text = ""
	searchBox.Parent = mainFrame

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 6)
	searchCorner.Parent = searchBox

	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = Color3.fromRGB(70, 70, 90)
	searchStroke.Thickness = 1
	searchStroke.Parent = searchBox

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		CollectionUI._renderItems()
	end)

	-- 아이템 그리드 (스크롤)
	contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -16, 1, -118)
	contentFrame.Position = UDim2.new(0, 8, 0, 110)
	contentFrame.BackgroundTransparency = 1
	contentFrame.ScrollBarThickness = 4
	contentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentFrame.Parent = mainFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, ITEM_SIZE, 0, ITEM_SIZE + 20)
	gridLayout.CellPadding = UDim2.new(0, ITEM_PADDING, 0, ITEM_PADDING)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = contentFrame

	-- 상세 정보 프레임 (아이템 클릭 시)
	detailFrame = Instance.new("Frame")
	detailFrame.Name = "Detail"
	detailFrame.Size = UDim2.new(0, PANEL_WIDTH - 20, 0, 130)
	detailFrame.Position = UDim2.new(0, 10, 1, -140)
	detailFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	detailFrame.BorderSizePixel = 0
	detailFrame.Visible = false
	detailFrame.ZIndex = 2
	detailFrame.Parent = mainFrame

	local detailCorner = Instance.new("UICorner")
	detailCorner.CornerRadius = UDim.new(0, 10)
	detailCorner.Parent = detailFrame

	local detailStroke = Instance.new("UIStroke")
	detailStroke.Color = Color3.fromRGB(100, 100, 130)
	detailStroke.Thickness = 1
	detailStroke.Parent = detailFrame

	-- 상세 이름
	local detailName = Instance.new("TextLabel")
	detailName.Name = "DetailName"
	detailName.Size = UDim2.new(1, -16, 0, 22)
	detailName.Position = UDim2.new(0, 8, 0, 8)
	detailName.BackgroundTransparency = 1
	detailName.TextColor3 = Color3.fromRGB(255, 255, 255)
	detailName.TextSize = 14
	detailName.Font = Enum.Font.GothamBold
	detailName.TextXAlignment = Enum.TextXAlignment.Left
	detailName.Parent = detailFrame

	-- 상세 정보 텍스트
	local detailInfo = Instance.new("TextLabel")
	detailInfo.Name = "DetailInfo"
	detailInfo.Size = UDim2.new(1, -16, 1, -36)
	detailInfo.Position = UDim2.new(0, 8, 0, 32)
	detailInfo.BackgroundTransparency = 1
	detailInfo.TextColor3 = Color3.fromRGB(180, 180, 190)
	detailInfo.TextSize = 11
	detailInfo.Font = Enum.Font.Gotham
	detailInfo.TextXAlignment = Enum.TextXAlignment.Left
	detailInfo.TextYAlignment = Enum.TextYAlignment.Top
	detailInfo.TextWrapped = true
	detailInfo.Parent = detailFrame

	-- 닫기 버튼 (상세)
	local closeDetail = Instance.new("TextButton")
	closeDetail.Name = "CloseDetail"
	closeDetail.Size = UDim2.new(0, 22, 0, 22)
	closeDetail.Position = UDim2.new(1, -28, 0, 6)
	closeDetail.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
	closeDetail.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeDetail.TextSize = 12
	closeDetail.Font = Enum.Font.GothamBold
	closeDetail.Text = "X"
	closeDetail.AutoButtonColor = true
	closeDetail.ZIndex = 3
	closeDetail.Parent = detailFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeDetail

	closeDetail.MouseButton1Click:Connect(function()
		detailFrame.Visible = false
	end)

	CollectionUI._updateCategoryButtons()
end

function CollectionUI._updateCategoryButtons()
	for cat, btn in _categoryButtons do
		if cat == _activeCategory then
			btn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
			btn.TextColor3 = Color3.fromRGB(200, 200, 210)
		end
	end
end

function CollectionUI._renderItems()
	if not contentFrame then return end

	-- 기존 슬롯 제거
	for _, child in contentFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	detailFrame.Visible = false

	local query = searchBox and searchBox.Text:lower() or ""
	local index = 0

	if _activeCategory == "건물" then
		for key, building in Constants.BUILDINGS do
			local name = building.name
			if query ~= "" and not name:lower():find(query, 1, true) and not key:lower():find(query, 1, true) then
				continue
			end
			index = index + 1
			CollectionUI._createBuildingSlot(key, building, index)
		end
	elseif _activeCategory == "펫" then
		for key, pet in Constants.PETS do
			if query ~= "" and not key:lower():find(query, 1, true) then
				continue
			end
			index = index + 1
			CollectionUI._createPetSlot(key, pet, index)
		end
	end

	-- 캔버스 크기
	local columns = math.floor((PANEL_WIDTH - 16) / (ITEM_SIZE + ITEM_PADDING))
	if columns < 1 then columns = 1 end
	local rows = math.ceil(index / columns)
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (ITEM_SIZE + 20 + ITEM_PADDING) + 10)

	-- 빈 목록
	if index == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(0, PANEL_WIDTH - 32, 0, 40)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		emptyLabel.TextSize = 13
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.Text = "항목이 없습니다"
		emptyLabel.Parent = contentFrame
	end
end

function CollectionUI._createBuildingSlot(key: string, building, index: number)
	local slot = Instance.new("TextButton")
	slot.Name = key
	slot.Size = UDim2.new(0, ITEM_SIZE, 0, ITEM_SIZE + 20)
	slot.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	slot.AutoButtonColor = true
	slot.LayoutOrder = index
	slot.Text = ""
	slot.Parent = contentFrame

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 8)
	slotCorner.Parent = slot

	local rarityColor = Constants.RARITY_COLORS[building.rarity] or Color3.fromRGB(180, 180, 180)
	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = rarityColor
	slotStroke.Thickness = 1.5
	slotStroke.Parent = slot

	-- 건물 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -4, 0, 30)
	nameLabel.Position = UDim2.new(0, 2, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = building.name
	nameLabel.TextWrapped = true
	nameLabel.Parent = slot

	-- 등급 표시
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, -4, 0, 14)
	rarityLabel.Position = UDim2.new(0, 2, 0, 42)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextSize = 10
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.Text = building.rarity
	rarityLabel.Parent = slot

	-- 유형 표시
	local typeLabel = Instance.new("TextLabel")
	typeLabel.Size = UDim2.new(1, -4, 0, 14)
	typeLabel.Position = UDim2.new(0, 2, 1, -18)
	typeLabel.BackgroundTransparency = 1
	typeLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	typeLabel.TextSize = 9
	typeLabel.Font = Enum.Font.Gotham
	typeLabel.Text = table.concat(building.types, "/")
	typeLabel.Parent = slot

	-- 클릭 시 상세 정보
	slot.MouseButton1Click:Connect(function()
		CollectionUI._showDetail(key, building)
	end)
end

function CollectionUI._createPetSlot(key: string, pet, index: number)
	local slot = Instance.new("TextButton")
	slot.Name = key
	slot.Size = UDim2.new(0, ITEM_SIZE, 0, ITEM_SIZE + 20)
	slot.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	slot.AutoButtonColor = true
	slot.LayoutOrder = index
	slot.Text = ""
	slot.Parent = contentFrame

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 8)
	slotCorner.Parent = slot

	local rarityColor = Constants.RARITY_COLORS[pet.rarity] or Color3.fromRGB(180, 180, 180)
	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = rarityColor
	slotStroke.Thickness = 1.5
	slotStroke.Parent = slot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -4, 0, 30)
	nameLabel.Position = UDim2.new(0, 2, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = key
	nameLabel.TextWrapped = true
	nameLabel.Parent = slot

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, -4, 0, 14)
	rarityLabel.Position = UDim2.new(0, 2, 0, 42)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextSize = 10
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.Text = pet.rarity
	rarityLabel.Parent = slot

	local typeLabel = Instance.new("TextLabel")
	typeLabel.Size = UDim2.new(1, -4, 0, 14)
	typeLabel.Position = UDim2.new(0, 2, 1, -18)
	typeLabel.BackgroundTransparency = 1
	typeLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	typeLabel.TextSize = 9
	typeLabel.Font = Enum.Font.Gotham
	typeLabel.Text = pet.petType
	typeLabel.Parent = slot

	slot.MouseButton1Click:Connect(function()
		CollectionUI._showPetDetail(key, pet)
	end)
end

function CollectionUI._showDetail(key: string, building)
	if not detailFrame then return end

	local detailName = detailFrame:FindFirstChild("DetailName")
	local detailInfo = detailFrame:FindFirstChild("DetailInfo")
	if not detailName or not detailInfo then return end

	detailName.Text = building.name .. " (" .. key .. ")"

	local lines = {}
	table.insert(lines, "등급: " .. building.rarity)
	table.insert(lines, "유형: " .. table.concat(building.types, ", "))
	if building.workTypes then
		table.insert(lines, "작업: " .. table.concat(building.workTypes, ", "))
	end
	local cs = building.collisionSize
	table.insert(lines, "크기: " .. cs.X .. " x " .. cs.Y .. " x " .. cs.Z)
	table.insert(lines, "최대 레벨: " .. BalanceConfig.Upgrade.MAX_LEVEL)

	detailInfo.Text = table.concat(lines, "\n")
	detailFrame.Visible = true
end

function CollectionUI._showPetDetail(key: string, pet)
	if not detailFrame then return end

	local detailName = detailFrame:FindFirstChild("DetailName")
	local detailInfo = detailFrame:FindFirstChild("DetailInfo")
	if not detailName or not detailInfo then return end

	detailName.Text = key

	local lines = {}
	table.insert(lines, "등급: " .. pet.rarity)
	table.insert(lines, "유형: " .. pet.petType)

	detailInfo.Text = table.concat(lines, "\n")
	detailFrame.Visible = true
end

function CollectionUI.show()
	if _visible or not mainFrame then return end
	_visible = true
	mainFrame.Visible = true
	CollectionUI._renderItems()
end

function CollectionUI.hide()
	if not _visible or not mainFrame then return end
	_visible = false
	mainFrame.Visible = false
	detailFrame.Visible = false
end

function CollectionUI.isVisible(): boolean
	return _visible
end

function CollectionUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return CollectionUI
