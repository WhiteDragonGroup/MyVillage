-- TimeState.luau
-- 낮/밤 상태 공유 모듈 (다른 서버 모듈이 조회용)
-- TimeManager.server.luau에서 매 프레임 업데이트

local TimeState = {}
local _isDay = true
local _currentHour = 12

function TimeState.isDay(): boolean
	return _isDay
end

function TimeState.getHour(): number
	return _currentHour
end

function TimeState.update(hour: number, isDay: boolean)
	_currentHour = hour
	_isDay = isDay
end

return TimeState
