-- MainHUD.luau
-- 기획서 기준 메인 HUD
-- 1) 중앙 상단: Seeds / Your Garden / Sell 텔레포트 버튼
-- 2) 중앙 좌측: 도감 / 상점 / 빌드모드 아이콘 버튼 (세로)
-- 3) 하단 좌측: 보석(위) + 돈(아래)
-- 4) 하단 우측: 날씨 아이콘 + 시간 + 호버 툴팁

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MainHUD = {}

local screenGui = nil
local _callbacks = {}
local _activeTab = nil
local _sideButtons = {}
local _coinLabel = nil
local _gemLabel = nil
local _weatherIcon = nil
local _weatherTooltip = nil
local _timeLabel = nil
local _timePeriodLabel = nil
local _coins = 0
local _gems = 0

local WEATHER_INFO = {
	Sunny        = { icon = "☀️", name = "맑음",  desc = "화창한 날씨입니다." },
	Rain         = { icon = "🌧️", name = "비",    desc = "비가 내리고 있습니다." },
	Frost        = { icon = "❄️", name = "서리",  desc = "차가운 서리가 내렸습니다." },
	ThunderStorm = { icon = "⛈️", name = "뇌우", desc = "번개를 조심하세요!" },
}

----------------------------------------------------------------
-- 1. 중앙 상단: Teleport 버튼 3개
----------------------------------------------------------------
local function createTopBar(parent)
	local topFrame = Instance.new("Frame")
	topFrame.Name = "TopBar"
	topFrame.Size = UDim2.new(0, 380, 0, 46)
	topFrame.Position = UDim2.new(0.5, -190, 0, 8)
	topFrame.BackgroundTransparency = 1
	topFrame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = topFrame

	local function makeBtn(name, text, size, color, strokeColor, order)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = size
		btn.BackgroundColor3 = color
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextSize = if order == 2 then 16 else 14
		btn.Font = Enum.Font.GothamBold
		btn.Text = text
		btn.AutoButtonColor = true
		btn.LayoutOrder = order
		btn.Parent = topFrame

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = btn

		local s = Instance.new("UIStroke")
		s.Color = strokeColor
		s.Thickness = 2
		s.Parent = btn

		return btn
	end

	makeBtn("Seeds", "Seeds", UDim2.new(0, 100, 0, 36), Color3.fromRGB(60, 140, 60), Color3.fromRGB(80, 180, 80), 1)
		.MouseButton1Click:Connect(function()
			if _callbacks.onTeleport then _callbacks.onTeleport("buildings") end
		end)

	makeBtn("YourGarden", "Your Garden", UDim2.new(0, 150, 0, 42), Color3.fromRGB(50, 120, 200), Color3.fromRGB(80, 150, 230), 2)
		.MouseButton1Click:Connect(function()
			if _callbacks.onTeleport then _callbacks.onTeleport("village") end
		end)

	makeBtn("Sell", "Sell", UDim2.new(0, 100, 0, 36), Color3.fromRGB(180, 50, 50), Color3.fromRGB(220, 80, 80), 3)
		.MouseButton1Click:Connect(function()
			if _callbacks.onTeleport then _callbacks.onTeleport("eggs") end
		end)
end

----------------------------------------------------------------
-- 2. 중앙 좌측: 도감 / 상점 / 빌드 아이콘 버튼 (세로)
----------------------------------------------------------------
local SIDE_DEFS = {
	{ id = "collection", label = "도감",  color = Color3.fromRGB(80, 120, 200) },
	{ id = "shop",       label = "상점",  color = Color3.fromRGB(200, 150, 50) },
	{ id = "build",      label = "빌드",  color = Color3.fromRGB(50, 150, 50) },
}

local function createSideBar(parent)
	local sideFrame = Instance.new("Frame")
	sideFrame.Name = "SideBar"
	sideFrame.Size = UDim2.new(0, 54, 0, 232)
	sideFrame.Position = UDim2.new(0, 10, 0.5, -90)
	sideFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	sideFrame.BackgroundTransparency = 0.15
	sideFrame.BorderSizePixel = 0
	sideFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = sideFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 90)
	stroke.Thickness = 1
	stroke.Parent = sideFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = sideFrame

	for i, def in SIDE_DEFS do
		local btn = Instance.new("TextButton")
		btn.Name = def.id
		btn.Size = UDim2.new(0, 44, 0, 44)
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
		btn.TextColor3 = Color3.fromRGB(200, 200, 210)
		btn.TextSize = 11
		btn.Font = Enum.Font.GothamBold
		btn.Text = def.label
		btn.AutoButtonColor = true
		btn.LayoutOrder = i
		btn.Parent = sideFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 10)
		btnCorner.Parent = btn

		_sideButtons[def.id] = { button = btn, def = def }

		btn.MouseButton1Click:Connect(function()
			if _activeTab == def.id then
				MainHUD.setActiveTab(nil)
			else
				MainHUD.setActiveTab(def.id)
			end
		end)
	end

	-- 설정 버튼 (사이드바 하단)
	local settingsBtn = Instance.new("TextButton")
	settingsBtn.Name = "settings"
	settingsBtn.Size = UDim2.new(0, 44, 0, 44)
	settingsBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	settingsBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
	settingsBtn.TextSize = 18
	settingsBtn.Font = Enum.Font.GothamBold
	settingsBtn.Text = "⚙"
	settingsBtn.AutoButtonColor = true
	settingsBtn.LayoutOrder = #SIDE_DEFS + 1
	settingsBtn.Parent = sideFrame

	local settingsCorner = Instance.new("UICorner")
	settingsCorner.CornerRadius = UDim.new(0, 10)
	settingsCorner.Parent = settingsBtn

	settingsBtn.MouseButton1Click:Connect(function()
		if _callbacks.onSettings then
			_callbacks.onSettings()
		end
	end)
