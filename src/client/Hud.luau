-- 팀이 만든 StarterGui UI(PlayerGui 복제본)에 기능을 연결한다.
-- 코인, 좌측·상단 버튼, 인벤토리(건물·자원 탭), 판매 확인창, 안내 문구.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared:WaitForChild("Buildings"))
local Items = require(Shared:WaitForChild("Items"))
local Net = require(Shared:WaitForChild("Net"))
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sellEvent = Net.event("Sell")
local travelEvent = Net.event("Travel")

local ROW_SHARE = 0.24 -- 스크롤 영역 대비 한 줄 높이
local ROW_GAP = 8
local TAB_WIDTH = 116
local BUTTON_HOVER_GROWTH = 6
local BUTTON_HOVER_TILT = 5
local BUTTON_PRESS_SHRINK = 4
local SELECTED_COLOR = Color3.fromRGB(120, 235, 120)
local POPUP_LAYER = 20 -- 다른 창 위에 표시
local RARITY = {
	Common = { "Common", Color3.fromRGB(160, 160, 160) },
	Uncommon = { "Uncommon", Color3.fromRGB(90, 190, 100) },
	Rare = { "Rare", Color3.fromRGB(80, 140, 235) },
	Epic = { "Epic", Color3.fromRGB(170, 90, 225) },
	Legendary = { "Legendary", Color3.fromRGB(240, 165, 50) },
}

local Hud = {}

local normal, features
local coinLabel
local panel, scroll, rowTemplate, tabBuildings, tabResources, bottom, sellSelected
local totalCoinsLabel, totalCountLabel
local popUp, popUpTitle, popUpBody
local toastHost
local activeTab = "Buildings"
local selected = {} -- [itemId] = true
local pendingSale
local shopHandler, buildHandler
local panels = {}
local panelListeners = {}

----------------------------------------------------------------
-- 도우미
----------------------------------------------------------------
local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

-- 같은 이름의 글자와 그 그림자(…Shadow)를 함께 바꾼다
local function setText(parent: Instance, name: string, text: string)
	for _, child in parent:GetChildren() do
		if child:IsA("TextLabel") and (child.Name == name or child.Name == name .. "Shadow") then
			child.Text = text
		end
	end
end

local function setButtonText(button: GuiButton, text: string)
	setText(button, "TextLabel", text)
end

local function childrenByHeight(parent: Instance, className: string)
	local list = {}
	for _, child in parent:GetChildren() do
		if child.ClassName == className then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return a.Position.Y.Scale < b.Position.Y.Scale
	end)
	return list
end

----------------------------------------------------------------
-- 인벤토리 목록
----------------------------------------------------------------
local function addRow(index: number, rowHeight: number, spec)
	local row = rowTemplate:Clone()
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, ROW_GAP + (index - 1) * (rowHeight + ROW_GAP))
	row.Size = UDim2.new(0.95, 0, 0, rowHeight)
	row.Name = "Row"

	setText(row, "NameText", spec.name)
	setText(row, "MutationText", spec.info)
	setText(row, "AcountText", spec.value or "")
	row.LevelText.Visible = false
	row.WeightText.Visible = false

	local rarity = spec.rarity and RARITY[spec.rarity]
	row.Rarity.Visible = rarity ~= nil
	if rarity then
		local label = row.Rarity.TextLabel
		local gradient = label:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient:Destroy() -- 샘플의 고정 색이 희귀도 색을 덮는다
		end
		label.Text = rarity[1]
		label.TextColor3 = rarity[2]
	end

	row.Icon.Image = "" -- 건물·자원 아이콘 에셋이 들어오면 연결한다

	setButtonText(row.Sell, spec.action)
	if spec.selected then
		row.UIStroke.Color = SELECTED_COLOR
		row.UIStroke.Thickness = 3
	end
	row.Sell.Activated:Connect(spec.onAction)
	row.Parent = scroll
end

local function clearRows()
	for _, child in scroll:GetChildren() do
		if child.Name == "Row" then
			child:Destroy()
		end
	end
end

