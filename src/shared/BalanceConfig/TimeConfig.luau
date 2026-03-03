-- TimeConfig.luau
-- 시간 시스템 밸런스 수치
-- 참조: TimeManager.server / TimeDisplay.client

local TimeConfig = {}

-- TIME_SCALE: 시간이 실제보다 몇 배 빠르게 흐르는지
--   6 = 실제 10분이 게임 내 1시간, 실제 4시간이 게임 내 하루
TimeConfig.TIME_SCALE = 6

-- UTC_OFFSET: 서버 시작 시점 기준 시간대 오프셋
--   9 = KST (한국 표준시, UTC+9)
TimeConfig.UTC_OFFSET = 9

-- DAY_START_HOUR / NIGHT_START_HOUR: 낮·밤 전환 기준 시각 (게임 내 시간)
--   해 아이콘 ↔ 달 아이콘 전환, 테두리 색상 전환에 사용
TimeConfig.DAY_START_HOUR = 6
TimeConfig.NIGHT_START_HOUR = 18

return TimeConfig