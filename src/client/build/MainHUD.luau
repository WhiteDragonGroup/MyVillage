-- MainHUD.luau
-- 디자인 UI 사용 (StarterGui/Normal)
-- Diamond, Money, Book, BulildMode, Shop, Weather, Buildings, Eggs, MyVillage, Shadow

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MainHUD = {}

local normalGui = nil
local _callbacks = {}
local _activeTab = nil
local _sideButtons = {}

local WEATHER_INFO = {
	Sunny        = { icon = "☀️", name = "맑음",  desc = "화창한 날씨입니다." },
	Rain         = { icon = "🌧️", name = "비",    desc = "비가 내리고 있습니다." },
	Frost        = { icon = "❄️", name = "서리",  desc = "차가운 서리가 내렸습니다." },
	ThunderStorm = { icon = "⛈️", name = "뇌우", desc = "번개를 조심하세요!" },
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
	-- 좌측 사이드 버튼 연결 (Book=도감, BulildMode=빌드, Shop=상점)
	local bookBtn = normalGui:FindFirstChild("Book")
	local buildBtn = normalGui:FindFirstChild("BulildMode")
	local shopBtn = normalGui:FindFirstChild("Shop")

	if bookBtn then
		_sideButtons["collection"] = bookBtn
		bookBtn.MouseButton1Click:Connect(function()
			if _activeTab == "collection" then
				MainHUD.setActiveTab(nil)
			else
				MainHUD.setActiveTab("collection")
			end
		end)
	end

	if buildBtn then
		_sideButtons["build"] = buildBtn
		buildBtn.MouseButton1Click:Connect(function()
			if _activeTab == "build" then
				MainHUD.setActiveTab(nil)
			else
				MainHUD.setActiveTab("build")
			end
		end)
	end

	if shopBtn then
		_sideButtons["shop"] = shopBtn
		shopBtn.MouseButton1Click:Connect(function()
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

-- 재화 업데이트
function MainHUD.updateCoins(coins: number)
	if not normalGui then return end
	local moneyFrame = normalGui:FindFirstChild("Money")
	if moneyFrame then
		local textLabel = moneyFrame:FindFirstChild("TextLabel")
		if textLabel then
			textLabel.Text = tostring(coins)
		end
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
	end
end

-- 날씨 업데이트
function MainHUD.updateWeather(weatherType: string)
	if not normalGui then return end
	local info = WEATHER_INFO[weatherType]
	if not info then return end

	local weatherFrame = normalGui:FindFirstChild("Weather")
	if not weatherFrame then return end

	-- Weather Info 프레임에 텍스트 업데이트
	local infoFrame = weatherFrame:FindFirstChild("Info")
	if infoFrame then
		local textLabel = infoFrame:FindFirstChild("TextLabel")
		if textLabel then
			textLabel.Text = info.name .. " - " .. info.desc
		end
	end
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

function MainHUD.destroy()
	-- 디자인 UI는 파괴하지 않음
end

return MainHUD
