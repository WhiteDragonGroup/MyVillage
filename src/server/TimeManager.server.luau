-- TimeManager.server.luau
-- 6배속 시간 시스템 (실제 10분 = 게임 1시간, 하루 = 실제 4시간)
-- 서버 시작 시점의 KST 시간을 기준으로 6배속 진행

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local TimeState = require(ServerScriptService:WaitForChild("Server"):WaitForChild("TimeState"))

local TIME_SCALE = BalanceConfig.Time.TIME_SCALE
local UTC_OFFSET = BalanceConfig.Time.UTC_OFFSET
local DAY_START = BalanceConfig.Time.DAY_START_HOUR
local NIGHT_START = BalanceConfig.Time.NIGHT_START_HOUR

-- 서버 시작 시점의 실제 KST 시간을 기준점으로
local startRealTime = os.time()
local startDate = os.date("!*t", startRealTime)
local startGameHours = ((startDate.hour + UTC_OFFSET) % 24) + startDate.min / 60 + startDate.sec / 3600

-- Day/Night fixed ClockTime values (instant transition)
local DAY_CLOCK = BalanceConfig.Time.DAY_CLOCK or 14   -- daytime ClockTime
local NIGHT_CLOCK = BalanceConfig.Time.NIGHT_CLOCK or 2 -- nighttime ClockTime

local function updateTime()
	local elapsed = os.time() - startRealTime
	local gameElapsedHours = (elapsed * TIME_SCALE) / 3600
	local clockTime = (startGameHours + gameElapsedHours) % 24

	-- Instant day/night transition (fixed ClockTime)
	local isDay = clockTime >= DAY_START and clockTime < NIGHT_START
	Lighting.ClockTime = if isDay then DAY_CLOCK else NIGHT_CLOCK

	TimeState.update(clockTime, isDay)
end

updateTime()
RunService.Heartbeat:Connect(updateTime)
