-- BagUI.luau
-- 게임 인벤토리 디자인 참고 (Adopt Me / Pet Sim X 스타일)
-- 카드형 슬롯, 등급 글로우, 호버 툴팁, 탭 카테고리

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local BagUI = {}

local _gui: ScreenGui? = nil
local _panel: Frame? = nil
local _grid: ScrollingFrame? = nil
local _tooltip: Frame? = nil
local _activeCategory = "All"
local _visible = false
local _onItemClick = nil

local PALETTE = {
	bgDeep = Color3.fromRGB(34, 28, 40),
	bgPanel = Color3.fromRGB(48, 40, 58),
	bgPanel2 = Color3.fromRGB(58, 48, 70),
	header = Color3.fromRGB(96, 70, 130),
	headerLight = Color3.fromRGB(130, 100, 170),
	gold = Color3.fromRGB(255, 210, 90),
	textMain = Color3.fromRGB(255, 250, 240),
	textDim = Color3.fromRGB(200, 195, 215),
	slotBg = Color3.fromRGB(60, 50, 75),
	slotInner = Color3.fromRGB(38, 32, 48),
	slotHover = Color3.fromRGB(78, 64, 95),
	closeBtn = Color3.fromRGB(220, 80, 80),
}

local RARITY = {
	Common = { color = Color3.fromRGB(160, 200, 160), glow = Color3.fromRGB(120, 220, 140) },
	Rare = { color = Color3.fromRGB(120, 180, 255), glow = Color3.fromRGB(80, 160, 255) },
	Epic = { color = Color3.fromRGB(200, 130, 255), glow = Color3.fromRGB(180, 100, 255) },
	Legendary = { color = Color3.fromRGB(255, 200, 80), glow = Color3.fromRGB(255, 170, 50) },
	Mythic = { color = Color3.fromRGB(255, 100, 110), glow = Color3.fromRGB(255, 60, 80) },
}

local function rarityOf(name): typeof(RARITY.Common)
	return RARITY[name] or RARITY.Common
end

local function tween(obj, props, duration, style, dir)
	local t = TweenService:Create(obj,
		TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
		props)
	t:Play()
	return t
end

local function newCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function newStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local function newShadow(parent, offsetY)
	-- 단순한 드롭쉐도우 (이미지 대신 frame)
	local sh = Instance.new("Frame")
	sh.Name = "Shadow"
	sh.Size = UDim2.new(1, 0, 1, 0)
	sh.Position = UDim2.new(0, 0, 0, offsetY or 4)
	sh.BackgroundColor3 = Color3.new(0, 0, 0)
	sh.BackgroundTransparency = 0.7
	sh.BorderSizePixel = 0
	sh.ZIndex = -1
	sh.Parent = parent
	newCorner(sh, 16)
	return sh
end

