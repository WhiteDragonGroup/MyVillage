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
	Egg_Common = {
		name = "일반 알",
		rarity = "일반",
		hatchTime = 30,
		price = 100,
		maxStock = 5,
		rarityWeights = {
			["일반"] = 90,
			["희귀"] = 10,
		},
		petPool = {
			{ petName = "건설 슬라임",   petType = "Construction", rarity = "일반", size = "Small", race = "골렘" },
			{ petName = "농사 슬라임",   petType = "Farming",      rarity = "일반", size = "Small", race = "식물" },
			{ petName = "채굴 슬라임",   petType = "Mining",       rarity = "일반", size = "Small", race = "골렘" },
			{ petName = "푸른 건설꾼",   petType = "Construction", rarity = "희귀", size = "Medium", race = "인간" },
		},
	},

	Egg_Rare = {
		name = "희귀 알",
		rarity = "희귀",
		hatchTime = 60,
		price = 300,
		maxStock = 3,
		rarityWeights = {
			["일반"] = 40,
			["희귀"] = 45,
			["에픽"] = 15,
		},
		petPool = {
			{ petName = "건설 슬라임",   petType = "Construction", rarity = "일반", size = "Small", race = "골렘" },
			{ petName = "푸른 건설꾼",   petType = "Construction", rarity = "희귀", size = "Medium", race = "인간" },
			{ petName = "농사 요정",     petType = "Farming",      rarity = "희귀", size = "Small", race = "식물" },
			{ petName = "채굴 드워프",   petType = "Mining",       rarity = "희귀", size = "Medium", race = "인간" },
			{ petName = "마법 건설사",   petType = "Construction", rarity = "에픽", size = "Medium", race = "로봇" },
		},
	},

	Egg_Epic = {
		name = "에픽 알",
		rarity = "에픽",
		hatchTime = 120,
		price = 800,
		maxStock = 2,
		rarityWeights = {
			["희귀"] = 40,
			["에픽"] = 45,
			["전설"] = 15,
		},
		petPool = {
			{ petName = "푸른 건설꾼",   petType = "Construction", rarity = "희귀", size = "Medium", race = "인간" },
			{ petName = "마법 건설사",   petType = "Construction", rarity = "에픽", size = "Medium", race = "로봇" },
			{ petName = "황금 농부",     petType = "Farming",      rarity = "에픽", size = "Big", race = "골렘" },
			{ petName = "용암 채굴꾼",   petType = "Mining",       rarity = "에픽", size = "Big", race = "공룡" },
			{ petName = "전설의 기사",   petType = "Construction", rarity = "전설", size = "Big", race = "인간" },
		},
	},

	Egg_Legendary = {
		name = "전설 알",
		rarity = "전설",
		hatchTime = 300,
		price = 2000,
		maxStock = 1,
		rarityWeights = {
			["에픽"] = 40,
			["전설"] = 45,
			["신화"] = 15,
		},
		petPool = {
			{ petName = "마법 건설사",   petType = "Construction", rarity = "에픽", size = "Medium", race = "로봇" },
			{ petName = "전설의 기사",   petType = "Construction", rarity = "전설", size = "Big", race = "인간" },
			{ petName = "세계수 정령",   petType = "Farming",      rarity = "전설", size = "Huge", race = "식물" },
			{ petName = "고대 골렘",     petType = "Mining",       rarity = "전설", size = "Huge", race = "골렘" },
			{ petName = "신화의 드래곤", petType = "Buff",         rarity = "신화", size = "Ultra", race = "공룡" },
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
