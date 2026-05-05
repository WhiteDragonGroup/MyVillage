-- Constants.luau
-- 빌드 시스템 상수 및 건물 카탈로그

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local Constants = {}

-- 그리드 설정 (BalanceConfig에서 재노출 — 기존 참조 호환)
Constants.GRID_SIZE = BalanceConfig.Building.GRID_SIZE
Constants.ROTATION_STEP = BalanceConfig.Building.ROTATION_STEP

-- 건물 유형
Constants.BuildingType = {
	Work = "Work",
	Rest = "Rest",
	Support = "Support",
	Decoration = "Decoration",
}

-- 건물 등급
Constants.BuildingRarity = {
	Common = "Common",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Mythic = "Mythic",
}

-- 등급별 색상
Constants.RARITY_COLORS = {
	["Common"] = Color3.fromRGB(180, 180, 180),
	["Rare"] = Color3.fromRGB(0, 150, 255),
	["Epic"] = Color3.fromRGB(180, 0, 255),
	["Legendary"] = Color3.fromRGB(255, 180, 0),
	["Mythic"] = Color3.fromRGB(255, 50, 50),
}

-- 건물 카탈로그
-- collisionSize: 충돌 판정용 고정 사이즈 (모델 실제 크기와 무관, 레벨 변경에도 불변)
--
-- icon: 레벨별 아이콘 테이블 { [level] = "rbxassetid://..." }
--   레벨 1~5까지 각각 다른 아이콘 지정 가능.
--   비어있는 레벨은 가까운 레벨 아이콘으로 자동 폴백 (Constants.getBuildingIcon 참고).
--
-- 작성 예시 (Mine 참고):
--   Mine = { ...,
--     icon = {
--       [1] = "rbxassetid://1234567890",  -- Lv.1 외형
--       [2] = "rbxassetid://1234567891",  -- Lv.2 외형
--       [3] = "rbxassetid://1234567892",  -- Lv.3 외형 (생략 시 Lv.2로 폴백)
--       [4] = "",                          -- 비워두면 Lv.3으로 폴백
--       [5] = "rbxassetid://1234567893",  -- Lv.5 (최대 레벨)
--     },
--   }
--
-- 사용법: Constants.getBuildingIcon("Mine", 3) → 해당 레벨 아이콘 반환
Constants.BUILDINGS = {
	ClockTower = {
		name = "Clock Tower", types = {"Decoration"}, rarity = "Common",
		collisionSize = Vector3.new(6, 10, 6),
		icon = {
			[1] = "rbxassetid://0", -- TODO: ClockTower Lv.1
			[2] = "rbxassetid://0", -- TODO: ClockTower Lv.2
			[3] = "rbxassetid://0", -- TODO: ClockTower Lv.3
			[4] = "rbxassetid://0", -- TODO: ClockTower Lv.4
			[5] = "rbxassetid://0", -- TODO: ClockTower Lv.5
		},
	},
	Farm = {
		name = "Farm", types = {"Work"}, rarity = "Common",
		collisionSize = Vector3.new(6, 3, 6), workTypes = {"Farming"},
		icon = {
			[1] = "rbxassetid://0", -- TODO: Farm Lv.1
			[2] = "rbxassetid://0", -- TODO: Farm Lv.2
			[3] = "rbxassetid://0", -- TODO: Farm Lv.3
			[4] = "rbxassetid://0", -- TODO: Farm Lv.4
			[5] = "rbxassetid://0", -- TODO: Farm Lv.5
		},
	},
	Mine = {
		name = "Mine", types = {"Work"}, rarity = "Common",
		collisionSize = Vector3.new(6, 4, 6), workTypes = {"Mining"},
		icon = {
			[1] = "rbxassetid://0", -- TODO: Mine Lv.1
			[2] = "rbxassetid://0", -- TODO: Mine Lv.2
			[3] = "rbxassetid://0", -- TODO: Mine Lv.3
			[4] = "rbxassetid://0", -- TODO: Mine Lv.4
			[5] = "rbxassetid://0", -- TODO: Mine Lv.5
		},
	},
	Campfire = {
		name = "Campfire", types = {"Rest"}, rarity = "Rare",
		collisionSize = Vector3.new(4, 3, 4),
		icon = {
			[1] = "rbxassetid://0", -- TODO: Campfire Lv.1
			[2] = "rbxassetid://0", -- TODO: Campfire Lv.2
			[3] = "rbxassetid://0", -- TODO: Campfire Lv.3
			[4] = "rbxassetid://0", -- TODO: Campfire Lv.4
			[5] = "rbxassetid://0", -- TODO: Campfire Lv.5
		},
	},
	PotionCafe = {
		name = "Potion Cafe", types = {"Rest"}, rarity = "Epic",
		collisionSize = Vector3.new(6, 5, 6),
		icon = {
			[1] = "rbxassetid://0", -- TODO: PotionCafe Lv.1
			[2] = "rbxassetid://0", -- TODO: PotionCafe Lv.2
			[3] = "rbxassetid://0", -- TODO: PotionCafe Lv.3
			[4] = "rbxassetid://0", -- TODO: PotionCafe Lv.4
			[5] = "rbxassetid://0", -- TODO: PotionCafe Lv.5
		},
	},
	HotSpring = {
		name = "Hot Spring", types = {"Rest"}, rarity = "Legendary",
		collisionSize = Vector3.new(8, 2, 8),
		icon = {
			[1] = "rbxassetid://0", -- TODO: HotSpring Lv.1
			[2] = "rbxassetid://0", -- TODO: HotSpring Lv.2
			[3] = "rbxassetid://0", -- TODO: HotSpring Lv.3
			[4] = "rbxassetid://0", -- TODO: HotSpring Lv.4
			[5] = "rbxassetid://0", -- TODO: HotSpring Lv.5
		},
	},
	TreeOfGrowth = {
		name = "Tree of Growth", types = {"Rest"}, rarity = "Mythic",
		collisionSize = Vector3.new(6, 12, 6),
		icon = {
			[1] = "rbxassetid://0", -- TODO: TreeOfGrowth Lv.1
			[2] = "rbxassetid://0", -- TODO: TreeOfGrowth Lv.2
			[3] = "rbxassetid://0", -- TODO: TreeOfGrowth Lv.3
			[4] = "rbxassetid://0", -- TODO: TreeOfGrowth Lv.4
			[5] = "rbxassetid://0", -- TODO: TreeOfGrowth Lv.5
		},
	},
	AltarOfBlessing = {
		name = "Altar of Blessing", types = {"Rest"}, rarity = "Mythic",
		collisionSize = Vector3.new(8, 6, 8),
		icon = {
			[1] = "rbxassetid://0", -- TODO: AltarOfBlessing Lv.1
			[2] = "rbxassetid://0", -- TODO: AltarOfBlessing Lv.2
			[3] = "rbxassetid://0", -- TODO: AltarOfBlessing Lv.3
			[4] = "rbxassetid://0", -- TODO: AltarOfBlessing Lv.4
			[5] = "rbxassetid://0", -- TODO: AltarOfBlessing Lv.5
		},
	},
	GiantFurnace = {
		name = "Giant Furnace", types = {"Support"}, rarity = "Epic",
		collisionSize = Vector3.new(8, 8, 8),
		icon = {
			[1] = "rbxassetid://0", -- TODO: GiantFurnace Lv.1
			[2] = "rbxassetid://0", -- TODO: GiantFurnace Lv.2
			[3] = "rbxassetid://0", -- TODO: GiantFurnace Lv.3
			[4] = "rbxassetid://0", -- TODO: GiantFurnace Lv.4
			[5] = "rbxassetid://0", -- TODO: GiantFurnace Lv.5
		},
	},
	Laboratory = {
		name = "Laboratory", types = {"Support"}, rarity = "Legendary",
		collisionSize = Vector3.new(8, 8, 8),
		icon = {
			[1] = "rbxassetid://0", -- TODO: Laboratory Lv.1
			[2] = "rbxassetid://0", -- TODO: Laboratory Lv.2
			[3] = "rbxassetid://0", -- TODO: Laboratory Lv.3
			[4] = "rbxassetid://0", -- TODO: Laboratory Lv.4
			[5] = "rbxassetid://0", -- TODO: Laboratory Lv.5
		},
	},
}

