-- TimeDisplay.client.luau
-- 화면에 현재 시간 표시

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI 생성
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TimeDisplay"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 배경 프레임
local frame = Instance.new("Frame")
frame.Name = "TimeFrame"
frame.Size = UDim2.new(0, 120, 0, 50)
frame.Position = UDim2.new(0.5, -60, 0, 10)  -- 상단 중앙
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BackgroundTransparency = 0.5
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- 모서리 둥글게
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

-- 시간 텍스트
local timeLabel = Instance.new("TextLabel")
timeLabel.Name = "TimeLabel"
timeLabel.Size = UDim2.new(1, 0, 0.6, 0)
timeLabel.Position = UDim2.new(0, 0, 0, 5)
timeLabel.BackgroundTransparency = 1
timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timeLabel.TextSize = 24
timeLabel.Font = Enum.Font.GothamBold
timeLabel.Text = "00:00"
timeLabel.Parent = frame

-- 오전/오후 텍스트
local periodLabel = Instance.new("TextLabel")
periodLabel.Name = "PeriodLabel"
periodLabel.Size = UDim2.new(1, 0, 0.4, 0)
periodLabel.Position = UDim2.new(0, 0, 0.55, 0)
periodLabel.BackgroundTransparency = 1
periodLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
periodLabel.TextSize = 14
periodLabel.Font = Enum.Font.Gotham
periodLabel.Text = "오전"
periodLabel.Parent = frame

-- 시간 업데이트
local function updateTime()
	local clockTime = Lighting.ClockTime
	local hours = math.floor(clockTime)
	local minutes = math.floor((clockTime % 1) * 60)

	-- 12시간 형식
	local displayHour = hours % 12
	if displayHour == 0 then displayHour = 12 end

	local period = hours < 12 and "오전" or "오후"

	timeLabel.Text = string.format("%02d:%02d", displayHour, minutes)
	periodLabel.Text = period
end

-- 매 프레임 업데이트
game:GetService("RunService").Heartbeat:Connect(updateTime)

print("TimeDisplay 로드됨")
