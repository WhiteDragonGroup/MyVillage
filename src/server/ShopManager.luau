-- ShopManager.luau
-- Server-wide shop: shared stock, rarity-based random stock on restock

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local ShopCfg = BalanceConfig.Shop

local ShopManager = {}

-- Global shop state (shared across all players)
local _globalShop = {
	stocks = {},
	lastQuantization = 0,
	updateResolution = 60 * 5, -- 5분 마다 업데이트
}

-- Rarity → chance of having stock (higher rarity = lower chance)
local RARITY_STOCK_CHANCE = {
	["Common"] = 1.0,
	["Rare"] = 0.7,
	["Epic"] = 0.4,
	["Legendary"] = 0.25,
	["Mythic"] = 0.15,
}

-- Currency functions (injected)
local _hasCoins = nil
local _spendCoins = nil

function ShopManager.setCurrencyFunctions(hasFn, spendFn)
	_hasCoins = hasFn
	_spendCoins = spendFn
end

-- Inventory add function (injected)
local _addItem = nil

function ShopManager.setInventoryFunction(addFn)
	_addItem = addFn
end

-- Build full item list from Constants.BUILDINGS + ShopConfig overrides
-- Excludes TownHall (starter building) + ClockTower (튜토리얼 1회 지급, 삭제·재구매 불가)
local EXCLUDED_BUILDINGS = { TownHall = true, ClockTower = true }

local RARITY_DEFAULT_PRICE = {
	["Common"] = 50,
	["Rare"] = 200,
	["Epic"] = 500,
	["Legendary"] = 1000,
	["Mythic"] = 2000,
}

local RARITY_DEFAULT_MAX_STOCK = {
	["Common"] = 3,
	["Rare"] = 2,
	["Epic"] = 1,
	["Legendary"] = 1,
	["Mythic"] = 1,
}

-- Merge ShopConfig items into lookup
local _shopConfigLookup = {}
for _, item in ShopCfg.SHOP_ITEMS do
	_shopConfigLookup[item.itemName] = item
end

-- Build full shop items list (all buildings)
local _allShopItems = {}
for itemName, building in Constants.BUILDINGS do
	if EXCLUDED_BUILDINGS[itemName] then continue end
	local cfg = _shopConfigLookup[itemName]
	table.insert(_allShopItems, {
		itemName = itemName,
		price = cfg and cfg.price or RARITY_DEFAULT_PRICE[building.rarity] or 100,
		maxStock = cfg and cfg.maxStock or RARITY_DEFAULT_MAX_STOCK[building.rarity] or 1,
	})
end
-- Sort by price
table.sort(_allShopItems, function(a, b) return a.price < b.price end)
print("[ShopManager] " .. #_allShopItems .. " buildings in shop")

-- Generate random stock based on rarity
local function generateStock(seed: number)
	local stocks = {}
	local rand = Random.new(seed)
	
	for _, item in _allShopItems do
		local building = Constants.BUILDINGS[item.itemName]
		local rarity = building and building.rarity or "Common"
		local chance = RARITY_STOCK_CHANCE[rarity] or 1.0

		if rand:NextNumber() <= chance then
			stocks[item.itemName] = rand:NextInteger(1, item.maxStock)
		else
			stocks[item.itemName] = 0
		end
	end
	return stocks
end

-- Initialize global shop (called once at server start)
local function initGlobalShop()
	_globalShop.lastQuantization = tick() // _globalShop.updateResolution
	_globalShop.stocks = generateStock(_globalShop.lastQuantization)
end

-- Check and perform restock if needed
function ShopManager._checkRestock()
	local currentQuantization = tick() // _globalShop.updateResolution
	if currentQuantization == _globalShop.lastQuantization then
		return false
	end

	_globalShop.lastQuantization = currentQuantization
	_globalShop.stocks = generateStock(_globalShop.lastQuantization)
	return true

	--local elapsed = tick() - _globalShop.lastRestock
	--if elapsed >= ShopCfg.RESTOCK_INTERVAL then
	--	_globalShop.stocks = generateStock()
	--	_globalShop.lastRestock = tick()
	--	return true -- restocked
	--end
	--return false
end

-- Player init/remove (no-op for global shop, kept for interface compat)
function ShopManager.initPlayer(player: Player)
	-- Global shop, nothing per-player
end

function ShopManager.removePlayer(player: Player)
	-- Global shop, nothing per-player
end

-- Get shop data for client
function ShopManager.getShopData(player: Player): ({ any }, number)
	ShopManager._checkRestock()

	local result = {}
	for _, item in _allShopItems do
		table.insert(result, {
			itemName = item.itemName,
			price = item.price,
			stock = _globalShop.stocks[item.itemName] or 0,
			maxStock = item.maxStock,
		})
	end

	--local restockTime = math.max(0, ShopCfg.RESTOCK_INTERVAL - (tick() - _globalShop.lastRestock))
	local restockTime = _globalShop.updateResolution - (tick() % _globalShop.updateResolution)
	return result, restockTime
end

-- Buy item
function ShopManager.buyItem(player: Player, itemName: string): (boolean, string)
	ShopManager._checkRestock()

	local shopItem = nil
	for _, item in _allShopItems do
		if item.itemName == itemName then
			shopItem = item
			break
		end
	end
	if not shopItem then return false, "Item not found" end

	local stock = _globalShop.stocks[itemName] or 0
	if stock <= 0 then return false, "Out of stock" end

	if not _hasCoins or not _spendCoins then return false, "Coin system not connected" end
	if not _hasCoins(player, shopItem.price) then return false, "Not enough coins" end
	if not _spendCoins(player, shopItem.price) then return false, "Coin deduction failed" end

	_globalShop.stocks[itemName] = stock - 1

	if _addItem then
		_addItem(player, itemName, 1, 1)
	end

	return true, "Purchase complete"
end

-- Gift purchase
function ShopManager.buyGift(buyer: Player, itemName: string, receiver: Player): (boolean, string)
	ShopManager._checkRestock()

	local shopItem = nil
	for _, item in _allShopItems do
		if item.itemName == itemName then
			shopItem = item
			break
		end
	end
	if not shopItem then return false, "Item not found" end

	local stock = _globalShop.stocks[itemName] or 0
	if stock <= 0 then return false, "Out of stock" end

	if not _hasCoins or not _spendCoins then return false, "Coin system not connected" end
	if not _hasCoins(buyer, shopItem.price) then return false, "Not enough coins" end
	if not _spendCoins(buyer, shopItem.price) then return false, "Coin deduction failed" end

	_globalShop.stocks[itemName] = stock - 1

	if _addItem then
		_addItem(receiver, itemName, 1, 1)
	end

	return true, "Gift complete"
end

-- Initialize on load
initGlobalShop()

return ShopManager
