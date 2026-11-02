-- 자원 26종 정의 (Notion: Item Catalog)
-- cycle: 주민 1명·일터 1레벨이 1개를 만드는 시간(초)
-- storage: 일터 1레벨의 자원별 기본 저장 한도

local LIST = {
	{ id = "Wheat", name = "Wheat", rarity = "Common", cycle = 5, storage = 24, price = 20 },
	{ id = "Corn", name = "Corn", rarity = "Common", cycle = 15, storage = 12, price = 25 },
	{ id = "Timber", name = "Timber", rarity = "Common", cycle = 8, storage = 30, price = 35 },
	{ id = "TreeSap", name = "Tree Sap", rarity = "Uncommon", cycle = 40, storage = 10, price = 20 },
	{ id = "Mushroom", name = "Mushroom", rarity = "Common", cycle = 8, storage = 60, price = 35 },
	{ id = "Charcoal", name = "Charcoal", rarity = "Common", cycle = 30, storage = 12, price = 25 },
	{ id = "Meat", name = "Meat", rarity = "Common", cycle = 10, storage = 30, price = 50 },
	{ id = "Petal", name = "Petal", rarity = "Common", cycle = 36, storage = 16, price = 30 },
	{ id = "Herb", name = "Herb", rarity = "Uncommon", cycle = 12, storage = 40, price = 40 },
	{ id = "Stone", name = "Stone", rarity = "Common", cycle = 12, storage = 25, price = 55 },
	{ id = "IronOre", name = "Iron Ore", rarity = "Uncommon", cycle = 60, storage = 20, price = 45 },
	{ id = "GoldOre", name = "Gold Ore", rarity = "Rare", cycle = 120, storage = 15, price = 90 },
	{ id = "Gem", name = "Gem", rarity = "Epic", cycle = 240, storage = 10, price = 200 },
	{ id = "Diamond", name = "Diamond", rarity = "Legendary", cycle = 600, storage = 10, price = 900 },
	{ id = "HotSpringEgg", name = "Hot Spring Egg", rarity = "Uncommon", cycle = 15, storage = 36, price = 80 },
	{ id = "Beeswax", name = "Beeswax", rarity = "Uncommon", cycle = 60, storage = 12, price = 60 },
	{ id = "Honey", name = "Honey", rarity = "Rare", cycle = 20, storage = 32, price = 90 },
	{ id = "GoldenLeaf", name = "Golden Leaf", rarity = "Rare", cycle = 90, storage = 8, price = 120 },
	{ id = "GoldenApple", name = "Golden Apple", rarity = "Epic", cycle = 30, storage = 24, price = 180 },
	{ id = "ArcaneDust", name = "Arcane Dust", rarity = "Rare", cycle = 90, storage = 10, price = 80 },
	{ id = "Crystal", name = "Crystal", rarity = "Epic", cycle = 30, storage = 30, price = 150 },
	{ id = "IronIngot", name = "Iron Ingot", rarity = "Rare", cycle = 36, storage = 36, price = 180 },
	{ id = "GoldIngot", name = "Gold Ingot", rarity = "Epic", cycle = 120, storage = 12, price = 250 },
	{ id = "StarlightShard", name = "Starlight Shard", rarity = "Legendary", cycle = 40, storage = 25, price = 240 },
	{ id = "ToolCrate", name = "Tool Crate", rarity = "Epic", cycle = 120, storage = 12, price = 300 },
	{ id = "SupplyCrate", name = "Supply Crate", rarity = "Rare", cycle = 45, storage = 30, price = 260 },
}

local Items = { List = LIST, ById = {} }

for order, item in LIST do
	item.order = order
	Items.ById[item.id] = item
end

return Items
