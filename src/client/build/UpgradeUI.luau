-- UpgradeUI.luau
-- 업그레이드 확인 다이얼로그 (레벨, 비용 표시)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UpgradeUI = {}

local screenGui = nil
local overlay = nil
local dialog = nil
local _callbacks = {}
local _visible = false

function UpgradeUI.init(callbacks: { onConfirm: () -> (), onCancel: () -> () })
	_callbacks = callbacks

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "UpgradeUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 30
	screenGui.Parent = playerGui

	-- 반투명 오버레이
	overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.Text = ""
	overlay.Visible = false
	overlay.Parent = screenGui
	overlay.MouseButton1Click:Connect(function()
		if _callbacks.onCancel then _callbacks.onCancel() end
	end)

	-- 다이얼로그 박스
	dialog = Instance.new("Frame")
	dialog.Name = "Dialog"
	dialog.Size = UDim2.new(0, 280, 0, 180)
	dialog.Position = UDim2.new(0.5, -140, 0.5, -90)
	dialog.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	dialog.BorderSizePixel = 0
	dialog.Visible = false
	dialog.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = dialog

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 120, 200)
	stroke.Thickness = 2
	stroke.Parent = dialog

	-- 제목
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.new(0, 10, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Text = "업그레이드"
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = dialog

	-- 정보 텍스트
	local info = Instance.new("TextLabel")
	info.Name = "InfoLabel"
	info.Size = UDim2.new(1, -20, 0, 50)
	info.Position = UDim2.new(0, 10, 0, 48)
	info.BackgroundTransparency = 1
	info.TextColor3 = Color3.fromRGB(200, 200, 210)
	info.TextSize = 14
	info.Font = Enum.Font.Gotham
	info.Text = ""
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Center
	info.Parent = dialog

	-- 버튼 영역
	local btnFrame = Instance.new("Frame")
	btnFrame.Size = UDim2.new(1, -20, 0, 44)
	btnFrame.Position = UDim2.new(0, 10, 1, -56)
	btnFrame.BackgroundTransparency = 1
	btnFrame.Parent = dialog

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = btnFrame

	-- 확인 버튼
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Name = "Confirm"
	confirmBtn.Size = UDim2.new(0, 110, 0, 38)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 50)
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.Text = "업그레이드"
	confirmBtn.TextSize = 15
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.AutoButtonColor = true
	confirmBtn.Parent = btnFrame

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmBtn

	confirmBtn.MouseButton1Click:Connect(function()
		if _callbacks.onConfirm then _callbacks.onConfirm() end
	end)

	-- 취소 버튼
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Name = "Cancel"
	cancelBtn.Size = UDim2.new(0, 110, 0, 38)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.Text = "취소"
	cancelBtn.TextSize = 15
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.AutoButtonColor = true
	cancelBtn.Parent = btnFrame

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelBtn

	cancelBtn.MouseButton1Click:Connect(function()
		if _callbacks.onCancel then _callbacks.onCancel() end
	end)
end

-- 다이얼로그 표시
function UpgradeUI.show(level: number, itemName: string?)
	if not dialog then return end
	_visible = true

	local maxLevel = BalanceConfig.Upgrade.MAX_LEVEL
	local nextLevel = level + 1

	local infoLabel = dialog:FindFirstChild("InfoLabel")
	if infoLabel then
		local buildingLabel = itemName or "건물"
		local cost = BalanceConfig.Upgrade.COST[level] or 0
		local costText = if cost > 0 then (cost .. " 코인") else "무료"
		infoLabel.Text = buildingLabel .. "\nLv." .. level .. " → Lv." .. nextLevel .. "\n비용: " .. costText

		if nextLevel > maxLevel then
			infoLabel.Text = "이미 최대 레벨입니다! (Lv." .. maxLevel .. ")"
		end
	end

	overlay.Visible = true
	dialog.Visible = true

	-- 스케일 애니메이션
	dialog.Size = UDim2.new(0, 250, 0, 160)
	TweenService:Create(dialog, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 280, 0, 180)
	}):Play()
end

-- 다이얼로그 숨기기
function UpgradeUI.hide()
	if not dialog then return end
	_visible = false
	overlay.Visible = false
	dialog.Visible = false
end

function UpgradeUI.isVisible(): boolean
	return _visible
end

function UpgradeUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return UpgradeUI
