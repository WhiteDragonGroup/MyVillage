-- SettingsUI.luau
-- 설정 UI (기획서 기준)
-- Weather VFX 토글, Music 슬라이더, SFX 슬라이더, Low Detail Mode 토글, Codes 입력

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SettingsUI = {}

local screenGui = nil
local overlay = nil
local mainFrame = nil
local _visible = false

local PANEL_WIDTH = 300
local PANEL_HEIGHT = 320

local _settings = {
	weatherVFX = true,
	musicVolume = 0.5,
	sfxVolume = 0.8,
	lowDetail = false,
}

local _onCodeSubmit = nil -- 외부 콜백

function SettingsUI.init(callbacks: { onCodeSubmit: ((string) -> ())? }?)
	_onCodeSubmit = callbacks and callbacks.onCodeSubmit or nil

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
	mainFrame.BackgroundColor3 = Color3.fromRGB(180, 120, 60)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 70, 30)
	stroke.Thickness = 3
	stroke.Parent = mainFrame

	-- 제목
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(60, 30, 10)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Text = "Settings"
	title.Parent = mainFrame

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -36, 0, 3)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.AutoButtonColor = true
	closeBtn.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		SettingsUI.hide()
	end)

	-- 설정 항목 컨테이너
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -20, 1, -46)
	content.Position = UDim2.new(0, 10, 0, 40)
	content.BackgroundTransparency = 1
	content.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	-- 1. Weather VFX 토글
	SettingsUI._createToggleRow(content, "Weather", 1, _settings.weatherVFX, function(val)
		_settings.weatherVFX = val
	end)

	-- 2. Music 슬라이더
	SettingsUI._createSliderRow(content, "Music", 2, _settings.musicVolume, function(val)
		_settings.musicVolume = val
	end)

	-- 3. SFX 슬라이더
	SettingsUI._createSliderRow(content, "SFX", 3, _settings.sfxVolume, function(val)
		_settings.sfxVolume = val
		SoundService.Volume = val
	end)

	-- 4. Low Detail Mode 토글
	SettingsUI._createToggleRow(content, "Low Detail Mode", 4, _settings.lowDetail, function(val)
		_settings.lowDetail = val
		if val then
			Lighting.GlobalShadows = false
		else
			Lighting.GlobalShadows = true
		end
	end)

	-- 5. Codes 입력
	SettingsUI._createCodeRow(content, 5)
end

function SettingsUI._createRow(parent, order): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(200, 140, 80)
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = parent

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 8)
	rowCorner.Parent = row

	return row
end

function SettingsUI._createToggleRow(parent, label, order, default, onChange)
	local row = SettingsUI._createRow(parent, order)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -70, 1, 0)
	nameLabel.Position = UDim2.new(0, 12, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(60, 30, 10)
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = label
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local isOn = default

	local toggleBg = Instance.new("Frame")
	toggleBg.Size = UDim2.new(0, 44, 0, 22)
	toggleBg.Position = UDim2.new(1, -56, 0.5, -11)
	toggleBg.BackgroundColor3 = if isOn then Color3.fromRGB(80, 180, 80) else Color3.fromRGB(120, 80, 60)
	toggleBg.Parent = row

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(1, 0)
	bgCorner.Parent = toggleBg

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.Position = if isOn then UDim2.new(1, -20, 0.5, -9) else UDim2.new(0, 2, 0.5, -9)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Parent = toggleBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = toggleBg

	btn.MouseButton1Click:Connect(function()
		isOn = not isOn
		toggleBg.BackgroundColor3 = if isOn then Color3.fromRGB(80, 180, 80) else Color3.fromRGB(120, 80, 60)
		knob.Position = if isOn then UDim2.new(1, -20, 0.5, -9) else UDim2.new(0, 2, 0.5, -9)
		onChange(isOn)
	end)
end

function SettingsUI._createSliderRow(parent, label, order, default, onChange)
	local row = SettingsUI._createRow(parent, order)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 60, 1, 0)
	nameLabel.Position = UDim2.new(0, 12, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(60, 30, 10)
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = label
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	-- 슬라이더 배경
	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -100, 0, 10)
	sliderBg.Position = UDim2.new(0, 80, 0.5, -5)
	sliderBg.BackgroundColor3 = Color3.fromRGB(120, 80, 50)
	sliderBg.Parent = row

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(1, 0)
	bgCorner.Parent = sliderBg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(default, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
	fill.Parent = sliderBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	-- 클릭으로 값 변경
	local sliderBtn = Instance.new("TextButton")
	sliderBtn.Size = UDim2.new(1, 0, 0, 24)
	sliderBtn.Position = UDim2.new(0, 80, 0.5, -12)
	sliderBtn.BackgroundTransparency = 1
	sliderBtn.Text = ""
	sliderBtn.Parent = row

	sliderBtn.MouseButton1Click:Connect(function()
		local mouse = Players.LocalPlayer:GetMouse()
		local absPos = sliderBg.AbsolutePosition.X
		local absSize = sliderBg.AbsoluteSize.X
		local ratio = math.clamp((mouse.X - absPos) / absSize, 0, 1)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		onChange(ratio)
	end)
end

function SettingsUI._createCodeRow(parent, order)
	local row = SettingsUI._createRow(parent, order)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 55, 1, 0)
	nameLabel.Position = UDim2.new(0, 12, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(60, 30, 10)
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = "Codes"
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local codeBox = Instance.new("TextBox")
	codeBox.Size = UDim2.new(1, -110, 0, 26)
	codeBox.Position = UDim2.new(0, 70, 0.5, -13)
	codeBox.BackgroundColor3 = Color3.fromRGB(255, 240, 220)
	codeBox.TextColor3 = Color3.fromRGB(40, 20, 10)
	codeBox.PlaceholderText = "Enter Code..."
	codeBox.PlaceholderColor3 = Color3.fromRGB(150, 130, 110)
	codeBox.TextSize = 11
	codeBox.Font = Enum.Font.Gotham
	codeBox.ClearTextOnFocus = true
	codeBox.Text = ""
	codeBox.Parent = row

	local codeCorner = Instance.new("UICorner")
	codeCorner.CornerRadius = UDim.new(0, 6)
	codeCorner.Parent = codeBox

	local submitBtn = Instance.new("TextButton")
	submitBtn.Size = UDim2.new(0, 28, 0, 26)
	submitBtn.Position = UDim2.new(1, -38, 0.5, -13)
	submitBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 80)
	submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	submitBtn.TextSize = 14
	submitBtn.Font = Enum.Font.GothamBold
	submitBtn.Text = ">"
	submitBtn.AutoButtonColor = true
	submitBtn.Parent = row

	local submitCorner = Instance.new("UICorner")
	submitCorner.CornerRadius = UDim.new(0, 6)
	submitCorner.Parent = submitBtn

	submitBtn.MouseButton1Click:Connect(function()
		local code = codeBox.Text
		if code ~= "" and _onCodeSubmit then
			_onCodeSubmit(code)
		end
		codeBox.Text = ""
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
