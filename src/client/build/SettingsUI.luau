-- SettingsUI.luau
-- Design UI: Features > Settings
-- Header(Close), ScrollingFrame(Music, SFX, LowDetailMode, Code)

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getSettingsFunc = remotes:WaitForChild("GetSettings")
local saveSettingEvent = remotes:WaitForChild("SaveSetting")

local SettingsUI = {}

local settingsFrame = nil
local _visible = false
local _onCodeSubmit = nil

function SettingsUI.init(callbacks: { onCodeSubmit: ((string) -> ())? }?)
	_onCodeSubmit = callbacks and callbacks.onCodeSubmit or nil

	local featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then return end

	settingsFrame = featuresGui:FindFirstChild("Settings")
	if not settingsFrame then return end

	settingsFrame.Visible = false

	-- Close button
	local header = settingsFrame:FindFirstChild("Header")
	if header then
		local closeBtn = header:FindFirstChild("Close")
		if closeBtn and closeBtn:IsA("GuiButton") then
			closeBtn.MouseButton1Click:Connect(function()
				SettingsUI.hide()
			end)
		end
	end

	-- ScrollingFrame
	local scrollFrame = settingsFrame:FindFirstChild("ScrollingFrame")
	if not scrollFrame then return end

	-- 서버에서 저장된 설정 불러오기 (실패 시 기본값)
	local settings = nil
	local ok = pcall(function()
		settings = getSettingsFunc:InvokeServer()
	end)
	if not ok or typeof(settings) ~= "table" then
		settings = {}
	end
	local initMusic = if typeof(settings.music) == "number" then settings.music else 1
	local initSfx = if typeof(settings.sfx) == "number" then settings.sfx else 1
	local initLowDetail = settings.lowDetail == true

	local function applyMusic(val)
		local musicGroup = SoundService:FindFirstChild("Music")
		if musicGroup and musicGroup:IsA("SoundGroup") then
			musicGroup.Volume = val
		end
	end
	local function applySfx(val)
		local sfxGroup = SoundService:FindFirstChild("SFX")
		if sfxGroup and sfxGroup:IsA("SoundGroup") then
			sfxGroup.Volume = val
		end
	end
	local function applyLowDetail(isOn)
		Lighting.GlobalShadows = not isOn
	end

	-- 초기값 즉시 적용
	applyMusic(initMusic)
	applySfx(initSfx)
	applyLowDetail(initLowDetail)

	-- Music slider
	local musicFrame = scrollFrame:FindFirstChild("Music")
	if musicFrame then
		SettingsUI._connectSlider(musicFrame, initMusic, function(val)
			applyMusic(val)
			saveSettingEvent:FireServer("music", val)
		end)
	end

	-- SFX slider
	local sfxFrame = scrollFrame:FindFirstChild("SFX")
	if sfxFrame then
		SettingsUI._connectSlider(sfxFrame, initSfx, function(val)
			applySfx(val)
			saveSettingEvent:FireServer("sfx", val)
		end)
	end

	-- Low Detail Mode (On/Off toggle via ImageButton in GaugeBar)
	local lowDetailFrame = scrollFrame:FindFirstChild("LowDetailMode")
	if lowDetailFrame then
		SettingsUI._connectOnOffToggle(lowDetailFrame, initLowDetail, function(isOn)
			applyLowDetail(isOn)
			saveSettingEvent:FireServer("lowDetail", isOn)
		end)
	end

	-- Code input
	local codeFrame = scrollFrame:FindFirstChild("Code")
	if codeFrame then
		local textBox = codeFrame:FindFirstChildWhichIsA("TextBox", true)
		local submitBtn = codeFrame:FindFirstChildWhichIsA("ImageButton", true)
			or codeFrame:FindFirstChildWhichIsA("TextButton", true)
		if submitBtn and textBox then
			submitBtn.MouseButton1Click:Connect(function()
				local code = textBox.Text
				if code ~= "" and _onCodeSubmit then
					_onCodeSubmit(code)
				end
				textBox.Text = ""
			end)
		end
	end
end

