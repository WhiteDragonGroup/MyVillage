-- WeatherManager.server.luau
-- 서버 날씨 관리: 쿨다운 → 날씨 발생 → 지속시간 → Sunny 복귀 사이클

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local WeatherCfg = BalanceConfig.Weather
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local weatherChangedEvent = remotes:WaitForChild("WeatherChanged")

-- 현재 날씨
local currentWeather = "Sunny"
local currentMessage = ""

-- 가중치 랜덤 선택 (Sunny 제외)
local function pickWeather(): string
	local totalWeight = 0
	for _, w in WeatherCfg.WEIGHTS do
		totalWeight += w
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for weatherType, w in WeatherCfg.WEIGHTS do
		cumulative += w
		if roll <= cumulative then
			return weatherType
		end
	end

	return "Rain" -- 폴백
end

-- 랜덤 범위
local function randomRange(min: number, max: number): number
	return min + math.random() * (max - min)
end

-- 날씨 변경 + 클라이언트 알림
local function setWeather(weatherType: string, message: string)
	currentWeather = weatherType
	currentMessage = message
	print("[WeatherManager] 날씨 변경:", weatherType, message ~= "" and ("| " .. message) or "")
	weatherChangedEvent:FireAllClients(weatherType, message)
end

-- 신규 접속자에게 현재 날씨 전송
Players.PlayerAdded:Connect(function(player)
	weatherChangedEvent:FireClient(player, currentWeather, "")
end)

-- 클라이언트 요청 시 현재 날씨 반환
local getWeatherFunc = remotes:WaitForChild("GetWeather")
getWeatherFunc.OnServerInvoke = function(_player)
	return currentWeather
end

-- 시작: Sunny
setWeather("Sunny", "")
print("[WeatherManager] 초기 상태: Sunny (쿨다운 대기)")

-- 날씨 사이클 루프
task.spawn(function()
	while true do
		-- 1. 쿨다운 대기 (Sunny 상태)
		local cooldown = randomRange(WeatherCfg.COOLDOWN_MIN, WeatherCfg.COOLDOWN_MAX)
		print("[WeatherManager] 쿨다운:", math.floor(cooldown) .. "초")
		task.wait(cooldown)

		-- 2. 날씨 발생
		local weather = pickWeather()
		local msgData = WeatherCfg.MESSAGES[weather]
		local startMsg = msgData and msgData.start or ""
		setWeather(weather, startMsg)

		-- 3. 지속시간 대기
		local duration = randomRange(WeatherCfg.DURATION_MIN, WeatherCfg.DURATION_MAX)
		print("[WeatherManager] 지속시간:", math.floor(duration) .. "초")
		task.wait(duration)

		-- 4. 날씨 종료 → Sunny 복귀
		local endMsg = msgData and msgData.finish or ""
		setWeather("Sunny", endMsg)
	end
end)
