-- BagUI.luau
-- 커스텀 가방 인벤토리: 알 + 건물 통합 표시. 그리드 슬롯, 카운트, 등급 색상

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
local _visible = false
local _onItemClick = nil

-- 등급 색상
local RARITY_COLOR = {
	Common = Color3.fromRGB(140, 200, 140),
	Rare = Color3.fromRGB(100, 180, 255),
	Epic = Color3.fromRGB(200, 130, 255),
	Legendary = Color3.fromRGB(255, 200, 80),
	Mythic = Color3.fromRGB(255, 100, 100),
}

local function tween(obj, props, duration, style)
	local t = TweenService:Create(obj,
		TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props)
	t:Play()
	return t
end

local function buildSlot(parent: GuiObject, item, onClick): Frame
	local rarity = item.rarity or "Common"
	local rarityColor = RARITY_COLOR[rarity] or Color3.fromRGB(180, 180, 180)

	local slot = Instance.new("Frame")
	slot.Size = UDim2.new(0, 86, 0, 100)
	slot.BackgroundColor3 = Color3.fromRGB(48, 40, 32)
	slot.BorderSizePixel = 0
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = rarityColor
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = slot

	-- 그라디언트
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(
		Color3.fromRGB(58, 48, 38),
		Color3.fromRGB(38, 30, 24)
	)
	grad.Parent = slot

	-- 아이콘 영역
	local iconHolder = Instance.new("Frame")
	iconHolder.Size = UDim2.new(1, -10, 0, 50)
	iconHolder.Position = UDim2.new(0, 5, 0, 6)
	iconHolder.BackgroundColor3 = Color3.fromRGB(28, 22, 18)
	iconHolder.BorderSizePixel = 0
	iconHolder.Parent = slot

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 6)
	iconCorner.Parent = iconHolder

	if item.iconAssetId and item.iconAssetId ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, -6, 1, -6)
		icon.Position = UDim2.new(0, 3, 0, 3)
		icon.BackgroundTransparency = 1
		icon.Image = item.iconAssetId
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = iconHolder
	else
		-- 폴백: 등급 색 dot
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 24, 0, 24)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(0.5, 0, 0.5, 0)
		dot.BackgroundColor3 = rarityColor
		dot.BorderSizePixel = 0
		dot.Parent = iconHolder
		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(1, 0)
		dc.Parent = dot
	end

	-- 카운트 배지 (1보다 클 때만)
	if item.count and item.count > 1 then
		local badge = Instance.new("Frame")
		badge.AnchorPoint = Vector2.new(1, 1)
		badge.Position = UDim2.new(1, -4, 1, -4)
		badge.Size = UDim2.new(0, 26, 0, 18)
		badge.BackgroundColor3 = Color3.fromRGB(20, 18, 14)
		badge.BorderSizePixel = 0
		badge.Parent = iconHolder

		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = badge

		local bs = Instance.new("UIStroke")
		bs.Color = rarityColor
		bs.Thickness = 1
		bs.Parent = badge

		local bl = Instance.new("TextLabel")
		bl.Size = UDim2.new(1, 0, 1, 0)
		bl.BackgroundTransparency = 1
		bl.TextColor3 = Color3.fromRGB(255, 255, 255)
		bl.TextSize = 11
		bl.Font = Enum.Font.GothamBold
		bl.Text = "x" .. item.count
		bl.Parent = badge
	end

	-- 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -8, 0, 18)
	nameLabel.Position = UDim2.new(0, 4, 0, 60)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = item.displayName or item.itemName or "?"
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = slot

	-- 등급
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, -8, 0, 14)
	rarityLabel.Position = UDim2.new(0, 4, 0, 80)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextSize = 9
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.Text = rarity
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
	rarityLabel.Parent = slot

	-- 클릭 영역
	local clickBtn = Instance.new("TextButton")
	clickBtn.Size = UDim2.new(1, 0, 1, 0)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.AutoButtonColor = false
	clickBtn.ZIndex = 5
	clickBtn.Parent = slot
	clickBtn.MouseEnter:Connect(function()
		tween(slot, { BackgroundColor3 = Color3.fromRGB(60, 50, 42) }, 0.12)
		tween(stroke, { Thickness = 3 }, 0.12)
	end)
	clickBtn.MouseLeave:Connect(function()
		tween(slot, { BackgroundColor3 = Color3.fromRGB(48, 40, 32) }, 0.12)
		tween(stroke, { Thickness = 2 }, 0.12)
	end)
	clickBtn.MouseButton1Click:Connect(function()
		if onClick then onClick(item) end
	end)

	return slot
end

