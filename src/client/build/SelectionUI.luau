-- SelectionUI.luau
-- 건물 선택 시 동적 버튼 표시
-- 일반 상태: 이동 / 저장 / 업그레이드 / 취소
-- 수리중 상태: 펫배치 / 업그레이드취소 / 취소

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SelectionUI = {}

local screenGui = nil
local panel = nil
local _callbacks = {}
local _visible = false
local _currentButtons = {} -- 동적 생성된 버튼들

local BUTTON_WIDTH = 80
local BUTTON_HEIGHT = 40
local PANEL_PADDING = 10

function SelectionUI.init(callbacks: {
	onStore: () -> (),
	onCancel: () -> (),
	onMove: () -> (),
	onUpgrade: () -> (),
	onCancelUpgrade: () -> (),
	onAssignPet: () -> (),
})
	_callbacks = callbacks

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SelectionUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 15
	screenGui.Parent = playerGui

	-- 패널 (동적 크기)
	panel = Instance.new("Frame")
	panel.Name = "SelectionPanel"
	panel.Size = UDim2.new(0, 200, 0, BUTTON_HEIGHT + PANEL_PADDING * 2)
	panel.Position = UDim2.new(0.5, -100, 1, -110 - (BUTTON_HEIGHT + PANEL_PADDING * 2))
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
	layout.Name = "Layout"
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
	table.insert(_currentButtons, btn)
end

-- 기존 버튼 모두 제거
local function clearButtons()
	for _, btn in _currentButtons do
		btn:Destroy()
	end
	_currentButtons = {}
end

-- 패널 크기 업데이트
local function resizePanel(buttonCount: number)
	local panelWidth = (BUTTON_WIDTH + PANEL_PADDING) * buttonCount + PANEL_PADDING
	local panelHeight = BUTTON_HEIGHT + PANEL_PADDING * 2
	panel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
	panel.Position = UDim2.new(0.5, -panelWidth / 2, 1, -110 - panelHeight)
end

-- 일반 상태 버튼 표시 (이동 / 저장 / 업그레이드 / 취소)
function SelectionUI.showNormal(level: number?, maxLevel: number?)
	if not panel then return end
	clearButtons()

	local lvl = level or 1
	local maxLvl = maxLevel or 5
	local buttonCount = 4

	if lvl >= maxLvl then
		buttonCount = 3 -- 최대 레벨이면 업그레이드 버튼 생략
	end

	-- 이동
	SelectionUI._createButton(panel, "Move", "이동", Color3.fromRGB(50, 120, 200), 1, function()
		if _callbacks.onMove then _callbacks.onMove() end
	end)

	-- 저장
	SelectionUI._createButton(panel, "Store", "저장", Color3.fromRGB(200, 150, 50), 2, function()
		if _callbacks.onStore then _callbacks.onStore() end
	end)

	-- 업그레이드 (최대 레벨이 아닐 때만)
	if lvl < maxLvl then
		SelectionUI._createButton(panel, "Upgrade", "업그레이드", Color3.fromRGB(80, 180, 80), 3, function()
			if _callbacks.onUpgrade then _callbacks.onUpgrade() end
		end)
	end

	-- 취소
	SelectionUI._createButton(panel, "Cancel", "취소", Color3.fromRGB(150, 50, 50), 4, function()
		if _callbacks.onCancel then _callbacks.onCancel() end
	end)

	resizePanel(buttonCount)
end

-- 수리중 상태 버튼 표시 (펫배치 / 업그레이드취소 / 취소)
function SelectionUI.showUpgrading()
	if not panel then return end
	clearButtons()

	-- 펫 배치
	SelectionUI._createButton(panel, "AssignPet", "펫배치", Color3.fromRGB(80, 180, 80), 1, function()
		if _callbacks.onAssignPet then _callbacks.onAssignPet() end
	end)

	-- 업그레이드 취소
	SelectionUI._createButton(panel, "CancelUpgrade", "수리취소", Color3.fromRGB(200, 120, 50), 2, function()
		if _callbacks.onCancelUpgrade then _callbacks.onCancelUpgrade() end
	end)

	-- 취소 (선택 해제)
	SelectionUI._createButton(panel, "Cancel", "취소", Color3.fromRGB(150, 50, 50), 3, function()
		if _callbacks.onCancel then _callbacks.onCancel() end
	end)

	resizePanel(3)
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
	clearButtons()
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