end

----------------------------------------------------------------
-- 3. 하단 좌측: 보석 + 돈
----------------------------------------------------------------
local function createCurrencyDisplay(parent)
	local frame = Instance.new("Frame")
	frame.Name = "CurrencyFrame"
	frame.Size = UDim2.new(0, 130, 0, 54)
	frame.Position = UDim2.new(0, 10, 1, -64)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 90)
	stroke.Thickness = 1
	stroke.Parent = frame

	-- 보석 (위)
	local gemIcon = Instance.new("TextLabel")
	gemIcon.Size = UDim2.new(0, 24, 0, 20)
	gemIcon.Position = UDim2.new(0, 8, 0, 5)
	gemIcon.BackgroundTransparency = 1
	gemIcon.TextColor3 = Color3.fromRGB(150, 100, 255)
	gemIcon.TextSize = 14
	gemIcon.Font = Enum.Font.GothamBold
	gemIcon.Text = "💎"
	gemIcon.Parent = frame

	_gemLabel = Instance.new("TextLabel")
	_gemLabel.Name = "GemLabel"
	_gemLabel.Size = UDim2.new(1, -38, 0, 20)
	_gemLabel.Position = UDim2.new(0, 32, 0, 5)
	_gemLabel.BackgroundTransparency = 1
	_gemLabel.TextColor3 = Color3.fromRGB(180, 150, 255)
	_gemLabel.TextSize = 13
	_gemLabel.Font = Enum.Font.GothamBold
	_gemLabel.Text = "0"
	_gemLabel.TextXAlignment = Enum.TextXAlignment.Left
	_gemLabel.Parent = frame

	-- 돈 (아래)
	local coinIcon = Instance.new("TextLabel")
	coinIcon.Size = UDim2.new(0, 24, 0, 20)
	coinIcon.Position = UDim2.new(0, 8, 0, 28)
	coinIcon.BackgroundTransparency = 1
	coinIcon.TextColor3 = Color3.fromRGB(255, 200, 60)
	coinIcon.TextSize = 14
	coinIcon.Font = Enum.Font.GothamBold
	coinIcon.Text = "$"
	coinIcon.Parent = frame

	_coinLabel = Instance.new("TextLabel")
	_coinLabel.Name = "CoinLabel"
	_coinLabel.Size = UDim2.new(1, -38, 0, 20)
	_coinLabel.Position = UDim2.new(0, 32, 0, 28)
	_coinLabel.BackgroundTransparency = 1
	_coinLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	_coinLabel.TextSize = 13
	_coinLabel.Font = Enum.Font.GothamBold
	_coinLabel.Text = "0"
	_coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	_coinLabel.Parent = frame
end

