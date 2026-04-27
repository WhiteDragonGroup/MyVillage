-- MarketplaceServer.server.luau
-- Developer Product purchase handling via MarketplaceService

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProductConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local serverScript = script.Parent
local InventoryManager = require(serverScript:WaitForChild("InventoryManager"))
local EggManager = require(serverScript:WaitForChild("EggManager"))

-- Gift purchase tracking: { [receiptId] = { buyer, receiverName, itemName } }
local _pendingGifts = {}

-- Create remotes for Robux purchases
local buyRobuxFunc = remotes:FindFirstChild("BuyRobux")
if not buyRobuxFunc then
	buyRobuxFunc = Instance.new("RemoteEvent")
	buyRobuxFunc.Name = "BuyRobux"
	buyRobuxFunc.Parent = remotes
end

local buyRobuxGiftFunc = remotes:FindFirstChild("BuyRobuxGift")
if not buyRobuxGiftFunc then
	buyRobuxGiftFunc = Instance.new("RemoteEvent")
	buyRobuxGiftFunc.Name = "BuyRobuxGift"
	buyRobuxGiftFunc.Parent = remotes
end

-- Get product price remote (for displaying localized price)
local getProductPriceFunc = remotes:FindFirstChild("GetProductPrice")
if not getProductPriceFunc then
	getProductPriceFunc = Instance.new("RemoteFunction")
	getProductPriceFunc.Name = "GetProductPrice"
	getProductPriceFunc.Parent = remotes
end

-- Notify remote for purchase success
local purchaseNotifyEvent = remotes:FindFirstChild("PurchaseNotify")
if not purchaseNotifyEvent then
	purchaseNotifyEvent = Instance.new("RemoteEvent")
	purchaseNotifyEvent.Name = "PurchaseNotify"
	purchaseNotifyEvent.Parent = remotes
end

local giftReceivedEvent = remotes:WaitForChild("GiftReceived")

----------------------------------------------------------------
-- ProcessReceipt: Handle completed purchases
----------------------------------------------------------------
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId
	local itemInfo = ProductConfig.getItemFromProduct(productId)

	if not itemInfo then
		warn("[Marketplace] Unknown product: " .. productId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success = false

	if itemInfo.type == "building" then
		-- Check if this is a gift purchase
		local giftKey = player.UserId .. "_" .. productId
		local giftData = _pendingGifts[giftKey]

		if giftData then
			-- Gift purchase: add to receiver's inventory
			local receiver = nil
			for _, p in Players:GetPlayers() do
				if p.Name == giftData.receiverName then
					receiver = p
					break
				end
			end

			if receiver then
				local ok = InventoryManager.addItem(receiver, itemInfo.itemName, 1, 1)
				if ok then
					success = true
					-- Notify receiver
					local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
					local building = Constants.BUILDINGS[itemInfo.itemName]
					local displayName = building and building.name or itemInfo.itemName
					giftReceivedEvent:FireClient(receiver, player.Name, displayName)

					-- Notify all players in server about gift
					for _, p in Players:GetPlayers() do
						purchaseNotifyEvent:FireClient(p, "gift", {
							buyer = player.Name,
							receiver = giftData.receiverName,
							itemName = displayName,
						})
					end
				end
			end
			_pendingGifts[giftKey] = nil
		else
			-- Normal purchase: add to buyer's inventory
			local ok = InventoryManager.addItem(player, itemInfo.itemName, 1, 1)
			if ok then
				success = true
				local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
				local building = Constants.BUILDINGS[itemInfo.itemName]
				local displayName = building and building.name or itemInfo.itemName
				purchaseNotifyEvent:FireClient(player, "building", {
					itemName = displayName,
				})
			end
		end
	elseif itemInfo.type == "egg" then
		local ok = EggManager.addEgg(player, itemInfo.itemName, 1)
		if ok then
			success = true
			purchaseNotifyEvent:FireClient(player, "egg", {
				itemName = itemInfo.itemName,
			})
		end
	end

	if success then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

----------------------------------------------------------------
-- BuyRobux: Prompt developer product purchase
----------------------------------------------------------------
buyRobuxFunc.OnServerEvent:Connect(function(player, itemType, itemName)
	if typeof(itemType) ~= "string" or typeof(itemName) ~= "string" then return end

	local productId = ProductConfig.getProductId(itemType, itemName)
	if productId <= 0 then
		warn("[Marketplace] No product for: " .. itemType .. "/" .. itemName)
		return
	end

	MarketplaceService:PromptProductPurchase(player, productId)
end)

----------------------------------------------------------------
-- BuyRobuxGift: Prompt product purchase as gift
----------------------------------------------------------------
buyRobuxGiftFunc.OnServerEvent:Connect(function(buyer, itemName, receiverName)
	if typeof(itemName) ~= "string" or typeof(receiverName) ~= "string" then return end

	-- Verify receiver exists
	local receiver = nil
	for _, p in Players:GetPlayers() do
		if p.Name == receiverName then
			receiver = p
			break
		end
	end
	if not receiver or receiver == buyer then return end

	local productId = ProductConfig.getProductId("building", itemName)
	if productId <= 0 then return end

	-- Store pending gift
	local giftKey = buyer.UserId .. "_" .. productId
	_pendingGifts[giftKey] = {
		receiverName = receiverName,
		itemName = itemName,
	}

	MarketplaceService:PromptProductPurchase(buyer, productId)

	-- Clear pending gift after 60s if not completed
	task.delay(60, function()
		_pendingGifts[giftKey] = nil
	end)
end)

----------------------------------------------------------------
-- GetProductPrice: Return localized price for a product
----------------------------------------------------------------
getProductPriceFunc.OnServerInvoke = function(player, itemType, itemName)
	if typeof(itemType) ~= "string" or typeof(itemName) ~= "string" then return nil end

	local productId = ProductConfig.getProductId(itemType, itemName)
	if productId <= 0 then return nil end

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)

	if ok and info then
		return {
			price = info.PriceInRobux,
			name = info.Name,
		}
	end

	return nil
end

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
	-- Clear any pending gifts from this player
	for key, _ in _pendingGifts do
		if key:find(tostring(player.UserId)) then
			_pendingGifts[key] = nil
		end
	end
end)

print("[MarketplaceServer] loaded")
