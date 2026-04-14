-- SettingsUI.luau
-- 디자인 UI 사용 (StarterGui/Features/Settings)
-- Header(Close), ScrollingFrame(Code, LowDetailMode, Music, SFX)

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SettingsUI = {}

local settingsFrame = nil
local _visible = false
local _onCodeSubmit = nil

function SettingsUI.init(callbacks: { onCodeSubmit: ((string) -> ())? }?)
	_onCodeSubmit = callbacks and callbacks.onCodeSubmit or nil

	local featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then
		warn("[SettingsUI] Features ScreenGui를 찾을 수 없음")
		return
	end

	settingsFrame = featuresGui:FindFirstChild("Settings")
	if not settingsFrame then
		warn("[SettingsUI] Settings를 찾을 수 없음")
		return
	end

	settingsFrame.Visible = false

	-- Close 버튼
	local header = settingsFrame:FindFirstChild("Header")
	if header then
		local closeBtn = header:FindFirstChild("Close")
		if closeBtn and closeBtn:IsA("GuiButton") then
			closeBtn.MouseButton1Click:Connect(function()
				SettingsUI.hide()
			end)
		end
	end

	-- ScrollingFrame 내 설정 항목 연결
	local scrollFrame = settingsFrame:FindFirstChild("ScrollingFrame")
	if not scrollFrame then return end

	-- Music 슬라이더
	local musicFrame = scrollFrame:FindFirstChild("Music")
	if musicFrame then
		SettingsUI._connectSlider(musicFrame, function(val)
			-- Music 볼륨 조절
		end)
	end

	-- SFX 슬라이더
	local sfxFrame = scrollFrame:FindFirstChild("SFX")
	if sfxFrame then
		SettingsUI._connectSlider(sfxFrame, function(val)
			SoundService.Volume = val
		end)
	end

	-- LowDetailMode 토글
	local lowDetailFrame = scrollFrame:FindFirstChild("LowDetailMode")
	if lowDetailFrame then
		SettingsUI._connectToggle(lowDetailFrame, function(isOn)
			Lighting.GlobalShadows = not isOn
		end)
	end

	-- Code 입력
	local codeFrame = scrollFrame:FindFirstChild("Code")
	if codeFrame then
		local textBox = codeFrame:FindFirstChildWhichIsA("TextBox")
		local submitBtn = codeFrame:FindFirstChildWhichIsA("TextButton") or codeFrame:FindFirstChildWhichIsA("ImageButton")
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

-- 슬라이더 연결 헬퍼 (디자인 UI의 슬라이더 구조에 맞춰 조정 필요)
function SettingsUI._connectSlider(frame, onChange)
	-- 디자인 UI 구조에 따라 슬라이더 바/핸들 찾아서 연결
	local slider = frame:FindFirstChildWhichIsA("TextButton") or frame:FindFirstChildWhichIsA("ImageButton")
	if slider then
		slider.MouseButton1Click:Connect(function()
			-- 간단 구현: 클릭 위치 기반 값 계산
			local mouse = Players.LocalPlayer:GetMouse()
			local fill = frame:FindFirstChild("Fill") or frame:FindFirstChildWhichIsA("Frame")
			if fill then
				local absPos = frame.AbsolutePosition.X
				local absSize = frame.AbsoluteSize.X
				local ratio = math.clamp((mouse.X - absPos) / absSize, 0, 1)
				onChange(ratio)
			end
		end)
	end
end

-- 토글 연결 헬퍼
function SettingsUI._connectToggle(frame, onChange)
	local toggleBtn = frame:FindFirstChildWhichIsA("TextButton") or frame:FindFirstChildWhichIsA("ImageButton")
	if toggleBtn then
		local isOn = false
		toggleBtn.MouseButton1Click:Connect(function()
			isOn = not isOn
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
