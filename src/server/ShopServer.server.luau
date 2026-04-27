-- ShopServer.server.luau
-- 상점 + 선물 Remote 핸들러

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getShopFunc = remotes:WaitForChild("GetShop")
local buyItemEvent = remotes:WaitForChild("BuyItem")
local shopUpdateEvent = remotes:WaitForChild("ShopUpdate")
local sendGiftEvent = remotes:WaitForChild("SendGift")
local giftReceivedEvent = remotes:WaitForChild("GiftReceived")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

-- Buy result notification
local buyResultEvent = remotes:FindFirstChild("BuyResult")
if not buyResultEvent then
	buyResultEvent = Instance.new("RemoteEvent")
	buyResultEvent.Name = "BuyResult"
	buyResultEvent.Parent = remotes
end

local serverScript = script.Parent
local ShopManager = require(serverScript:WaitForChild("ShopManager"))
local InventoryManager = require(serverScript:WaitForChild("InventoryManager"))
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))

-- ShopManager에 코인/인벤토리 함수 연결
ShopManager.setCurrencyFunctions(
	function(player, amount) return CurrencyManager.hasCoins(player, amount) end,
	function(player, amount) return CurrencyManager.spendCoins(player, amount) end
)
ShopManager.setInventoryFunction(function(player, itemName, count, level)
	return InventoryManager.addItem(player, itemName, count, level)
end)

-- 상점 갱신 알림
local function notifyShopUpdate(player: Player)
	local shopData, restockTime = ShopManager.getShopData(player)
	shopUpdateEvent:FireClient(player, shopData, restockTime)
end

----------------------------------------------------------------
-- GetShop: 상점 데이터 조회
----------------------------------------------------------------
getShopFunc.OnServerInvoke = function(player)
	return ShopManager.getShopData(player)
end

----------------------------------------------------------------
-- BuyItem: 상점에서 건물 구매
----------------------------------------------------------------
buyItemEvent.OnServerEvent:Connect(function(player, itemName)
	if typeof(itemName) ~= "string" then return end

	local success, msg = ShopManager.buyItem(player, itemName)
	if success then
		local building = Constants.BUILDINGS[itemName]
		local displayName = building and building.name or itemName
		buyResultEvent:FireClient(player, true, displayName .. " purchased!")
	else
		buyResultEvent:FireClient(player, false, msg)
	end

	notifyShopUpdate(player)
end)

----------------------------------------------------------------
-- SendGift: 상점에서 건물 선물
----------------------------------------------------------------
sendGiftEvent.OnServerEvent:Connect(function(buyer, itemName, receiverName)
	if typeof(itemName) ~= "string" or typeof(receiverName) ~= "string" then return end

	-- 수신자 찾기
	local receiver = nil
	for _, p in Players:GetPlayers() do
		if p.Name == receiverName then
			receiver = p
			break
		end
	end

	if not receiver then
		warn(buyer.Name .. " - 선물 실패: 수신자 없음 (" .. receiverName .. ")")
		return
	end

	if receiver == buyer then
		warn(buyer.Name .. " - 자기 자신에게 선물 불가")
		return
	end

	local success, msg = ShopManager.buyGift(buyer, itemName, receiver)
	if success then
		local building = Constants.BUILDINGS[itemName]
		local displayName = building and building.name or itemName

		-- 수신자에게 알림
		giftReceivedEvent:FireClient(receiver, buyer.Name, displayName)

		-- 서버 전체에 선물 알림
		buyResultEvent:FireClient(buyer, true, "Gifted " .. displayName .. " to " .. receiver.DisplayName .. "!")
		for _, p in Players:GetPlayers() do
			if p ~= buyer and p ~= receiver then
				buyResultEvent:FireClient(p, true, buyer.DisplayName .. " gifted " .. displayName .. " to " .. receiver.DisplayName .. "!")
			end
		end
	else
		buyResultEvent:FireClient(buyer, false, msg)
	end

	notifyShopUpdate(buyer)
end)

print("ShopServer 로드됨 - 상점 + 선물 시스템")
