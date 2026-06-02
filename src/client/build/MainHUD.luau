-- MainHUD.luau
-- 디자인 UI 사용 (StarterGui/Normal)
-- Diamond, Money, Book, BulildMode, Shop, Weather, Buildings, Eggs, MyVillage, Shadow

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MainHUD = {}

local normalGui = nil
local _callbacks = {}
local _activeTab = nil
local _sideButtons = {}

-- Weather icon image IDs: add rbxassetid:// to imageId field
-- TODO: Replace empty imageId with actual asset IDs
local WEATHER_INFO = {
	Sunny        = { icon = "☀️", name = "Sunny",  desc = "It's a sunny day.", imageId = "" },
	Rain         = { icon = "🌧️", name = "Rain",    desc = "It's raining.", imageId = "" },
	Frost        = { icon = "❄️", name = "Frost",  desc = "A cold frost has settled.", imageId = "" },
	ThunderStorm = { icon = "⛈️", name = "Thunderstorm", desc = "Watch out for lightning!", imageId = "" },
}

function MainHUD.init(callbacks: {
	onTabChanged: (string?) -> (),
	onTeleport: ((string) -> ())?,
	onSettings: (() -> ())?,
})
	_callbacks = callbacks

	-- StarterGui에서 복사된 Normal ScreenGui 찾기
	normalGui = playerGui:WaitForChild("Normal", 10)
	if not normalGui then
		warn("[MainHUD] Normal ScreenGui를 찾을 수 없음")
		return
	end
	-- 좌측 사이드 버튼들은 Normal > Frame 안에 있음
	local sideFrame = normalGui:FindFirstChild("Frame")

	-- 클릭 연결 헬퍼 (ImageButton/TextButton이면 직접, 아니면 투명 버튼 추가)
	local function connectButton(element, callback)
		if not element then return end
		if element:IsA("GuiButton") then
			element.MouseButton1Click:Connect(callback)
		else
			-- ImageLabel/Frame 등이면 투명 버튼 추가
			local existing = element:FindFirstChild("_ClickArea")
			if not existing then
				local clickBtn = Instance.new("TextButton")
				clickBtn.Name = "_ClickArea"
				clickBtn.Size = UDim2.new(1, 0, 1, 0)
				clickBtn.BackgroundTransparency = 1
				clickBtn.Text = ""
				clickBtn.ZIndex = 10
				clickBtn.Parent = element
				clickBtn.MouseButton1Click:Connect(callback)
			end
		end
	end

	-- Button hover/click animation helper
	local function addButtonAnimation(element, tiltEnabled)
		if not element then return end
		local btn = element
		if not btn:IsA("GuiObject") then return end

		-- Store original
		local origSize = btn.Size
		local origRot = btn.Rotation

		local function onHover()
			local growSize = UDim2.new(origSize.X.Scale, origSize.X.Offset + 6, origSize.Y.Scale, origSize.Y.Offset + 6)
			TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = growSize,
				Rotation = if tiltEnabled then 5 else origRot,
			}):Play()
		end

		local function onLeave()
			TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
				Size = origSize,
				Rotation = origRot,
			}):Play()
		end

		local function onClick()
			local shrinkSize = UDim2.new(origSize.X.Scale, origSize.X.Offset - 4, origSize.Y.Scale, origSize.Y.Offset - 4)
			TweenService:Create(btn, TweenInfo.new(0.05, Enum.EasingStyle.Quad), {
				Size = shrinkSize,
			}):Play()
			task.delay(0.05, function()
				TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = origSize,
				}):Play()
			end)
		end

		btn.MouseEnter:Connect(onHover)
		btn.MouseLeave:Connect(onLeave)

		-- Find clickable child for click feedback
		local clickTarget = btn
		if not btn:IsA("GuiButton") then
			clickTarget = btn:FindFirstChild("_ClickArea") or btn:FindFirstChildWhichIsA("GuiButton")
		end
		if clickTarget and clickTarget:IsA("GuiButton") then
			clickTarget.MouseButton1Down:Connect(onClick)
		end
	end

	-- 좌측 사이드 버튼 연결 (Normal > Frame 안에 있음)
	local bookBtn = sideFrame and sideFrame:FindFirstChild("Pets")  -- Pets = 도감(베타)
	local buildBtn = sideFrame and sideFrame:FindFirstChild("BulildMode")
	local shopBtn = sideFrame and sideFrame:FindFirstChild("Shop")

	if bookBtn then
		_sideButtons["collection"] = bookBtn
		-- 베타: 도감 비활성화 (회색 처리 + "제작중" 메시지)
		if bookBtn:IsA("ImageLabel") or bookBtn:IsA("ImageButton") then
			bookBtn.ImageTransparency = 0.5
		end
		connectButton(bookBtn, function()
			MainHUD.showMessage("Collection is under construction.")
		end)
	end

	if buildBtn then
		_sideButtons["build"] = buildBtn
		connectButton(buildBtn, function()
			if _activeTab == "build" then
				MainHUD.setActiveTab(nil)
			else
				MainHUD.setActiveTab("build")
			end
		end)
	end

	if shopBtn then
		_sideButtons["shop"] = shopBtn
		connectButton(shopBtn, function()
			if _activeTab == "shop" then
				MainHUD.setActiveTab(nil)
			else
				MainHUD.setActiveTab("shop")
			end
		end)
	end

	-- 텔레포트 버튼 연결
	local buildingsBtn = normalGui:FindFirstChild("Buildings")
	local eggsBtn = normalGui:FindFirstChild("Eggs")
	local villageBtn = normalGui:FindFirstChild("MyVillage")

	local function connectTeleport(element, destination)
		if not element then return end
		-- 자기 자신이 버튼이면 직접 연결
		if element:IsA("GuiButton") then
			element.MouseButton1Click:Connect(function()
				if _callbacks.onTeleport then _callbacks.onTeleport(destination) end
			end)
		else
			-- 자식에서 버튼 찾기, 없으면 투명 TextButton 추가
			local btn = element:FindFirstChildWhichIsA("TextButton") or element:FindFirstChildWhichIsA("ImageButton")
			if btn then
				btn.MouseButton1Click:Connect(function()
					if _callbacks.onTeleport then _callbacks.onTeleport(destination) end
				end)
			else
				local clickBtn = Instance.new("TextButton")
				clickBtn.Name = "ClickArea"
				clickBtn.Size = UDim2.new(1, 0, 1, 0)
				clickBtn.BackgroundTransparency = 1
				clickBtn.Text = ""
				clickBtn.ZIndex = 10
				clickBtn.Parent = element
				clickBtn.MouseButton1Click:Connect(function()
					if _callbacks.onTeleport then _callbacks.onTeleport(destination) end
				end)
			end
		end
	end

	connectTeleport(buildingsBtn, "buildings")
	connectTeleport(eggsBtn, "eggs")
	connectTeleport(villageBtn, "village")

	-- Setting 버튼 → Settings UI 열기
	local settingBtn = normalGui:FindFirstChild("Setting")
	if settingBtn then
		connectButton(settingBtn, function()
			if _callbacks.onSettings then
				_callbacks.onSettings()
			end
		end)
	end

	-- Apply button animations
	-- Side buttons: tilt + grow
	addButtonAnimation(bookBtn, true)
	addButtonAnimation(buildBtn, true)
	addButtonAnimation(shopBtn, true)
	addButtonAnimation(settingBtn, true)
	-- Teleport buttons: size only, no tilt
	addButtonAnimation(buildingsBtn, false)
	addButtonAnimation(eggsBtn, false)
	addButtonAnimation(villageBtn, false)

	-- 날씨 표시: Weather > Info
	local weatherBtn = normalGui:FindFirstChild("Weather")
	if weatherBtn then
		local infoFrame = weatherBtn:FindFirstChild("Info")
		if infoFrame then
			infoFrame.Visible = false
			-- 호버로 Info 표시
			if weatherBtn:IsA("GuiButton") or weatherBtn:IsA("ImageButton") then
				weatherBtn.MouseEnter:Connect(function()
					infoFrame.Visible = true
				end)
				weatherBtn.MouseLeave:Connect(function()
					infoFrame.Visible = false
				end)
			end
		end
	end

	-- 시간 업데이트 루프
	RunService.Heartbeat:Connect(function()
		-- Money 텍스트 업데이트는 updateCoins에서 처리
		-- 시간은 Weather Info에 표시하거나, 별도 처리 불필요 (TimeDisplay 대체)
	end)