local function ensureGui()
	if _gui and _gui.Parent then return end

	_gui = Instance.new("ScreenGui")
	_gui.Name = "BagUI"
	_gui.ResetOnSpawn = false
	_gui.DisplayOrder = 30
	_gui.IgnoreGuiInset = false
	_gui.Enabled = false
	_gui.Parent = playerGui

	-- Overlay (클릭으로 닫기)
	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Parent = _gui
	overlay.MouseButton1Click:Connect(function() BagUI.hide() end)

	-- 패널
	_panel = Instance.new("Frame")
	_panel.Size = UDim2.new(0, 480, 0, 420)
	_panel.AnchorPoint = Vector2.new(0.5, 0.5)
	_panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	_panel.BackgroundColor3 = Color3.fromRGB(38, 32, 26)
	_panel.BorderSizePixel = 0
	_panel.Parent = _gui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = _panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(180, 130, 60)
	panelStroke.Thickness = 2
	panelStroke.Parent = _panel

	local panelGrad = Instance.new("UIGradient")
	panelGrad.Rotation = 90
	panelGrad.Color = ColorSequence.new(
		Color3.fromRGB(48, 40, 32),
		Color3.fromRGB(28, 22, 18)
	)
	panelGrad.Parent = _panel

	-- 헤더
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = Color3.fromRGB(140, 90, 50)
	header.BorderSizePixel = 0
	header.Parent = _panel

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 16)
	hCorner.Parent = header

	-- 헤더 하단 둥근 모서리 가리기
	local hMask = Instance.new("Frame")
	hMask.Size = UDim2.new(1, 0, 0, 16)
	hMask.Position = UDim2.new(0, 0, 1, -16)
	hMask.BackgroundColor3 = Color3.fromRGB(140, 90, 50)
	hMask.BorderSizePixel = 0
	hMask.Parent = header

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -100, 1, 0)
	title.Position = UDim2.new(0, 16, 0, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 240, 200)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.Text = "Inventory"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- 닫기 X
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(190, 60, 50)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.AutoButtonColor = true
	closeBtn.Parent = header
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function() BagUI.hide() end)

	-- 그리드 ScrollingFrame
	_grid = Instance.new("ScrollingFrame")
	_grid.Size = UDim2.new(1, -24, 1, -70)
	_grid.Position = UDim2.new(0, 12, 0, 60)
	_grid.BackgroundTransparency = 1
	_grid.BorderSizePixel = 0
	_grid.ScrollBarThickness = 6
	_grid.ScrollBarImageColor3 = Color3.fromRGB(180, 130, 60)
	_grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	_grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	_grid.Parent = _panel

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 86, 0, 100)
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = _grid

	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 6)
	gridPad.PaddingBottom = UDim.new(0, 6)
	gridPad.PaddingLeft = UDim.new(0, 6)
	gridPad.PaddingRight = UDim.new(0, 6)
	gridPad.Parent = _grid
end

local function clearSlots()
	if not _grid then return end
	for _, child in _grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function populate(items)
	clearSlots()
	for i, item in items do
		local slot = buildSlot(_grid, item, _onItemClick)
		slot.LayoutOrder = i
	end
end

local function loadInventory()
	local items = {}

	-- 알 인벤토리
	local getEggsFunc = remotes:FindFirstChild("GetEggs")
	if getEggsFunc then
		local ok, eggs = pcall(function() return getEggsFunc:InvokeServer() end)
		if ok and eggs then
			for _, egg in eggs do
				local info = BalanceConfig.Egg.EGGS[egg.eggType]
				table.insert(items, {
					itemName = egg.eggType,
					displayName = (info and info.name) or egg.eggType,
					rarity = info and info.rarity or "Common",
					count = egg.count,
					iconAssetId = nil,
					kind = "egg",
				})
			end
		end
	end

	-- 건물 인벤토리
	local getInventoryFunc = remotes:FindFirstChild("GetInventory")
	if getInventoryFunc then
		local ok, inv = pcall(function() return getInventoryFunc:InvokeServer() end)
		if ok and inv then
			for _, b in inv do
				local info = Constants.BUILDINGS[b.itemName]
				if info then
					table.insert(items, {
						itemName = b.itemName,
						displayName = info.name or b.itemName,
						rarity = info.rarity or "Common",
						count = b.count,
						level = b.level,
						iconAssetId = info.icon,
						kind = "building",
					})
				end
			end
		end
	end

	populate(items)
end

function BagUI.init(callbacks: { onItemClick: ((any) -> ())? }?)
	_onItemClick = callbacks and callbacks.onItemClick or nil
	ensureGui()

	-- 기본 Roblox Backpack 비활성화
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	-- ₩(Backquote) 또는 I 키로 토글
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.I then
			if _visible then BagUI.hide() else BagUI.show() end
		end
	end)

	-- 인벤토리 변경 시 자동 갱신
	local inventoryUpdateEvent = remotes:FindFirstChild("InventoryUpdate")
	if inventoryUpdateEvent then
		inventoryUpdateEvent.OnClientEvent:Connect(function()
			if _visible then loadInventory() end
		end)
	end
	local eggUpdateEvent = remotes:FindFirstChild("EggUpdate")
	if eggUpdateEvent then
		eggUpdateEvent.OnClientEvent:Connect(function(eventType)
			if _visible and eventType == "inventory" then loadInventory() end
		end)
	end
end

function BagUI.show()
	ensureGui()
	if _visible then return end
	_visible = true
	_gui.Enabled = true

	loadInventory()

	-- 슬라이드인 애니메이션
	if _panel then
		_panel.Size = UDim2.new(0, 480, 0, 0)
		tween(_panel, { Size = UDim2.new(0, 480, 0, 420) }, 0.25, Enum.EasingStyle.Back)
	end
end

function BagUI.hide()
	if not _visible then return end
	_visible = false
	if _gui then _gui.Enabled = false end
end

function BagUI.isVisible(): boolean
	return _visible
end

return BagUI
