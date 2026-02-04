-- MoveHandleUI.luau
-- 이동/회전 드래그 핸들 + Place 버튼 (BillboardGui)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MoveHandleUI = {}

local screenGui = nil
local panel = nil
local placeButton = nil
local rotateLeftButton = nil
local rotateRightButton = nil
local _callbacks = {}
local _visible = false

local BUTTON_SIZE = 44
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

	-- 하단 중앙 패널
	panel = Instance.new("Frame")
	panel.Name = "MovePanel"
	panel.Size = UDim2.new(0, (BUTTON_SIZE + PANEL_PADDING) * 4 + PANEL_PADDING * 2, 0, BUTTON_SIZE + PANEL_PADDING * 2)
	panel.Position = UDim2.new(0.5, -panel.Size.X.Offset / 2, 1, -140)
	panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 80, 100)
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

	-- 왼쪽 회전
	rotateLeftButton = MoveHandleUI._createButton(panel, "RotateLeft", "↶", Color3.fromRGB(80, 80, 120), 1, function()
		if _callbacks.onRotateLeft then _callbacks.onRotateLeft() end
	end)

	-- 오른쪽 회전
	rotateRightButton = MoveHandleUI._createButton(panel, "RotateRight", "↷", Color3.fromRGB(80, 80, 120), 2, function()
		if _callbacks.onRotateRight then _callbacks.onRotateRight() end
	end)

	-- Place 버튼
	placeButton = MoveHandleUI._createButton(panel, "Place", "배치", Color3.fromRGB(50, 180, 50), 3, function()
		if _callbacks.onPlace then _callbacks.onPlace() end
	end)

	-- Cancel 버튼
	MoveHandleUI._createButton(panel, "Cancel", "취소", Color3.fromRGB(150, 50, 50), 4, function()
		if _callbacks.onCancel then _callbacks.onCancel() end
	end)
end

function MoveHandleUI._createButton(parent, name, text, color, order, callback)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text
	btn.TextSize = 18
	btn.Font = Enum.Font.GothamBold
	btn.LayoutOrder = order
	btn.AutoButtonColor = true
	btn.Parent = parent

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = btn

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
