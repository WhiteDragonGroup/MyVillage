-- TimeConfig.luau
-- 시간 시스템 밸런스 수치
-- 참조: TimeManager.server / TimeDisplay.client

local TimeConfig = {}

-- TIME_SCALE: 시간이 실제보다 몇 배 빠르게 흐르는지
--   120 = 낮(6시→18시) 12 게임시간 = 6 실제분, 밤(18시→6시) 12 게임시간 = 6 실제분.
--         한 사이클 12분 (낮 6분 + 밤 6분).
TimeConfig.TIME_SCALE = 120

-- UTC_OFFSET: 서버 시작 시점 기준 시간대 오프셋
--   9 = KST (한국 표준시, UTC+9)
TimeConfig.UTC_OFFSET = 9

-- DAY_START_HOUR / NIGHT_START_HOUR: 낮·밤 전환 기준 시각 (게임 내 시간)
--   해 아이콘 ↔ 달 아이콘 전환, 테두리 색상 전환에 사용
TimeConfig.DAY_START_HOUR = 6
TimeConfig.NIGHT_START_HOUR = 18

-- Fixed ClockTime for instant day/night transition
TimeConfig.DAY_CLOCK = 14    -- daytime lighting
TimeConfig.NIGHT_CLOCK = 2   -- nighttime lighting

return TimeConfig