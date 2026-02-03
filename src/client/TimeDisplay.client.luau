-- TimeDisplay.client.luau
-- 화면에 현재 시간 표시 (예쁜 버전)

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI 생성
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TimeDisplay"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 메인 프레임
local frame = Instance.new("Frame")
frame.Name = "TimeFrame"
frame.Size = UDim2.new(0, 160, 0, 70)
frame.Position = UDim2.new(0.5, -80, 0, 15)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- 모서리 둥글게
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = frame

-- 그림자 효과
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0, -10, 0, -5)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5554236805"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.6
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(23, 23, 277, 277)
shadow.ZIndex = -1
shadow.Parent = frame

-- 아이콘 (해/달)
local icon = Instance.new("TextLabel")
icon.Name = "Icon"
icon.Size = UDim2.new(0, 40, 0, 40)
icon.Position = UDim2.new(0, 10, 0.5, -20)
icon.BackgroundTransparency = 1
icon.TextSize = 30
icon.Text = "☀️"
icon.Parent = frame

-- 시간 텍스트
local timeLabel = Instance.new("TextLabel")
timeLabel.Name = "TimeLabel"
timeLabel.Size = UDim2.new(0, 100, 0, 35)
timeLabel.Position = UDim2.new(0, 50, 0, 8)
timeLabel.BackgroundTransparency = 1
timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timeLabel.TextSize = 28
timeLabel.Font = Enum.Font.GothamBold
timeLabel.Text = "08:00"
timeLabel.TextXAlignment = Enum.TextXAlignment.Center
timeLabel.Parent = frame

-- 오전/오후 + 요일
local periodLabel = Instance.new("TextLabel")
periodLabel.Name = "PeriodLabel"
periodLabel.Size = UDim2.new(0, 100, 0, 20)
periodLabel.Position = UDim2.new(0, 50, 0, 42)
periodLabel.BackgroundTransparency = 1
periodLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
periodLabel.TextSize = 14
periodLabel.Font = Enum.Font.Gotham
periodLabel.Text = "오전"
periodLabel.TextXAlignment = Enum.TextXAlignment.Center
periodLabel.Parent = frame

-- 테두리 글로우
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(100, 150, 255)
stroke.Thickness = 1.5
stroke.Transparency = 0.5
stroke.Parent = frame

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

	-- 아이콘 변경 (낮/밤)
	if hours >= 6 and hours < 18 then
		icon.Text = "☀️"
		stroke.Color = Color3.fromRGB(255, 200, 100)  -- 낮 = 따뜻한 색
	else
		icon.Text = "🌙"
		stroke.Color = Color3.fromRGB(100, 150, 255)  -- 밤 = 파란색
	end
end

-- 매 프레임 업데이트
game:GetService("RunService").Heartbeat:Connect(updateTime)

print("TimeDisplay 로드됨")
