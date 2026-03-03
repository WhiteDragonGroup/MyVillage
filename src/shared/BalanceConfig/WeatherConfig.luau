-- WeatherConfig.luau
-- 날씨 시스템 밸런스 설정

local WeatherConfig = {}

WeatherConfig.CYCLE_INTERVAL = 300      -- 날씨 변경 주기 (초, 5분)
WeatherConfig.WEIGHTS = {
	Sunny = 40,
	Rain = 25,
	Frost = 15,
	ThunderStorm = 20,
}
WeatherConfig.EFFECT_OFFSET = CFrame.new(0, 30, -10) -- 카메라 기준 오프셋 (위 30, 앞 10)
WeatherConfig.EFFECT_SIZE = Vector3.new(100, 1, 100) -- 이펙트 파트 크기 (넓게 덮음)
WeatherConfig.TRANSITION_TIME = 2       -- 전환 페이드 시간 (초)

return WeatherConfig
