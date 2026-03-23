-- PetDetailUI.luau
-- 펫 상세 정보 UI: 레벨, 스탯, 돌연변이, 상태 표시

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PetDetailUI = {}

local screenGui = nil
local overlay = nil
local mainFrame = nil
local _visible = false

local PANEL_WIDTH = 280
local PANEL_HEIGHT = 360

function PetDetailUI.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PetDetailUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 32
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
		PetDetailUI.hide()
	end)

	-- 메인 패널
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "PetDetailPanel"
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
	stroke.Color = Color3.fromRGB(100, 180, 100)
	stroke.Thickness = 1.5
	stroke.Parent = mainFrame

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -32, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 12
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.AutoButtonColor = true
	closeBtn.ZIndex = 3
	closeBtn.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		PetDetailUI.hide()
	end)
end

-- 펫 데이터로 상세 UI 표시
function PetDetailUI.show(petData: { [string]: any })
	if not mainFrame then return end
	_visible = true

	-- 기존 동적 콘텐츠 제거
	for _, child in mainFrame:GetChildren() do
		if child:GetAttribute("_dynamic") then
			child:Destroy()
		end
	end

	local y = 12

	-- 펫 이름
	local nameLabel = PetDetailUI._label(mainFrame, petData.petName or "???", y, 18, Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255))
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Position = UDim2.new(0, 12, 0, y)
	nameLabel.Size = UDim2.new(1, -50, 0, 24)
	y = y + 30

	-- 등급
	local rarityColor = Constants.RARITY_COLORS[petData.rarity] or Color3.fromRGB(180, 180, 180)
	local rarityLabel = PetDetailUI._label(mainFrame, petData.rarity or "일반", y, 12, Enum.Font.GothamBold, rarityColor)
	y = y + 20

	-- 구분선
	local sep1 = PetDetailUI._separator(mainFrame, y)
	y = y + 8

	-- 기본 정보
	local infoLines = {
		{ "유형", Constants.PetType[petData.petType] or petData.petType or "?" },
		{ "종족", petData.race or "?" },
		{ "사이즈", petData.size or "?" },
		{ "무게", string.format("%.1fkg", petData.weight or 0) },
		{ "레벨", "Lv." .. (petData.level or 1) },
		{ "경험치", tostring(petData.xp or 0) .. " / " .. tostring(BalanceConfig.Pet.XP_REQUIRED[petData.level or 1] or "MAX") },
		{ "상태", petData.state or "Idle" },
	}

	for _, info in infoLines do
		PetDetailUI._infoRow(mainFrame, info[1], info[2], y)
		y = y + 20
	end

	-- 구분선
	PetDetailUI._separator(mainFrame, y)
	y = y + 8

	-- 특성
	local traitsText = "없음"
	if petData.traits and #petData.traits > 0 then
		traitsText = table.concat(petData.traits, ", ")
	end
	PetDetailUI._infoRow(mainFrame, "특성", traitsText, y)
	y = y + 24

	-- 돌연변이
	local mutLabel = PetDetailUI._label(mainFrame, "돌연변이", y, 12, Enum.Font.GothamBold, Color3.fromRGB(200, 200, 210))
	y = y + 18

	if petData.mutations and #petData.mutations > 0 then
		for _, mut in petData.mutations do
			local mutName = Constants.MUTATION_NAMES[mut] or mut
			local mutColor = Constants.MUTATION_COLORS[mut] or Color3.fromRGB(200, 200, 200)
			local mutLbl = PetDetailUI._label(mainFrame, "  " .. mutName, y, 11, Enum.Font.Gotham, mutColor)
			y = y + 16
		end
	else
		PetDetailUI._label(mainFrame, "  없음", y, 11, Enum.Font.Gotham, Color3.fromRGB(120, 120, 130))
		y = y + 16
	end

	-- 패널 높이 조정
	mainFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, math.max(PANEL_HEIGHT, y + 16))
	mainFrame.Position = UDim2.new(0.5, -PANEL_WIDTH / 2, 0.5, -math.max(PANEL_HEIGHT, y + 16) / 2)

	overlay.Visible = true
	mainFrame.Visible = true
end

function PetDetailUI._label(parent, text, y, size, font, color): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 0, size + 4)
	label.Position = UDim2.new(0, 12, 0, y)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextSize = size
	label.Font = font
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label:SetAttribute("_dynamic", true)
	label.Parent = parent
	return label
end

function PetDetailUI._infoRow(parent, key, value, y)
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.new(0, 80, 0, 16)
	keyLabel.Position = UDim2.new(0, 12, 0, y)
	keyLabel.BackgroundTransparency = 1
	keyLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	keyLabel.TextSize = 11
	keyLabel.Font = Enum.Font.Gotham
	keyLabel.Text = key
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel:SetAttribute("_dynamic", true)
	keyLabel.Parent = parent

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, -104, 0, 16)
	valLabel.Position = UDim2.new(0, 92, 0, y)
	valLabel.BackgroundTransparency = 1
	valLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valLabel.TextSize = 11
	valLabel.Font = Enum.Font.GothamBold
	valLabel.Text = value
	valLabel.TextXAlignment = Enum.TextXAlignment.Left
	valLabel:SetAttribute("_dynamic", true)
	valLabel.Parent = parent
end

function PetDetailUI._separator(parent, y): Frame
	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, -24, 0, 1)
	sep.Position = UDim2.new(0, 12, 0, y)
	sep.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	sep.BorderSizePixel = 0
	sep:SetAttribute("_dynamic", true)
	sep.Parent = parent
	return sep
end

function PetDetailUI.hide()
	if not mainFrame then return end
	_visible = false
	overlay.Visible = false
	mainFrame.Visible = false
end

function PetDetailUI.isVisible(): boolean
	return _visible
end

function PetDetailUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return PetDetailUI
