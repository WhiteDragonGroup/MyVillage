-- SettingsUI.luau
-- 설정 UI: 사운드 볼륨, 그래픽 품질, 알림 토글

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local UserSettings = UserSettings

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SettingsUI = {}

local screenGui = nil
local overlay = nil
local mainFrame = nil
local _visible = false

local PANEL_WIDTH = 280
local PANEL_HEIGHT = 300

-- 설정 값 (로컬)
local _settings = {
	masterVolume = 1.0,
	musicVolume = 0.5,
	sfxVolume = 0.8,
	notifications = true,
}

function SettingsUI.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SettingsUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 35
	screenGui.Parent = playerGui

	-- 오버레이
	overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.Text = ""
	overlay.Visible = false
	overlay.Parent = screenGui
	overlay.MouseButton1Click:Connect(function()
		SettingsUI.hide()
	end)

	-- 메인 패널
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "SettingsPanel"
	mainFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
	mainFrame.Position = UDim2.new(0.5, -PANEL_WIDTH / 2, 0.5, -PANEL_HEIGHT / 2)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	mainFrame.BackgroundTransparency = 0.05
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 100, 130)
	stroke.Thickness = 1.5
	stroke.Parent = mainFrame

	-- 제목
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 30)
	title.Position = UDim2.new(0, 8, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Text = "설정"
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = mainFrame

	-- 설정 항목 컨테이너
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -20, 1, -90)
	contentFrame.Position = UDim2.new(0, 10, 0, 48)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = contentFrame

	-- 마스터 볼륨
	SettingsUI._createSlider(contentFrame, "마스터 볼륨", 1, _settings.masterVolume, function(val)
		_settings.masterVolume = val
		SoundService.Volume = val
	end)

	-- 음악 볼륨
	SettingsUI._createSlider(contentFrame, "음악 볼륨", 2, _settings.musicVolume, function(val)
		_settings.musicVolume = val
	end)

	-- 효과음 볼륨
	SettingsUI._createSlider(contentFrame, "효과음 볼륨", 3, _settings.sfxVolume, function(val)
		_settings.sfxVolume = val
	end)

	-- 알림 토글
	SettingsUI._createToggle(contentFrame, "선물 알림", 4, _settings.notifications, function(val)
		_settings.notifications = val
	end)

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(1, -20, 0, 34)
	closeBtn.Position = UDim2.new(0, 10, 1, -44)
	closeBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "닫기"
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.AutoButtonColor = true
	closeBtn.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		SettingsUI.hide()
	end)
end

function SettingsUI._createSlider(parent: Frame, label: string, order: number, defaultVal: number, onChange: (number) -> ())
	local row = Instance.new("Frame")
	row.Name = label
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 100, 0, 16)
	nameLabel.Position = UDim2.new(0, 0, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = label
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(0, 40, 0, 16)
	valueLabel.Position = UDim2.new(1, -40, 0, 2)
	valueLabel.BackgroundTransparency = 1
	valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valueLabel.TextSize = 11
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.Text = tostring(math.floor(defaultVal * 100)) .. "%"
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = row

	-- 슬라이더 배경
	local sliderBg = Instance.new("Frame")
	sliderBg.Name = "SliderBG"
	sliderBg.Size = UDim2.new(1, 0, 0, 8)
	sliderBg.Position = UDim2.new(0, 0, 0, 24)
	sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	sliderBg.Parent = row

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = sliderBg

	-- 슬라이더 채움
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(defaultVal, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 160, 80)
	fill.Parent = sliderBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	-- 클릭으로 값 변경
	local sliderBtn = Instance.new("TextButton")
	sliderBtn.Name = "SliderBtn"
	sliderBtn.Size = UDim2.new(1, 0, 0, 16)
	sliderBtn.Position = UDim2.new(0, 0, 0, 20)
	sliderBtn.BackgroundTransparency = 1
	sliderBtn.Text = ""
	sliderBtn.Parent = row

	local dragging = false

	local function updateValue(inputX)
		local absPos = sliderBg.AbsolutePosition.X
		local absSize = sliderBg.AbsoluteSize.X
		local ratio = math.clamp((inputX - absPos) / absSize, 0, 1)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		valueLabel.Text = tostring(math.floor(ratio * 100)) .. "%"
		onChange(ratio)
	end

	sliderBtn.MouseButton1Down:Connect(function()
		dragging = true
	end)

	sliderBtn.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateValue(input.Position.X)
		end
	end)

	sliderBtn.MouseButton1Click:Connect(function()
		-- 클릭 위치로 즉시 이동
		local mouse = Players.LocalPlayer:GetMouse()
		updateValue(mouse.X)
	end)

	game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

function SettingsUI._createToggle(parent: Frame, label: string, order: number, defaultVal: boolean, onChange: (boolean) -> ())
	local row = Instance.new("Frame")
	row.Name = label
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -60, 1, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = label
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "Toggle"
	toggleBtn.Size = UDim2.new(0, 50, 0, 24)
	toggleBtn.Position = UDim2.new(1, -50, 0.5, -12)
	toggleBtn.TextSize = 11
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.AutoButtonColor = true
	toggleBtn.Parent = row

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 6)
	toggleCorner.Parent = toggleBtn

	local isOn = defaultVal

	local function updateToggle()
		if isOn then
			toggleBtn.Text = "ON"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			toggleBtn.Text = "OFF"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			toggleBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
		end
	end

	updateToggle()

	toggleBtn.MouseButton1Click:Connect(function()
		isOn = not isOn
		updateToggle()
		onChange(isOn)
	end)
end

function SettingsUI.show()
	if _visible or not mainFrame then return end
	_visible = true
	overlay.Visible = true
	mainFrame.Visible = true
end

function SettingsUI.hide()
	if not _visible or not mainFrame then return end
	_visible = false
	overlay.Visible = false
	mainFrame.Visible = false
end

function SettingsUI.isVisible(): boolean
	return _visible
end

function SettingsUI.getSettings()
	return _settings
end

function SettingsUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return SettingsUI
