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

-- 광산/농장 capacity 시스템 (배율은 1 고정, 레벨에 따라 수용 한도 증가)
-- 레벨업할 때마다 더 많은 코인을 모을 수 있음. 한도 차면 더 안 차고, 수확하면 비워짐.
-- TODO: 실제 income 로직(수확 트리거, 시간당 코인 누적, UI 표시)은 미구현
BuildingConfig.WORK_INCOME_RATE = 1   -- 초당 코인 (배율 1 고정)
BuildingConfig.WORK_CAPACITY_BY_LEVEL = {
	[1] = 100,
	[2] = 250,
	[3] = 500,
	[4] = 1000,
	[5] = 2000,
}

return BuildingConfig