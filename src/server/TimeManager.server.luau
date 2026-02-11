-- TimeManager.server.luau
-- 6배속 시간 시스템 (실제 10분 = 게임 1시간, 하루 = 실제 4시간)
-- 서버 시작 시점의 KST 시간을 기준으로 6배속 진행

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local TIME_SCALE = BalanceConfig.TIME_SCALE
local UTC_OFFSET = BalanceConfig.UTC_OFFSET

-- 서버 시작 시점의 실제 KST 시간을 기준점으로
local startRealTime = os.time()
local startDate = os.date("!*t", startRealTime)
local startGameHours = ((startDate.hour + UTC_OFFSET) % 24) + startDate.min / 60 + startDate.sec / 3600

local function updateTime()
	local elapsed = os.time() - startRealTime
	local gameElapsedHours = (elapsed * TIME_SCALE) / 3600
	Lighting.ClockTime = (startGameHours + gameElapsedHours) % 24
end

updateTime()
RunService.Heartbeat:Connect(updateTime)
