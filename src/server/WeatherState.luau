-- WeatherState.luau
-- 서버 날씨 상태 공유 모듈: 다른 서버 모듈에서 현재 날씨를 조회할 수 있도록 함

local WeatherState = {}

local _currentWeather: string = "Sunny"

function WeatherState.get(): string
	return _currentWeather
end

function WeatherState.set(weather: string)
	_currentWeather = weather
end

return WeatherState
