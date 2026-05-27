-- WorkBuildingDisplay.luau
-- 광산/농장 등 Work 건물 위에 (현재/최대) 코인 + 보석 표시 BillboardGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WorkBuildingDisplay = {}

local _tracked: { [BasePart]: { gui: BillboardGui, coinLabel: TextLabel, gemLabel: TextLabel } } = {}

-- HUD(좌측 하단) Diamond 아이콘 에셋을 한 번 읽어 재사용 (게임 공용 다이아 아이콘).
local _diamondIcon: string? = nil
local function getDiamondIcon(): string
	if _diamondIcon ~= nil then return _diamondIcon end
	_diamondIcon = ""
	local normal = playerGui:FindFirstChild("Normal")
	local d = normal and normal:FindFirstChild("Diamond")
	if d then
		if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" then
			_diamondIcon = d.Image
		else
			local img = d:FindFirstChildWhichIsA("ImageLabel") or d:FindFirstChildWhichIsA("ImageButton")
			if img and img.Image ~= "" then
				_diamondIcon = img.Image
			end
		end
	end
	return _diamondIcon
end

local function isWorkBuilding(building: BasePart): boolean
	local itemName = building:GetAttribute("ItemName")
	if not itemName then return false end
	local info = Constants.BUILDINGS[itemName]
	if not info or not info.types then return false end
	for _, t in info.types do
		if t == "Work" then return true end
	end
	return false
end

local function createDisplay(building: BasePart)
	if _tracked[building] then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = "WorkInfo"
	-- 약 2배 확대
	gui.Size = UDim2.new(0, 320, 0, 100)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.Parent = building

	local coinLabel = Instance.new("TextLabel")
	coinLabel.Size = UDim2.new(1, 0, 0, 48)
	coinLabel.Position = UDim2.new(0, 0, 0, 0)
	coinLabel.BackgroundTransparency = 1
	coinLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Heavy)
	coinLabel.TextSize = 36
	coinLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	coinLabel.TextStrokeTransparency = 0
	coinLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	coinLabel.Text = "$0/0"
	coinLabel.Parent = gui

	local gemLabel = Instance.new("TextLabel")
	gemLabel.Size = UDim2.new(1, 0, 0, 36)
	gemLabel.Position = UDim2.new(0, 0, 0, 52)
	gemLabel.BackgroundTransparency = 1
	-- 폰트 통일 (GothamBold → 게임 메인 폰트)
	gemLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
	gemLabel.RichText = true -- 다이아 아이콘을 <img>로 인라인 표시
	gemLabel.TextSize = 28
	gemLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
	gemLabel.TextStrokeTransparency = 0
	gemLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	gemLabel.Text = ""
	gemLabel.Parent = gui

	_tracked[building] = { gui = gui, coinLabel = coinLabel, gemLabel = gemLabel }

	building.AncestryChanged:Connect(function(_, parent)
		if not parent then
			_tracked[building] = nil
		end
	end)
end

local function updateDisplay(building: BasePart, info)
	local stored = building:GetAttribute("StoredCoins") or 0
	local gems = building:GetAttribute("StoredGems") or 0
	local level = building:GetAttribute("Level") or 1
	local caps = BalanceConfig.Building.WORK_CAPACITY_BY_LEVEL or {}
	local cap = caps[level] or caps[1] or 100

	info.coinLabel.Text = string.format("$%d / $%d", stored, cap)

	if gems > 0 then
		local icon = getDiamondIcon()
		if icon ~= "" then
			info.gemLabel.Text = '<img src="' .. icon .. '"/> ' .. tostring(gems)
		else
			info.gemLabel.Text = "💎 " .. gems -- HUD 아이콘 못 찾을 때 폴백
		end
		info.gemLabel.Visible = true
	else
		info.gemLabel.Visible = false
	end
end

local function scan()
	for _, desc in workspace:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") and isWorkBuilding(desc) then
			createDisplay(desc)
		end
	end
end

function WorkBuildingDisplay.init()
	scan()
	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") and isWorkBuilding(desc) then
			createDisplay(desc)
		end
	end)

	-- 매 0.5초 갱신
	task.spawn(function()
		while true do
			task.wait(0.5)
			for building, info in _tracked do
				if building.Parent then
					updateDisplay(building, info)
				end
			end
		end
	end)
end

return WorkBuildingDisplay
