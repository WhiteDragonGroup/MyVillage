-- ShopUI.luau
-- 건물 상점 UI: 재고 타이머, 스크롤 상품 목록, 구매/선물 버튼

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopUI = {}

local screenGui = nil
local mainFrame = nil
local contentFrame = nil
local timerLabel = nil
local _visible = false
local _callbacks = {}
local _shopData = {} -- { itemName, price, stock, maxStock }
local _restockTime = 0 -- 남은 시간 (초)
local _timerConnection = nil

local PANEL_WIDTH = 300
local PANEL_HEIGHT = 420
local ITEM_HEIGHT = 70
local ITEM_PADDING = 6

function ShopUI.init(callbacks: { onBuy: (string) -> (), onGift: (string) -> () })
	_callbacks = callbacks

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 25
	screenGui.Parent = playerGui

	-- 메인 패널
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "ShopPanel"
	mainFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
	mainFrame.Position = UDim2.new(0, 10, 0, 104)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	mainFrame.BackgroundTransparency = 0.05
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 150, 50)
	stroke.Thickness = 1.5
	stroke.Parent = mainFrame

	-- 제목
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 100, 0, 28)
	title.Position = UDim2.new(0, 8, 0, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Text = "건물 상점"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = mainFrame

	-- 재고 타이머
	timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.Size = UDim2.new(0, 160, 0, 24)
	timerLabel.Position = UDim2.new(1, -168, 0, 10)
	timerLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	timerLabel.BackgroundTransparency = 0.3
	timerLabel.TextColor3 = Color3.fromRGB(200, 200, 60)
	timerLabel.TextSize = 11
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.Text = "Restocking in: --:--"
	timerLabel.Parent = mainFrame

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0, 6)
	timerCorner.Parent = timerLabel

	-- 상품 목록 (스크롤)
	contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -16, 1, -52)
	contentFrame.Position = UDim2.new(0, 8, 0, 44)
	contentFrame.BackgroundTransparency = 1
	contentFrame.ScrollBarThickness = 4
	contentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentFrame.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ITEM_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = contentFrame
end

function ShopUI.updateShop(shopData: { any }, restockTime: number)
	_shopData = shopData
	_restockTime = restockTime
	if _visible then
		ShopUI._renderItems()
		ShopUI._startTimer()
	end
end

function ShopUI._renderItems()
	if not contentFrame then return end

	for _, child in contentFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for i, item in _shopData do
		local building = Constants.BUILDINGS[item.itemName]
		if not building then continue end

		local slot = Instance.new("Frame")
		slot.Name = item.itemName
		slot.Size = UDim2.new(1, 0, 0, ITEM_HEIGHT)
		slot.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		slot.BorderSizePixel = 0
		slot.LayoutOrder = i
		slot.Parent = contentFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slot

		local rarityColor = Constants.RARITY_COLORS[building.rarity] or Color3.fromRGB(180, 180, 180)
		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = rarityColor
		slotStroke.Thickness = 1
		slotStroke.Parent = slot

		-- 건물 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 120, 0, 20)
		nameLabel.Position = UDim2.new(0, 10, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = building.name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- 등급 + 유형
		local infoLabel = Instance.new("TextLabel")
		infoLabel.Size = UDim2.new(0, 120, 0, 16)
		infoLabel.Position = UDim2.new(0, 10, 0, 28)
		infoLabel.BackgroundTransparency = 1
		infoLabel.TextColor3 = rarityColor
		infoLabel.TextSize = 10
		infoLabel.Font = Enum.Font.Gotham
		infoLabel.Text = building.rarity .. " | " .. table.concat(building.types, "/")
		infoLabel.TextXAlignment = Enum.TextXAlignment.Left
		infoLabel.Parent = slot

		-- 재고
		local stockLabel = Instance.new("TextLabel")
		stockLabel.Size = UDim2.new(0, 120, 0, 14)
		stockLabel.Position = UDim2.new(0, 10, 0, 48)
		stockLabel.BackgroundTransparency = 1
		stockLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
		stockLabel.TextSize = 10
		stockLabel.Font = Enum.Font.Gotham
		stockLabel.Text = "남은 재고: " .. item.stock .. " / " .. item.maxStock
		stockLabel.TextXAlignment = Enum.TextXAlignment.Left
		stockLabel.Parent = slot

		-- 가격 표시
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(0, 60, 0, 18)
		priceLabel.Position = UDim2.new(1, -145, 0, 8)
		priceLabel.BackgroundTransparency = 1
		priceLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
		priceLabel.TextSize = 12
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.Text = "$" .. item.price
		priceLabel.TextXAlignment = Enum.TextXAlignment.Right
		priceLabel.Parent = slot

		-- 구매 버튼
		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(0, 50, 0, 28)
		buyBtn.Position = UDim2.new(1, -125, 0, 30)
		buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyBtn.TextSize = 11
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.AutoButtonColor = true
		buyBtn.Parent = slot

		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 6)
		buyCorner.Parent = buyBtn

		if item.stock > 0 then
			buyBtn.Text = "구매"
			buyBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			buyBtn.MouseButton1Click:Connect(function()
				if _callbacks.onBuy then
					_callbacks.onBuy(item.itemName)
				end
			end)
		else
			buyBtn.Text = "품절"
			buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			buyBtn.Active = false
			buyBtn.TextTransparency = 0.5
		end

		-- 선물 버튼
		local giftBtn = Instance.new("TextButton")
		giftBtn.Size = UDim2.new(0, 50, 0, 28)
		giftBtn.Position = UDim2.new(1, -68, 0, 30)
		giftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		giftBtn.TextSize = 11
		giftBtn.Font = Enum.Font.GothamBold
		giftBtn.AutoButtonColor = true
		giftBtn.Parent = slot

		local giftCorner = Instance.new("UICorner")
		giftCorner.CornerRadius = UDim.new(0, 6)
		giftCorner.Parent = giftBtn

		if item.stock > 0 then
			giftBtn.Text = "선물"
			giftBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 150)
			giftBtn.MouseButton1Click:Connect(function()
				if _callbacks.onGift then
					_callbacks.onGift(item.itemName)
				end
			end)
		else
			giftBtn.Text = "선물"
			giftBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			giftBtn.Active = false
			giftBtn.TextTransparency = 0.5
		end
	end

	-- 캔버스 크기
	local totalHeight = #_shopData * (ITEM_HEIGHT + ITEM_PADDING)
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

function ShopUI._startTimer()
	if _timerConnection then
		_timerConnection:Disconnect()
		_timerConnection = nil
	end

	_timerConnection = RunService.Heartbeat:Connect(function(dt)
		if not _visible or not timerLabel then return end
		_restockTime = math.max(0, _restockTime - dt)
		local mins = math.floor(_restockTime / 60)
		local secs = math.floor(_restockTime % 60)
		timerLabel.Text = string.format("Restocking in: %d:%02d", mins, secs)
	end)
end

function ShopUI.show()
	if _visible or not mainFrame then return end
	_visible = true
	mainFrame.Visible = true
	ShopUI._renderItems()
	ShopUI._startTimer()
end

function ShopUI.hide()
	if not _visible or not mainFrame then return end
	_visible = false
	mainFrame.Visible = false
	if _timerConnection then
		_timerConnection:Disconnect()
		_timerConnection = nil
	end
end

function ShopUI.isVisible(): boolean
	return _visible
end

function ShopUI.destroy()
	if _timerConnection then
		_timerConnection:Disconnect()
		_timerConnection = nil
	end
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return ShopUI
