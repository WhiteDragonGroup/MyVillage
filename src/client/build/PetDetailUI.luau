-- PetDetailUI.luau
-- 펫 상세 정보 UI (기획서 기준)
-- 아이콘, 이름, 희귀도, 설명, 무게, 하는 일, 돌연변이, 버프, 레벨/경험치

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

local PANEL_WIDTH = 320
local PANEL_HEIGHT = 420

function PetDetailUI.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PetDetailUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 32
	screenGui.Parent = playerGui

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

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "PetDetailPanel"
	mainFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
	mainFrame.Position = UDim2.new(0.5, -PANEL_WIDTH / 2, 0.5, -PANEL_HEIGHT / 2)
	mainFrame.BackgroundColor3 = Color3.fromRGB(45, 35, 55)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 80, 130)
	stroke.Thickness = 2
	stroke.Parent = mainFrame

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.new(0, 26, 0, 26)
	closeBtn.Position = UDim2.new(1, -32, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 13
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.AutoButtonColor = true
	closeBtn.ZIndex = 3
	closeBtn.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		PetDetailUI.hide()
	end)
end

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

	-- 이름 + 희귀도
	local rarityColor = Constants.RARITY_COLORS[petData.rarity] or Color3.fromRGB(180, 180, 180)

	local nameLabel = PetDetailUI._makeLabel(mainFrame, petData.petName or "???", y, 17, Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255))
	nameLabel.Size = UDim2.new(1, -50, 0, 22)
	y = y + 24

	local rarityLabel = PetDetailUI._makeLabel(mainFrame, petData.rarity or "일반", y, 12, Enum.Font.GothamBold, rarityColor)
	y = y + 18

	-- 구분선
	PetDetailUI._makeSep(mainFrame, y)
	y = y + 8

	-- 설명
	local petType = petData.petType or "Construction"
	local petTypeKor = Constants.PetType[petType] or petType
	local descLabel = PetDetailUI._makeLabel(mainFrame, petData.petName .. " - " .. petTypeKor .. " 전문 펫입니다.", y, 10, Enum.Font.Gotham, Color3.fromRGB(180, 170, 190))
	descLabel.Size = UDim2.new(1, -24, 0, 30)
	descLabel.TextWrapped = true
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	y = y + 34

	PetDetailUI._makeSep(mainFrame, y)
	y = y + 8

	-- 기본 정보 2열
	local size = petData.size or "Small"
	local stdWeight = BalanceConfig.Pet.SIZE_STANDARD_WEIGHT[size] or 5

	PetDetailUI._makeRow(mainFrame, "무게", string.format("%.1fkg", petData.weight or stdWeight), y)
	PetDetailUI._makeRow2(mainFrame, "하는 일들", petTypeKor, y)
	y = y + 20

	PetDetailUI._makeRow(mainFrame, "종족", petData.race or "?", y)
	PetDetailUI._makeRow2(mainFrame, "사이즈", size, y)
	y = y + 24

	PetDetailUI._makeSep(mainFrame, y)
	y = y + 8

	-- 돌연변이 목록
	local mutTitle = PetDetailUI._makeLabel(mainFrame, "돌연변이 목록", y, 11, Enum.Font.GothamBold, Color3.fromRGB(200, 190, 220))
	y = y + 16

	if petData.mutations and #petData.mutations > 0 then
		for _, mut in petData.mutations do
			local mutName = Constants.MUTATION_NAMES[mut] or mut
			local mutColor = Constants.MUTATION_COLORS[mut] or Color3.fromRGB(200, 200, 200)
			PetDetailUI._makeLabel(mainFrame, "  " .. mutName, y, 10, Enum.Font.Gotham, mutColor)
			y = y + 14
		end
	else
		PetDetailUI._makeLabel(mainFrame, "  없음", y, 10, Enum.Font.Gotham, Color3.fromRGB(120, 110, 130))
		y = y + 14
	end

	y = y + 4

	-- 버프 목록
	local buffTitle = PetDetailUI._makeLabel(mainFrame, "버프 목록", y, 11, Enum.Font.GothamBold, Color3.fromRGB(200, 190, 220))
	y = y + 16

	if petData.traits and #petData.traits > 0 then
		for _, trait in petData.traits do
			PetDetailUI._makeLabel(mainFrame, "  " .. trait, y, 10, Enum.Font.Gotham, Color3.fromRGB(180, 220, 180))
			y = y + 14
		end
	else
		PetDetailUI._makeLabel(mainFrame, "  없음", y, 10, Enum.Font.Gotham, Color3.fromRGB(120, 110, 130))
		y = y + 14
	end

	y = y + 4
	PetDetailUI._makeSep(mainFrame, y)
	y = y + 8

	-- 레벨 / 경험치 바
	local level = petData.level or 1
	local xp = petData.xp or 0
	local xpRequired = BalanceConfig.Pet.XP_REQUIRED[level] or 0

	PetDetailUI._makeLabel(mainFrame, "레벨 " .. level, y, 12, Enum.Font.GothamBold, Color3.fromRGB(255, 220, 100))

	-- EXP 바 (우측)
	local expText = xp .. " / " .. (xpRequired > 0 and xpRequired or "MAX") .. " EXP"
	local expLabel = PetDetailUI._makeLabel(mainFrame, expText, y, 10, Enum.Font.Gotham, Color3.fromRGB(180, 180, 200))
	expLabel.Position = UDim2.new(0, 80, 0, y)
	expLabel.Size = UDim2.new(1, -92, 0, 14)
	expLabel.TextXAlignment = Enum.TextXAlignment.Right
	y = y + 18

	-- EXP 바 비주얼
	local expBg = Instance.new("Frame")
	expBg.Size = UDim2.new(1, -24, 0, 10)
	expBg.Position = UDim2.new(0, 12, 0, y)
	expBg.BackgroundColor3 = Color3.fromRGB(60, 50, 70)
	expBg:SetAttribute("_dynamic", true)
	expBg.Parent = mainFrame

	local expBgCorner = Instance.new("UICorner")
	expBgCorner.CornerRadius = UDim.new(1, 0)
	expBgCorner.Parent = expBg

	local expRatio = if xpRequired > 0 then math.clamp(xp / xpRequired, 0, 1) else 1
	local expFill = Instance.new("Frame")
	expFill.Size = UDim2.new(expRatio, 0, 1, 0)
	expFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	expFill.Parent = expBg

	local expFillCorner = Instance.new("UICorner")
	expFillCorner.CornerRadius = UDim.new(1, 0)
	expFillCorner.Parent = expFill

	y = y + 18

	-- 패널 높이 조정
	mainFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, math.max(PANEL_HEIGHT, y + 12))
	mainFrame.Position = UDim2.new(0.5, -PANEL_WIDTH / 2, 0.5, -math.max(PANEL_HEIGHT, y + 12) / 2)

	overlay.Visible = true
	mainFrame.Visible = true
