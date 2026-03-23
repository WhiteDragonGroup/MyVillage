-- GiftUI.luau
-- 선물 대상 플레이어 선택 UI (모달)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GiftUI = {}

local screenGui = nil
local overlay = nil
local listFrame = nil
local contentFrame = nil
local _callbacks = {}
local _visible = false
local _giftItemName = nil

local SLOT_WIDTH = 220
local SLOT_HEIGHT = 44
local SLOT_PADDING = 6

function GiftUI.init(callbacks: { onSelectPlayer: (string, Player) -> (), onClose: () -> () })
	_callbacks = callbacks

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GiftUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 35
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
	listFrame.Name = "GiftPlayerList"
	listFrame.Size = UDim2.new(0, SLOT_WIDTH + 30, 0, 280)
	listFrame.Position = UDim2.new(0.5, -(SLOT_WIDTH + 30) / 2, 0.5, -140)
	listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	listFrame.BorderSizePixel = 0
	listFrame.Visible = false
	listFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = listFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 80, 150)
	stroke.Thickness = 2
	stroke.Parent = listFrame

	-- 제목
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 15
	title.Font = Enum.Font.GothamBold
	title.Text = "선물할 플레이어 선택"
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

function GiftUI.show(itemName: string)
	if not listFrame then return end
	_visible = true
	_giftItemName = itemName

	-- 기존 슬롯 제거
	for _, child in contentFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- 다른 플레이어 목록
	local index = 0
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == player then continue end
		index = index + 1

		local slot = Instance.new("Frame")
		slot.Name = otherPlayer.Name
		slot.Size = UDim2.new(1, 0, 0, SLOT_HEIGHT)
		slot.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
		slot.BorderSizePixel = 0
		slot.LayoutOrder = index
		slot.Parent = contentFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slot

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = Color3.fromRGB(80, 80, 100)
		slotStroke.Thickness = 1
		slotStroke.Parent = slot

		-- 플레이어 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -80, 1, 0)
		nameLabel.Position = UDim2.new(0, 10, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = otherPlayer.DisplayName
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- 선물 버튼
		local sendBtn = Instance.new("TextButton")
		sendBtn.Size = UDim2.new(0, 55, 0, 28)
		sendBtn.Position = UDim2.new(1, -65, 0.5, -14)
		sendBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 150)
		sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		sendBtn.TextSize = 11
		sendBtn.Font = Enum.Font.GothamBold
		sendBtn.Text = "선물"
		sendBtn.AutoButtonColor = true
		sendBtn.Parent = slot

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = sendBtn

		sendBtn.MouseButton1Click:Connect(function()
			if _callbacks.onSelectPlayer and _giftItemName then
				_callbacks.onSelectPlayer(_giftItemName, otherPlayer)
			end
		end)
	end

	-- 캔버스 크기
	local totalHeight = index * (SLOT_HEIGHT + SLOT_PADDING)
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

	-- 빈 목록
	if index == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 0, 40)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		emptyLabel.TextSize = 13
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.Text = "다른 플레이어가 없습니다"
		emptyLabel.Parent = contentFrame
	end

	overlay.Visible = true
	listFrame.Visible = true
end

function GiftUI.hide()
	if not listFrame then return end
	_visible = false
	_giftItemName = nil
	overlay.Visible = false
	listFrame.Visible = false
end

function GiftUI.isVisible(): boolean
	return _visible
end

function GiftUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return GiftUI
