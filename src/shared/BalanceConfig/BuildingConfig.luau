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
}

return BuildingConfig