-- SelectionUI.luau
-- 건물 선택 시 Store/Cancel/Move 버튼 표시

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SelectionUI = {}

local screenGui = nil
local panel = nil
local _callbacks = {}
local _visible = false

local BUTTON_WIDTH = 80
local BUTTON_HEIGHT = 40
local PANEL_PADDING = 10

function SelectionUI.init(callbacks: { onStore: () -> (), onCancel: () -> (), onMove: () -> () })
	_callbacks = callbacks

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SelectionUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 15
	screenGui.Parent = playerGui

	-- 패널 (인벤토리 위)
	local panelWidth = (BUTTON_WIDTH + PANEL_PADDING) * 3 + PANEL_PADDING
	local panelHeight = BUTTON_HEIGHT + PANEL_PADDING * 2

	panel = Instance.new("Frame")
	panel.Name = "SelectionPanel"
	panel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
	panel.Position = UDim2.new(0.5, -panelWidth / 2, 1, -110 - panelHeight)
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
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, PANEL_PADDING)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, PANEL_PADDING)
	padding.PaddingRight = UDim.new(0, PANEL_PADDING)
	padding.Parent = panel

	-- 이동
	SelectionUI._createButton(panel, "Move", "이동", Color3.fromRGB(50, 120, 200), 1, function()
		if _callbacks.onMove then _callbacks.onMove() end
	end)

	-- 저장
	SelectionUI._createButton(panel, "Store", "저장", Color3.fromRGB(200, 150, 50), 2, function()
		if _callbacks.onStore then _callbacks.onStore() end
	end)

	-- 취소 (ESC 힌트)
	SelectionUI._createButton(panel, "Cancel", "취소 (Esc)", Color3.fromRGB(150, 50, 50), 3, function()
		if _callbacks.onCancel then _callbacks.onCancel() end
	end)
end

function SelectionUI._createButton(parent, name, text, color, order, callback)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, BUTTON_WIDTH, 0, BUTTON_HEIGHT)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.LayoutOrder = order
	btn.AutoButtonColor = true
	btn.Parent = parent

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	btn.MouseButton1Click:Connect(callback)
end

function SelectionUI.show()
	if not panel then return end
	_visible = true
	panel.Visible = true

	-- 페이드인
	panel.BackgroundTransparency = 1
	TweenService:Create(panel, TweenInfo.new(0.15), {
		BackgroundTransparency = 0.1
	}):Play()
end

function SelectionUI.hide()
	if not panel then return end
	_visible = false
	panel.Visible = false
end

function SelectionUI.isVisible(): boolean
	return _visible
end

function SelectionUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return SelectionUI
