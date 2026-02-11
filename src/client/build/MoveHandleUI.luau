-- MoveHandleUI.luau
-- 이동/회전 드래그 핸들 + Place 버튼

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MoveHandleUI = {}

local screenGui = nil
local panel = nil
local placeButton = nil

local _callbacks = {}
local _visible = false

local BUTTON_SIZE = 56
local PANEL_PADDING = 8

function MoveHandleUI.init(callbacks: {
	onPlace: () -> (),
	onRotateLeft: () -> (),
	onRotateRight: () -> (),
	onCancel: () -> (),
})
	_callbacks = callbacks

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MoveHandleUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 20
	screenGui.Parent = playerGui

	-- 하단 중앙 패널 (인벤토리 위)
	local panelWidth = (BUTTON_SIZE + PANEL_PADDING) * 4 + PANEL_PADDING * 2
	local panelHeight = BUTTON_SIZE + PANEL_PADDING * 2

	panel = Instance.new("Frame")
	panel.Name = "MovePanel"
	panel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
	panel.Position = UDim2.new(0.5, -panelWidth / 2, 1, -85 - panelHeight)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 90)
	stroke.Thickness = 1
	stroke.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, PANEL_PADDING)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, PANEL_PADDING)
	padding.PaddingRight = UDim.new(0, PANEL_PADDING)
	padding.Parent = panel

	-- 반시계 회전
	MoveHandleUI._createButton(panel, "RotateLeft", "반시계", "Q", Color3.fromRGB(70, 90, 140), 1, function()
		if _callbacks.onRotateLeft then _callbacks.onRotateLeft() end
	end)

	-- 시계 회전
	MoveHandleUI._createButton(panel, "RotateRight", "시계", "E", Color3.fromRGB(70, 90, 140), 2, function()
		if _callbacks.onRotateRight then _callbacks.onRotateRight() end
	end)

	-- Place 버튼
	placeButton = MoveHandleUI._createButton(panel, "Place", "배치", nil, Color3.fromRGB(50, 180, 50), 3, function()
		if _callbacks.onPlace then _callbacks.onPlace() end
	end)

	-- Cancel 버튼
	MoveHandleUI._createButton(panel, "Cancel", "취소", nil, Color3.fromRGB(150, 50, 50), 4, function()
		if _callbacks.onCancel then _callbacks.onCancel() end
	end)
end

function MoveHandleUI._createButton(parent, name, text, topLabel, color, order, callback)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.LayoutOrder = order
	btn.AutoButtonColor = true
	btn.Parent = parent

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = btn

	-- 단축키 배지 (오른쪽 위 상자)
	if topLabel then
		local badge = Instance.new("TextLabel")
		badge.Size = UDim2.new(0, 20, 0, 14)
		badge.Position = UDim2.new(1, -22, 0, 2)
		badge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		badge.BackgroundTransparency = 0.3
		badge.TextColor3 = Color3.fromRGB(200, 200, 220)
		badge.TextSize = 10
		badge.Font = Enum.Font.GothamBold
		badge.Text = topLabel
		badge.Parent = btn

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 4)
		badgeCorner.Parent = badge
	end

	btn.MouseButton1Click:Connect(callback)
	return btn
end

function MoveHandleUI.show()
	if not panel then return end
	_visible = true
	panel.Visible = true
end

function MoveHandleUI.hide()
	if not panel then return end
	_visible = false
	panel.Visible = false
end

-- Place 버튼 활성/비활성 (충돌 감지 연동)
function MoveHandleUI.setPlaceEnabled(enabled: boolean)
	if not placeButton then return end

	if enabled then
		placeButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
		placeButton.TextTransparency = 0
		placeButton.Active = true
	else
		placeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		placeButton.TextTransparency = 0.5
		placeButton.Active = false
	end
end

function MoveHandleUI.isVisible(): boolean
	return _visible
end

function MoveHandleUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return MoveHandleUI
