-- AdminUI.luau
-- 어드민 테스트 패널 UI (채팅 /admin 으로 열기)

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AdminUI = {}

local screenGui = nil
local mainFrame = nil
local _visible = false

local PANEL_WIDTH = 260
local PANEL_HEIGHT = 380

local BUTTONS = {
	{ label = "Add All Buildings", cmd = "/addallbuildings" },
	{ label = "Add All Pets", cmd = "/addallpets" },
	{ label = "Add All Eggs", cmd = "/addalleggs" },
	{ label = "Add 10K Coins", cmd = "/addcoins 10000" },
	{ label = "Set Coins 200", cmd = "/setcoins 200" },
	{ label = "Restock Shop", cmd = "/restock" },
	{ label = "Set Day", cmd = "/settime 14" },
	{ label = "Set Night", cmd = "/settime 2" },
	{ label = "Reset Data", cmd = "/reset" },
}

function AdminUI.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AdminUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "AdminPanel"
	mainFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
	mainFrame.Position = UDim2.new(1, -PANEL_WIDTH - 10, 0.5, -PANEL_HEIGHT / 2)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	mainFrame.BackgroundTransparency = 0.1
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 100, 100)
	stroke.Thickness = 2
	stroke.Parent = mainFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 100, 100)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Text = "Admin Panel"
	title.Parent = mainFrame

	-- Close
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -28, 0, 3)
	closeBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 12
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.AutoButtonColor = true
	closeBtn.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		AdminUI.hide()
	end)

	-- Buttons
	local y = 36
	for _, btn in BUTTONS do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -20, 0, 30)
		button.Position = UDim2.new(0, 10, 0, y)
		button.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 12
		button.Font = Enum.Font.GothamBold
		button.Text = btn.label
		button.AutoButtonColor = true
		button.Parent = mainFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = button

		button.MouseButton1Click:Connect(function()
			-- 채팅으로 명령어 실행
			player:Chat(btn.cmd)
		end)

		y = y + 34
	end

	-- /admin 채팅으로 열기
	player.Chatted:Connect(function(msg)
		if msg == "/admin" then
			AdminUI.toggle()
		end
	end)
end

function AdminUI.show()
	if mainFrame then
		_visible = true
		mainFrame.Visible = true
	end
end

function AdminUI.hide()
	if mainFrame then
		_visible = false
		mainFrame.Visible = false
	end
end

function AdminUI.toggle()
	if _visible then
		AdminUI.hide()
	else
		AdminUI.show()
	end
end

function AdminUI.isVisible()
	return _visible
end

return AdminUI
