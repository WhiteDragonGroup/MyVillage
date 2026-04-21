-- ShopConfig.luau
-- 건물 상점 밸런스 수치
-- 참조: ShopManager / ShopUI

local ShopConfig = {}

-- 상점 재입고 간격 (초) — 게임 내 시간 기준
ShopConfig.RESTOCK_INTERVAL = 300 -- 5분

-- 상점 판매 목록: itemName, 가격(코인), 최대 재고
ShopConfig.SHOP_ITEMS = {
	{ itemName = "Garden",     price = 50,   maxStock = 3 },
	{ itemName = "Mine",       price = 120,  maxStock = 2 },
	{ itemName = "Inn",        price = 80,   maxStock = 2 },
	{ itemName = "Fountain",   price = 40,   maxStock = 5 },
	{ itemName = "Market",     price = 150,  maxStock = 1 },
	{ itemName = "Blacksmith", price = 200,  maxStock = 1 },
	{ itemName = "HotSpring",  price = 180,  maxStock = 1 },
	{ itemName = "Library",    price = 250,  maxStock = 1 },
	{ itemName = "Lab",        price = 500,  maxStock = 1 },
	{ itemName = "Brewery",    price = 400,  maxStock = 1 },
	{ itemName = "Pavilion",   price = 450,  maxStock = 1 },
	{ itemName = "MagicTower", price = 800,  maxStock = 1 },
	{ itemName = "Temple",     price = 1500, maxStock = 1 },
	{ itemName = "WorldTree",  price = 2000, maxStock = 1 },
	{ itemName = "Campfire",   price = 30,   maxStock = 5 },
	{ itemName = "PotionCafe", price = 220,  maxStock = 1 },
	{ itemName = "AltarOfBlessing", price = 1000, maxStock = 1 },
	{ itemName = "Farm",       price = 60,   maxStock = 3 },
	{ itemName = "Laboratory", price = 600, maxStock = 1 },
	{ itemName = "GiantFurnace", price = 700, maxStock = 1 },
	{ itemName = "TreeOfGrowth", price = 900, maxStock = 1 },
	{ itemName = "ClockTower", price = 350, maxStock = 1 },
}

return ShopConfig