----------------------------------------------------------------
-- 툴팁
----------------------------------------------------------------
local function ensureTooltip()
	if _tooltip and _tooltip.Parent then return end

	_tooltip = Instance.new("Frame")
	_tooltip.Name = "Tooltip"
	_tooltip.Size = UDim2.new(0, 220, 0, 90)
	_tooltip.BackgroundColor3 = PALETTE.bgDeep
	_tooltip.BackgroundTransparency = 0.05
	_tooltip.BorderSizePixel = 0
	_tooltip.Visible = false
	_tooltip.ZIndex = 100
	_tooltip.Parent = _gui
	newCorner(_tooltip, 10)
	newStroke(_tooltip, PALETTE.gold, 1, 0.4)

	local tName = Instance.new("TextLabel")
	tName.Name = "ItemName"
	tName.Size = UDim2.new(1, -16, 0, 20)
	tName.Position = UDim2.new(0, 8, 0, 8)
	tName.BackgroundTransparency = 1
	tName.Font = Enum.Font.GothamBold
	tName.TextSize = 15
	tName.TextColor3 = PALETTE.textMain
	tName.TextXAlignment = Enum.TextXAlignment.Left
	tName.ZIndex = 101
	tName.Parent = _tooltip

	local tRarity = Instance.new("TextLabel")
	tRarity.Name = "Rarity"
	tRarity.Size = UDim2.new(1, -16, 0, 14)
	tRarity.Position = UDim2.new(0, 8, 0, 30)
	tRarity.BackgroundTransparency = 1
	tRarity.Font = Enum.Font.GothamBold
	tRarity.TextSize = 11
	tRarity.TextXAlignment = Enum.TextXAlignment.Left
	tRarity.ZIndex = 101
	tRarity.Parent = _tooltip

	local tDesc = Instance.new("TextLabel")
	tDesc.Name = "Desc"
	tDesc.Size = UDim2.new(1, -16, 1, -54)
	tDesc.Position = UDim2.new(0, 8, 0, 50)
	tDesc.BackgroundTransparency = 1
	tDesc.Font = Enum.Font.Gotham
	tDesc.TextSize = 11
	tDesc.TextColor3 = PALETTE.textDim
	tDesc.TextXAlignment = Enum.TextXAlignment.Left
	tDesc.TextYAlignment = Enum.TextYAlignment.Top
	tDesc.TextWrapped = true
	tDesc.ZIndex = 101
	tDesc.Parent = _tooltip
end

local function showTooltip(item, anchor: GuiObject)
	ensureTooltip()
	if not _tooltip then return end
	local r = rarityOf(item.rarity)
	_tooltip.ItemName.Text = item.displayName or item.itemName or "?"
	_tooltip.Rarity.Text = (item.rarity or "Common")
	_tooltip.Rarity.TextColor3 = r.color
	_tooltip.Desc.Text = item.description or ""

	local pos = anchor.AbsolutePosition
	local size = anchor.AbsoluteSize
	-- 슬롯 우측에 표시, 화면 밖이면 좌측
	local screenSize = workspace.CurrentCamera.ViewportSize
	local x = pos.X + size.X + 8
	if x + 220 > screenSize.X then
		x = pos.X - 228
	end
	local y = math.min(pos.Y, screenSize.Y - 100)
	_tooltip.Position = UDim2.new(0, x, 0, y)
	_tooltip.Visible = true
end

local function hideTooltip()
	if _tooltip then _tooltip.Visible = false end
end

