-- 작업대 제작 창. 기획대로 상점과 같은 레이아웃을 쓰도록 BuildingsShopFrame을 복제한다.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared:WaitForChild("Buildings"))
local Items = require(Shared:WaitForChild("Items"))
local Net = require(Shared:WaitForChild("Net"))
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer
local craftEvent = Net.event("Craft")
local travelEvent = Net.event("Travel")

local ROW_GAP = 8
local INFO_WIDTH = 0.47
local INFO_HEIGHT = 0.62
local MISSING_COLOR = "#ff6b5e"

local CraftUi = {}

local frame, scroll, readyTemplate, blockedTemplate
local rowHeightShare
local order = {}

local function materialText(def): (string, boolean)
	local parts, ready = {}, true

	local ids = {}
	for itemId in def.recipe do
		table.insert(ids, itemId)
	end
	table.sort(ids, function(a, b)
		return Items.ById[a].order < Items.ById[b].order
	end)

	for _, itemId in ids do
		local need = def.recipe[itemId]
		local owned = State.data.resources[itemId] or 0
		local text = string.format("%s %s/%s", Items.ById[itemId].name, Hud.formatNumber(owned), Hud.formatNumber(need))
		if owned < need then
			ready = false
			text = string.format('<font color="%s">%s</font>', MISSING_COLOR, text)
		end
		table.insert(parts, text)
	end

	return table.concat(parts, "  ·  "), ready
end

local function describe(def): string
	if def.kind == "Home" then
		return string.format("Houses %d villagers", def.residents)
	end
	local outputs = {}
	for _, itemId in def.outputs do
		table.insert(outputs, Items.ById[itemId].name)
	end
	return string.format("Up to %d workers · %s", def.capacity, table.concat(outputs, ", "))
end

local function addRow(index: number, rowHeight: number, def)
	local locked = def.unlock > State.data.clockTower
	local materials, ready = materialText(def)
	local canCraft = ready and not locked

	local row = (if canCraft then readyTemplate else blockedTemplate):Clone()
	row.Name = "Row"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, ROW_GAP + (index - 1) * (rowHeight + ROW_GAP))
	row.Size = UDim2.new(row.Size.X.Scale, 0, 0, rowHeight)

	Hud.setText(row, "NameText", def.name)
	-- 재료 종류가 달라도 넘치지 않게 글자 크기를 칸에 맞춘다
	local info = row.InfoText
	info.RichText = true
	info.TextScaled = true
	info.Size = UDim2.fromScale(INFO_WIDTH, INFO_HEIGHT)
	local status = if locked then string.format("Requires Clock Tower Lv.%d", def.unlock) else materials
	info.Text = describe(def) .. "\n" .. status
	row.Rarity.Visible = false
	row.Icon.Image = "" -- 건물 아이콘 에셋이 들어오면 연결한다
	row.BuyRobux.Visible = false

	row.StockText.Visible = false

	local button = row.BuyDollar
	button.Position = row.BuyRobux.Position
	button.TextLabel.Text = "Craft"
	if not canCraft then
		button.AutoButtonColor = false
	else
		button.Activated:Connect(function()
			craftEvent:FireServer(def.id)
		end)
	end

	row.Parent = scroll
end

local function render()
	for _, child in scroll:GetChildren() do
		if child.Name == "Row" then
			child:Destroy()
		end
	end

	local rowHeight = math.floor(scroll.AbsoluteSize.Y * rowHeightShare)
	for index, def in order do
		addRow(index, rowHeight, def)
	end
	scroll.CanvasSize = UDim2.fromOffset(0, ROW_GAP + #order * (rowHeight + ROW_GAP))
end

function CraftUi.open()
	Hud.showOnly(frame)
	frame.Visible = true
	task.defer(render)
end

function CraftUi.start()
	local source = player:WaitForChild("PlayerGui"):WaitForChild("Features"):WaitForChild("BuildingsShopFrame")

	frame = source:Clone()
	frame.Name = "CraftFrame"
	frame.Visible = false
	frame.Parent = source.Parent
	Hud.registerPanel(frame)

	Hud.setText(frame.Header, "TextLabel", "Crafting")
	frame.Header.RestockText.Visible = false

	scroll = frame:WaitForChild("ScrollingFrame")
	scroll:WaitForChild("Frame")
	readyTemplate, blockedTemplate = Hud.takeCardTemplates(scroll)
	rowHeightShare = readyTemplate.Size.Y.Scale * math.max(scroll.CanvasSize.Y.Scale, 1)

	for _, def in Buildings.ById do
		if def.recipe then
			table.insert(order, def)
		end
	end
	table.sort(order, function(a, b)
		if a.unlock ~= b.unlock then
			return a.unlock < b.unlock
		end
		if a.coins ~= b.coins then
			return a.coins < b.coins
		end
		return a.id < b.id
	end)

	frame.Header:WaitForChild("Close").Activated:Connect(function()
		frame.Visible = false
	end)

	-- 상단 Eggs 버튼 자리를 작업대 빠른 이동으로 쓴다
	local top = player.PlayerGui:WaitForChild("Normal"):WaitForChild("TopFrame"):WaitForChild("Eggs")
	top.Visible = true
	top.TextLabel.Text = "Craft"
	local icon = top:FindFirstChildOfClass("ImageLabel")
	if icon then
		icon.Visible = false
	end
	top.Activated:Connect(function()
		travelEvent:FireServer("Workbench")
		CraftUi.open()
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "WorkbenchPrompt" then
			CraftUi.open()
		end
	end)

	State.Changed:Connect(function()
		if frame.Visible then
			render()
		end
	end)
end

return CraftUi
