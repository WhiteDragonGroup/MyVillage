-- MainHUD.luau
-- 화면 좌측 상단: "Your Village" 타이틀 + 탭 버튼 (빌드/상점/도감)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MainHUD = {}

local screenGui = nil
local _callbacks = {}
local _activeTab = nil -- "build" | "shop" | "collection" | nil
local _tabButtons = {}

local TAB_DEFS = {
	{ id = "build",      label = "빌드",  icon = "🏗️", color = Color3.fromRGB(50, 150, 50) },
	{ id = "shop",       label = "상점",  icon = "🛒", color = Color3.fromRGB(200, 150, 50) },
	{ id = "collection", label = "도감",  icon = "📖", color = Color3.fromRGB(80, 120, 200) },
}

function MainHUD.init(callbacks: { onTabChanged: (string?) -> (), onSettings: (() -> ())? })
	_callbacks = callbacks

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHUD"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 3
	screenGui.Parent = playerGui

	-- 타이틀 프레임
	local titleFrame = Instance.new("Frame")
	titleFrame.Name = "TitleFrame"
	titleFrame.Size = UDim2.new(0, 200, 0, 36)
	titleFrame.Position = UDim2.new(0, 10, 0, 10)
	titleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	titleFrame.BackgroundTransparency = 0.15
	titleFrame.BorderSizePixel = 0
	titleFrame.Parent = screenGui

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 10)
	titleCorner.Parent = titleFrame

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(100, 180, 100)
	titleStroke.Thickness = 1.5
	titleStroke.Parent = titleFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -16, 1, 0)
	titleLabel.Position = UDim2.new(0, 8, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "Your Village"
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleFrame

	-- 설정 버튼 (타이틀 우측)
	local settingsBtn = Instance.new("TextButton")
	settingsBtn.Name = "SettingsBtn"
	settingsBtn.Size = UDim2.new(0, 30, 0, 30)
	settingsBtn.Position = UDim2.new(1, -36, 0.5, -15)
	settingsBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	settingsBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
	settingsBtn.TextSize = 16
	settingsBtn.Font = Enum.Font.GothamBold
	settingsBtn.Text = "..."
	settingsBtn.AutoButtonColor = true
	settingsBtn.Parent = titleFrame

	local settingsCorner = Instance.new("UICorner")
	settingsCorner.CornerRadius = UDim.new(0, 8)
	settingsCorner.Parent = settingsBtn

	settingsBtn.MouseButton1Click:Connect(function()
		if _callbacks.onSettings then
			_callbacks.onSettings()
		end
	end)

	-- 탭 버튼들
	local tabFrame = Instance.new("Frame")
	tabFrame.Name = "TabFrame"
	tabFrame.Size = UDim2.new(0, 240, 0, 44)
	tabFrame.Position = UDim2.new(0, 10, 0, 52)
	tabFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	tabFrame.BackgroundTransparency = 0.15
	tabFrame.BorderSizePixel = 0
	tabFrame.Parent = screenGui

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 10)
	tabCorner.Parent = tabFrame

	local tabStroke = Instance.new("UIStroke")
	tabStroke.Color = Color3.fromRGB(70, 70, 90)
	tabStroke.Thickness = 1
	tabStroke.Parent = tabFrame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Parent = tabFrame

	local tabPadding = Instance.new("UIPadding")
	tabPadding.PaddingLeft = UDim.new(0, 6)
	tabPadding.PaddingRight = UDim.new(0, 6)
	tabPadding.Parent = tabFrame

	for i, tabDef in TAB_DEFS do
		local btn = Instance.new("TextButton")
		btn.Name = tabDef.id
		btn.Size = UDim2.new(0, 70, 0, 34)
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
		btn.TextColor3 = Color3.fromRGB(200, 200, 210)
		btn.TextSize = 13
		btn.Font = Enum.Font.GothamBold
		btn.Text = tabDef.label
		btn.AutoButtonColor = true
		btn.LayoutOrder = i
		btn.Parent = tabFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		_tabButtons[tabDef.id] = { button = btn, def = tabDef }

		btn.MouseButton1Click:Connect(function()
			if _activeTab == tabDef.id then
				-- 같은 탭 다시 클릭 → 닫기
				MainHUD.setActiveTab(nil)
			else
				MainHUD.setActiveTab(tabDef.id)
			end
		end)
	end
end

function MainHUD.setActiveTab(tabId: string?)
	_activeTab = tabId

	for id, info in _tabButtons do
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

function MainHUD.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return MainHUD