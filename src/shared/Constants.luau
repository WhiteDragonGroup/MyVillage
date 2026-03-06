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
Constants.BUILDINGS = {
	TownHall    = { name = "마을회관",  types = {"지원"}, rarity = "일반", collisionSize = Vector3.new(8, 6, 8) },
	Garden      = { name = "텃밭",      types = {"일터"}, rarity = "일반", collisionSize = Vector3.new(6, 2, 6) },
	Mine        = { name = "광산",      types = {"일터"}, rarity = "희귀", collisionSize = Vector3.new(6, 4, 6) },
	Lab         = { name = "연구소",    types = {"지원"}, rarity = "에픽", collisionSize = Vector3.new(8, 8, 8) },
	HotSpring   = { name = "온천",      types = {"쉼터"}, rarity = "희귀", collisionSize = Vector3.new(8, 2, 8) },
	Blacksmith  = { name = "대장간",    types = {"일터"}, rarity = "희귀", collisionSize = Vector3.new(6, 5, 6) },
	Inn         = { name = "여관",      types = {"쉼터"}, rarity = "일반", collisionSize = Vector3.new(7, 5, 6) },
	Fountain    = { name = "분수대",    types = {"장식"}, rarity = "일반", collisionSize = Vector3.new(4, 3, 4) },
	Market      = { name = "시장",      types = {"일터"}, rarity = "일반", collisionSize = Vector3.new(8, 4, 6) },
	Library     = { name = "도서관",    types = {"지원"}, rarity = "희귀", collisionSize = Vector3.new(7, 6, 7) },
	MagicTower  = { name = "마법탑",    types = {"지원"}, rarity = "전설", collisionSize = Vector3.new(5, 12, 5) },
	Brewery     = { name = "양조장",    types = {"일터"}, rarity = "에픽", collisionSize = Vector3.new(6, 5, 8) },
	Pavilion    = { name = "정자",      types = {"쉼터"}, rarity = "에픽", collisionSize = Vector3.new(8, 4, 8) },
	Temple      = { name = "신전",      types = {"지원"}, rarity = "신화", collisionSize = Vector3.new(10, 8, 10) },
	WorldTree   = { name = "세계수",    types = {"쉼터"}, rarity = "신화", collisionSize = Vector3.new(6, 14, 6) },
}

-- 펫 유형
Constants.PetType = {
	Construction = "건설",
}

-- 업그레이드 상태
Constants.UpgradeState = {
	None = "",            -- 일반 상태
	Upgrading = "Upgrading",  -- 수리중
}

-- 펫 카탈로그
Constants.PETS = {
	["초보 건설 슬라임"] = { petType = "Construction", rarity = "일반" },
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
