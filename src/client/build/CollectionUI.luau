-- CollectionUI.luau
-- 도감 UI (기획서 기준)
-- 좌: 카테고리 탭(Pets/Buildings/Mutations) + 검색 + 아이템 리스트(희귀도순)
-- 우: 선택된 아이템 상세 설명

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CollectionUI = {}

local screenGui = nil
local mainFrame = nil
local listFrame = nil   -- 좌측 리스트
local detailFrame = nil -- 우측 상세
local searchBox = nil
local _visible = false
local _activeCategory = "Pets"
local _categoryButtons = {}

local PANEL_WIDTH = 500
local PANEL_HEIGHT = 380
local LIST_WIDTH = 200
local ITEM_HEIGHT = 36
local ITEM_PADDING = 4

-- 희귀도 정렬 순서
local RARITY_ORDER = { ["일반"] = 1, ["희귀"] = 2, ["에픽"] = 3, ["전설"] = 4, ["신화"] = 5 }

local CATEGORIES = { "Pets", "Buildings", "Mutations" }

----------------------------------------------------------------
-- 초기화
----------------------------------------------------------------
function CollectionUI.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CollectionUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 25
	screenGui.Parent = playerGui

	-- 메인 패널 (책 모양)
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "CollectionPanel"
	mainFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
	mainFrame.Position = UDim2.new(0.5, -PANEL_WIDTH / 2, 0.5, -PANEL_HEIGHT / 2)
	mainFrame.BackgroundColor3 = Color3.fromRGB(60, 35, 30)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 60, 40)
	stroke.Thickness = 2
	stroke.Parent = mainFrame

	-- 제목
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(80, 45, 35)
	title.TextColor3 = Color3.fromRGB(255, 230, 200)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Text = "Collection"
	title.Parent = mainFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 12)
	titleCorner.Parent = title

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 26, 0, 26)
	closeBtn.Position = UDim2.new(1, -30, 0, 2)
	closeBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 50)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.AutoButtonColor = true
	closeBtn.ZIndex = 3
	closeBtn.Parent = mainFrame

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		CollectionUI.hide()
	end)

	-- ======== 좌측: 카테고리 + 검색 + 리스트 ========
	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = UDim2.new(0, LIST_WIDTH + 60, 1, -36)
	leftPanel.Position = UDim2.new(0, 4, 0, 34)
	leftPanel.BackgroundTransparency = 1
	leftPanel.Parent = mainFrame

	-- 카테고리 탭 (세로)
	local catFrame = Instance.new("Frame")
	catFrame.Name = "Categories"
	catFrame.Size = UDim2.new(0, 52, 1, 0)
	catFrame.Position = UDim2.new(0, 0, 0, 0)
	catFrame.BackgroundTransparency = 1
	catFrame.Parent = leftPanel

	local catLayout = Instance.new("UIListLayout")
	catLayout.FillDirection = Enum.FillDirection.Vertical
	catLayout.Padding = UDim.new(0, 4)
	catLayout.Parent = catFrame

	for i, cat in CATEGORIES do
		local catBtn = Instance.new("TextButton")
		catBtn.Name = cat
		catBtn.Size = UDim2.new(1, 0, 0, 32)
		catBtn.BackgroundColor3 = Color3.fromRGB(90, 55, 45)
		catBtn.TextColor3 = Color3.fromRGB(200, 180, 160)
		catBtn.TextSize = 10
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

	-- 검색 바 + 리스트 (카테고리 오른쪽)
	local listPanel = Instance.new("Frame")
	listPanel.Name = "ListPanel"
	listPanel.Size = UDim2.new(0, LIST_WIDTH, 1, 0)
	listPanel.Position = UDim2.new(0, 56, 0, 0)
	listPanel.BackgroundTransparency = 1
	listPanel.Parent = leftPanel

	-- 검색 바
	searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.Size = UDim2.new(1, 0, 0, 26)
	searchBox.Position = UDim2.new(0, 0, 0, 0)
	searchBox.BackgroundColor3 = Color3.fromRGB(80, 50, 40)
	searchBox.TextColor3 = Color3.fromRGB(255, 230, 200)
	searchBox.PlaceholderText = "Search..."
	searchBox.PlaceholderColor3 = Color3.fromRGB(150, 130, 110)
	searchBox.TextSize = 11
	searchBox.Font = Enum.Font.Gotham
	searchBox.ClearTextOnFocus = false
	searchBox.Text = ""
	searchBox.Parent = listPanel

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 6)
	searchCorner.Parent = searchBox

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		CollectionUI._renderItems()
	end)

	-- 아이템 리스트 (스크롤)
	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "ItemList"
	listFrame.Size = UDim2.new(1, 0, 1, -32)
	listFrame.Position = UDim2.new(0, 0, 0, 30)
	listFrame.BackgroundColor3 = Color3.fromRGB(70, 40, 35)
	listFrame.BackgroundTransparency = 0.3
	listFrame.ScrollBarThickness = 4
	listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.Parent = listPanel

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 6)
	listCorner.Parent = listFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, ITEM_PADDING)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = listFrame

	-- ======== 우측: 상세 설명 패널 ========
	detailFrame = Instance.new("Frame")
	detailFrame.Name = "DetailPanel"
	detailFrame.Size = UDim2.new(0, PANEL_WIDTH - LIST_WIDTH - 72, 1, -36)
	detailFrame.Position = UDim2.new(0, LIST_WIDTH + 66, 0, 34)
	detailFrame.BackgroundColor3 = Color3.fromRGB(75, 45, 38)
	detailFrame.BackgroundTransparency = 0.2
	detailFrame.BorderSizePixel = 0
	detailFrame.Parent = mainFrame

	local detailCorner = Instance.new("UICorner")
	detailCorner.CornerRadius = UDim.new(0, 8)
	detailCorner.Parent = detailFrame

	-- 상세 기본 텍스트
	local placeholder = Instance.new("TextLabel")
	placeholder.Name = "Placeholder"
	placeholder.Size = UDim2.new(1, -16, 1, 0)
	placeholder.Position = UDim2.new(0, 8, 0, 0)
	placeholder.BackgroundTransparency = 1
	placeholder.TextColor3 = Color3.fromRGB(150, 130, 110)
	placeholder.TextSize = 12
	placeholder.Font = Enum.Font.Gotham
	placeholder.Text = "Select an item"
	placeholder.Parent = detailFrame

	CollectionUI._updateCategoryButtons()
