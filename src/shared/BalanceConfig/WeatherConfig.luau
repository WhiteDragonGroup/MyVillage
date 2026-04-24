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

WeatherConfig.MESSAGES = {
	Rain = {
		start = "Rain soaks the earth and awakens life.\nFarming efficiency increased by 50%!",
		finish = "The rain has stopped.",
	},
	Frost = {
		start = "A cold chill freezes time itself.\nPet buff durations are paused!",
		finish = "The frost has lifted.",
	},
	ThunderStorm = {
		start = "Lightning strikes with great power!\nPets struck by lightning become permanently stronger!",
		finish = "The thunderstorm has passed.",
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
