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
EggConfig.EGGS = {
	-- 일반 알: Skeleton, Ghost, SnowMole, Firewood + 레어알 일부
	Egg_Common = {
		name = "일반 알",
		rarity = "일반",
		hatchTime = 30,
		price = 1000,
		maxStock = 5,
		rarityWeights = {
			["일반"] = 85,
			["희귀"] = 15,
		},
		petPool = {
			{ petName = "Skeleton",      petType = "Mining",       rarity = "일반", size = "Small" },
			{ petName = "Ghost",         petType = "Farming",      rarity = "일반", size = "Small" },
			{ petName = "SnowMole",      petType = "Mining",       rarity = "일반", size = "Small" },
			{ petName = "Firewood",      petType = "Buff",         rarity = "일반", size = "Small" },
			{ petName = "Imp",           petType = "Mining",       rarity = "희귀", size = "Medium" },
			{ petName = "ZombieNewbie",  petType = "Farming",      rarity = "희귀", size = "Small" },
		},
	},

	-- 레어 알: Imp, Sunflowie, ZombieNewbie, Yeti + 에픽알 일부
	Egg_Rare = {
		name = "희귀 알",
		rarity = "희귀",
		hatchTime = 60,
		price = 5000,
		maxStock = 3,
		rarityWeights = {
			["일반"] = 30,
			["희귀"] = 55,
			["에픽"] = 15,
		},
		petPool = {
			{ petName = "Ghost",         petType = "Farming",      rarity = "일반", size = "Small" },
			{ petName = "Skeleton",      petType = "Mining",       rarity = "일반", size = "Small" },
			{ petName = "Imp",           petType = "Mining",       rarity = "희귀", size = "Medium" },
			{ petName = "Sunflowie",     petType = "Farming",      rarity = "희귀", size = "Medium" },
			{ petName = "ZombieNewbie",  petType = "Farming",      rarity = "희귀", size = "Small" },
			{ petName = "Yeti",          petType = "Farming",      rarity = "희귀", size = "Big" },
			{ petName = "Zipbit",        petType = "Construction", rarity = "에픽", size = "Small" },
			{ petName = "CrystalGolem",  petType = "Mining",       rarity = "에픽", size = "Medium" },
		},
	},

	-- 에픽 알: Zipbit, CrystalGolem, IceGolem + 전설알 일부
	Egg_Epic = {
		name = "에픽 알",
		rarity = "에픽",
		hatchTime = 120,
		price = 30000,
		maxStock = 2,
		rarityWeights = {
			["희귀"] = 35,
			["에픽"] = 50,
			["전설"] = 15,
		},
		petPool = {
			{ petName = "Imp",           petType = "Mining",       rarity = "희귀", size = "Medium" },
			{ petName = "Sunflowie",     petType = "Farming",      rarity = "희귀", size = "Medium" },
			{ petName = "Zipbit",        petType = "Construction", rarity = "에픽", size = "Small" },
			{ petName = "CrystalGolem",  petType = "Mining",       rarity = "에픽", size = "Medium" },
			{ petName = "IceGolem",      petType = "Mining",       rarity = "에픽", size = "Medium" },
			{ petName = "BabyDragon",    petType = "Mining",       rarity = "전설", size = "Medium" },
		},
	},

	-- 전설 알: BabyDragon, Witch, Lumini + 에픽
	Egg_Legendary = {
		name = "전설 알",
		rarity = "전설",
		hatchTime = 300,
		price = 150000,
		maxStock = 1,
		rarityWeights = {
			["에픽"] = 45,
			["전설"] = 55,
		},
		petPool = {
			{ petName = "Zipbit",        petType = "Construction", rarity = "에픽", size = "Small" },
			{ petName = "CrystalGolem",  petType = "Mining",       rarity = "에픽", size = "Medium" },
			{ petName = "IceGolem",      petType = "Mining",       rarity = "에픽", size = "Medium" },
			{ petName = "BabyDragon",    petType = "Mining",       rarity = "전설", size = "Medium" },
			{ petName = "Witch",         petType = "Farming",      rarity = "전설", size = "Medium" },
			{ petName = "Lumini",        petType = "Farming",      rarity = "전설", size = "Small" },
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
