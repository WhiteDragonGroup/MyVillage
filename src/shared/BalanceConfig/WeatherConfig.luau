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
WeatherConfig.CAMERA_OFFSET = 20        -- 이펙트 파트 카메라 앞 거리
WeatherConfig.EFFECT_SIZE = Vector3.new(40, 1, 40) -- 이펙트 파트 기본 크기
WeatherConfig.TRANSITION_TIME = 2       -- 전환 페이드 시간 (초)

return WeatherConfig