-- 레벨별 아이콘 조회 헬퍼. 해당 레벨 비어있으면 가까운 레벨로 폴백.
function Constants.getBuildingIcon(itemName: string, level: number?): string
	local info = Constants.BUILDINGS[itemName]
	if not info or typeof(info.icon) ~= "table" then return "" end
	level = level or 1
	-- 정확한 레벨
	if info.icon[level] and info.icon[level] ~= "" then
		return info.icon[level]
	end
	-- 가까운 낮은 레벨로 폴백
	for l = level, 1, -1 do
		if info.icon[l] and info.icon[l] ~= "" then
			return info.icon[l]
		end
	end
	-- 그 다음 높은 레벨로 폴백
	for l = level + 1, 5 do
		if info.icon[l] and info.icon[l] ~= "" then
			return info.icon[l]
		end
	end
	return ""
end

-- 펫 유형
Constants.PetType = {
	Construction = "Construction",
	Farming = "Farming",
	Mining = "Mining",
	Buff = "Buff",
}

-- 펫 행동 상태
Constants.PetState = {
	Idle = "Idle",
	Working = "Working",
	Fatigued = "Fatigued",
	Resting = "Resting",
	Wandering = "Wandering",
	Chatting = "Chatting",
	Sleeping = "Sleeping",
	Assigned = "Assigned",
}

