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
-- icon: 빌드모드 인벤토리 아이콘 이미지 (rbxassetid://숫자)
-- TODO: 각 건물별 아이콘 이미지 Asset ID를 icon 필드에 입력해주세요
Constants.BUILDINGS = {
	TownHall    = { name = "Town Hall",  types = {"Support"}, rarity = "Common", collisionSize = Vector3.new(8, 6, 8), icon = "" },
	Garden      = { name = "Garden",      types = {"Work"}, rarity = "Common", collisionSize = Vector3.new(6, 2, 6), workTypes = {"Farming"}, icon = "" },
	Mine        = { name = "Mine",      types = {"Work"}, rarity = "Rare", collisionSize = Vector3.new(6, 4, 6), workTypes = {"Mining"}, icon = "" },
	Lab         = { name = "Laboratory",    types = {"Support"}, rarity = "Epic", collisionSize = Vector3.new(8, 8, 8), icon = "" },
	HotSpring   = { name = "Hot Spring",      types = {"Rest"}, rarity = "Rare", collisionSize = Vector3.new(8, 2, 8), icon = "" },
	Blacksmith  = { name = "Blacksmith",    types = {"Work"}, rarity = "Rare", collisionSize = Vector3.new(6, 5, 6), workTypes = {"Construction"}, icon = "" },
	Inn         = { name = "Inn",      types = {"Rest"}, rarity = "Common", collisionSize = Vector3.new(7, 5, 6), icon = "" },
	Fountain    = { name = "Fountain",    types = {"Decoration"}, rarity = "Common", collisionSize = Vector3.new(4, 3, 4), icon = "" },
	Market      = { name = "Market",      types = {"Work"}, rarity = "Common", collisionSize = Vector3.new(8, 4, 6), workTypes = {"Farming", "Mining"}, icon = "" },
	Library     = { name = "Library",    types = {"Support"}, rarity = "Rare", collisionSize = Vector3.new(7, 6, 7), icon = "" },
	MagicTower  = { name = "Magic Tower",    types = {"Support"}, rarity = "Legendary", collisionSize = Vector3.new(5, 12, 5), icon = "" },
	Brewery     = { name = "Brewery",    types = {"Work"}, rarity = "Epic", collisionSize = Vector3.new(6, 5, 8), workTypes = {"Farming"}, icon = "" },
	Pavilion    = { name = "Pavilion",      types = {"Rest"}, rarity = "Epic", collisionSize = Vector3.new(8, 4, 8), icon = "" },
	Temple      = { name = "Temple",      types = {"Support"}, rarity = "Mythic", collisionSize = Vector3.new(10, 8, 10), icon = "" },
	WorldTree   = { name = "World Tree",    types = {"Rest"}, rarity = "Mythic", collisionSize = Vector3.new(6, 14, 6), icon = "" },
	Campfire    = { name = "Campfire", types = {"Rest"}, rarity = "Common", collisionSize = Vector3.new(4, 3, 4), icon = "" },
	PotionCafe  = { name = "Potion Cafe",  types = {"Support"}, rarity = "Rare", collisionSize = Vector3.new(6, 5, 6), icon = "" },
	AltarOfBlessing = { name = "Altar of Blessing", types = {"Support"}, rarity = "Legendary", collisionSize = Vector3.new(8, 6, 8), icon = "" },
	Farm        = { name = "Farm",      types = {"Work"}, rarity = "Common", collisionSize = Vector3.new(8, 3, 8), workTypes = {"Farming"}, icon = "" },
	Laboratory  = { name = "Laboratory",    types = {"Support"}, rarity = "Epic", collisionSize = Vector3.new(8, 8, 8), icon = "" },
	GiantFurnace = { name = "Giant Furnace", types = {"Work"}, rarity = "Epic", collisionSize = Vector3.new(8, 8, 8), workTypes = {"Mining"}, icon = "" },
	TreeOfGrowth = { name = "Tree of Growth", types = {"Rest"}, rarity = "Legendary", collisionSize = Vector3.new(6, 12, 6), icon = "" },
	ClockTower  = { name = "Clock Tower",    types = {"Decoration"}, rarity = "Rare", collisionSize = Vector3.new(6, 10, 6), icon = "" },
}

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
	["Firewood"]      = { name = "Firewood",       petTypes = {"Buff"},                     rarity = "Common" },
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

-- 돌연변이 타입
Constants.MutationType = {
	Shocked = "Shocked",     -- 충전된
	Gold = "Gold",           -- 골드
	Inverted = "Inverted",   -- 반전된
	Celestial = "Celestial", -- 셀레스티얼
	Charged = "Charged",     -- 차지드
	Potential = "Potential",  -- 포텐셜
}

-- 돌연변이 표시명
Constants.MUTATION_NAMES = {
	Shocked = "Shocked",
	Gold = "Gold",
	Inverted = "Inverted",
	Celestial = "Celestial",
	Charged = "Charged",
	Potential = "Potential",
}

-- 돌연변이 색상 (UI/VFX 참조)
Constants.MUTATION_COLORS = {
	Shocked = Color3.fromRGB(100, 200, 255),
	Gold = Color3.fromRGB(255, 215, 0),
	Inverted = Color3.fromRGB(180, 50, 255),
	Celestial = Color3.fromRGB(200, 230, 255),
	Charged = Color3.fromRGB(255, 255, 100),
	Potential = Color3.fromRGB(100, 255, 150),
}

-- 하이라이트 색상
Constants.HIGHLIGHT_COLORS = {
	Hover = Color3.fromRGB(255, 255, 255),     -- 흰색
	Selected = Color3.fromRGB(0, 255, 0),      -- 초록
	Collision = Color3.fromRGB(255, 0, 0),     -- 빨강
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