----------------------------------------------------------------
-- 4. 하단 우측: 날씨 아이콘 + 시간
----------------------------------------------------------------
local function createWeatherTimeDisplay(parent)
	local frame = Instance.new("Frame")
	frame.Name = "WeatherTimeFrame"
	frame.Size = UDim2.new(0, 110, 0, 54)
	frame.Position = UDim2.new(1, -120, 1, -64)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 90)
	stroke.Thickness = 1
	stroke.Parent = frame

	-- 날씨 아이콘 (좌측)
	_weatherIcon = Instance.new("TextLabel")
	_weatherIcon.Name = "WeatherIcon"
	_weatherIcon.Size = UDim2.new(0, 36, 0, 36)
	_weatherIcon.Position = UDim2.new(0, 6, 0.5, -18)
	_weatherIcon.BackgroundTransparency = 1
	_weatherIcon.TextSize = 24
	_weatherIcon.Text = "☀️"
	_weatherIcon.Parent = frame

	-- 시간 (우측 상단)
	_timeLabel = Instance.new("TextLabel")
	_timeLabel.Name = "TimeLabel"
	_timeLabel.Size = UDim2.new(0, 60, 0, 24)
	_timeLabel.Position = UDim2.new(0, 42, 0, 4)
	_timeLabel.BackgroundTransparency = 1
	_timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	_timeLabel.TextSize = 16
	_timeLabel.Font = Enum.Font.GothamBold
	_timeLabel.Text = "08:00"
	_timeLabel.TextXAlignment = Enum.TextXAlignment.Center
	_timeLabel.Parent = frame

	-- 오전/오후 (우측 하단)
	_timePeriodLabel = Instance.new("TextLabel")
	_timePeriodLabel.Name = "PeriodLabel"
	_timePeriodLabel.Size = UDim2.new(0, 60, 0, 16)
	_timePeriodLabel.Position = UDim2.new(0, 42, 0, 30)
	_timePeriodLabel.BackgroundTransparency = 1
	_timePeriodLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	_timePeriodLabel.TextSize = 11
	_timePeriodLabel.Font = Enum.Font.Gotham
	_timePeriodLabel.Text = "오전"
	_timePeriodLabel.TextXAlignment = Enum.TextXAlignment.Center
	_timePeriodLabel.Parent = frame

	-- 호버 툴팁 (날씨 설명)
	_weatherTooltip = Instance.new("Frame")
	_weatherTooltip.Name = "WeatherTooltip"
	_weatherTooltip.Size = UDim2.new(0, 160, 0, 44)
	_weatherTooltip.Position = UDim2.new(0, -168, 0.5, -22)
	_weatherTooltip.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	_weatherTooltip.BorderSizePixel = 0
	_weatherTooltip.Visible = false
	_weatherTooltip.Parent = frame

	local tipCorner = Instance.new("UICorner")
	tipCorner.CornerRadius = UDim.new(0, 8)
	tipCorner.Parent = _weatherTooltip

	local tipStroke = Instance.new("UIStroke")
	tipStroke.Color = Color3.fromRGB(80, 80, 100)
	tipStroke.Thickness = 1
	tipStroke.Parent = _weatherTooltip

	local tipLabel = Instance.new("TextLabel")
	tipLabel.Name = "TipLabel"
	tipLabel.Size = UDim2.new(1, -12, 1, 0)
	tipLabel.Position = UDim2.new(0, 6, 0, 0)
	tipLabel.BackgroundTransparency = 1
	tipLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	tipLabel.TextSize = 11
	tipLabel.Font = Enum.Font.Gotham
	tipLabel.TextWrapped = true
	tipLabel.TextXAlignment = Enum.TextXAlignment.Left
	tipLabel.Text = ""
	tipLabel.Parent = _weatherTooltip

	-- 호버 감지
	local hoverBtn = Instance.new("TextButton")
	hoverBtn.Name = "HoverBtn"
	hoverBtn.Size = UDim2.new(1, 0, 1, 0)
	hoverBtn.BackgroundTransparency = 1
	hoverBtn.Text = ""
	hoverBtn.Parent = frame

	hoverBtn.MouseEnter:Connect(function()
		_weatherTooltip.Visible = true
	end)
	hoverBtn.MouseLeave:Connect(function()
		_weatherTooltip.Visible = false
	end)

	-- 시간 업데이트 루프
	RunService.Heartbeat:Connect(function()
		if not _timeLabel then return end
		local clockTime = Lighting.ClockTime
		local hours = math.floor(clockTime)
		local minutes = math.floor((clockTime % 1) * 60)

		local displayHour = hours % 12
		if displayHour == 0 then displayHour = 12 end
		local period = hours < 12 and "오전" or "오후"

		_timeLabel.Text = string.format("%02d:%02d", displayHour, minutes)
		_timePeriodLabel.Text = period
	end)
end

----------------------------------------------------------------
-- 공개 API
----------------------------------------------------------------

function MainHUD.init(callbacks: {
	onTabChanged: (string?) -> (),
	onTeleport: ((string) -> ())?,
	onSettings: (() -> ())?,
})
	_callbacks = callbacks

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHUD"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 3
	screenGui.Parent = playerGui

	createTopBar(screenGui)
	createSideBar(screenGui)
	createCurrencyDisplay(screenGui)
	createWeatherTimeDisplay(screenGui)
end

function MainHUD.setActiveTab(tabId: string?)
	_activeTab = tabId

	for id, info in _sideButtons do
		if id == tabId then
			info.button.BackgroundColor3 = info.def.color
			info.button.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			info.button.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
			info.button.TextColor3 = Color3.fromRGB(200, 200, 210)
		end
	end

	if _callbacks.onTabChanged then
		_callbacks.onTabChanged(tabId)
	end
end

function MainHUD.getActiveTab(): string?
	return _activeTab
end

function MainHUD.updateCoins(coins: number)
	_coins = coins
	if _coinLabel then
		_coinLabel.Text = tostring(coins)
	end
end

function MainHUD.updateGems(gems: number)
	_gems = gems
	if _gemLabel then
		_gemLabel.Text = tostring(gems)
	end
end

function MainHUD.updateWeather(weatherType: string)
	local info = WEATHER_INFO[weatherType]
	if not info then
		info = { icon = "?", name = weatherType, desc = "" }
	end

	if _weatherIcon then
		_weatherIcon.Text = info.icon
	end

	if _weatherTooltip then
		local tipLabel = _weatherTooltip:FindFirstChild("TipLabel")
		if tipLabel then
			tipLabel.Text = info.name .. "\n" .. info.desc
		end
	end
end

function MainHUD.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return MainHUD