end

function MainHUD.setActiveTab(tabId: string?)
	_activeTab = tabId

	if _callbacks.onTabChanged then
		_callbacks.onTabChanged(tabId)
	end
end

function MainHUD.getActiveTab(): string?
	return _activeTab
end

-- 재화 펄스 애니메이션 (프레임 전체 커졌다 줄어듦)
local _prevCoins = nil
local _prevGems = nil

local function pulseFrame(frame: GuiObject)
	local origSize = frame:GetAttribute("_origSize")
	if not origSize then
		origSize = frame.Size
		frame:SetAttribute("_origSize", string.format("%.4f,%d,%.4f,%d", origSize.X.Scale, origSize.X.Offset, origSize.Y.Scale, origSize.Y.Offset))
	else
		local p = string.split(origSize, ",")
		origSize = UDim2.new(tonumber(p[1]), tonumber(p[2]), tonumber(p[3]), tonumber(p[4]))
	end

	-- 커지기
	local expandSize = UDim2.new(origSize.X.Scale, origSize.X.Offset + 8, origSize.Y.Scale, origSize.Y.Offset + 8)
	TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
		Size = expandSize
	}):Play()

	-- 줄어들기
	task.delay(0.1, function()
		TweenService:Create(frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			Size = origSize
		}):Play()
	end)
