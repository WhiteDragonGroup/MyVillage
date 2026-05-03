-- ShopConfig.luau
-- 건물 상점 밸런스 수치
-- 참조: ShopManager / ShopUI

local ShopConfig = {}

-- 상점 재입고 간격 (초)
--ShopConfig.RESTOCK_INTERVAL = 300 -- 5분

-- 상점 판매 목록: itemName, 가격(코인), 최대 재고
ShopConfig.SHOP_ITEMS = {
	-- Common
	{ itemName = "Farm",            price = 60,    maxStock = 3 },
	{ itemName = "Mine",            price = 80,    maxStock = 3 },
	{ itemName = "ClockTower",      price = 100,   maxStock = 1 },
	-- Rare
	{ itemName = "Campfire",        price = 250,   maxStock = 2 },
	-- Epic
	{ itemName = "PotionCafe",      price = 800,   maxStock = 1 },
	{ itemName = "GiantFurnace",    price = 1000,  maxStock = 1 },
	-- Legendary
	{ itemName = "HotSpring",       price = 3000,  maxStock = 1 },
	{ itemName = "Laboratory",      price = 4000,  maxStock = 1 },
	-- Mythic
	{ itemName = "TreeOfGrowth",    price = 10000, maxStock = 1 },
	{ itemName = "AltarOfBlessing", price = 15000, maxStock = 1 },
}

return ShopConfig