end

----------------------------------------------------------------
-- 카테고리 버튼 업데이트
----------------------------------------------------------------
function CollectionUI._updateCategoryButtons()
	for cat, btn in _categoryButtons do
		if cat == _activeCategory then
			btn.BackgroundColor3 = Color3.fromRGB(140, 80, 50)
			btn.TextColor3 = Color3.fromRGB(255, 240, 220)
		else
			btn.BackgroundColor3 = Color3.fromRGB(90, 55, 45)
			btn.TextColor3 = Color3.fromRGB(200, 180, 160)
		end
	end
end

----------------------------------------------------------------
-- 아이템 리스트 렌더링
----------------------------------------------------------------
function CollectionUI._renderItems()
	if not listFrame then return end

	for _, child in listFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local query = searchBox and searchBox.Text:lower() or ""
	local items = {}

	if _activeCategory == "Pets" then
		for key, pet in Constants.PETS do
			if query == "" or key:lower():find(query, 1, true) then
				table.insert(items, { key = key, name = key, rarity = pet.rarity, data = pet, type = "pet" })
			end
		end
		-- 기본 펫도 추가
		for _, dp in BalanceConfig.Pet.DEFAULT_PETS do
			local exists = false
			for _, item in items do
				if item.name == dp.petName then exists = true; break end
			end
			if not exists and (query == "" or dp.petName:lower():find(query, 1, true)) then
				table.insert(items, { key = dp.petName, name = dp.petName, rarity = dp.rarity, data = dp, type = "pet" })
			end
		end
	elseif _activeCategory == "Buildings" then
		for key, building in Constants.BUILDINGS do
			local name = building.name
			if query == "" or name:lower():find(query, 1, true) or key:lower():find(query, 1, true) then
				table.insert(items, { key = key, name = name, rarity = building.rarity, data = building, type = "building" })
			end
		end
	elseif _activeCategory == "Mutations" then
		for key, displayName in Constants.MUTATION_NAMES do
			if query == "" or displayName:lower():find(query, 1, true) or key:lower():find(query, 1, true) then
				table.insert(items, { key = key, name = displayName, rarity = nil, data = key, type = "mutation" })
			end
		end
	end

	-- 희귀도순 정렬
	table.sort(items, function(a, b)
		local oa = RARITY_ORDER[a.rarity] or 0
		local ob = RARITY_ORDER[b.rarity] or 0
		if oa ~= ob then return oa < ob end
		return a.name < b.name
	end)

	for i, item in items do
		local rarityColor = Color3.fromRGB(180, 160, 140)
		if item.rarity then
			rarityColor = Constants.RARITY_COLORS[item.rarity] or rarityColor
		elseif item.type == "mutation" then
			rarityColor = Constants.MUTATION_COLORS[item.data] or Color3.fromRGB(200, 180, 255)
		end

		local slot = Instance.new("TextButton")
		slot.Name = item.key
		slot.Size = UDim2.new(1, -4, 0, ITEM_HEIGHT)
		slot.BackgroundColor3 = Color3.fromRGB(90, 55, 45)
		slot.AutoButtonColor = true
		slot.LayoutOrder = i
		slot.Text = ""
		slot.Parent = listFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slot

		-- 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -30, 1, 0)
		nameLabel.Position = UDim2.new(0, 8, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 230, 200)
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = item.name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- 등급 점
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 10, 0, 10)
		dot.Position = UDim2.new(1, -18, 0.5, -5)
		dot.BackgroundColor3 = rarityColor
		dot.Parent = slot

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot

		slot.MouseButton1Click:Connect(function()
			CollectionUI._showDetail(item)
		end)
	end

	local totalHeight = #items * (ITEM_HEIGHT + ITEM_PADDING)
	listFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

