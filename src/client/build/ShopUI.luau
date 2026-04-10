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

function ShopUI.init(callbacks: { onBuy: (string) -> (), onBuyGem: ((string) -> ())?, onGift: (string) -> (), onBuyEgg: ((string) -> ())? })
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
	mainFrame.Position = UDim2.new(0.5, -PANEL_WIDTH / 2, 0.5, -PANEL_HEIGHT / 2)
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

		local rarityColor = Constants.RARITY_COLORS[building.rarity] or Color3.fromRGB(180, 180, 180)
		local soldOut = item.stock <= 0

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

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = rarityColor
		slotStroke.Thickness = 1
		slotStroke.Parent = slot

		-- 건물 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 130, 0, 18)
		nameLabel.Position = UDim2.new(0, 10, 0, 4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = building.name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- 재고 + 희귀도 (이름 오른쪽)
		local stockText = "X" .. item.stock .. " Stock"
		if soldOut then stockText = "NO STOCK" end

		local stockLabel = Instance.new("TextLabel")
		stockLabel.Size = UDim2.new(0, 80, 0, 14)
		stockLabel.Position = UDim2.new(0, 10, 0, 22)
		stockLabel.BackgroundTransparency = 1
		stockLabel.TextColor3 = if soldOut then Color3.fromRGB(200, 80, 80) else Color3.fromRGB(160, 160, 170)
		stockLabel.TextSize = 9
		stockLabel.Font = Enum.Font.Gotham
		stockLabel.Text = stockText
		stockLabel.TextXAlignment = Enum.TextXAlignment.Left
		stockLabel.Parent = slot

		-- 희귀도 뱃지
		local rarityBadge = Instance.new("TextLabel")
		rarityBadge.Size = UDim2.new(0, 50, 0, 16)
		rarityBadge.Position = UDim2.new(0, 90, 0, 21)
		rarityBadge.BackgroundColor3 = rarityColor
		rarityBadge.BackgroundTransparency = 0.3
		rarityBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
		rarityBadge.TextSize = 8
		rarityBadge.Font = Enum.Font.GothamBold
		rarityBadge.Text = building.rarity
		rarityBadge.Parent = slot

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 4)
		badgeCorner.Parent = rarityBadge

		-- 가격
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(0, 50, 0, 16)
		priceLabel.Position = UDim2.new(0, 10, 0, 40)
		priceLabel.BackgroundTransparency = 1
		priceLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
		priceLabel.TextSize = 12
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.Text = "$" .. item.price
		priceLabel.TextXAlignment = Enum.TextXAlignment.Left
		priceLabel.Parent = slot

		-- 구매 버튼 (돈)
		local function makeBtn(text, color, xPos, callback)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 42, 0, 22)
			btn.Position = UDim2.new(1, xPos, 0, 38)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextSize = 9
			btn.Font = Enum.Font.GothamBold
			btn.Text = text
			btn.AutoButtonColor = true
			btn.Parent = slot
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 5)
			c.Parent = btn
			if soldOut then
				btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
				btn.Active = false
				btn.TextTransparency = 0.5
			else
				btn.BackgroundColor3 = color
				btn.MouseButton1Click:Connect(callback)
			end
			return btn
		end

		-- $ 구매
		makeBtn("$" .. item.price, Color3.fromRGB(50, 140, 50), -180, function()
			if _callbacks.onBuy then _callbacks.onBuy(item.itemName) end
		end)

		-- 보석 구매 (가격 x2)
		makeBtn("💎" .. math.floor(item.price * 0.5), Color3.fromRGB(100, 70, 200), -134, function()
			if _callbacks.onBuyGem then _callbacks.onBuyGem(item.itemName) end
		end)

		-- 선물 버튼
		local giftBtn = Instance.new("TextButton")
		giftBtn.Size = UDim2.new(0, 42, 0, 22)
		giftBtn.Position = UDim2.new(1, -88, 0, 38)
		giftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		giftBtn.TextSize = 9
		giftBtn.Font = Enum.Font.GothamBold
		giftBtn.Text = "선물"
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

	-- === 알 섹션 ===
	local EggCfg = BalanceConfig.Egg
	if EggCfg and EggCfg.EGGS then
		-- 구분선
		local sepFrame = Instance.new("Frame")
		sepFrame.Size = UDim2.new(1, -8, 0, 24)
		sepFrame.BackgroundTransparency = 1
		sepFrame.LayoutOrder = #_shopData + 1
		sepFrame.Parent = contentFrame

		local sepLabel = Instance.new("TextLabel")
		sepLabel.Size = UDim2.new(1, 0, 1, 0)
		sepLabel.BackgroundTransparency = 1
		sepLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		sepLabel.TextSize = 13
		sepLabel.Font = Enum.Font.GothamBold
		sepLabel.Text = "── 알 (Eggs) ──"
		sepLabel.Parent = sepFrame

		local eggIndex = 0
		for eggType, eggInfo in EggCfg.EGGS do
			eggIndex = eggIndex + 1
			local rarityColor = Constants.RARITY_COLORS[eggInfo.rarity] or Color3.fromRGB(180, 180, 180)

			local eggSlot = Instance.new("Frame")
			eggSlot.Name = eggType
			eggSlot.Size = UDim2.new(1, 0, 0, 56)
			eggSlot.BackgroundColor3 = Color3.fromRGB(45, 40, 55)
			eggSlot.BorderSizePixel = 0
			eggSlot.LayoutOrder = #_shopData + 1 + eggIndex
			eggSlot.Parent = contentFrame

			local eggCorner = Instance.new("UICorner")
			eggCorner.CornerRadius = UDim.new(0, 8)
			eggCorner.Parent = eggSlot

			local eggStroke = Instance.new("UIStroke")
			eggStroke.Color = rarityColor
			eggStroke.Thickness = 1
			eggStroke.Parent = eggSlot

			-- 이름
			local eName = Instance.new("TextLabel")
			eName.Size = UDim2.new(0, 130, 0, 18)
			eName.Position = UDim2.new(0, 10, 0, 4)
			eName.BackgroundTransparency = 1
			eName.TextColor3 = Color3.fromRGB(255, 255, 255)
			eName.TextSize = 12
			eName.Font = Enum.Font.GothamBold
			eName.Text = eggInfo.name
			eName.TextXAlignment = Enum.TextXAlignment.Left
			eName.Parent = eggSlot

			-- 부화 시간 + 희귀도
			local eInfo = Instance.new("TextLabel")
			eInfo.Size = UDim2.new(0, 150, 0, 14)
			eInfo.Position = UDim2.new(0, 10, 0, 22)
			eInfo.BackgroundTransparency = 1
			eInfo.TextColor3 = rarityColor
			eInfo.TextSize = 9
			eInfo.Font = Enum.Font.Gotham
			eInfo.Text = eggInfo.rarity .. " | 부화: " .. eggInfo.hatchTime .. "초"
			eInfo.TextXAlignment = Enum.TextXAlignment.Left
			eInfo.Parent = eggSlot

			-- 가격 + 구매 버튼
			local ePrice = Instance.new("TextLabel")
			ePrice.Size = UDim2.new(0, 50, 0, 16)
			ePrice.Position = UDim2.new(0, 10, 0, 38)
			ePrice.BackgroundTransparency = 1
			ePrice.TextColor3 = Color3.fromRGB(255, 200, 60)
			ePrice.TextSize = 11
			ePrice.Font = Enum.Font.GothamBold
			ePrice.Text = "$" .. eggInfo.price
			ePrice.TextXAlignment = Enum.TextXAlignment.Left
			ePrice.Parent = eggSlot

			local eBuyBtn = Instance.new("TextButton")
			eBuyBtn.Size = UDim2.new(0, 50, 0, 24)
			eBuyBtn.Position = UDim2.new(1, -62, 0, 16)
			eBuyBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 50)
			eBuyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			eBuyBtn.TextSize = 10
			eBuyBtn.Font = Enum.Font.GothamBold
			eBuyBtn.Text = "구매"
			eBuyBtn.AutoButtonColor = true
			eBuyBtn.Parent = eggSlot

			local eBuyCorner = Instance.new("UICorner")
			eBuyCorner.CornerRadius = UDim.new(0, 6)
			eBuyCorner.Parent = eBuyBtn

			eBuyBtn.MouseButton1Click:Connect(function()
				if _callbacks.onBuyEgg then
					_callbacks.onBuyEgg(eggType)
				end
			end)
		end
	end

	-- 캔버스 크기
	local totalChildren = 0
	for _, child in contentFrame:GetChildren() do
		if child:IsA("GuiObject") then totalChildren = totalChildren + 1 end
	end
	local totalHeight = totalChildren * (ITEM_HEIGHT + ITEM_PADDING)
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