local function describeBuilding(def, level: number): string
	if def.kind == "Home" then
		return string.format("%d residents", def.residents)
	end
	local outputs = {}
	for _, itemId in def.outputs do
		table.insert(outputs, Items.ById[itemId].name)
	end
	return string.format("Lv%d · %d workers · %s", level, def.capacity, table.concat(outputs, ", "))
end

local function equipTool(key: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or not backpack then
		return
	end
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("BuildingKey") == key then
			humanoid:EquipTool(tool)
			panel.Visible = false
			return
		end
	end
end

local function buildingRows()
	local rows = {}
	for _, group in State.data.stored do
		local def = Buildings.ById[group.id]
		table.insert(rows, {
			name = def.name,
			info = describeBuilding(def, group.level),
			value = "×" .. group.count,
			action = "Equip",
			onAction = function()
				equipTool(group.key)
			end,
		})
	end
	return rows
end

local render -- 아래에서 정의

local function resourceRows()
	local rows = {}
	for _, item in Items.List do
		local owned = State.data.resources[item.id] or 0
		if owned > 0 then
			table.insert(rows, {
				name = item.name,
				info = string.format("Owned %s · $%s each", formatNumber(owned), formatNumber(item.price)),
				value = "$" .. formatNumber(owned * item.price),
				rarity = item.rarity,
				action = if selected[item.id] then "Selected" else "Select",
				selected = selected[item.id] == true,
				onAction = function()
					selected[item.id] = if selected[item.id] then nil else true
					render()
				end,
			})
		end
	end
	return rows
end

local function saleOf(filter)
	local amounts, count, coins = {}, 0, 0
	for itemId, owned in State.data.resources do
		if owned > 0 and filter(itemId) then
			amounts[itemId] = owned
			count += owned
			coins += owned * Items.ById[itemId].price
		end
	end
	return amounts, count, coins
end

local function selectAny()
	return true
end

local function isSelected(itemId: string): boolean
	return selected[itemId] == true
end

function render()
	clearRows()

	local isResources = activeTab == "Resources"
	setText(panel.Header, "TextLabel", if isResources then "Resources" else "Buildings")
	bottom.Visible = isResources
	tabBuildings.BackgroundTransparency = if isResources then 0.5 else 0
	tabResources.BackgroundTransparency = if isResources then 0 else 0.5

	local rows = if isResources then resourceRows() else buildingRows()
	local rowHeight = math.floor(scroll.AbsoluteSize.Y * ROW_SHARE)
	for index, spec in rows do
		addRow(index, rowHeight, spec)
	end
	scroll.CanvasSize = UDim2.fromOffset(0, ROW_GAP + #rows * (rowHeight + ROW_GAP))

	if isResources then
		local _, count, coins = saleOf(selectAny)
		totalCountLabel.Text = string.format("Total resources : %s", formatNumber(count))
		totalCoinsLabel.Text = string.format("Total cash : $%s", formatNumber(coins))
	end
end

local function openTab(tab: string)
	if panel.Visible and activeTab == tab then
		panel.Visible = false
		return
	end
	activeTab = tab
	Hud.showOnly(panel)
	panel.Visible = true
	task.defer(render) -- 프레임이 보인 뒤의 크기로 계산한다
end

----------------------------------------------------------------
-- 판매 확인
----------------------------------------------------------------
local function askSale(request, title: string, count: number, coins: number)
	pendingSale = request
	popUpTitle.Text = title
	popUpBody.Text = string.format("%s resources → $%s", formatNumber(count), formatNumber(coins))
	popUp.Visible = true
end

local function setupPopUp()
	popUp = features:WaitForChild("PopUp")
	popUp.ZIndex = POPUP_LAYER
	local labels = childrenByHeight(popUp, "TextLabel")
	popUpTitle, popUpBody = labels[1], labels[2]

	local arrow = popUpBody:FindFirstChildOfClass("ImageLabel")
	if arrow then
		arrow.Visible = false
	end

	local frame = popUp:WaitForChild("Frame")
	setButtonText(frame.Confirm, "Sell")

	frame.Confirm.Activated:Connect(function()
		popUp.Visible = false
		if pendingSale then
			sellEvent:FireServer(pendingSale)
			pendingSale = nil
			table.clear(selected)
		end
	end)
	frame.Cancle.Activated:Connect(function()
		popUp.Visible = false
		pendingSale = nil
	end)
end

----------------------------------------------------------------
-- 화면 연결
----------------------------------------------------------------
local function cloneActionButton(source: GuiButton, name: string, parent: Instance, position: UDim2): GuiButton
	local button = source:Clone()
	button.Name = name
	button.Position = position
	button.Parent = parent
	return button
end

local function setupInventory()
	panel = features:WaitForChild("SellPets")
	scroll = panel:WaitForChild("ScrollingFrame")
	bottom = panel:WaitForChild("Bottom")

	rowTemplate = scroll:WaitForChild("Frame"):Clone()
	for _, child in scroll:GetChildren() do
		if child.Name == "Frame" then
			child:Destroy()
		end
	end

	local labels = childrenByHeight(bottom, "TextLabel")
	totalCountLabel, totalCoinsLabel = labels[1], labels[2]

	local sellAll = bottom:WaitForChild("Sell")
	sellSelected = cloneActionButton(sellAll, "SellSelected", bottom, UDim2.new(0.62, 0, sellAll.Position.Y.Scale, 0))
	setButtonText(sellSelected, "Sell Selected")

	tabBuildings = cloneActionButton(sellAll, "TabBuildings", panel.Header, UDim2.fromScale(0.6, 0.5))
	tabResources = cloneActionButton(sellAll, "TabResources", panel.Header, UDim2.fromScale(0.82, 0.5))
	tabBuildings.Size = UDim2.fromOffset(TAB_WIDTH, sellAll.Size.Y.Offset)
	tabResources.Size = tabBuildings.Size
	setButtonText(tabBuildings, "Buildings")
	setButtonText(tabResources, "Resources")

	tabBuildings.Activated:Connect(function()
		activeTab = "Buildings"
		render()
	end)
	tabResources.Activated:Connect(function()
		activeTab = "Resources"
		render()
	end)
	panel.Header:WaitForChild("Close").Activated:Connect(function()
		panel.Visible = false
	end)
	sellSelected.Activated:Connect(function()
		local amounts, count, coins = saleOf(isSelected)
		if count > 0 then
			askSale(amounts, "Sell selected resources?", count, coins)
		end
	end)
	sellAll.Activated:Connect(function()
		local _, count, coins = saleOf(selectAny)
		if count > 0 then
			askSale("all", "Sell everything, including crafting materials?", count, coins)
		end
	end)
end

-- 마우스를 올리면 살짝 기울며 커지고, 누르면 줄어든다
local function animateSideButton(button: GuiButton)
	local size = button.Size
	local rotation = button.Rotation

	local function resized(offset: number): UDim2
		return UDim2.new(size.X.Scale, size.X.Offset + offset, size.Y.Scale, size.Y.Offset + offset)
	end

	local function play(duration: number, style: Enum.EasingStyle, goal)
		TweenService:Create(button, TweenInfo.new(duration, style, Enum.EasingDirection.Out), goal):Play()
	end

	button.MouseEnter:Connect(function()
		play(0.15, Enum.EasingStyle.Back, { Size = resized(BUTTON_HOVER_GROWTH), Rotation = BUTTON_HOVER_TILT })
	end)
	button.MouseLeave:Connect(function()
		play(0.15, Enum.EasingStyle.Quad, { Size = size, Rotation = rotation })
	end)
	button.MouseButton1Down:Connect(function()
		play(0.05, Enum.EasingStyle.Quad, { Size = resized(-BUTTON_PRESS_SHRINK) })
	end)
	button.MouseButton1Up:Connect(function()
		play(0.1, Enum.EasingStyle.Back, { Size = resized(BUTTON_HOVER_GROWTH) })
	end)
end

local function setupNormal()
	-- 현재 기획에 없는 항목
	for _, name in { "Diamond", "Weather", "Setting" } do
		normal[name].Visible = false
	end
	local restockSign = playerGui:FindFirstChild("EggShopRestock")
	if restockSign then
		restockSign.Enabled = false
	end

	coinLabel = normal.Money.TextLabel

	local left = normal.Frame
	left.Pets.Activated:Connect(function()
		openTab("Resources")
	end)
	left.BulildMode.Activated:Connect(function()
		if buildHandler then
			buildHandler()
		end
	end)
	left.Shop.Activated:Connect(function()
		if shopHandler then
			shopHandler()
		end
	end)

	for _, button in { left.Pets, left.BulildMode, left.Shop } do
		animateSideButton(button)
	end

	normal.TopFrame.MyVillage.Activated:Connect(function()
		travelEvent:FireServer("Home")
	end)
	normal.TopFrame.Buildings.Activated:Connect(function()
		travelEvent:FireServer("Shop")
	end)
end

local function setupToast()
	local gui = Ui.make("ScreenGui", {
		Name = "VillageToast",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = playerGui,
	})
	toastHost = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.fromOffset(360, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.make("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 2),
		}),
	})
