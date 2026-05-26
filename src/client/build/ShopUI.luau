-- ShopUI.luau
-- 디자인 UI 사용 (StarterGui/Features/BuildingsShopFrame + ShopFrame)
-- BuildingsShopFrame: 건물 상점, ShopFrame: 알 상점

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local ProductConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProductConfig"))

local clientScript = script.Parent.Parent
local CameraManager = require(clientScript:WaitForChild("systems"):WaitForChild("CameraManager"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")

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
local _lastUpdate = 0

function ShopUI.init(callbacks: { onBuy: (string) -> (), onBuyGem: ((string) -> ())?, onGift: (string) -> (), onBuyEgg: ((string) -> ())?, onReloadRequest: () -> ()?, onOpen: () -> ()? })
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

		-- Connect egg buy/gift buttons in ShopFrame
		ShopUI._connectEggShop(shopFrame)
	end
end

-- Connect buttons inside egg/diamond shop items
function ShopUI._connectEggShop(frame)
	-- Debug: print all Gift elements
	for _, child in frame:GetDescendants() do
		if child.Name == "Gift" then
			print("[EggShop] Gift found: " .. child.ClassName .. " parent: " .. child.Parent.Name)
		end
	end

	for _, child in frame:GetDescendants() do
		-- Find Gift buttons (any GuiObject named "Gift")
		if child.Name == "Gift" then
			local clickTarget = child
			-- If not a button, add transparent click area
			if not child:IsA("GuiButton") then
				local clickBtn = Instance.new("TextButton")
				clickBtn.Name = "_GiftClick"
				clickBtn.Size = UDim2.new(1, 0, 1, 0)
				clickBtn.BackgroundTransparency = 1
				clickBtn.Text = ""
				clickBtn.ZIndex = 10
				clickBtn.Parent = child
				clickTarget = clickBtn
			end
			-- Find which egg/item this belongs to
			local parent = child.Parent
			while parent and parent ~= frame do
				local eggType = ShopUI._matchEggType(parent)
				if eggType then
					clickTarget.MouseButton1Click:Connect(function()
						if _callbacks.onGift then _callbacks.onGift(eggType) end
					end)
					print("[EggShop] Gift connected: " .. eggType)
					break
				end
				parent = parent.Parent
			end
		end

		-- Find Buy buttons for eggs
		if (child.Name == "Buy" or child.Name == "BuyButton") and child:IsA("GuiButton") then
			local parent = child.Parent
			while parent and parent ~= frame do
				local eggType = ShopUI._matchEggType(parent)
				if eggType then
					child.MouseButton1Click:Connect(function()
						if _callbacks.onBuyEgg then _callbacks.onBuyEgg(eggType) end
					end)
					break
				end
				parent = parent.Parent
			end
		end
	end
end

function ShopUI._matchEggType(element): string?
	local name = element.Name:lower()

	-- Search all TextLabels in descendants for egg name
	local allText = ""
	for _, desc in element:GetDescendants() do
		if desc:IsA("TextLabel") then
			allText = allText .. " " .. desc.Text:lower()
		end
	end

	if name:find("legendary") or allText:find("legendary") then return "Egg_Legendary" end
	if name:find("epic") or allText:find("epic") then return "Egg_Epic" end
	if name:find("rare") or allText:find("rare") then return "Egg_Rare" end
	if name:find("common") or allText:find("common") then return "Egg_Common" end

	return nil
end

function ShopUI.updateShop(shopData: { any }, restockTime: number)
	_lastUpdate = tick()
	_shopData = shopData
	_restockTime = restockTime
	print("[ShopUI] received " .. #shopData .. " items, restock in " .. math.floor(restockTime) .. "s")
	if _visible then
		ShopUI._renderItems()
		ShopUI._startTimer()
	end
end

local _shopSlotTemplate = nil
local _shopSlotHeight = nil

function ShopUI._renderItems()
	if not buildingsShopFrame then return end

	local scrollFrame = buildingsShopFrame:FindFirstChild("ScrollingFrame")
	if not scrollFrame then return end

	-- 슬롯 템플릿 저장 (최초 1회) + 원본 높이 기록
	if not _shopSlotTemplate then
		for _, child in scrollFrame:GetChildren() do
			if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("TextButton") then
				if child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
					_shopSlotHeight = child.AbsoluteSize.Y
					_shopSlotTemplate = child:Clone()
					break
				end
			end
		end
	end

	-- 기존 슬롯 모두 제거 (레이아웃 객체 보존)
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end

	if not _shopSlotTemplate then
		warn("[ShopUI] No slot template found in ScrollingFrame")
		return
	end

	print("[ShopUI] rendering " .. #_shopData .. " items")

	-- Ensure layout exists
	if not scrollFrame:FindFirstChildWhichIsA("UIListLayout") and not scrollFrame:FindFirstChildWhichIsA("UIGridLayout") then
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = scrollFrame
	end

	for i, item in _shopData do
		local building = Constants.BUILDINGS[item.itemName]
		if not building then continue end

		local slot = _shopSlotTemplate:Clone()
		slot.Name = "Slot_" .. item.itemName
		slot.Visible = true
		slot.LayoutOrder = i
		slot.Parent = scrollFrame

		-- Debug: print ALL descendants (first item only)
		if i == 1 then
			for _, desc in slot:GetDescendants() do
				print("[ShopSlot] " .. desc:GetFullName():sub(#slot:GetFullName() + 2) .. " (" .. desc.ClassName .. ")")
			end
		end

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
			if stockText:IsA("TextLabel") or stockText:IsA("TextButton") then
				stockText.TextColor3 = if item.stock > 0
					then Color3.fromRGB(255, 255, 255)
					else Color3.fromRGB(198, 36, 39)
			end
		end

		-- Rarity
		local rarityFrame = slot:FindFirstChild("Rarity")
		if rarityFrame then
			local rarityLabel = rarityFrame:FindFirstChild("TextLabel") or rarityFrame:FindFirstChildWhichIsA("TextLabel")
			if rarityLabel then rarityLabel.Text = building.rarity end
		end

		-- Icon (레벨 1 이미지)
		local iconLabel = slot:FindFirstChild("Icon", true)
		if iconLabel and (iconLabel:IsA("ImageLabel") or iconLabel:IsA("ImageButton")) and Constants.getBuildingIcon then
			local iconId = Constants.getBuildingIcon(item.itemName, 1)
			if iconId ~= "" then iconLabel.Image = iconId end
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
				buyDollar.BackgroundColor3 = Color3.fromRGB(198, 36, 39)
				buyDollar.BackgroundTransparency = 0
			end
		end

		-- BuyRobux
		local buyRobux = slot:FindFirstChild("BuyRobux")
		if buyRobux and buyRobux:IsA("GuiButton") then
			local btnText = buyRobux:FindFirstChild("TextLabel") or buyRobux:FindFirstChildWhichIsA("TextLabel")
			local productId = ProductConfig.getProductId("building", item.itemName)
			if productId > 0 then
				-- Fetch localized price async
				task.spawn(function()
					local getPriceFunc = remotes:FindFirstChild("GetProductPrice")
					if getPriceFunc then
						local info = getPriceFunc:InvokeServer("building", item.itemName)
						if info and info.price and btnText then
							btnText.Text = "R$" .. info.price
						end
					end
				end)
			end
			if item.stock > 0 then
				buyRobux.MouseButton1Click:Connect(function()
					if _callbacks.onBuyGem then _callbacks.onBuyGem(item.itemName) end
				end)
			else
				buyRobux.Active = false
				buyRobux.BackgroundTransparency = 0.5
			end
		end

		-- Gift button (BuyRobux > Gift)
		local giftBtn = slot:FindFirstChild("Gift", true)
		if giftBtn then
			if giftBtn:IsA("GuiButton") then
				if item.stock > 0 then
					giftBtn.MouseButton1Click:Connect(function()
						if _callbacks.onGift then _callbacks.onGift(item.itemName) end
					end)
				else
					giftBtn.Active = false
					giftBtn.BackgroundTransparency = 0.5
				end
			else
				-- ImageLabel: add transparent click button
				local clickBtn = Instance.new("TextButton")
				clickBtn.Name = "_GiftClick"
				clickBtn.Size = UDim2.new(1, 0, 1, 0)
				clickBtn.BackgroundTransparency = 1
				clickBtn.Text = ""
				clickBtn.ZIndex = 10
				clickBtn.Parent = giftBtn
				if item.stock > 0 then
					clickBtn.MouseButton1Click:Connect(function()
						if _callbacks.onGift then _callbacks.onGift(item.itemName) end
					end)
				end
			end
		end
	end

	-- Fix slot heights to original pixel size, then auto-expand canvas
	if _shopSlotHeight and _shopSlotHeight > 0 then
		for _, child in scrollFrame:GetChildren() do
			if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
				child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset, 0, _shopSlotHeight)
			end
		end
	end
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
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

	local _reloadRequested = false
	-- TODO: Hot 폴링 대신 task.spawn, while, task.wait(1) 으로 low-priority 폴링을 하는편이
	--       좋아보여요
	_timerConnection = RunService.Heartbeat:Connect(function(_dt)
		if not _visible then return end
		local updateDiff = tick() - _lastUpdate
		local currentRemain = math.max(0, _restockTime - updateDiff)
		
		if currentRemain == 0 then
			if not _reloadRequested then
				_reloadRequested = true
				if _callbacks.onReloadRequest then
					_callbacks.onReloadRequest()
				end
			end 
		else
			_reloadRequested = false
		end

		-- RestockText 업데이트
		if buildingsShopFrame then
			local header = buildingsShopFrame:FindFirstChild("Header")
			if header then
				local restockText = header:FindFirstChild("RestockText")
				if restockText then
					local mins = currentRemain // 60
					local secs = math.floor(currentRemain % 60)
					restockText.Text = string.format("Restocking in %d:%02d", mins, secs)
				end
			end
		end
	end)
end

function ShopUI.show()
	if _visible then return end
	_visible = true
	if _callbacks.onOpen then
		_callbacks.onOpen()
	end
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
	CameraManager.ResetFOV(TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))
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

function ShopUI.isBuildingsShopVisible(): boolean
	return buildingsShopFrame and buildingsShopFrame.Visible == true
end

function ShopUI.destroy()
	if _timerConnection then
		_timerConnection:Disconnect()
	end
end

return ShopUI
