-- 건물 19종 정의 (Notion: Building Catalog)
-- kind: "Home" | "Work" | "Landmark"
-- model: ReplicatedStorage.Buildings 아래 폴더 이름. 없으면 임시 블록으로 표시한다.

local Buildings = {}

Buildings.MAX_LEVEL = 5

-- 시계탑 레벨 n → n+1 강화 비용
Buildings.ClockTowerUpgrade = { 8000, 40000, 180000, 750000 }

local DEFS = {
	ClockTower = { kind = "Landmark", name = "Clock Tower", unlock = 1, model = "ClockTower" },

	Cottage2 = { kind = "Home", name = "2-Resident Cottage", unlock = 1, coins = 800, residents = 2,
		recipe = { Wheat = 20, Timber = 10 }, houseModel = "House_2" },
	Cottage3 = { kind = "Home", name = "3-Resident Cottage", unlock = 1, coins = 1500, residents = 3,
		recipe = { Wheat = 30, Timber = 20 }, houseModel = "House_1" },
	House4 = { kind = "Home", name = "4-Resident House", unlock = 2, coins = 3000, residents = 4,
		recipe = { Timber = 35, Stone = 15 }, houseModel = "House_6" },
	House5 = { kind = "Home", name = "5-Resident House", unlock = 3, coins = 5500, residents = 5,
		recipe = { Timber = 50, Stone = 30, IronOre = 8 }, houseModel = "House_3" },
	House6 = { kind = "Home", name = "6-Resident House", unlock = 4, coins = 8500, residents = 6,
		recipe = { Timber = 70, Stone = 45, IronOre = 15, GoldenLeaf = 3 }, houseModel = "House_9" },

	-- 농장 작물 밑동은 흙 아래로 묻히는 모양이라 밭(가장 넓은 파츠)을 바닥에 맞춘다
	Farm = { kind = "Work", name = "Farm", unlock = 1, coins = 1000, capacity = 2, model = "Farm", groundOnWidestPart = true,
		outputs = { "Wheat", "Corn" }, recipe = { Wheat = 20, Timber = 10 },
		upgrade = { 800, 2000, 5000, 12000 } },
	Lumberyard = { kind = "Work", name = "Lumberyard", unlock = 1, coins = 1200, capacity = 4,
		outputs = { "Timber", "TreeSap" }, recipe = { Wheat = 25, Corn = 10 },
		upgrade = { 1200, 3000, 7500, 18000 }, color = Color3.fromRGB(150, 105, 65) },
	MushroomFarm = { kind = "Work", name = "Mushroom Farm", unlock = 1, coins = 1600, capacity = 3,
		outputs = { "Mushroom" }, recipe = { Timber = 25, TreeSap = 10 },
		upgrade = { 1000, 2500, 6000, 15000 }, color = Color3.fromRGB(190, 90, 80) },
	Campfire = { kind = "Work", name = "Campfire", unlock = 1, coins = 1600, capacity = 2, model = "Campfire",
		outputs = { "Meat", "Charcoal" }, recipe = { Timber = 20, Corn = 10 },
		upgrade = { 1000, 2500, 6000, 15000 } },
	HerbGarden = { kind = "Work", name = "Herb Garden", unlock = 2, coins = 2400, capacity = 2,
		outputs = { "Herb", "Petal" }, recipe = { Timber = 25, TreeSap = 12, Wheat = 10 },
		upgrade = { 1200, 3000, 7500, 18000 }, color = Color3.fromRGB(110, 180, 110) },
	Mine = { kind = "Work", name = "Mine", unlock = 2, coins = 2800, capacity = 5, model = "Mine",
		outputs = { "Stone", "IronOre", "GoldOre", "Gem", "Diamond" }, recipe = { Timber = 40, Charcoal = 12 },
		upgrade = { 1800, 4500, 11000, 27000 } },
	HotSpring = { kind = "Work", name = "Hot Spring", unlock = 2, coins = 4800, capacity = 3, model = "HotSpring",
		outputs = { "HotSpringEgg" }, recipe = { Stone = 35, Timber = 25, Herb = 10 },
		upgrade = { 1600, 4000, 10000, 24000 } },
	Apiary = { kind = "Work", name = "Apiary", unlock = 3, coins = 6500, capacity = 4,
		outputs = { "Honey", "Beeswax" }, recipe = { Timber = 50, Petal = 20, Herb = 15 },
		upgrade = { 2000, 5000, 12000, 30000 }, color = Color3.fromRGB(235, 185, 70) },
	TreeOfGrowth = { kind = "Work", name = "Tree of Growth", unlock = 3, coins = 12000, capacity = 4, model = "TreeOfGrowth",
		outputs = { "GoldenApple", "GoldenLeaf" }, recipe = { TreeSap = 30, Honey = 50, Beeswax = 20 },
		upgrade = { 2500, 6000, 15000, 36000 } },
	CrystalMine = { kind = "Work", name = "Crystal Mine", unlock = 4, coins = 12000, capacity = 5,
		outputs = { "Crystal", "ArcaneDust" }, recipe = { Stone = 60, IronOre = 20, Gem = 5 },
		upgrade = { 3000, 7500, 18000, 45000 }, color = Color3.fromRGB(140, 110, 220) },
	GrandSmelter = { kind = "Work", name = "Grand Smelter", unlock = 5, coins = 20000, capacity = 6, model = "GiantFurnace",
		outputs = { "IronIngot", "GoldIngot" }, recipe = { Stone = 90, IronOre = 40, GoldOre = 15, Charcoal = 30 },
		upgrade = { 5000, 12500, 30000, 75000 } },
	BlessingAltar = { kind = "Work", name = "Blessing Altar", unlock = 5, coins = 22000, capacity = 5, model = "AltarOfBlessing",
		outputs = { "StarlightShard" }, recipe = { Crystal = 25, ArcaneDust = 15, GoldIngot = 10, Diamond = 3 },
		upgrade = { 4000, 10000, 25000, 60000 } },
	LargeWarehouse = { kind = "Work", name = "Large Warehouse", unlock = 5, coins = 24000, capacity = 6,
		outputs = { "SupplyCrate", "ToolCrate" }, recipe = { Timber = 90, IronIngot = 25, GoldIngot = 8, Beeswax = 15 },
		upgrade = { 4500, 11000, 27000, 65000 }, color = Color3.fromRGB(120, 130, 145) },
}

for id, def in DEFS do
	def.id = id
end

Buildings.ById = DEFS

return Buildings
