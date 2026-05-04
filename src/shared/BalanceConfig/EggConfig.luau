-- EggConfig.luau
-- 알 부화 시스템 밸런스 수치

local EggConfig = {}

-- 동시 설치 가능 알 수
EggConfig.MAX_PLACED_EGGS = 3

-- 알 카탈로그
-- hatchTime: 부화 시간 (초)
-- price: 상점 가격 (코인)
-- petPool: 부화 가능한 펫 목록 { {petName, petType, rarity, size, race, weight} }
-- rarityWeights: 등급별 가중치 (합계 100)
-- shopEmergeWeight: 상점에 등장할 확률(가중치)
EggConfig.EGGS = {
	-- 일반 알: Skeleton, Ghost, SnowMole, Firewood + 레어알 일부
	Egg_Common = {
		name = "Common Egg",
		rarity = "Common",
		hatchTime = 30,
		price = 1000,
		maxStock = 5,
		shopEmergeWeight = 70,
		rarityWeights = {
			["Common"] = 85,
			["Rare"] = 15,
		},
		petPool = {
			{ petName = "Skeleton",      petType = "Mining",       rarity = "Common", size = "Small" },
			{ petName = "Ghost",         petType = "Farming",      rarity = "Common", size = "Small" },
			{ petName = "SnowMole",      petType = "Mining",       rarity = "Common", size = "Small" },
			-- { petName = "Firewood",      petType = "Buff",         rarity = "Common", size = "Small" }, -- 명세 미정
			{ petName = "Imp",           petType = "Mining",       rarity = "Rare", size = "Medium" },
			{ petName = "ZombieNewbie",  petType = "Farming",      rarity = "Rare", size = "Small" },
		},
	},

	-- 레어 알: Imp, Sunflowie, ZombieNewbie, Yeti + 에픽알 일부
	Egg_Rare = {
		name = "Rare Egg",
		rarity = "Rare",
		hatchTime = 60,
		price = 5000,
		maxStock = 3,
		shopEmergeWeight = 30,
		rarityWeights = {
			["Common"] = 30,
			["Rare"] = 55,
			["Epic"] = 15,
		},
		petPool = {
			{ petName = "Ghost",         petType = "Farming",      rarity = "Common", size = "Small" },
			{ petName = "Skeleton",      petType = "Mining",       rarity = "Common", size = "Small" },
			{ petName = "Imp",           petType = "Mining",       rarity = "Rare", size = "Medium" },
			{ petName = "Sunflowie",     petType = "Farming",      rarity = "Rare", size = "Medium" },
			{ petName = "ZombieNewbie",  petType = "Farming",      rarity = "Rare", size = "Small" },
			{ petName = "Yeti",          petType = "Farming",      rarity = "Rare", size = "Big" },
			{ petName = "Zipbit",        petType = "Construction", rarity = "Epic", size = "Small" },
			{ petName = "CrystalGolem",  petType = "Mining",       rarity = "Epic", size = "Medium" },
		},
	},

	-- 에픽 알: Zipbit, CrystalGolem, IceGolem + 전설알 일부
	Egg_Epic = {
		name = "Epic Egg",
		rarity = "Epic",
		hatchTime = 120,
		price = 30000,
		maxStock = 2,
		shopEmergeWeight = 10,
		rarityWeights = {
			["Rare"] = 35,
			["Epic"] = 50,
			["Legendary"] = 15,
		},
		petPool = {
			{ petName = "Imp",           petType = "Mining",       rarity = "Rare", size = "Medium" },
			{ petName = "Sunflowie",     petType = "Farming",      rarity = "Rare", size = "Medium" },
			{ petName = "Zipbit",        petType = "Construction", rarity = "Epic", size = "Small" },
			{ petName = "CrystalGolem",  petType = "Mining",       rarity = "Epic", size = "Medium" },
			{ petName = "IceGolem",      petType = "Mining",       rarity = "Epic", size = "Medium" },
			{ petName = "BabyDragon",    petType = "Mining",       rarity = "Legendary", size = "Medium" },
		},
	},

	-- 전설 알: BabyDragon, Witch, Lumini + 에픽
	Egg_Legendary = {
		name = "Legendary Egg",
		rarity = "Legendary",
		hatchTime = 300,
		price = 150000,
		maxStock = 1,
		shopEmergeWeight = 3,
		rarityWeights = {
			["Epic"] = 45,
			["Legendary"] = 55,
		},
		petPool = {
			{ petName = "Zipbit",        petType = "Construction", rarity = "Epic", size = "Small" },
			{ petName = "CrystalGolem",  petType = "Mining",       rarity = "Epic", size = "Medium" },
			{ petName = "IceGolem",      petType = "Mining",       rarity = "Epic", size = "Medium" },
			{ petName = "BabyDragon",    petType = "Mining",       rarity = "Legendary", size = "Medium" },
			{ petName = "Witch",         petType = "Farming",      rarity = "Legendary", size = "Medium" },
			{ petName = "Lumini",        petType = "Farming",      rarity = "Legendary", size = "Small" },
		},
	},
}

-- 선천적 돌연변이 확률 (부화 시)
EggConfig.MUTATION_CHANCE = {
	Shocked = 0,       -- 후천적만
	Gold = 0.005,      -- 0.5%
	Inverted = 0.002,  -- 0.2%
	Celestial = 0,
	Charged = 0,
	Potential = 0,
}

-- 프리미엄 전설 알 돌연변이 배율
EggConfig.PREMIUM_MUTATION_MULTIPLIER = 10

return EggConfig
