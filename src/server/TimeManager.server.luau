-- TimeManager.server.luau
-- 1분 = 1시간 (24분 = 하루)

local Lighting = game:GetService("Lighting")

-- 설정
local MINUTES_PER_HOUR = 1  -- 실제 1분 = 게임 1시간
local START_HOUR = 8        -- 시작 시간 (오전 8시)

-- 시작 시간 설정
Lighting.ClockTime = START_HOUR

-- 시간 흐름
while true do
	task.wait(MINUTES_PER_HOUR * 60 / 60)  -- 1초마다 1분 (60초 = 1시간)

	Lighting.ClockTime = (Lighting.ClockTime + 1/60) % 24
end