-- 펫 사이즈
Constants.PetSize = {
	Small = "Small",
	Medium = "Medium",
	Big = "Big",
	Huge = "Huge",
	Ultra = "Ultra",
}

-- 펫 종족
Constants.PetRace = {
	Human = "Human", Plant = "Plant", Dinosaur = "Dinosaur", Bug = "Bug",
	Robot = "Robot", Golem = "Golem", Skeleton = "Skeleton",
}

-- 업그레이드 상태
Constants.UpgradeState = {
	None = "",            -- 일반 상태
	Upgrading = "Upgrading",  -- 수리중
}

-- 펫 카탈로그
Constants.PETS = {
	-- 일반
	["FarmerNewbie"]  = { name = "Farmer Newbie",      petTypes = {"Farming", "Construction"},  rarity = "Common", size = "Small" },
	["Skeleton"]      = { name = "Skeleton",        petTypes = {"Mining", "Construction"},   rarity = "Common", size = "Small" },
	["Ghost"]         = { name = "Ghost",            petTypes = {"Farming", "Buff"},          rarity = "Common", size = "Small" },
	["SnowMole"]      = { name = "Snow Mole",       petTypes = {"Mining"},                   rarity = "Common", size = "Small" },
	-- ["Firewood"]      = { name = "Firewood",       petTypes = {"Buff"},                     rarity = "Common" }, -- 명세 미정
	-- 레어
	["Imp"]           = { name = "Imp",            petTypes = {"Mining", "Construction", "Buff"}, rarity = "Rare", size = "Medium" },
	["Sunflowie"]     = { name = "Sunflowie",        petTypes = {"Farming", "Buff"},          rarity = "Rare", size = "Medium" },
	["ZombieNewbie"]  = { name = "Zombie Newbie",       petTypes = {"Farming", "Construction"},  rarity = "Rare", size = "Small" },
	["Yeti"]          = { name = "Yeti",            petTypes = {"Farming", "Construction"},  rarity = "Rare", size = "Big" },
	-- 에픽
	["Zipbit"]        = { name = "Zipbit",          petTypes = {"Construction", "Buff"},     rarity = "Epic", size = "Small" },
	["CrystalGolem"]  = { name = "Crystal Golem",   petTypes = {"Mining", "Construction"},   rarity = "Epic", size = "Medium" },
	["IceGolem"]      = { name = "Ice Golem",     petTypes = {"Mining", "Construction"},   rarity = "Epic", size = "Medium" },
	-- 전설
	["BabyDragon"]    = { name = "Baby Dragon",   petTypes = {"Mining", "Construction", "Buff"}, rarity = "Legendary", size = "Medium" },
	["Witch"]         = { name = "Witch",            petTypes = {"Farming"},                  rarity = "Legendary", size = "Medium" },
	["Lumini"]        = { name = "Lumini",          petTypes = {"Farming", "Buff"},          rarity = "Legendary", size = "Small" },
}

-- ============================================================
-- BUFF TYPES: Pet buffs (replaces old Mutation system)
-- Common buffs (above X line) + Unique buffs (below X line)
-- ============================================================
Constants.BuffType = {
	-- Common buffs
	Vitality = "Vitality",
	Haste = "Haste",
	Blessing = "Blessing",
	Fortune = "Fortune",
	Satiation = "Satiation",
	Energy = "Energy",
	Serenity = "Serenity",
	-- Unique buffs (specific pets only)
	AllysEncouragement = "AllysEncouragement",
	GhostsSong = "GhostsSong",
	Charge = "Charge",
	DemonicPower = "DemonicPower",
	DragonsPower = "DragonsPower",
	BurningHeart = "BurningHeart",
}