-- Slider: GaugeBar > Gauge (fill) + ImageButton (handle)
function SettingsUI._connectSlider(frame, initial: number, onChange)
	-- Find GaugeBar
	local gaugeBar = frame:FindFirstChild("GaugeBar", true)
	if not gaugeBar then return end

	local fillBar = gaugeBar:FindFirstChild("Gauge")
	local handle = gaugeBar:FindFirstChild("ImageButton")
		or gaugeBar:FindFirstChildWhichIsA("ImageButton")

	-- Set handle anchor for centering
	if handle then
		handle.AnchorPoint = Vector2.new(0.5, handle.AnchorPoint.Y)
	end

	-- Apply initial value visually (no callback)
	local startRatio = math.clamp(initial or 1, 0, 1)
	if fillBar then
		fillBar.Size = UDim2.new(startRatio, 0, fillBar.Size.Y.Scale, fillBar.Size.Y.Offset)
	end
	if handle then
		handle.Position = UDim2.new(startRatio, 0, handle.Position.Y.Scale, handle.Position.Y.Offset)
	end

	-- Create invisible click area over the bar
	local clickArea = Instance.new("TextButton")
	clickArea.Name = "_SliderClick"
	clickArea.Size = UDim2.new(1, 0, 1, 0)
	clickArea.BackgroundTransparency = 1
	clickArea.Text = ""
	clickArea.ZIndex = 20
	clickArea.Parent = gaugeBar

	local dragging = false

	local function updateSlider(inputX)
		local absPos = gaugeBar.AbsolutePosition.X
		local absSize = gaugeBar.AbsoluteSize.X
		if absSize == 0 then return end
		local ratio = math.clamp((inputX - absPos) / absSize, 0, 1)
		if fillBar then
			fillBar.Size = UDim2.new(ratio, 0, fillBar.Size.Y.Scale, fillBar.Size.Y.Offset)
		end
		if handle then
			handle.Position = UDim2.new(ratio, 0, handle.Position.Y.Scale, handle.Position.Y.Offset)
		end
		onChange(ratio)
	end

	clickArea.MouseButton1Down:Connect(function()
		dragging = true
		local mouse = player:GetMouse()
		updateSlider(mouse.X)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateSlider(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

-- Toggle: find clickable element + visual feedback (text only)
function SettingsUI._connectToggle(frame, onChange)
	local isOn = false

	local toggleBtn = frame:FindFirstChildWhichIsA("ImageButton", true)
		or frame:FindFirstChildWhichIsA("TextButton", true)

	-- Find a TextLabel to show ON/OFF status
	local statusLabel = nil
	for _, desc in frame:GetDescendants() do
		if desc:IsA("TextLabel") then
			statusLabel = desc
			break
		end
	end

	if not toggleBtn then
		toggleBtn = Instance.new("TextButton")
		toggleBtn.Name = "_Toggle"
		toggleBtn.Size = UDim2.new(1, 0, 1, 0)
		toggleBtn.BackgroundTransparency = 1
		toggleBtn.Text = ""
		toggleBtn.ZIndex = 10
		toggleBtn.Parent = frame
	end

	local function updateVisual()
		if statusLabel then
			statusLabel.Text = if isOn then "ON" else "OFF"
			statusLabel.TextColor3 = if isOn
				then Color3.fromRGB(80, 220, 80)
				else Color3.fromRGB(180, 180, 180)
		end
	end

	updateVisual()

	toggleBtn.MouseButton1Click:Connect(function()
		isOn = not isOn
		updateVisual()
		onChange(isOn)
	end)
end

-- On/Off toggle: GaugeBar > ImageButton (handle) clicks to toggle left/right
function SettingsUI._connectOnOffToggle(frame, initial: boolean, onChange)
	local gaugeBar = frame:FindFirstChild("GaugeBar", true)
	if not gaugeBar then return end

	local handle = gaugeBar:FindFirstChild("ImageButton")
		or gaugeBar:FindFirstChildWhichIsA("ImageButton")
	local gauge = gaugeBar:FindFirstChild("Gauge")

	local isOn = initial == true

	-- Make handle clickable (it's already an ImageButton)
	-- Also add transparent click area on the whole gauge bar
	local clickArea = Instance.new("TextButton")
	clickArea.Name = "_ToggleClick"
	clickArea.Size = UDim2.new(1, 0, 1, 0)
	clickArea.BackgroundTransparency = 1
	clickArea.Text = ""
	clickArea.ZIndex = 20
	clickArea.Parent = gaugeBar

	local function updateVisual(instant: boolean?)
		if handle then
			handle.AnchorPoint = Vector2.new(0.5, handle.AnchorPoint.Y)
			local targetPos = UDim2.new(if isOn then 1 else 0, 0, handle.Position.Y.Scale, handle.Position.Y.Offset)
			if instant then
				handle.Position = targetPos
			else
				TweenService:Create(handle, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					Position = targetPos,
				}):Play()
			end
		end
		if gauge then
			local targetSize = UDim2.new(if isOn then 1 else 0, 0, gauge.Size.Y.Scale, gauge.Size.Y.Offset)
			if instant then
				gauge.Size = targetSize
			else
				TweenService:Create(gauge, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					Size = targetSize,
				}):Play()
			end
		end
	end

	-- Sync visual to initial state without tween
	updateVisual(true)

	clickArea.MouseButton1Click:Connect(function()
		isOn = not isOn
		updateVisual()
		onChange(isOn)
	end)

	if handle and handle:IsA("GuiButton") then
		handle.MouseButton1Click:Connect(function()
			isOn = not isOn
			updateVisual()
			onChange(isOn)
		end)
	end
end

function SettingsUI.show()
	if _visible or not settingsFrame then return end
	_visible = true
	settingsFrame.Visible = true
end

function SettingsUI.hide()
	if not _visible or not settingsFrame then return end
	_visible = false
	settingsFrame.Visible = false
end

function SettingsUI.isVisible(): boolean
	return _visible
end

function SettingsUI.getSettings()
	return {}
end

function SettingsUI.destroy()
end

return SettingsUI
