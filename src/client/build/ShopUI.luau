-- ShopUI.luau
-- 디자인 UI 사용 (StarterGui/Features/BuildingsShopFrame + ShopFrame)
-- BuildingsShopFrame: 건물 상점, ShopFrame: 알 상점

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopUI = {}

local featuresGui = nil
local buildingsShopFrame = nil
local shopFrame = nil -- 알 상점
local _visible = false
local _callbacks = {}
local _shopData = {}
local _restockTime = 0
local _timerConnection = nil

function ShopUI.init(callbacks: { onBuy: (string) -> (), onBuyGem: ((string) -> ())?, onGift: (string) -> (), onBuyEgg: ((string) -> ())? })
	_callbacks = callbacks

	featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then
		warn("[ShopUI] Features ScreenGui를 찾을 수 없음")
		return
	end

	buildingsShopFrame = featuresGui:FindFirstChild("BuildingsShopFrame")
	shopFrame = featuresGui:FindFirstChild("ShopFrame")

	if buildingsShopFrame then
		buildingsShopFrame.Visible = false

		-- Close 버튼
		local header = buildingsShopFrame:FindFirstChild("Header")
		if header then
			local closeBtn = header:FindFirstChild("Close")
			if closeBtn then
				if closeBtn:IsA("GuiButton") then
					closeBtn.MouseButton1Click:Connect(function()
						ShopUI.hide()
					end)
				else
					local btn = Instance.new("TextButton")
					btn.Name = "_Close"
					btn.Size = UDim2.new(1, 0, 1, 0)
					btn.BackgroundTransparency = 1
					btn.Text = ""
					btn.ZIndex = 10
					btn.Parent = closeBtn
					btn.MouseButton1Click:Connect(function()
						ShopUI.hide()
					end)
				end
			end
		end
	end

	if shopFrame then
		shopFrame.Visible = false

		local header = shopFrame:FindFirstChild("Header")
		if header then
			local closeBtn = header:FindFirstChild("Close")
			if closeBtn and closeBtn:IsA("GuiButton") then
				closeBtn.MouseButton1Click:Connect(function()
					ShopUI.hide()
				end)
			end
		end
	end
end

function ShopUI.updateShop(shopData: { any }, restockTime: number)
	_shopData = shopData
	_restockTime = restockTime
	if _visible then
		ShopUI._renderItems()
		ShopUI._startTimer()
	end
end

local _shopSlotTemplate = nil

function ShopUI._renderItems()
	if not buildingsShopFrame then return end

	local scrollFrame = buildingsShopFrame:FindFirstChild("ScrollingFrame")
	if not scrollFrame then return end

	-- 슬롯 템플릿 저장 (최초 1회)
	if not _shopSlotTemplate then
		for _, child in scrollFrame:GetChildren() do
			if child.Name == "Frame" and child:IsA("GuiObject") then
				_shopSlotTemplate = child:Clone()
				break
			end
		end
	end

	-- 기존 슬롯 모두 제거
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	if not _shopSlotTemplate then return end

	for i, item in _shopData do
		local building = Constants.BUILDINGS[item.itemName]
		if not building then continue end

		local slot = _shopSlotTemplate:Clone()
		slot.Name = "Slot_" .. item.itemName
		slot.Visible = true
		slot.LayoutOrder = i
		slot.Parent = scrollFrame

		-- NameText
		local nameText = slot:FindFirstChild("NameText")
		if nameText then nameText.Text = building.name end
		local nameShadow = slot:FindFirstChild("NameTextShadow")
		if nameShadow then nameShadow.Text = building.name end

		-- PriceText
		local priceText = slot:FindFirstChild("PriceText")
		if priceText then priceText.Text = "$" .. item.price end

		-- StockText
		local stockText = slot:FindFirstChild("StockText")
		if stockText then
			stockText.Text = if item.stock > 0 then item.stock .. "x stock" else "NO STOCK"
		end

		-- Rarity
		local rarityFrame = slot:FindFirstChild("Rarity")
		if rarityFrame then
			local rarityLabel = rarityFrame:FindFirstChild("TextLabel") or rarityFrame:FindFirstChildWhichIsA("TextLabel")
			if rarityLabel then rarityLabel.Text = building.rarity end
		end

		-- BuyDollar
		local buyDollar = slot:FindFirstChild("BuyDollar")
		if buyDollar and buyDollar:IsA("GuiButton") then
			local btnText = buyDollar:FindFirstChild("TextLabel") or buyDollar:FindFirstChildWhichIsA("TextLabel")
			if btnText then btnText.Text = "$" .. item.price end
			if item.stock > 0 then
				buyDollar.MouseButton1Click:Connect(function()
					if _callbacks.onBuy then _callbacks.onBuy(item.itemName) end
				end)
			else
				buyDollar.Active = false
				buyDollar.BackgroundTransparency = 0.5
			end
		end

		-- BuyRobux
		local buyRobux = slot:FindFirstChild("BuyRobux")
		if buyRobux and buyRobux:IsA("GuiButton") then
			local btnText = buyRobux:FindFirstChild("TextLabel") or buyRobux:FindFirstChildWhichIsA("TextLabel")
			if btnText then btnText.Text = math.floor(item.price * 0.2) end
			if item.stock > 0 then
				buyRobux.MouseButton1Click:Connect(function()
					if _callbacks.onBuyGem then _callbacks.onBuyGem(item.itemName) end
				end)
			else
				buyRobux.Active = false
				buyRobux.BackgroundTransparency = 0.5
			end
		end
	end
