-- BuffUI.luau
-- HUD에 활성 버프 아이콘 + 남은 시간 + 마우스오버 설명

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BuffCfg = BalanceConfig.Buff

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buffUpdateEvent = remotes:WaitForChild("BuffUpdate")
local getBuffsFunc = remotes:WaitForChild("GetBuffs")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BuffUI = {}

local _gui: ScreenGui? = nil
local _container: Frame? = nil
local _tooltip: Frame? = nil
local _slots: { [string]: { frame: Frame, icon: ImageLabel?, fallback: Frame?, timeLabel: TextLabel, expireAt: number } } = {}

local function ensureGui()
	if _gui and _gui.Parent then return end
	_gui = Instance.new("ScreenGui")
	_gui.Name = "BuffsHUD"
	_gui.ResetOnSpawn = false
	_gui.IgnoreGuiInset = false
	_gui.Parent = playerGui

	_container = Instance.new("Frame")
	_container.Name = "Container"
	_container.AnchorPoint = Vector2.new(1, 0)
	_container.Position = UDim2.new(1, -10, 0, 80)
	_container.Size = UDim2.new(0, 240, 0, 50)
	_container.BackgroundTransparency = 1
	_container.Parent = _gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = _container

	-- Tooltip
	_tooltip = Instance.new("Frame")
	_tooltip.Name = "Tooltip"
	_tooltip.Size = UDim2.new(0, 220, 0, 60)
	_tooltip.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	_tooltip.BackgroundTransparency = 0.1
	_tooltip.BorderSizePixel = 0
	_tooltip.Visible = false
	_tooltip.Parent = _gui

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 6)
	tCorner.Parent = _tooltip

	local tName = Instance.new("TextLabel")
	tName.Name = "BuffName"
	tName.Size = UDim2.new(1, -10, 0, 20)
	tName.Position = UDim2.new(0, 5, 0, 4)
	tName.BackgroundTransparency = 1
	tName.TextColor3 = Color3.fromRGB(255, 220, 130)
	tName.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
	tName.TextSize = 14
	tName.TextXAlignment = Enum.TextXAlignment.Left
	tName.Parent = _tooltip

	local tDesc = Instance.new("TextLabel")
	tDesc.Name = "Desc"
	tDesc.Size = UDim2.new(1, -10, 1, -28)
	tDesc.Position = UDim2.new(0, 5, 0, 26)
	tDesc.BackgroundTransparency = 1
	tDesc.TextColor3 = Color3.fromRGB(220, 220, 220)
	tDesc.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Regular)
	tDesc.TextSize = 12
	tDesc.TextWrapped = true
	tDesc.TextXAlignment = Enum.TextXAlignment.Left
	tDesc.TextYAlignment = Enum.TextYAlignment.Top
	tDesc.Parent = _tooltip
end

local function showTooltip(buffId: string, anchor: GuiObject)
	if not _tooltip then return end
	local cfg = BuffCfg.BUFFS[buffId]
	if not cfg then return end
	_tooltip.BuffName.Text = cfg.name or buffId
	_tooltip.Desc.Text = cfg.description or ""
	local pos = anchor.AbsolutePosition
	_tooltip.Position = UDim2.new(0, pos.X - 230, 0, pos.Y + 50)
	_tooltip.Visible = true
end

local function hideTooltip()
	if _tooltip then _tooltip.Visible = false end
end

local function createSlot(buffId: string): typeof(_slots[""])
	local cfg = BuffCfg.BUFFS[buffId] or { color = Color3.new(0.5, 0.5, 0.5) }
	local frame = Instance.new("Frame")
	frame.Name = buffId
	frame.Size = UDim2.new(0, 44, 0, 50)
	frame.BackgroundTransparency = 1

	local iconHolder = Instance.new("Frame")
	iconHolder.Size = UDim2.new(0, 36, 0, 36)
	iconHolder.Position = UDim2.new(0.5, -18, 0, 0)
	iconHolder.BackgroundColor3 = cfg.color or Color3.fromRGB(150, 150, 150)
	iconHolder.BorderSizePixel = 0
	iconHolder.Parent = frame

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 6)
	hCorner.Parent = iconHolder

	-- 아이콘은 Constants.BUFF_ICONS 단일 소스에서 우선 조회 (BuffConfig.icon 폴백)
	local iconId = (Constants.BUFF_ICONS and Constants.BUFF_ICONS[buffId]) or cfg.icon or ""
	local icon: ImageLabel? = nil
	if iconId ~= "" then
		icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, -4, 1, -4)
		icon.Position = UDim2.new(0, 2, 0, 2)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.Parent = iconHolder
	end

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size = UDim2.new(1, 0, 0, 12)
	timeLabel.Position = UDim2.new(0, 0, 0, 38)
	timeLabel.BackgroundTransparency = 1
	timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timeLabel.TextStrokeTransparency = 0
	timeLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
	timeLabel.TextSize = 11
	timeLabel.Text = "0s"
	timeLabel.Parent = frame

	-- 마우스 hover로 tooltip
	local hoverBtn = Instance.new("TextButton")
	hoverBtn.Size = UDim2.new(1, 0, 1, 0)
	hoverBtn.BackgroundTransparency = 1
	hoverBtn.Text = ""
	hoverBtn.ZIndex = 5
	hoverBtn.Parent = iconHolder
	hoverBtn.MouseEnter:Connect(function() showTooltip(buffId, iconHolder) end)
	hoverBtn.MouseLeave:Connect(hideTooltip)

	frame.Parent = _container

	return { frame = frame, icon = icon, fallback = iconHolder, timeLabel = timeLabel, expireAt = 0 }
end

local function formatRemaining(secs: number): string
	if secs <= 0 then return "0s" end
	if secs < 60 then return string.format("%ds", math.floor(secs)) end
	local m = math.floor(secs / 60)
	local s = math.floor(secs % 60)
	return string.format("%d:%02d", m, s)
end

local function updateBuffs(buffs: { { buffId: string, remaining: number } })
	ensureGui()
	local seen: { [string]: boolean } = {}
	local now = tick()
	for _, b in buffs do
		seen[b.buffId] = true
		local slot = _slots[b.buffId]
		if not slot then
			slot = createSlot(b.buffId)
			_slots[b.buffId] = slot
		end
		slot.expireAt = now + b.remaining
	end
	-- 사라진 버프 제거
	for buffId, slot in _slots do
		if not seen[buffId] then
			if slot.frame and slot.frame.Parent then slot.frame:Destroy() end
			_slots[buffId] = nil
		end
	end
end

function BuffUI.init()
	ensureGui()

	-- 초기 로드
	task.spawn(function()
		local ok, buffs = pcall(function()
			return getBuffsFunc:InvokeServer()
		end)
		if ok and typeof(buffs) == "table" then
			updateBuffs(buffs)
		end
	end)

	buffUpdateEvent.OnClientEvent:Connect(updateBuffs)

	-- 매초 남은 시간 갱신
	RunService.Heartbeat:Connect(function()
		local now = tick()
		for buffId, slot in _slots do
			local remaining = slot.expireAt - now
			if remaining <= 0 then
				if slot.frame and slot.frame.Parent then slot.frame:Destroy() end
				_slots[buffId] = nil
			else
				slot.timeLabel.Text = formatRemaining(remaining)
			end
		end
	end)
end

return BuffUI