end

-- Shadow 크기를 텍스트에 맞게 동기화
local function syncShadow(frame: GuiObject)
	local shadow = frame:FindFirstChild("Shadow")
	local textLabel = frame:FindFirstChild("TextLabel")
	if not shadow or not textLabel then return end

	-- TextLabel의 TextBounds로 Shadow 너비 계산 (프레임은 건드리지 않음)
	task.delay(0.1, function()
		if not textLabel.Parent then return end
		local textWidth = textLabel.TextBounds.X
		if textWidth <= 0 then return end
		local iconSpace = 30 -- 아이콘(💎/$) 공간
		local padding = 15
		local newWidth = textWidth + iconSpace + padding
		-- Shadow 높이는 유지, 너비만 변경
		shadow.Size = UDim2.new(0, newWidth, shadow.Size.Y.Scale, shadow.Size.Y.Offset)
	end)
end

-- 재화 업데이트
function MainHUD.updateCoins(coins: number)
	if not normalGui then return end
	local moneyFrame = normalGui:FindFirstChild("Money")
	if moneyFrame then
		local textLabel = moneyFrame:FindFirstChild("TextLabel")
		if textLabel then
			textLabel.Text = "$   " .. tostring(coins)
		end
		syncShadow(moneyFrame)
		if _prevCoins ~= nil and _prevCoins ~= coins then
			pulseFrame(moneyFrame)
		end
		_prevCoins = coins
	end
end

function MainHUD.updateGems(gems: number)
	if not normalGui then return end
	local diamondFrame = normalGui:FindFirstChild("Diamond")
	if diamondFrame then
		local textLabel = diamondFrame:FindFirstChild("TextLabel")
		if textLabel then
			textLabel.Text = tostring(gems)
		end
		syncShadow(diamondFrame)
		if _prevGems ~= nil and _prevGems ~= gems then
			pulseFrame(diamondFrame)
		end
		_prevGems = gems
	end
end

-- 날씨 업데이트
function MainHUD.updateWeather(weatherType: string)
	if not normalGui then return end
	local info = WEATHER_INFO[weatherType]
	if not info then return end

	local weatherFrame = normalGui:FindFirstChild("Weather")
	if not weatherFrame then return end

	-- 날씨 아이콘 이미지: Constants.WEATHER_ICONS 우선, 폴백 imageId
	local iconId = (Constants.WEATHER_ICONS and Constants.WEATHER_ICONS[weatherType]) or info.imageId or ""
	if weatherFrame:IsA("ImageButton") or weatherFrame:IsA("ImageLabel") then
		if iconId ~= "" then
			weatherFrame.Image = iconId
		end
	end

	-- Weather 직속 TextLabel 업데이트 (날씨 이름)
	local weatherText = weatherFrame:FindFirstChild("TextLabel")
	if weatherText and weatherText:IsA("TextLabel") then
		weatherText.Text = info.name
	end

	-- Weather Info 프레임에 텍스트 업데이트
	local infoFrame = weatherFrame:FindFirstChild("Info")
	if infoFrame then
		local textLabel = infoFrame:FindFirstChild("TextLabel")
		if textLabel then
			textLabel.Text = info.name .. " - " .. info.desc
		end
	end
end

-- Message system: 미리 만들어둔 Normal.Message TextLabel을 재사용 (Studio에서 디자인된 박스)
-- 한 번에 하나의 메시지만 표시. 새 메시지가 오면 직전 메시지 페이드 취소 후 즉시 표시.
local _msgBaseStyle = nil
local _msgState = { token = nil, cancelDelay = nil }

