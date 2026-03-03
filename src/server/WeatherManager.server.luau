-- WeatherManager.server.luau
-- 서버 날씨 관리: 가중치 랜덤 선택 + 주기적 변경 + 클라이언트 동기화

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local WeatherCfg = BalanceConfig.Weather
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local weatherChangedEvent = remotes:WaitForChild("WeatherChanged")

-- 현재 날씨
local currentWeather = "Sunny"

-- 가중치 랜덤 선택
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

	return "Sunny"
end

-- 날씨 변경
local function changeWeather()
	local newWeather = pickWeather()
	currentWeather = newWeather
	print("[WeatherManager] 날씨 변경:", currentWeather)
	weatherChangedEvent:FireAllClients(currentWeather)
end

-- 신규 접속자에게 현재 날씨 전송
Players.PlayerAdded:Connect(function(player)
	weatherChangedEvent:FireClient(player, currentWeather)
end)

-- 클라이언트 요청 시 현재 날씨 반환 (init 후 동기화용)
local getWeatherFunc = remotes:WaitForChild("GetWeather")
getWeatherFunc.OnServerInvoke = function(_player)
	return currentWeather
end

-- 초기 날씨 설정
changeWeather()
print("[WeatherManager] 초기 날씨:", currentWeather)

-- 주기적 날씨 변경
task.spawn(function()
	while true do
		task.wait(WeatherCfg.CYCLE_INTERVAL)
		changeWeather()
	end
end)
