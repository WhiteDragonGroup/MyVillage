-- Constants.luau
-- 빌드 시스템 상수 및 건물 카탈로그

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local Constants = {}

-- 그리드 설정 (BalanceConfig에서 재노출 — 기존 참조 호환)
Constants.GRID_SIZE = BalanceConfig.GRID_SIZE
Constants.ROTATION_STEP = BalanceConfig.ROTATION_STEP

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
Constants.BUILDINGS = {
	DummyBlock = { name = "더미블록", types = {"장식"}, rarity = "일반" },
	DummyBlock2 = { name = "더미블록2", types = {"장식"}, rarity = "일반" },
	TownHall = { name = "마을회관", types = {"지원"}, rarity = "일반" },
	Garden = { name = "텃밭", types = {"일터"}, rarity = "일반" },
	Mine = { name = "광산", types = {"일터"}, rarity = "희귀" },
	Lab = { name = "연구소", types = {"지원"}, rarity = "에픽" },
	HotSpring = { name = "온천", types = {"쉼터"}, rarity = "희귀" },
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
Constants.DEFAULT_INVENTORY = BalanceConfig.DEFAULT_INVENTORY

return Constants
