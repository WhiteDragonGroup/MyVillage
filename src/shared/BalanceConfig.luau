-- BalanceConfig.luau
-- 게임플레이 밸런스 수치 전용 모듈
-- 여기 숫자만 바꾸면 게임 전체에 즉시 반영됨
-- 구조적 상수(건물 카탈로그, enum 등)는 Constants.luau에 유지

local BalanceConfig = {}

------------------------------------------------------------------------
-- 시간 시스템 (TimeManager.server / TimeDisplay.client)
------------------------------------------------------------------------
-- TIME_SCALE: 시간이 실제보다 몇 배 빠르게 흐르는지
--   6 = 실제 10분이 게임 내 1시간, 실제 4시간이 게임 내 하루
BalanceConfig.TIME_SCALE = 6

-- UTC_OFFSET: 서버 시작 시점 기준 시간대 오프셋
--   9 = KST (한국 표준시, UTC+9)
BalanceConfig.UTC_OFFSET = 9

-- DAY_START_HOUR / NIGHT_START_HOUR: 낮·밤 전환 기준 시각 (게임 내 시간)
--   해 아이콘 ↔ 달 아이콘 전환, 테두리 색상 전환에 사용
BalanceConfig.DAY_START_HOUR = 6
BalanceConfig.NIGHT_START_HOUR = 18

------------------------------------------------------------------------
-- 배치 시스템 (PlacementClient / GridSnap / DragHandler)
------------------------------------------------------------------------
-- GRID_SIZE: 건물 배치 시 스냅 단위 (stud)
--   작을수록 정밀 배치, 클수록 빠른 배치
BalanceConfig.GRID_SIZE = 0.1

-- ROTATION_STEP: 건물 회전 단위 (도)
--   90 = 4방향, 45 = 8방향
BalanceConfig.ROTATION_STEP = 90

-- PLACEMENT_PREVIEW_DISTANCE: 새 건물 배치 시 캐릭터 앞에 프리뷰가 뜨는 거리 (stud)
BalanceConfig.PLACEMENT_PREVIEW_DISTANCE = 10

------------------------------------------------------------------------
-- 스폰/이동 (PlotManager.server)
------------------------------------------------------------------------
-- SPAWN_DELAY: 캐릭터 스폰 후 플롯으로 이동하기까지 대기 시간 (초)
--   너무 짧으면 HumanoidRootPart가 아직 없을 수 있음
BalanceConfig.SPAWN_DELAY = 0.5

-- SPAWN_HEIGHT_OFFSET: BuildZone 위로 얼마나 높이 스폰하는지 (stud)
--   낮으면 건물에 끼일 수 있고, 높으면 낙하 거리가 김
BalanceConfig.SPAWN_HEIGHT_OFFSET = 5

------------------------------------------------------------------------
-- 인벤토리 (Constants → InventoryManager)
------------------------------------------------------------------------
-- DEFAULT_INVENTORY: 플레이어 최초 접속 시 기본 지급 아이템
--   itemName = Items 폴더 내 템플릿 이름, count = 지급 수량
BalanceConfig.DEFAULT_INVENTORY = {
	{ itemName = "DummyBlock", count = 20 },
	{ itemName = "DummyBlock2", count = 20 },
}

return BalanceConfig
