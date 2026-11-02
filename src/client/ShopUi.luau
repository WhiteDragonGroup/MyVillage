-- 팀 UI의 BuildingsShopFrame에 현재 매물과 구매를 연결한다

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
local buyEvent = Net.event("Buy")

local ROW_GAP = 8
local INFO_WIDTH = 0.68

local ShopUi = {}

local frame, scroll, readyTemplate, blockedTemplate, restockText
local rowHeightShare

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

local function addRow(index: number, rowHeight: number, entry, shop)
	local def = Buildings.ById[entry.id]
	local locked = def.unlock > State.data.clockTower
	local soldOut = entry.left <= 0
	local affordable = State.data.coins >= def.coins
	local canBuy = not locked and not soldOut and affordable

	local row = (if canBuy then readyTemplate else blockedTemplate):Clone()
	row.Name = "Row"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, ROW_GAP + (index - 1) * (rowHeight + ROW_GAP))
	row.Size = UDim2.new(row.Size.X.Scale, 0, 0, rowHeight)

	Hud.setText(row, "NameText", def.name)
	row.InfoText.Text = describe(def)
	row.InfoText.Size = UDim2.fromScale(INFO_WIDTH, row.InfoText.Size.Y.Scale)
	row.Rarity.Visible = false
	row.Icon.Image = "" -- 건물 아이콘 에셋이 들어오면 연결한다
	row.BuyRobux.Visible = false -- Robux 가격 확정 전

	if locked then
		row.StockText.Text = string.format("Requires Clock Tower Lv.%d", def.unlock)
	elseif soldOut then
		row.StockText.Text = "NO STOCK"
	else
		-- 재고는 있으니 글자색은 구매 가능 행과 같게 둔다
		row.StockText.Text = string.format("%dx stock", entry.left)
		row.StockText.TextColor3 = readyTemplate.StockText.TextColor3
	end

	local buy = row.BuyDollar
	buy.Position = row.BuyRobux.Position -- Robux 버튼이 숨겨진 자리를 쓴다
	buy.TextLabel.Text = "$ " .. Hud.formatNumber(def.coins)
	if locked or soldOut then
		buy.AutoButtonColor = false
	else
		-- 코인이 모자라면 누를 때 서버가 사유를 알려 준다
		buy.Activated:Connect(function()
			buyEvent:FireServer(entry.id, shop.cycle)
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

	local shop = State.data.shop
	if not shop then
		return
	end

	local rowHeight = math.floor(scroll.AbsoluteSize.Y * rowHeightShare)
	for index, entry in shop.entries do
		addRow(index, rowHeight, entry, shop)
	end
	scroll.CanvasSize = UDim2.fromOffset(0, ROW_GAP + #shop.entries * (rowHeight + ROW_GAP))
end

local function refreshTimer()
	local shop = State.data.shop
	if not shop then
		return
	end
	local remaining = math.max(0, math.ceil(shop.endsAt - workspace:GetServerTimeNow()))
	restockText.Text = string.format("Restocking In %02d:%02d", math.floor(remaining / 60), remaining % 60)
end

function ShopUi.toggle()
	if frame.Visible then
		frame.Visible = false
		return
	end
	Hud.showOnly(frame)
	frame.Visible = true
	task.defer(function()
		render()
		refreshTimer()
	end)
end

function ShopUi.close()
	frame.Visible = false
end

function ShopUi.start()
	frame = player:WaitForChild("PlayerGui"):WaitForChild("Features"):WaitForChild("BuildingsShopFrame")
	scroll = frame:WaitForChild("ScrollingFrame")
	restockText = frame:WaitForChild("Header"):WaitForChild("RestockText")

	scroll:WaitForChild("Frame")
	readyTemplate, blockedTemplate = Hud.takeCardTemplates(scroll)
	rowHeightShare = readyTemplate.Size.Y.Scale * math.max(scroll.CanvasSize.Y.Scale, 1)

	frame.Header:WaitForChild("Close").Activated:Connect(ShopUi.close)
	Hud.onShopButton(ShopUi.toggle)
	Hud.registerPanel(frame)

	State.Changed:Connect(function()
		if frame.Visible then
			render()
			refreshTimer()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" and not frame.Visible then
			ShopUi.toggle()
		end
	end)

	Net.event("BuyResult").OnClientEvent:Connect(function(ok, text)
		Hud.toast(text, if ok then nil else Color3.fromRGB(235, 70, 60))
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if frame.Visible then
				refreshTimer()
			end
		end
	end)
end

return ShopUi