Constants.BUFF_NAMES = {
	Vitality = "Vitality",
	Haste = "Haste",
	Blessing = "Blessing",
	Fortune = "Fortune",
	Satiation = "Satiation",
	Energy = "Energy",
	Serenity = "Serenity",
	AllysEncouragement = "Ally's Encouragement",
	GhostsSong = "Ghost's Song",
	Charge = "Charge",
	DemonicPower = "Demonic Power",
	DragonsPower = "Dragon's Power",
	BurningHeart = "Burning Heart",
}

Constants.BUFF_DESCRIPTIONS = {
	Vitality = "Your pet is overflowing with vitality! Work efficiency increases by n%.",
	Haste = "Pet's steps feel lighter! Reach your destination n% faster.",
	Blessing = "A powerful blessing has taken hold! Work efficiency increases by n%.",
	Fortune = "Luck has increased! Pet is n% more likely to discover gems while mining.",
	Satiation = "Well-fed and ready to go! Work efficiency increases by n%.",
	Energy = "Energy is overflowing! Your pet can keep working without sleep.",
	Serenity = "Your pet feels at peace. The pet can work longer before rest.",
	AllysEncouragement = "Your allies are cheering you on! You feel energized! Work efficiency increases by n%!",
	GhostsSong = "A mysterious song echoes from somewhere... your focus sharpens! Work efficiency increases by n%!",
	Charge = "Fully charged and ready to go! You feel unstoppable! Work efficiency increases by n%!",
	DemonicPower = "A forbidden power surges through you... overwhelming strength fills your body! Work efficiency increases by n%!",
	DragonsPower = "The mighty power of a dragon surrounds you! Work efficiency increases by n%!",
	BurningHeart = "Your heart burns with passion! Energy overflows within you! Work efficiency increases by n%!",
}

-- ============================================================
-- BUFF COLORS: Replace with desired colors
-- ============================================================
Constants.BUFF_COLORS = {
	Vitality = Color3.fromRGB(255, 100, 100),
	Haste = Color3.fromRGB(100, 200, 255),
	Blessing = Color3.fromRGB(255, 215, 0),
	Fortune = Color3.fromRGB(100, 255, 150),
	Satiation = Color3.fromRGB(200, 150, 100),
	Energy = Color3.fromRGB(255, 255, 100),
	Serenity = Color3.fromRGB(150, 200, 255),
	AllysEncouragement = Color3.fromRGB(255, 180, 100),
	GhostsSong = Color3.fromRGB(180, 200, 255),
	Charge = Color3.fromRGB(255, 255, 100),
	DemonicPower = Color3.fromRGB(180, 50, 255),
	DragonsPower = Color3.fromRGB(255, 100, 50),
	BurningHeart = Color3.fromRGB(255, 50, 50),
}

-- ============================================================
-- BUFF ICONS: Replace "" with "rbxassetid://NUMBER"
-- ============================================================
Constants.BUFF_ICONS = {
	Vitality = "",
	Haste = "",
	Blessing = "",
	Fortune = "",
	Satiation = "",
	Energy = "",
	Serenity = "",
	AllysEncouragement = "",
	GhostsSong = "",
	Charge = "",
	DemonicPower = "",
	DragonsPower = "",
	BurningHeart = "",
}

-- Legacy compatibility (old mutation references)
Constants.MutationType = Constants.BuffType
Constants.MUTATION_NAMES = Constants.BUFF_NAMES
Constants.MUTATION_COLORS = Constants.BUFF_COLORS

-- 하이라이트 색상
Constants.HIGHLIGHT_COLORS = {
	Hover = Color3.fromRGB(255, 255, 255),     -- 흰색
	Selected = Color3.fromRGB(0, 255, 0),      -- 초록
	Collision = Color3.fromRGB(255, 0, 0),     -- 빨강
	Moving = Color3.fromRGB(0, 120, 255),      -- 파란색 (이동 중)
}

-- 빌드 상태
Constants.BuildState = {
	Idle = "Idle",
	BuildMode = "BuildMode",
	Selected = "Selected",
	PlacingNew = "PlacingNew",
	Moving = "Moving",
}

-- 시작 인벤토리 (BalanceConfig에서 재노출 — 기존 참조 호환)
Constants.DEFAULT_INVENTORY = BalanceConfig.Building.DEFAULT_INVENTORY

-- 건물 종류별 충돌 사이즈 조회
function Constants.getCollisionSize(itemName: string): Vector3
	local info = Constants.BUILDINGS[itemName]
	if info and info.collisionSize then
		return info.collisionSize
	end
	return Vector3.new(4, 4, 4) -- 폴백 기본값
end

return Constants