end

-- 헬퍼: 라벨
function PetDetailUI._makeLabel(parent, text, y, size, font, color): TextLabel
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

-- 헬퍼: 정보 행 (좌측)
function PetDetailUI._makeRow(parent, key, value, y)
	local kl = Instance.new("TextLabel")
	kl.Size = UDim2.new(0, 50, 0, 14)
	kl.Position = UDim2.new(0, 12, 0, y)
	kl.BackgroundTransparency = 1
	kl.TextColor3 = Color3.fromRGB(140, 130, 160)
	kl.TextSize = 10
	kl.Font = Enum.Font.Gotham
	kl.Text = key
	kl.TextXAlignment = Enum.TextXAlignment.Left
	kl:SetAttribute("_dynamic", true)
	kl.Parent = parent

	local vl = Instance.new("TextLabel")
	vl.Size = UDim2.new(0, 80, 0, 14)
	vl.Position = UDim2.new(0, 60, 0, y)
	vl.BackgroundTransparency = 1
	vl.TextColor3 = Color3.fromRGB(255, 255, 255)
	vl.TextSize = 10
	vl.Font = Enum.Font.GothamBold
	vl.Text = value
	vl.TextXAlignment = Enum.TextXAlignment.Left
	vl:SetAttribute("_dynamic", true)
	vl.Parent = parent
end

-- 헬퍼: 정보 행 (우측)
function PetDetailUI._makeRow2(parent, key, value, y)
	local kl = Instance.new("TextLabel")
	kl.Size = UDim2.new(0, 60, 0, 14)
	kl.Position = UDim2.new(0.5, 4, 0, y)
	kl.BackgroundTransparency = 1
	kl.TextColor3 = Color3.fromRGB(140, 130, 160)
	kl.TextSize = 10
	kl.Font = Enum.Font.Gotham
	kl.Text = key
	kl.TextXAlignment = Enum.TextXAlignment.Left
	kl:SetAttribute("_dynamic", true)
	kl.Parent = parent

	local vl = Instance.new("TextLabel")
	vl.Size = UDim2.new(0, 80, 0, 14)
	vl.Position = UDim2.new(0.5, 62, 0, y)
	vl.BackgroundTransparency = 1
	vl.TextColor3 = Color3.fromRGB(255, 255, 255)
	vl.TextSize = 10
	vl.Font = Enum.Font.GothamBold
	vl.Text = value
	vl.TextXAlignment = Enum.TextXAlignment.Left
	vl:SetAttribute("_dynamic", true)
	vl.Parent = parent
end

-- 헬퍼: 구분선
function PetDetailUI._makeSep(parent, y)
	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, -24, 0, 1)
	sep.Position = UDim2.new(0, 12, 0, y)
	sep.BackgroundColor3 = Color3.fromRGB(80, 70, 100)
	sep.BorderSizePixel = 0
	sep:SetAttribute("_dynamic", true)
	sep.Parent = parent
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
