-- EggSkipUI.luau
-- 부화 대기 중인 알의 SkipHatchPrompt(서버가 부착) → 클라가 Triggered 받아 확인 다이얼로그 표시.
-- 확인 시 SkipHatch RemoteEvent를 서버로 발사.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local skipHatchEvent = remotes:WaitForChild("SkipHatch")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local EggSkipUI = {}

local MAIN_FONT = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)

local _activeDialog: ScreenGui? = nil

-- 비용 계산 (서버와 동일 규칙): max(1, ceil(분 / 5))
local function computeCost(remainingSec: number): number
	if remainingSec <= 0 then return 0 end
	local mins = remainingSec / 60
	return math.max(1, math.ceil(mins / 5))
end

local function closeDialog()
	if _activeDialog and _activeDialog.Parent then
		_activeDialog:Destroy()
	end
	_activeDialog = nil
end

local function showConfirmDialog(eggId: string, cost: number, remainingSec: number)
	closeDialog()

	local gui = Instance.new("ScreenGui")
	gui.Name = "EggSkipConfirm"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = playerGui
	_activeDialog = gui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 320, 0, 160)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 200, 220)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 130)
	title.FontFace = MAIN_FONT
	title.TextSize = 18
	title.Text = "Skip hatch?"
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -20, 0, 60)
	body.Position = UDim2.new(0, 10, 0, 38)
	body.BackgroundTransparency = 1
	body.TextColor3 = Color3.fromRGB(230, 230, 230)
	body.FontFace = MAIN_FONT
	body.TextSize = 14
	body.TextWrapped = true
	body.Text = string.format("Spend %d diamonds to skip the wait?\n(Remaining: %d min) You'll still need to interact once more to hatch.",
		cost, math.ceil(remainingSec / 60))
	body.Parent = frame

	-- Yes 버튼
	local yesBtn = Instance.new("TextButton")
	yesBtn.Size = UDim2.new(0, 130, 0, 36)
	yesBtn.Position = UDim2.new(0, 20, 1, -46)
	yesBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
	yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	yesBtn.FontFace = MAIN_FONT
	yesBtn.TextSize = 16
	yesBtn.Text = "Yes (" .. cost .. " 💎)"
	yesBtn.Parent = frame
	Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 8)

	local noBtn = Instance.new("TextButton")
	noBtn.Size = UDim2.new(0, 130, 0, 36)
	noBtn.Position = UDim2.new(1, -150, 1, -46)
	noBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	noBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	noBtn.FontFace = MAIN_FONT
	noBtn.TextSize = 16
	noBtn.Text = "No"
	noBtn.Parent = frame
	Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 8)

	yesBtn.MouseButton1Click:Connect(function()
		skipHatchEvent:FireServer(eggId)
		closeDialog()
	end)
	noBtn.MouseButton1Click:Connect(closeDialog)

	-- 10초 후 자동 닫힘 (실수 방지)
	Debris:AddItem(gui, 10)
end

local function onPromptTriggered(prompt: ProximityPrompt)
	-- 알 모델에서 eggId / 남은시간 읽기
	local model = prompt.Parent
	if not model then return end
	-- prompt가 PrimaryPart에 붙어있을 수도 있어서 부모 모델까지 거슬러 올라감
	local eggModel = model
	if not model:GetAttribute("EggId") then
		local m = model:FindFirstAncestorWhichIsA("Model")
		if m and m:GetAttribute("EggId") then
			eggModel = m
		end
	end
	local eggId = eggModel:GetAttribute("EggId")
	if not eggId then return end
	local remaining = tonumber(eggModel:GetAttribute("RemainingSeconds")) or 0
	local cost = computeCost(remaining)
	if cost <= 0 then return end
	showConfirmDialog(eggId, cost, remaining)
end

local _wiredPrompts: { [ProximityPrompt]: boolean } = {}
local function wirePrompt(prompt: ProximityPrompt)
	if _wiredPrompts[prompt] then return end
	if prompt.Name ~= "SkipHatchPrompt" then return end
	_wiredPrompts[prompt] = true
	prompt.Triggered:Connect(function(plr)
		if plr == player then onPromptTriggered(prompt) end
	end)
	prompt.AncestryChanged:Connect(function(_, parent)
		if not parent then _wiredPrompts[prompt] = nil end
	end)
end

function EggSkipUI.init()
	-- 기존 SkipHatchPrompt 스캔
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "SkipHatchPrompt" then
			wirePrompt(d)
		end
	end
	-- 신규 추가 감시
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") and d.Name == "SkipHatchPrompt" then
			wirePrompt(d)
		end
	end)
end

return EggSkipUI
