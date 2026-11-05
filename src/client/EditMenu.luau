-- 내 마을 건물을 클릭하면 열리는 메뉴: 정보, 강화, 이동·회전, 보관

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared:WaitForChild("Buildings"))
local Items = require(Shared:WaitForChild("Items"))
local Net = require(Shared:WaitForChild("Net"))
local Production = require(Shared:WaitForChild("Production"))
local Ui = require(script.Parent.Ui)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)
local BuildMode = require(script.Parent.BuildMode)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local storeEvent = Net.event("Store")
local upgradeEvent = Net.event("Upgrade")

local CLICK_DISTANCE = 500

local EditMenu = {}

local info, selectButtons
local selected, highlight, modelConnection, pendingReselect
local enabled = false
local selectionChanged

local function myFolder(): Instance?
	for _, plot in workspace:WaitForChild("Plots"):GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot:FindFirstChild("Village")
		end
	end
	return nil
end

local function upgradeInfo(model: Model, def)
	local level = model:GetAttribute("Level")

	if def.kind == "Landmark" then
		return level, Buildings.ClockTowerUpgrade[level], nil
	end
	if def.kind == "Work" then
		local cost = def.upgrade[level]
		local blocked = if level >= State.data.clockTower
			then string.format("Requires Clock Tower Lv.%d", level + 1)
			else nil
		return level, cost, blocked
	end
	return level, nil, nil
end

local function bodyText(model: Model, def): string
	local level = model:GetAttribute("Level")
	local lines = {}

	if def.kind == "Home" then
		table.insert(lines, string.format("Residents : %d", def.residents))
		table.insert(lines, "Villagers find the nearest open workplace on their own.")
	elseif def.kind == "Landmark" then
		table.insert(lines, string.format("Workplace level cap : %d", level))
		local unlocks = {}
		for _, other in Buildings.ById do
			if other.unlock == level + 1 and other.recipe then
				table.insert(unlocks, other.name)
			end
		end
		table.sort(unlocks)
		if #unlocks > 0 then
			table.insert(lines, "Next level unlocks : " .. table.concat(unlocks, ", "))
		end
	else
		table.insert(lines, string.format("Workers : %d/%d", model:GetAttribute("Workers") or 0, def.capacity))
		for _, itemId in def.outputs do
			local item = Items.ById[itemId]
			local cap = Production.capacityOf(itemId, level)
			local stored = model:GetAttribute("Store_" .. itemId) or 0
			local nextIn = model:GetAttribute("Next_" .. itemId) or -1
			local status = if stored >= cap
				then "FULL"
				elseif nextIn >= 0 then string.format("next %ds", nextIn)
				else "no workers"
			table.insert(lines, string.format("%s %d/%d · %s", item.name, stored, cap, status))
		end
		if level < Buildings.MAX_LEVEL then
			table.insert(lines, string.format("Next level : +%d each, storage x2", level + 1))
		end
	end

	return table.concat(lines, "\n")
end

-- 보관 중인 건물의 상세 정보
local function catalogText(def, level: number): string
	local lines = {}

	if def.kind == "Home" then
		table.insert(lines, string.format("Residents : %d", def.residents))
		table.insert(lines, "Villagers find the nearest open workplace on their own.")
	else
		table.insert(lines, string.format("Up to %d workers · makes %d each", def.capacity, level))
		for _, itemId in def.outputs do
			local item = Items.ById[itemId]
			table.insert(lines, string.format("%s : %ds · storage %d", item.name, item.cycle, Production.capacityOf(itemId, level)))
		end
	end

	return table.concat(lines, "\n")
end

local function refresh()
	if not selected or not selected.Parent then
		return
	end

	local def = Buildings.ById[selected:GetAttribute("BuildingId")]
	local level, cost, blocked = upgradeInfo(selected, def)

	Hud.setText(info.Header, "TextLabel", if def.kind == "Home" then def.name else string.format("%s LV.%d", def.name, level))
	info.Frame.Info.TextLabel.Text = bodyText(selected, def)

	local button = info.Frame.Upgrade
	button.Visible = def.kind ~= "Home"
	if def.kind ~= "Home" then
		if cost then
			button.LevelText.Text = string.format("Level: %d > %d", level, level + 1)
			button.CostText.Text = blocked or ("Cost : $" .. Hud.formatNumber(cost))
		else
			button.LevelText.Text = string.format("Level: %d", level)
			button.CostText.Text = "Max Level"
		end
	end
end