end

function ShopUI._renderItems_disabled()
	if not buildingsShopFrame then return end

	local scrollFrame = buildingsShopFrame:FindFirstChild("ScrollingFrame")
	if not scrollFrame then return end

	for _, child in scrollFrame:GetChildren() do
		if child:IsA("GuiObject") and child:GetAttribute("_dynamic") then
			child:Destroy()
		end
	end

	for i, item in _shopData do
		local building = Constants.BUILDINGS[item.itemName]
		if not building then continue end

		local rarityColor = Constants.RARITY_COLORS[building.rarity] or Color3.fromRGB(180, 180, 180)

		local slot = Instance.new("TextButton")
		slot.Name = item.itemName
		slot.Size = UDim2.new(1, -8, 0, 60)
		slot.BackgroundColor3 = Color3.fromRGB(50, 40, 35)
		slot.BackgroundTransparency = 0.3
		slot.AutoButtonColor = true
		slot.LayoutOrder = i
		slot.Text = ""
		slot:SetAttribute("_dynamic", true)
		slot.Parent = scrollFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = slot

		local stroke = Instance.new("UIStroke")
		stroke.Color = rarityColor
		stroke.Thickness = 1
		stroke.Parent = slot

		-- 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 140, 0, 18)
		nameLabel.Position = UDim2.new(0, 10, 0, 6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = building.name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- 재고 + 희귀도
		local infoText = "X" .. item.stock .. " Stock | " .. building.rarity
		if item.stock <= 0 then infoText = "NO STOCK | " .. building.rarity end
		local infoLabel = Instance.new("TextLabel")
		infoLabel.Size = UDim2.new(0, 150, 0, 14)
		infoLabel.Position = UDim2.new(0, 10, 0, 24)
		infoLabel.BackgroundTransparency = 1
		infoLabel.TextColor3 = rarityColor
		infoLabel.TextSize = 9
		infoLabel.Font = Enum.Font.Gotham
		infoLabel.Text = infoText
		infoLabel.TextXAlignment = Enum.TextXAlignment.Left
		infoLabel.Parent = slot

		-- 가격
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(0, 60, 0, 16)
		priceLabel.Position = UDim2.new(0, 10, 0, 40)
		priceLabel.BackgroundTransparency = 1
		priceLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
		priceLabel.TextSize = 11
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.Text = "$" .. item.price
		priceLabel.TextXAlignment = Enum.TextXAlignment.Left
		priceLabel.Parent = slot

		-- 구매 버튼
		if item.stock > 0 then
			slot.MouseButton1Click:Connect(function()
				if _callbacks.onBuy then _callbacks.onBuy(item.itemName) end
			end)
		end
	end
end

function ShopUI._startTimer()
	if _timerConnection then
		_timerConnection:Disconnect()
		_timerConnection = nil
	end

	_timerConnection = RunService.Heartbeat:Connect(function(dt)
		if not _visible then return end
		_restockTime = math.max(0, _restockTime - dt)

		-- RestockText 업데이트
		if buildingsShopFrame then
			local header = buildingsShopFrame:FindFirstChild("Header")
			if header then
				local restockText = header:FindFirstChild("RestockText")
				if restockText then
					local mins = math.floor(_restockTime / 60)
					local secs = math.floor(_restockTime % 60)
					restockText.Text = string.format("Restocking in %d:%02d", mins, secs)
				end
			end
		end
	end)
end

function ShopUI.show()
	if _visible then return end
	_visible = true
	-- Shop 버튼 = 알 상점 (ShopFrame)
	if shopFrame then shopFrame.Visible = true end
end

-- 건물 상점 열기 (NPC용)
function ShopUI.showBuildingsShop()
	if buildingsShopFrame then
		_visible = true
		buildingsShopFrame.Visible = true
		ShopUI._renderItems()
		ShopUI._startTimer()
	end
end

function ShopUI.hide()
	_visible = false
	if shopFrame then shopFrame.Visible = false end
	if buildingsShopFrame then buildingsShopFrame.Visible = false end
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
	end
end

return ShopUI
