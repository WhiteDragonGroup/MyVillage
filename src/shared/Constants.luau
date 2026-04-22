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
	Work = "일터",
	Rest = "쉼터",
	Support = "지원",
	Decoration = "장식",
}

-- 건물 등급
Constants.BuildingRarity = {
	Common = "일반",
	Rare = "희귀",
	Epic = "에픽",
	Legendary = "전설",
	Mythic = "신화",
}

-- 등급별 색상
Constants.RARITY_COLORS = {
	["일반"] = Color3.fromRGB(180, 180, 180),
	["희귀"] = Color3.fromRGB(0, 150, 255),
	["에픽"] = Color3.fromRGB(180, 0, 255),
	["전설"] = Color3.fromRGB(255, 180, 0),
	["신화"] = Color3.fromRGB(255, 50, 50),
}

-- 건물 카탈로그
-- collisionSize: 충돌 판정용 고정 사이즈 (모델 실제 크기와 무관, 레벨 변경에도 불변)
-- icon: 빌드모드 인벤토리 아이콘 이미지 (rbxassetid://숫자)
-- TODO: 각 건물별 아이콘 이미지 Asset ID를 icon 필드에 입력해주세요
Constants.BUILDINGS = {
	TownHall    = { name = "마을회관",  types = {"지원"}, rarity = "일반", collisionSize = Vector3.new(8, 6, 8), icon = "" },
	Garden      = { name = "텃밭",      types = {"일터"}, rarity = "일반", collisionSize = Vector3.new(6, 2, 6), workTypes = {"농사"}, icon = "" },
	Mine        = { name = "광산",      types = {"일터"}, rarity = "희귀", collisionSize = Vector3.new(6, 4, 6), workTypes = {"채굴"}, icon = "" },
	Lab         = { name = "연구소",    types = {"지원"}, rarity = "에픽", collisionSize = Vector3.new(8, 8, 8), icon = "" },
	HotSpring   = { name = "온천",      types = {"쉼터"}, rarity = "희귀", collisionSize = Vector3.new(8, 2, 8), icon = "" },
	Blacksmith  = { name = "대장간",    types = {"일터"}, rarity = "희귀", collisionSize = Vector3.new(6, 5, 6), workTypes = {"건설"}, icon = "" },
	Inn         = { name = "여관",      types = {"쉼터"}, rarity = "일반", collisionSize = Vector3.new(7, 5, 6), icon = "" },
	Fountain    = { name = "분수대",    types = {"장식"}, rarity = "일반", collisionSize = Vector3.new(4, 3, 4), icon = "" },
	Market      = { name = "시장",      types = {"일터"}, rarity = "일반", collisionSize = Vector3.new(8, 4, 6), workTypes = {"농사", "채굴"}, icon = "" },
	Library     = { name = "도서관",    types = {"지원"}, rarity = "희귀", collisionSize = Vector3.new(7, 6, 7), icon = "" },
	MagicTower  = { name = "마법탑",    types = {"지원"}, rarity = "전설", collisionSize = Vector3.new(5, 12, 5), icon = "" },
	Brewery     = { name = "양조장",    types = {"일터"}, rarity = "에픽", collisionSize = Vector3.new(6, 5, 8), workTypes = {"농사"}, icon = "" },
	Pavilion    = { name = "정자",      types = {"쉼터"}, rarity = "에픽", collisionSize = Vector3.new(8, 4, 8), icon = "" },
	Temple      = { name = "신전",      types = {"지원"}, rarity = "신화", collisionSize = Vector3.new(10, 8, 10), icon = "" },
	WorldTree   = { name = "세계수",    types = {"쉼터"}, rarity = "신화", collisionSize = Vector3.new(6, 14, 6), icon = "" },
	Campfire    = { name = "캠프파이어", types = {"쉼터"}, rarity = "일반", collisionSize = Vector3.new(4, 3, 4), icon = "" },
	PotionCafe  = { name = "포션카페",  types = {"지원"}, rarity = "희귀", collisionSize = Vector3.new(6, 5, 6), icon = "" },
	AltarOfBlessing = { name = "축복의 제단", types = {"지원"}, rarity = "전설", collisionSize = Vector3.new(8, 6, 8), icon = "" },
	Farm        = { name = "농장",      types = {"일터"}, rarity = "일반", collisionSize = Vector3.new(8, 3, 8), workTypes = {"농사"}, icon = "" },
	Laboratory  = { name = "연구소",    types = {"지원"}, rarity = "에픽", collisionSize = Vector3.new(8, 8, 8), icon = "" },
	GiantFurnace = { name = "거대 용광로", types = {"일터"}, rarity = "에픽", collisionSize = Vector3.new(8, 8, 8), workTypes = {"채굴"}, icon = "" },
	TreeOfGrowth = { name = "성장의 나무", types = {"쉼터"}, rarity = "전설", collisionSize = Vector3.new(6, 12, 6), icon = "" },
	ClockTower  = { name = "시계탑",    types = {"장식"}, rarity = "희귀", collisionSize = Vector3.new(6, 10, 6), icon = "" },
}

-- 펫 유형
Constants.PetType = {
	Construction = "건설",
	Farming = "농사",
	Mining = "채굴",
	Buff = "버프",
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
	Human = "인간", Plant = "식물", Dinosaur = "공룡", Bug = "벌레",
	Robot = "로봇", Golem = "골렘", Skeleton = "해골",
}

-- 업그레이드 상태
Constants.UpgradeState = {
	None = "",            -- 일반 상태
	Upgrading = "Upgrading",  -- 수리중
}

-- 펫 카탈로그
Constants.PETS = {
	-- 일반
	["FarmerNewbie"]  = { name = "농부 뉴비",      petTypes = {"Farming", "Construction"},  rarity = "일반", size = "Small" },
	["Skeleton"]      = { name = "스켈레톤",        petTypes = {"Mining", "Construction"},   rarity = "일반", size = "Small" },
	["Ghost"]         = { name = "유령",            petTypes = {"Farming", "Buff"},          rarity = "일반", size = "Small" },
	["SnowMole"]      = { name = "눈 두더지",       petTypes = {"Mining"},                   rarity = "일반", size = "Small" },
	["Firewood"]      = { name = "장작 필요",       petTypes = {"Buff"},                     rarity = "일반" },
	-- 레어
	["Imp"]           = { name = "임프",            petTypes = {"Mining", "Construction", "Buff"}, rarity = "희귀", size = "Medium" },
	["Sunflowie"]     = { name = "썬플라워",        petTypes = {"Farming", "Buff"},          rarity = "희귀", size = "Medium" },
	["ZombieNewbie"]  = { name = "좀비 뉴비",       petTypes = {"Farming", "Construction"},  rarity = "희귀", size = "Small" },
	["Yeti"]          = { name = "예티",            petTypes = {"Farming", "Construction"},  rarity = "희귀", size = "Big" },
	-- 에픽
	["Zipbit"]        = { name = "집비트",          petTypes = {"Construction", "Buff"},     rarity = "에픽", size = "Small" },
	["CrystalGolem"]  = { name = "크리스탈 골렘",   petTypes = {"Mining", "Construction"},   rarity = "에픽", size = "Medium" },
	["IceGolem"]      = { name = "아이스 골렘",     petTypes = {"Mining", "Construction"},   rarity = "에픽", size = "Medium" },
	-- 전설
	["BabyDragon"]    = { name = "베이비 드래곤",   petTypes = {"Mining", "Construction", "Buff"}, rarity = "전설", size = "Medium" },
	["Witch"]         = { name = "마녀",            petTypes = {"Farming"},                  rarity = "전설", size = "Medium" },
	["Lumini"]        = { name = "루미니",          petTypes = {"Farming", "Buff"},          rarity = "전설", size = "Small" },
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
	Shocked = "충전된",
	Gold = "골드",
	Inverted = "반전된",
	Celestial = "셀레스티얼",
	Charged = "차지드",
	Potential = "포텐셜",
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