----------------------------------------------------------------
-- 슬롯
----------------------------------------------------------------
local function buildSlot(parent, item, onClick)
	local r = rarityOf(item.rarity)

	-- 카드 컨테이너
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 96, 0, 116)
	card.BackgroundColor3 = PALETTE.slotBg
	card.BorderSizePixel = 0
	card.ClipsDescendants = false
	card.Parent = parent
	newCorner(card, 12)

	-- 그라디언트 배경
	local cardGrad = Instance.new("UIGradient")
	cardGrad.Rotation = 90
	cardGrad.Color = ColorSequence.new(
		Color3.fromRGB(70, 58, 88),
		Color3.fromRGB(50, 40, 65)
	)
	cardGrad.Parent = card

	-- 등급 글로우 (외곽)
	local glow = Instance.new("UIStroke")
	glow.Color = r.color
	glow.Thickness = 2
	glow.Transparency = 0.3
	glow.Parent = card

	-- 등급 색 상단 배너 (작게)
	local banner = Instance.new("Frame")
	banner.Size = UDim2.new(1, 0, 0, 5)
	banner.Position = UDim2.new(0, 0, 0, 0)
	banner.BackgroundColor3 = r.color
	banner.BorderSizePixel = 0
	banner.Parent = card
	newCorner(banner, 12)
	-- 하단 둥근 각 막기
	local bMask = Instance.new("Frame")
	bMask.Size = UDim2.new(1, 0, 0, 4)
	bMask.Position = UDim2.new(0, 0, 1, -4)
	bMask.BackgroundColor3 = r.color
	bMask.BorderSizePixel = 0
	bMask.Parent = banner

	-- 아이콘 영역
	local iconBox = Instance.new("Frame")
	iconBox.Size = UDim2.new(1, -14, 0, 64)
	iconBox.Position = UDim2.new(0, 7, 0, 11)
	iconBox.BackgroundColor3 = PALETTE.slotInner
	iconBox.BorderSizePixel = 0
	iconBox.Parent = card
	newCorner(iconBox, 8)

	-- 아이콘 박스 그라디언트
	local iconGrad = Instance.new("UIGradient")
	iconGrad.Rotation = 135
	iconGrad.Color = ColorSequence.new(
		Color3.fromRGB(50, 42, 60),
		Color3.fromRGB(30, 24, 40)
	)
	iconGrad.Parent = iconBox

	-- 등급 글로우 (아이콘 박스 안쪽)
	local iconGlow = Instance.new("UIGradient")
	iconGlow.Rotation = 90
	iconGlow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, r.glow),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
	})
	iconGlow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})

	if item.iconAssetId and item.iconAssetId ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, -10, 1, -10)
		icon.Position = UDim2.new(0, 5, 0, 5)
		icon.BackgroundTransparency = 1
		icon.Image = item.iconAssetId
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = iconBox
	else
		-- 폴백: 등급 색 동그라미 + 텍스트
		local circle = Instance.new("Frame")
		circle.Size = UDim2.new(0, 36, 0, 36)
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.new(0.5, 0, 0.5, 0)
		circle.BackgroundColor3 = r.color
		circle.BorderSizePixel = 0
		circle.Parent = iconBox
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(1, 0)
		cc.Parent = circle
		local cs = Instance.new("UIStroke")
		cs.Color = Color3.new(1, 1, 1)
		cs.Thickness = 1.5
		cs.Transparency = 0.5
		cs.Parent = circle

		-- 첫 글자
		local letter = Instance.new("TextLabel")
		letter.Size = UDim2.new(1, 0, 1, 0)
		letter.BackgroundTransparency = 1
		letter.Font = Enum.Font.GothamBold
		letter.TextSize = 18
		letter.TextColor3 = Color3.new(1, 1, 1)
		letter.Text = string.upper(string.sub(item.displayName or "?", 1, 1))
		letter.Parent = circle
	end

	-- 카운트 배지
	if item.count and item.count > 1 then
		local badge = Instance.new("Frame")
		badge.AnchorPoint = Vector2.new(1, 1)
		badge.Position = UDim2.new(1, -3, 1, -3)
		badge.Size = UDim2.new(0, 30, 0, 18)
		badge.BackgroundColor3 = PALETTE.gold
		badge.BorderSizePixel = 0
		badge.ZIndex = 3
		badge.Parent = iconBox
		newCorner(badge, 8)
		newStroke(badge, Color3.fromRGB(80, 50, 10), 1, 0.2)

		local bl = Instance.new("TextLabel")
		bl.Size = UDim2.new(1, 0, 1, 0)
		bl.BackgroundTransparency = 1
		bl.Font = Enum.Font.GothamBold
		bl.TextSize = 11
		bl.TextColor3 = Color3.fromRGB(60, 40, 10)
		bl.Text = "x" .. item.count
		bl.ZIndex = 4
		bl.Parent = badge
	end

	-- 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -10, 0, 18)
	nameLabel.Position = UDim2.new(0, 5, 0, 80)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 11
	nameLabel.TextColor3 = PALETTE.textMain
	nameLabel.Text = item.displayName or "?"
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = card

	-- 등급 텍스트
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, -10, 0, 12)
	rarityLabel.Position = UDim2.new(0, 5, 1, -16)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextSize = 9
	rarityLabel.TextColor3 = r.color
	rarityLabel.Text = item.rarity or "Common"
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
	rarityLabel.Parent = card

	-- 클릭/호버 영역
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ZIndex = 5
	btn.Parent = card

	btn.MouseEnter:Connect(function()
		tween(card, { Size = UDim2.new(0, 100, 0, 120) }, 0.15)
		tween(glow, { Thickness = 3, Transparency = 0.1 }, 0.15)
		showTooltip(item, card)
	end)
	btn.MouseLeave:Connect(function()
		tween(card, { Size = UDim2.new(0, 96, 0, 116) }, 0.15)
		tween(glow, { Thickness = 2, Transparency = 0.3 }, 0.15)
		hideTooltip()
	end)
	btn.MouseButton1Click:Connect(function()
		hideTooltip()
		if onClick then onClick(item) end
	end)

	return card
