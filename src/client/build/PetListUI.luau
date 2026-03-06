-- PetListUI.luau
-- 펫 목록 표시 + 배치/회수 버튼

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PetListUI = {}

local screenGui = nil
local overlay = nil
local listFrame = nil
local contentFrame = nil
local _callbacks = {}
local _visible = false
local _targetBuildingId = nil

local SLOT_WIDTH = 240
local SLOT_HEIGHT = 50
local SLOT_PADDING = 6

function PetListUI.init(callbacks: { onAssign: (string, string) -> (), onUnassign: (string) -> (), onClose: () -> () })
	_callbacks = callbacks

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PetListUI"
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
		if _callbacks.onClose then _callbacks.onClose() end
	end)

	-- 리스트 프레임
	listFrame = Instance.new("Frame")
	listFrame.Name = "PetList"
	listFrame.Size = UDim2.new(0, SLOT_WIDTH + 30, 0, 320)
	listFrame.Position = UDim2.new(0.5, -(SLOT_WIDTH + 30) / 2, 0.5, -160)
	listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	listFrame.BorderSizePixel = 0
	listFrame.Visible = false
	listFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = listFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 180, 100)
	stroke.Thickness = 2
	stroke.Parent = listFrame

	-- 제목
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Text = "펫 배치"
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = listFrame

	-- 스크롤 영역
	contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -20, 1, -90)
	contentFrame.Position = UDim2.new(0, 10, 0, 45)
	contentFrame.BackgroundTransparency = 1
	contentFrame.ScrollBarThickness = 4
	contentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentFrame.Parent = listFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, SLOT_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = contentFrame

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.new(1, -20, 0, 34)
	closeBtn.Position = UDim2.new(0, 10, 1, -44)
	closeBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "닫기"
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.AutoButtonColor = true
	closeBtn.Parent = listFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		if _callbacks.onClose then _callbacks.onClose() end
	end)
end

-- 펫 목록 표시
function PetListUI.show(pets: { any }, buildingId: string)
	if not listFrame then return end
	_visible = true
	_targetBuildingId = buildingId

	-- 기존 슬롯 제거
	for _, child in contentFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- 펫 슬롯 생성
	local index = 0
	for i, pet in pets do
		index = index + 1

		local slot = Instance.new("Frame")
		slot.Name = pet.petId
		slot.Size = UDim2.new(1, 0, 0, SLOT_HEIGHT)
		slot.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
		slot.BorderSizePixel = 0
		slot.LayoutOrder = index
		slot.Parent = contentFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slot

		-- 등급 테두리
		local rarityColor = Constants.RARITY_COLORS[pet.rarity] or Color3.fromRGB(180, 180, 180)
		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = rarityColor
		slotStroke.Thickness = 1
		slotStroke.Parent = slot

		-- 펫 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -90, 0, 20)
		nameLabel.Position = UDim2.new(0, 10, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = pet.petName
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- 상태 표시
		local levelStr = "Lv." .. (pet.level or 1)
		local weightStr = string.format("%.1fkg", pet.weight or 0)
		local statusText = ""
		if pet.assignedBuildingId ~= "" then
			statusText = levelStr .. " | " .. weightStr .. " | 건설 중"
		else
			statusText = levelStr .. " | " .. weightStr .. " | 대기 중"
		end
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(1, -90, 0, 16)
		statusLabel.Position = UDim2.new(0, 10, 0, 26)
		statusLabel.BackgroundTransparency = 1
		statusLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
		statusLabel.TextSize = 11
		statusLabel.Font = Enum.Font.Gotham
		statusLabel.Text = statusText
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Parent = slot

		-- 배치/회수 버튼
		local actionBtn = Instance.new("TextButton")
		actionBtn.Size = UDim2.new(0, 65, 0, 32)
		actionBtn.Position = UDim2.new(1, -75, 0.5, -16)
		actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		actionBtn.TextSize = 12
		actionBtn.Font = Enum.Font.GothamBold
		actionBtn.AutoButtonColor = true
		actionBtn.Parent = slot

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = actionBtn

		if pet.assignedBuildingId == "" then
			-- 배치 가능
			actionBtn.Text = "배치"
			actionBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			actionBtn.MouseButton1Click:Connect(function()
				if _callbacks.onAssign and _targetBuildingId then
					_callbacks.onAssign(pet.petId, _targetBuildingId)
				end
			end)
		elseif pet.assignedBuildingId == buildingId then
			-- 이 건물에 배치된 펫 → 회수 가능
			actionBtn.Text = "회수"
			actionBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 50)
			actionBtn.MouseButton1Click:Connect(function()
				if _callbacks.onUnassign then
					_callbacks.onUnassign(pet.petId)
				end
			end)
		else
			-- 다른 건물에 배치된 펫
			actionBtn.Text = "사용중"
			actionBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			actionBtn.Active = false
			actionBtn.TextTransparency = 0.5
		end
	end

	-- 캔버스 크기 업데이트
	local totalHeight = index * (SLOT_HEIGHT + SLOT_PADDING)
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

	-- 빈 목록 처리
	if index == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 0, 40)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		emptyLabel.TextSize = 13
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.Text = "펫이 없습니다"
		emptyLabel.Parent = contentFrame
	end

	overlay.Visible = true
	listFrame.Visible = true
end

-- 숨기기
function PetListUI.hide()
	if not listFrame then return end
	_visible = false
	_targetBuildingId = nil
	overlay.Visible = false
	listFrame.Visible = false
end

function PetListUI.isVisible(): boolean
	return _visible
end

function PetListUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return PetListUI