end

function Hud.toast(text: string, color: Color3?)
	local label = Ui.label({
		Size = UDim2.new(1, 0, 0, 26),
		Text = text,
		TextColor3 = color or Ui.Colors.White,
		TextSize = 20,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = toastHost,
	})
	task.delay(1.4, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

Hud.setText = setText
Hud.formatNumber = formatNumber

Hud.equipTool = equipTool

function Hud.onShopButton(handler)
	shopHandler = handler
end

function Hud.onBuildButton(handler)
	buildHandler = handler
end

-- 상점 카드 샘플은 구매 가능(초록)과 품절(빨강) 두 줄이다. 둘 다 틀로 챙기고 샘플을 지운다.
function Hud.takeCardTemplates(scroll: ScrollingFrame): (Frame, Frame)
	local ready, blocked
	for _, child in scroll:GetChildren() do
		if child.Name == "Frame" then
			if child.StockText.Text == "NO STOCK" then
				blocked = child:Clone()
			else
				ready = child:Clone()
			end
			child:Destroy()
		end
	end
	return ready, blocked or ready
end

function Hud.registerPanel(frame: GuiObject)
	panels[frame] = true
end

-- 다른 창을 닫는다. 호출한 쪽이 자기 창을 연다.
function Hud.showOnly(frame: GuiObject)
	for other in panels do
		if other ~= frame then
			other.Visible = false
		end
	end
	for _, listener in panelListeners do
		listener(frame)
	end
end

function Hud.onPanelOpened(listener)
	table.insert(panelListeners, listener)
end

-- 배치 모드 버튼 (BuildMode.Move 폴더)
function Hud.placementButtons()
	return playerGui:WaitForChild("BuildMode"):WaitForChild("Move")
end

function Hud.start()
	normal = playerGui:WaitForChild("Normal")
	features = playerGui:WaitForChild("Features")

	-- 복제본이 리스폰 때 초기화되면 연결이 끊기므로 유지한다
	for _, gui in { normal, features, playerGui:WaitForChild("BuildMode") } do
		gui.ResetOnSpawn = false
		-- 원본에 Active가 꺼진 버튼이 있어 눌리지 않는다
		for _, object in gui:GetDescendants() do
			if object:IsA("GuiButton") then
				object.Active = true
			end
		end
	end

	setupNormal()
	setupInventory()
	Hud.registerPanel(panel)
	setupPopUp()
	setupToast()

	local function refreshCoins()
		coinLabel.Text = "$ " .. formatNumber(State.data.coins)
	end
	refreshCoins()

	State.Changed:Connect(function()
		refreshCoins()
		if panel.Visible then
			render()
		end
	end)

	Net.event("Harvested").OnClientEvent:Connect(function(gained)
		for itemId, amount in gained do
			Hud.toast(string.format("+%s %s", formatNumber(amount), Items.ById[itemId].name))
		end
	end)
end

return Hud