end

----------------------------------------------------------------
-- GUI 구조
----------------------------------------------------------------
local function ensureGui()
	if _gui and _gui.Parent then return end

	_gui = Instance.new("ScreenGui")
	_gui.Name = "BagUI"
	_gui.ResetOnSpawn = false
	_gui.DisplayOrder = 30
	_gui.IgnoreGuiInset = false
	_gui.Enabled = false
	_gui.Parent = playerGui

	-- 어두운 오버레이
	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.55
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Parent = _gui
	overlay.MouseButton1Click:Connect(function() BagUI.hide() end)

	-- 패널 컨테이너
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, 560, 0, 460)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.BackgroundTransparency = 1
	container.Parent = _gui

	-- 드롭쉐도우
	newShadow(container, 6)

	-- 메인 패널
	_panel = Instance.new("Frame")
	_panel.Size = UDim2.new(1, 0, 1, 0)
	_panel.BackgroundColor3 = PALETTE.bgPanel
	_panel.BorderSizePixel = 0
	_panel.Parent = container
	newCorner(_panel, 16)

	local panelGrad = Instance.new("UIGradient")
	panelGrad.Rotation = 90
	panelGrad.Color = ColorSequence.new(
		PALETTE.bgPanel2,
		PALETTE.bgPanel
	)
	panelGrad.Parent = _panel

	newStroke(_panel, PALETTE.headerLight, 2, 0.4)

	-- 헤더
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundColor3 = PALETTE.header
	header.BorderSizePixel = 0
	header.Parent = _panel
	newCorner(header, 16)

	-- 헤더 하단 모서리 막기
	local hMask = Instance.new("Frame")
	hMask.Size = UDim2.new(1, 0, 0, 16)
	hMask.Position = UDim2.new(0, 0, 1, -16)
	hMask.BackgroundColor3 = PALETTE.header
	hMask.BorderSizePixel = 0
	hMask.Parent = header

	local headerGrad = Instance.new("UIGradient")
	headerGrad.Rotation = 90
	headerGrad.Color = ColorSequence.new(
		PALETTE.headerLight,
		PALETTE.header
	)
	headerGrad.Parent = header

	-- 가방 아이콘 자리 (작은 동그라미)
	local bagIcon = Instance.new("Frame")
	bagIcon.Size = UDim2.new(0, 32, 0, 32)
	bagIcon.AnchorPoint = Vector2.new(0, 0.5)
	bagIcon.Position = UDim2.new(0, 14, 0.5, 0)
	bagIcon.BackgroundColor3 = PALETTE.gold
	bagIcon.BorderSizePixel = 0
	bagIcon.Parent = header
	local biCorner = Instance.new("UICorner")
	biCorner.CornerRadius = UDim.new(1, 0)
	biCorner.Parent = bagIcon
	local biStroke = Instance.new("UIStroke")
	biStroke.Color = Color3.fromRGB(120, 80, 30)
	biStroke.Thickness = 2
	biStroke.Parent = bagIcon

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 200, 1, 0)
	title.Position = UDim2.new(0, 56, 0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = PALETTE.textMain
	title.TextStrokeTransparency = 0.7
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.Text = "MY BAG"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 38, 0, 38)
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
	closeBtn.BackgroundColor3 = PALETTE.closeBtn
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextSize = 18
	closeBtn.Text = "×"
	closeBtn.AutoButtonColor = true
	closeBtn.Parent = header
	newCorner(closeBtn, 10)
	newStroke(closeBtn, Color3.fromRGB(140, 40, 40), 1.5)
	closeBtn.MouseButton1Click:Connect(function() BagUI.hide() end)

	-- 카테고리 탭
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, -24, 0, 40)
	tabBar.Position = UDim2.new(0, 12, 0, 64)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = _panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabBar

	local CATEGORIES = { "All", "Eggs", "Pets" }
	for i, cat in CATEGORIES do
		local tab = Instance.new("TextButton")
		tab.Name = "Tab_" .. cat
		tab.Size = UDim2.new(0, 84, 1, -8)
		tab.Position = UDim2.new(0, 0, 0, 4)
		tab.BackgroundColor3 = (cat == _activeCategory) and PALETTE.gold or PALETTE.bgPanel
		tab.TextColor3 = (cat == _activeCategory) and Color3.fromRGB(60, 40, 10) or PALETTE.textDim
		tab.Font = Enum.Font.GothamBold
		tab.TextSize = 12
		tab.Text = cat
		tab.AutoButtonColor = false
		tab.LayoutOrder = i
		tab.Parent = tabBar
		newCorner(tab, 8)
		newStroke(tab, (cat == _activeCategory) and Color3.fromRGB(140, 100, 30) or PALETTE.bgPanel2, 1)

		tab.MouseButton1Click:Connect(function()
			_activeCategory = cat
			-- 탭 비주얼 갱신
			for _, t in tabBar:GetChildren() do
				if t:IsA("TextButton") then
					local active = (t.Name == "Tab_" .. cat)
					tween(t, {
						BackgroundColor3 = active and PALETTE.gold or PALETTE.bgPanel,
						TextColor3 = active and Color3.fromRGB(60, 40, 10) or PALETTE.textDim,
					}, 0.12)
				end
			end
			BagUI._refresh()
		end)
	end

	-- 그리드
	_grid = Instance.new("ScrollingFrame")
	_grid.Size = UDim2.new(1, -24, 1, -120)
	_grid.Position = UDim2.new(0, 12, 0, 110)
	_grid.BackgroundColor3 = PALETTE.bgDeep
	_grid.BackgroundTransparency = 0.4
	_grid.BorderSizePixel = 0
	_grid.ScrollBarThickness = 6
	_grid.ScrollBarImageColor3 = PALETTE.gold
	_grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	_grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	_grid.Parent = _panel
	newCorner(_grid, 12)
	newStroke(_grid, PALETTE.bgPanel2, 1, 0.3)

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 96, 0, 116)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.Parent = _grid

	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 12)
	gridPad.PaddingBottom = UDim.new(0, 12)
	gridPad.PaddingLeft = UDim.new(0, 12)
	gridPad.PaddingRight = UDim.new(0, 12)
	gridPad.Parent = _grid