local function notifySelection()
	if selectionChanged then
		selectionChanged(selected ~= nil)
	end
end

local function clear()
	selected = nil
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if modelConnection then
		modelConnection:Disconnect()
		modelConnection = nil
	end
	info.Visible = false
	for _, button in selectButtons:GetChildren() do
		button.Visible = false
	end
	notifySelection()
end

local function select(model: Model)
	clear()
	selected = model

	highlight = Ui.make("Highlight", {
		FillTransparency = 0.8,
		OutlineColor = Color3.fromRGB(255, 240, 120),
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Parent = model,
	})

	local def = Buildings.ById[model:GetAttribute("BuildingId")]
	local movable = def.kind ~= "Landmark"
	selectButtons.Move.Visible = movable
	selectButtons.Store.Visible = movable
	selectButtons.Cancle.Visible = true

	Hud.showOnly(info)
	info.Visible = true
	modelConnection = model.AttributeChanged:Connect(refresh)
	refresh()
	notifySelection()
end

local function modelAtPointer(position: Vector2): Model?
	local folder = myFolder()
	if not folder then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }

	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * CLICK_DISTANCE, params)
	if not hit then
		return nil
	end

	local current = hit.Instance
	while current and current.Parent ~= folder do
		current = current.Parent
	end
	return current
end

local function onPointer(position: Vector2)
	if not enabled or BuildMode.isActive() then
		return
	end
	local character = player.Character
	if character and character:FindFirstChildOfClass("Tool") then
		return
	end

	local model = modelAtPointer(position)
	if model then
		select(model)
	elseif selected then
		clear()
	end
end

function EditMenu.showDetails(id: string, level: number)
	clear()

	local def = Buildings.ById[id]
	Hud.showOnly(info)
	Hud.setText(info.Header, "TextLabel", if def.kind == "Work" then string.format("%s LV.%d", def.name, level) else def.name)
	info.Frame.Info.TextLabel.Text = catalogText(def, level)
	info.Frame.Upgrade.Visible = false
	info.Visible = true
	selectButtons.Cancle.Visible = true
end

function EditMenu.setEnabled(value: boolean)
	enabled = value
	if not value then
		clear()
	end
end

function EditMenu.onSelectionChanged(handler)
	selectionChanged = handler
end

function EditMenu.start()
	local gui = player:WaitForChild("PlayerGui")
	info = gui:WaitForChild("Features"):WaitForChild("BuildingInfo")
	selectButtons = gui:WaitForChild("BuildMode"):WaitForChild("Select")
	Hud.registerPanel(info)

	info.Header.Rarity.Visible = false
	info.Frame.Icon.Image = "" -- 건물 아이콘 에셋이 들어오면 연결한다
	selectButtons.Upgrade:Destroy() -- 강화는 정보 창의 버튼 하나로 쓴다
	info.Frame.Info.TextLabel.TextYAlignment = Enum.TextYAlignment.Top
	info.Frame.Info.TextLabel.TextXAlignment = Enum.TextXAlignment.Left

	info.Frame.Upgrade.Activated:Connect(function()
		if not selected then
			return
		end
		upgradeEvent:FireServer(selected.Name)
	end)

	selectButtons.Cancle.Activated:Connect(clear)
	Hud.onBuildingDetails(EditMenu.showDetails)

	-- 다른 창을 열면 선택을 해제한다
	Hud.onPanelOpened(function(frame)
		if frame ~= info and selected then
			clear()
		end
	end)

	selectButtons.Store.Activated:Connect(function()
		if selected then
			storeEvent:FireServer(selected.Name)
			clear()
		end
	end)

	selectButtons.Move.Activated:Connect(function()
		if selected then
			local model = selected
			clear()
			BuildMode.startMove(model)
		end
	end)

	-- 강화하면 모델이 교체되므로 같은 건물을 다시 선택한다
	local function watchFolder(folder: Instance)
		folder.ChildAdded:Connect(function(child)
			if pendingReselect == child.Name then
				pendingReselect = nil
				task.defer(select, child)
			end
		end)
		folder.ChildRemoved:Connect(function(child)
			if selected == child then
				pendingReselect = child.Name
				clear()
			end
		end)
	end

	task.spawn(function()
		local folder = myFolder()
		while not folder do
			task.wait(0.5)
			folder = myFolder()
		end
		watchFolder(folder)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onPointer(UserInputService:GetMouseLocation())
		elseif input.UserInputType == Enum.UserInputType.Touch then
			onPointer(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	State.Changed:Connect(refresh)
end

return EditMenu