local function captureMsgBaseStyle(msg)
	if _msgBaseStyle then return end
	local stroke = msg:FindFirstChildWhichIsA("UIStroke")
	_msgBaseStyle = {
		bg = msg.BackgroundTransparency,
		text = msg.TextTransparency,
		stroke = stroke and stroke.Transparency or 0,
	}
end

function MainHUD.showMessage(text: string, duration: number?)
	if not normalGui then return end
	local msg = normalGui:FindFirstChild("Message")
	if not msg or not msg:IsA("TextLabel") then return end
	captureMsgBaseStyle(msg)

	duration = duration or 2

	-- 이전 메시지 페이드 타이머 취소
	if _msgState.cancelDelay then
		task.cancel(_msgState.cancelDelay)
		_msgState.cancelDelay = nil
	end

	local token = {}
	_msgState.token = token
	local stroke = msg:FindFirstChildWhichIsA("UIStroke")

	msg.Text = text
	msg.Visible = true
	-- 페이드 인 시작 (투명)
	msg.TextTransparency = 1
	msg.BackgroundTransparency = 1
	if stroke then stroke.Transparency = 1 end

	-- 페이드 인 → 원래 스타일로
	TweenService:Create(msg, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = _msgBaseStyle.text,
		BackgroundTransparency = _msgBaseStyle.bg,
	}):Play()
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = _msgBaseStyle.stroke }):Play()
	end

	-- duration 후 페이드 아웃
	_msgState.cancelDelay = task.delay(duration, function()
		if _msgState.token ~= token or not msg.Parent then return end
		local fadeOut = TweenService:Create(msg, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			if _msgState.token == token then
				msg.Visible = false
				-- 다음 표시를 위해 base 스타일로 복원
				msg.TextTransparency = _msgBaseStyle.text
				msg.BackgroundTransparency = _msgBaseStyle.bg
				if stroke then stroke.Transparency = _msgBaseStyle.stroke end
				_msgState.token = nil
				_msgState.cancelDelay = nil
			end
		end)
	end)
end

-- Shadow (오버레이) 표시/숨김
function MainHUD.showShadow()
	if not normalGui then return end
	local shadow = normalGui:FindFirstChild("Shadow")
	if shadow then shadow.Visible = true end
end

function MainHUD.hideShadow()
	if not normalGui then return end
	local shadow = normalGui:FindFirstChild("Shadow")
	if shadow then shadow.Visible = false end
end

-- 빌드모드: 다른 UI 숨김 (빌드 버튼만 유지 + 메시지)
function MainHUD.hideBuildModeUI()
	if not normalGui then return end
	local buildBtn = _sideButtons["build"]
	local sideFrame = buildBtn and buildBtn.Parent

	for _, child in normalGui:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "_MessageContainer" and child.Visible then
			child:SetAttribute("_wasHidden", true)
			child.Visible = false
		end
	end

	-- 빌드 버튼만 다시 보이기
	if sideFrame then
		sideFrame.Visible = true
		-- 사이드 Frame 안의 다른 버튼 숨기기
		for _, btn in sideFrame:GetChildren() do
			if btn:IsA("GuiObject") and btn ~= buildBtn then
				btn:SetAttribute("_sideHidden", true)
				btn.Visible = false
			end
		end
	end
end

-- 빌드모드 종료: UI 복원 (숨겼던 것 다시 보이기)
function MainHUD.restoreBuildModeUI()
	if not normalGui then return end
	for _, child in normalGui:GetChildren() do
		if child:IsA("GuiObject") and child:GetAttribute("_wasHidden") then
			child.Visible = true
			child:SetAttribute("_wasHidden", nil)
		end
	end
	-- 사이드 버튼 복원
	local buildBtn = _sideButtons["build"]
	local sideFrame = buildBtn and buildBtn.Parent
	if sideFrame then
		for _, btn in sideFrame:GetChildren() do
			if btn:IsA("GuiObject") and btn:GetAttribute("_sideHidden") then
				btn.Visible = true
				btn:SetAttribute("_sideHidden", nil)
			end
		end
	end
end

-- Build mode button visual state
function MainHUD.setBuildButtonEnabled(enabled: boolean)
	local btn = _sideButtons["build"]
	if not btn then return end
	if btn:IsA("ImageLabel") or btn:IsA("ImageButton") then
		btn.ImageTransparency = if enabled then 0 else 0.5
	end
end

function MainHUD.destroy()
	-- 디자인 UI는 파괴하지 않음
end

return MainHUD