end

----------------------------------------------------------------
-- 데이터 로드 + 렌더
----------------------------------------------------------------
local _allItems = {}

local function clearSlots()
	if not _grid then return end
	for _, child in _grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function loadInventory()
	_allItems = {}

	-- 알
	local getEggsFunc = remotes:FindFirstChild("GetEggs")
	if getEggsFunc then
		local ok, eggs = pcall(function() return getEggsFunc:InvokeServer() end)
		if ok and eggs then
			for _, egg in eggs do
				local info = BalanceConfig.Egg.EGGS[egg.eggType]
				table.insert(_allItems, {
					itemName = egg.eggType,
					displayName = (info and info.name) or egg.eggType,
					rarity = info and info.rarity or "Common",
					count = egg.count,
					iconAssetId = nil,
					description = info and info.description or "An egg waiting to hatch.",
					kind = "egg",
				})
			end
		end
	end

	-- 펫 (배정 안 된 펫만)
	local getPetsFunc = remotes:FindFirstChild("GetPets")
	if getPetsFunc then
		local ok, pets = pcall(function() return getPetsFunc:InvokeServer() end)
		if ok and pets then
			for _, pet in pets do
				if (pet.assignedBuildingId == "" or pet.assignedBuildingId == nil) then
					local petInfo = Constants.PETS[pet.petName]
					local desc = string.format("%s · Lv.%d · %.1fkg",
						pet.rarity or "Common",
						pet.level or 1,
						pet.weight or 0)
					table.insert(_allItems, {
						itemName = pet.petName,
						petId = pet.petId,
						displayName = (petInfo and petInfo.name) or pet.petName,
						rarity = pet.rarity or "Common",
						count = 1,
						iconAssetId = petInfo and petInfo.icon,
						description = desc,
						kind = "pet",
					})
				end
			end
		end
	end

	BagUI._refresh()