----------------------------------------------------------------
-- 상세 패널 표시
----------------------------------------------------------------
function CollectionUI._showDetail(item)
	if not detailFrame then return end

	-- 기존 동적 콘텐츠 제거
	for _, child in detailFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local y = 10
	local contentWidth = detailFrame.AbsoluteSize.X - 16

	-- 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -16, 0, 22)
	nameLabel.Position = UDim2.new(0, 8, 0, y)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 240, 210)
	nameLabel.TextSize = 15
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = item.name
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = detailFrame
	y = y + 26

	-- 희귀도
	if item.rarity then
		local rarityColor = Constants.RARITY_COLORS[item.rarity] or Color3.fromRGB(180, 180, 180)
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(1, -16, 0, 16)
		rarityLabel.Position = UDim2.new(0, 8, 0, y)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.TextColor3 = rarityColor
		rarityLabel.TextSize = 11
		rarityLabel.Font = Enum.Font.GothamBold
		rarityLabel.Text = item.rarity
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
		rarityLabel.Parent = detailFrame
		y = y + 20
	end

	-- 구분선
	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, -16, 0, 1)
	sep.Position = UDim2.new(0, 8, 0, y)
	sep.BackgroundColor3 = Color3.fromRGB(120, 80, 60)
	sep.BorderSizePixel = 0
	sep.Parent = detailFrame
	y = y + 8

	if item.type == "pet" then
		-- 펫 상세: 설명, 기본 무게, 하는 일
		local petData = item.data
		local petType = petData.petType or "?"
		local petTypeKor = Constants.PetType[petType] or petType

		local lines = {
			{ "Type", petTypeKor },
			{ "Race", petData.race or "?" },
		}

		-- 기본 무게
		local size = petData.size or "Small"
		local stdWeight = BalanceConfig.Pet.SIZE_STANDARD_WEIGHT[size] or 5
		table.insert(lines, { "Base Weight", string.format("%.1fkg", stdWeight) })
		table.insert(lines, { "Size", size })

		for _, info in lines do
			CollectionUI._infoRow(detailFrame, info[1], info[2], y)
			y = y + 18
		end

		y = y + 6
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -16, 0, 40)
		descLabel.Position = UDim2.new(0, 8, 0, y)
		descLabel.BackgroundTransparency = 1
		descLabel.TextColor3 = Color3.fromRGB(200, 180, 160)
		descLabel.TextSize = 10
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Text = "This pet specializes in " .. petTypeKor .. "."
		descLabel.Parent = detailFrame

	elseif item.type == "building" then
		-- 건물 상세: 유형, 크기, 설명
		local building = item.data
		local lines = {
			{ "Type", table.concat(building.types, ", ") },
		}
		if building.workTypes then
			table.insert(lines, { "Work", table.concat(building.workTypes, ", ") })
		end
		local cs = building.collisionSize
		table.insert(lines, { "Size", cs.X .. " x " .. cs.Y .. " x " .. cs.Z })

		for _, info in lines do
			CollectionUI._infoRow(detailFrame, info[1], info[2], y)
			y = y + 18
		end

		y = y + 6
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -16, 0, 40)
		descLabel.Position = UDim2.new(0, 8, 0, y)
		descLabel.BackgroundTransparency = 1
		descLabel.TextColor3 = Color3.fromRGB(200, 180, 160)
		descLabel.TextSize = 10
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Text = building.name .. " building."
		descLabel.Parent = detailFrame

	elseif item.type == "mutation" then
		-- 돌연변이 상세
		local mutKey = item.data
		local mutColor = Constants.MUTATION_COLORS[mutKey] or Color3.fromRGB(200, 200, 200)
		local speedBonus = BalanceConfig.Weather.MUTATION_SPEED_BONUS[mutKey]

		if speedBonus then
			CollectionUI._infoRow(detailFrame, "Effect", "Work efficiency +" .. math.floor(speedBonus * 100) .. "%", y)
			y = y + 18
		end

		y = y + 6
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -16, 0, 50)
		descLabel.Position = UDim2.new(0, 8, 0, y)
		descLabel.BackgroundTransparency = 1
		descLabel.TextColor3 = mutColor
		descLabel.TextSize = 10
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Text = item.name .. " mutation."
		descLabel.Parent = detailFrame
	end
end

function CollectionUI._infoRow(parent, key, value, y)
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.new(0, 70, 0, 14)
	keyLabel.Position = UDim2.new(0, 8, 0, y)
	keyLabel.BackgroundTransparency = 1
	keyLabel.TextColor3 = Color3.fromRGB(170, 150, 130)
	keyLabel.TextSize = 10
	keyLabel.Font = Enum.Font.Gotham
	keyLabel.Text = key
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.Parent = parent

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, -86, 0, 14)
	valLabel.Position = UDim2.new(0, 78, 0, y)
	valLabel.BackgroundTransparency = 1
	valLabel.TextColor3 = Color3.fromRGB(255, 230, 200)
	valLabel.TextSize = 10
	valLabel.Font = Enum.Font.GothamBold
	valLabel.Text = value
	valLabel.TextXAlignment = Enum.TextXAlignment.Left
	valLabel.Parent = parent
end

----------------------------------------------------------------
-- 공개 API
----------------------------------------------------------------
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
