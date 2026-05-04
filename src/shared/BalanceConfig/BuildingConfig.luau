-- BuildingConfig.luau
-- 건물·배치 시스템 밸런스 수치
-- 참조: PlacementClient / GridSnap / DragHandler / InventoryManager

local BuildingConfig = {}

-- GRID_SIZE: 건물 배치 시 스냅 단위 (stud)
--   작을수록 정밀 배치, 클수록 빠른 배치
BuildingConfig.GRID_SIZE = 0.1

-- ROTATION_STEP: 건물 회전 단위 (도)
--   90 = 4방향, 45 = 8방향
BuildingConfig.ROTATION_STEP = 90

-- PLACEMENT_PREVIEW_DISTANCE: 새 건물 배치 시 캐릭터 앞에 프리뷰가 뜨는 거리 (stud)
BuildingConfig.PLACEMENT_PREVIEW_DISTANCE = 10

-- DEFAULT_INVENTORY: 플레이어 최초 접속 시 기본 지급 건물
--   itemName = Items 폴더 내 템플릿 이름, count = 지급 수량
BuildingConfig.DEFAULT_INVENTORY = {
	{ itemName = "Mine", count = 2 },
	{ itemName = "HotSpring", count = 2 },
}

-- 광산/농장 수입 시스템
-- 펫이 일하면 돈이 누적되고 한도까지 채움. 플레이어가 건물에 닿으면 수확.
-- Mine: 부 수입원 (Farm 절반) + 매우 낮은 확률로 보석
-- Farm: 주 수입원 (Mine의 ~2배), 보석 없음
BuildingConfig.WORK_INCOME = {
	Mine = { rate = 1, gemChance = 0.02 },  -- 초당 1코인, 2% 보석 확률
	Farm = { rate = 2, gemChance = 0 },     -- 초당 2코인
}
BuildingConfig.WORK_CAPACITY_BY_LEVEL = {
	[1] = 1000,
	[2] = 2500,
	[3] = 5000,
	[4] = 10000,
	[5] = 20000,
}

return BuildingConfig