end

function BagUI._refresh()
	if not _grid then return end
	clearSlots()
	local rarityOrder = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }
	local kindFilter = nil
	if _activeCategory == "Eggs" then kindFilter = "egg"
	elseif _activeCategory == "Pets" then kindFilter = "pet"
	end

	local filtered = {}
	for _, it in _allItems do
		if not kindFilter or it.kind == kindFilter then
			table.insert(filtered, it)
		end
	end
	table.sort(filtered, function(a, b)
		if a.kind ~= b.kind then
			return a.kind == "egg" -- 알 먼저
		end
		local ra = rarityOrder[a.rarity] or 99
		local rb = rarityOrder[b.rarity] or 99
		if ra ~= rb then return ra < rb end
		return (a.displayName or "") < (b.displayName or "")
	end)

	if #filtered == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -20, 0, 60)
		empty.Position = UDim2.new(0, 10, 0, 30)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.GothamBold
		empty.TextSize = 14
		empty.TextColor3 = PALETTE.textDim
		empty.Text = "Bag is empty."
		empty.Parent = _grid
		return
	end

	for i, item in filtered do
		local slot = buildSlot(_grid, item, _onItemClick)
		slot.LayoutOrder = i
	end
end

----------------------------------------------------------------
-- 공개 API
----------------------------------------------------------------
function BagUI.init(callbacks: { onItemClick: ((any) -> ())? }?)
	_onItemClick = callbacks and callbacks.onItemClick or nil
	ensureGui()

	-- 기본 Roblox Backpack 비활성화
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	-- ₩(Backquote) 키로 토글
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Backquote then
			if _visible then BagUI.hide() else BagUI.show() end
		end
	end)

	-- 인벤토리 변경 자동 반영
	local eggUpdateEvent = remotes:FindFirstChild("EggUpdate")
	if eggUpdateEvent then
		eggUpdateEvent.OnClientEvent:Connect(function(eventType)
			if _visible and eventType == "inventory" then loadInventory() end
		end)
	end
	local petUpdateEvent = remotes:FindFirstChild("PetUpdate")
	if petUpdateEvent then
		petUpdateEvent.OnClientEvent:Connect(function()
			if _visible then loadInventory() end
		end)
	end
end

function BagUI.show()
	ensureGui()
	if _visible then return end
	_visible = true
	_gui.Enabled = true

	loadInventory()

	-- 부드럽게 열기
	if _panel then
		_panel.Parent.Size = UDim2.new(0, 560, 0, 0)
		tween(_panel.Parent, { Size = UDim2.new(0, 560, 0, 460) }, 0.28, Enum.EasingStyle.Back)
	end
end

function BagUI.hide()
	if not _visible then return end
	_visible = false
	hideTooltip()
	if _gui then _gui.Enabled = false end
end

function BagUI.isVisible(): boolean
	return _visible
end

return BagUI
