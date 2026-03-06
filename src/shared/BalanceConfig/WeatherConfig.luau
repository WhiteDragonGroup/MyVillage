-- WeatherConfig.luau
-- 날씨 시스템 밸런스 설정

local WeatherConfig = {}

-- 타이밍
WeatherConfig.COOLDOWN_MIN = 1800     -- 날씨 사이 쿨다운 최소 (초, 30분)
WeatherConfig.COOLDOWN_MAX = 3000     -- 날씨 사이 쿨다운 최대 (초, 50분)
WeatherConfig.DURATION_MIN = 420      -- 날씨 지속시간 최소 (초, 7분)
WeatherConfig.DURATION_MAX = 600      -- 날씨 지속시간 최대 (초, 10분)

-- 가중치 (Sunny 제외 — Sunny는 날씨 사이 기본 상태)
WeatherConfig.WEIGHTS = {
	Rain = 35,
	Frost = 35,
	ThunderStorm = 20,
	-- 추후 추가: Glitch, Eclipse 등
}

-- 알림 메시지 { 영어, 한국어 }
WeatherConfig.MESSAGES = {
	Rain = {
		start = "비는 대지를 적시고 생명을 깨웁니다.\n농사 효율이 50% 증가합니다!",
		finish = "비가 그쳤습니다.",
	},
	Frost = {
		start = "차가운 기운이 시간을 얼려버립니다.\n펫의 버프 지속시간이 소모되지 않습니다!",
		finish = "눈이 그쳤습니다.",
	},
	ThunderStorm = {
		start = "폭풍우 속 번개의 힘이 깃듭니다!\n번개에 맞은 펫이 영구적으로 더 강력해집니다!",
		finish = "뇌우가 지나갔습니다.",
	},
}

-- 번개 설정 (ThunderStorm)
WeatherConfig.LIGHTNING_INTERVAL_MIN = 3   -- 번개 최소 간격 (초)
WeatherConfig.LIGHTNING_INTERVAL_MAX = 8   -- 번개 최대 간격 (초)
WeatherConfig.LIGHTNING_RADIUS = 5         -- 번개 피격 판정 반경

-- 돌연변이 건설 속도 보너스
WeatherConfig.MUTATION_SPEED_BONUS = {
	Shocked = 0.3,    -- +30%
	Gold = 0.5,       -- +50%
	Inverted = 1.0,   -- +100%
}

-- VFX 설정
WeatherConfig.EFFECT_OFFSET = CFrame.new(0, 30, -10) -- 카메라 기준 오프셋 (위 30, 앞 10)
WeatherConfig.EFFECT_SIZE = Vector3.new(100, 1, 100) -- 이펙트 파트 크기 (넓게 덮음)
WeatherConfig.TRANSITION_TIME = 2       -- 전환 페이드 시간 (초)

return WeatherConfig
