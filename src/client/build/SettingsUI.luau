-- SettingsUI.luau
-- Design UI: Features > Settings
-- Header(Close), ScrollingFrame(Music, SFX, LowDetailMode, Code)

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

	-- Music slider
	local musicFrame = scrollFrame:FindFirstChild("Music")
	if musicFrame then
		SettingsUI._connectSlider(musicFrame, function(val)
			-- TODO: Music volume group
		end)
	end

	-- SFX slider
	local sfxFrame = scrollFrame:FindFirstChild("SFX")
	if sfxFrame then
		SettingsUI._connectSlider(sfxFrame, function(val)
			SoundService.Volume = val
		end)
	end

	-- Low Detail Mode toggle
	local lowDetailFrame = scrollFrame:FindFirstChild("LowDetailMode")
	if lowDetailFrame then
		SettingsUI._connectToggle(lowDetailFrame, function(isOn)
			Lighting.GlobalShadows = not isOn
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

-- Slider: find bar/fill and make clickable
function SettingsUI._connectSlider(frame, onChange)
	-- Find the slider bar (Frame with a fill child)
	local sliderBar = nil
	local fillBar = nil
	local handle = nil

	for _, child in frame:GetDescendants() do
		if child:IsA("Frame") and child.Name ~= frame.Name then
			-- Look for a frame that could be a slider bar
			local possibleFill = child:FindFirstChildWhichIsA("Frame")
			if possibleFill then
				sliderBar = child
				fillBar = possibleFill
			end
		end
	end

	if not sliderBar then return end

	-- Create invisible click area over the bar
	local clickArea = Instance.new("TextButton")
	clickArea.Name = "_SliderClick"
	clickArea.Size = UDim2.new(1, 0, 1, 0)
	clickArea.BackgroundTransparency = 1
	clickArea.Text = ""
	clickArea.ZIndex = 10
	clickArea.Parent = sliderBar

	local dragging = false

	local function updateSlider(inputX)
		local absPos = sliderBar.AbsolutePosition.X
		local absSize = sliderBar.AbsoluteSize.X
		if absSize == 0 then return end
		local ratio = math.clamp((inputX - absPos) / absSize, 0, 1)
		if fillBar then
			fillBar.Size = UDim2.new(ratio, 0, fillBar.Size.Y.Scale, fillBar.Size.Y.Offset)
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

-- Toggle: find clickable element
function SettingsUI._connectToggle(frame, onChange)
	local isOn = false

	-- Find any button or clickable in the frame
	local toggleBtn = frame:FindFirstChildWhichIsA("ImageButton", true)
		or frame:FindFirstChildWhichIsA("TextButton", true)

	if not toggleBtn then
		-- Add transparent button
		toggleBtn = Instance.new("TextButton")
		toggleBtn.Name = "_Toggle"
		toggleBtn.Size = UDim2.new(1, 0, 1, 0)
		toggleBtn.BackgroundTransparency = 1
		toggleBtn.Text = ""
		toggleBtn.ZIndex = 10
		toggleBtn.Parent = frame
	end

	toggleBtn.MouseButton1Click:Connect(function()
		isOn = not isOn
		onChange(isOn)
	end)
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
