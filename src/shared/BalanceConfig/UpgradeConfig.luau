-- UpgradeConfig.luau
-- 건물 업그레이드 밸런스 수치
-- 참조: UpgradeManager / UpgradeServer / UpgradeDisplay

local UpgradeConfig = {}

-- 최대 레벨
UpgradeConfig.MAX_LEVEL = 5

-- 레벨별 업그레이드 비용 (코인)
UpgradeConfig.COST = {
	[1] = 100,  -- Lv.1 → Lv.2
	[2] = 300,  -- Lv.2 → Lv.3
	[3] = 600,  -- Lv.3 → Lv.4
	[4] = 1000, -- Lv.4 → Lv.5
}

-- 레벨별 외형 변화: 크기 배율 (원본 대비)
UpgradeConfig.SIZE_SCALE = {
	[1] = 1.0,
	[2] = 1.05,
	[3] = 1.10,
	[4] = 1.15,
	[5] = 1.20,
}

-- 레벨별 색상 밝기 증가 (0~1, 원본 색상에 더함)
UpgradeConfig.COLOR_BRIGHTEN = {
	[1] = 0.0,
	[2] = 0.03,
	[3] = 0.06,
	[4] = 0.09,
	[5] = 0.12,
}

-- 업그레이드 진행도 관련
UpgradeConfig.PROGRESS_TICK = 1 -- 서버 틱 간격 (초)

return UpgradeConfig
