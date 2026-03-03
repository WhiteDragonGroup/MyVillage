-- SpawnConfig.luau
-- 스폰/이동 밸런스 수치
-- 참조: PlotManager.server

local SpawnConfig = {}

-- DELAY: 캐릭터 스폰 후 플롯으로 이동하기까지 대기 시간 (초)
--   너무 짧으면 HumanoidRootPart가 아직 없을 수 있음
SpawnConfig.DELAY = 0.5

-- HEIGHT_OFFSET: BuildZone 위로 얼마나 높이 스폰하는지 (stud)
--   낮으면 건물에 끼일 수 있고, 높으면 낙하 거리가 김
SpawnConfig.HEIGHT_OFFSET = 5

return SpawnConfig
