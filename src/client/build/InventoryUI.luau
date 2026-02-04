-- InventoryUI.luau
-- 하단 인벤토리 바 (슬라이드 애니메이션)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local InventoryUI = {}

local screenGui = nil
local barFrame = nil
local contentFrame = nil
local _onItemSelected = nil  -- 콜백: (itemName) -> ()
local _visible = false
local _inventory = {}  -- { {itemName, count} }

local SLOT_SIZE = 70
local SLOT_PADDING = 8
local BAR_HEIGHT = 90
local SLIDE_TIME = 0.25

function InventoryUI.init(onItemSelected: (string) -> ())
	_onItemSelected = onItemSelected

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InventoryUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

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

	-- 스크롤 가능한 콘텐츠
	contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -20, 1, -10)
	contentFrame.Position = UDim2.new(0, 10, 0, 5)
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

-- 인벤토리 데이터 업데이트
function InventoryUI.updateInventory(inventory: { { itemName: string, count: number } })
	_inventory = inventory
	if _visible then
		InventoryUI._renderSlots()
	end
end

-- 슬롯 렌더링
function InventoryUI._renderSlots()
	if not contentFrame then return end

	-- 기존 슬롯 제거
	for _, child in contentFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for i, item in _inventory do
		local building = Constants.BUILDINGS[item.itemName]
		if not building then continue end

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
		local rarityColor = Constants.RARITY_COLORS[building.rarity] or Color3.fromRGB(180, 180, 180)
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
		nameLabel.Text = building.name
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

		-- 클릭 이벤트
		slot.MouseButton1Click:Connect(function()
			if _onItemSelected then
				_onItemSelected(item.itemName)
			end
		end)
	end

	-- 캔버스 크기 업데이트
	local totalWidth = #_inventory * (SLOT_SIZE + SLOT_PADDING)
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
