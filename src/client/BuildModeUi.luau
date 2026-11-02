-- 망치 버튼의 빌드 모드. 다른 화면을 숨기고 OwnedBuildings에 보유 건물을 보여 준다.
-- 건물 클릭 편집은 이 모드에서만 되고, 모드 중에는 접촉 수확을 멈춘다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared:WaitForChild("Buildings"))
local Net = require(Shared:WaitForChild("Net"))
local Ui = require(script.Parent.Ui)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)
local BuildMode = require(script.Parent.BuildMode)
local EditMenu = require(script.Parent.EditMenu)

local player = Players.LocalPlayer
local editingEvent = Net.event("SetEditing")

local VILLAGE_MARGIN = 10
local SLOT_WIDTH = 0.43
local SLOT_COLUMNS = { 0.05, 0.52 }
local SLOT_GAP = 8
local FIRST_FIELD_STEP = 3 -- 이 튜토리얼 단계부터는 마을을 돌아다녀야 해서 모드를 끈다

local CATEGORIES = {
	All = { title = "All Buildings" },
	WorkSpots = { title = "WorkSpots", kind = "Work" },
	RestSpots = { title = "RestSpots", kind = "Home" },
}

local BuildModeUi = {}

local normal, owned, scroll, slotTemplate, hammer
local active = false
local category = "All"
local hiddenObjects = {}
local lastTutorial

local function myPlot(): Model?
	for _, plot in workspace:WaitForChild("Plots"):GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function isInVillage(plot: Model): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local zone = plot:WaitForChild("BuildZone")
	local position = zone.CFrame:PointToObjectSpace(root.Position)
	return math.abs(position.X) <= zone.Size.X / 2 + VILLAGE_MARGIN
		and math.abs(position.Z) <= zone.Size.Z / 2 + VILLAGE_MARGIN
end

local function addSlot(index: number, group)
	local def = Buildings.ById[group.id]
	local slot = slotTemplate:Clone()
	local column = (index - 1) % #SLOT_COLUMNS
	local row = (index - 1 - column) / #SLOT_COLUMNS
	local width = scroll.AbsoluteSize.X * SLOT_WIDTH

	slot.Name = "BuildingSlot"
	slot.Size = UDim2.new(SLOT_WIDTH, 0, 0, width)
	slot.Position = UDim2.new(SLOT_COLUMNS[column + 1], 0, 0, SLOT_GAP + row * (width + SLOT_GAP))
	slot.Icon.Image = "" -- 건물 아이콘 에셋이 들어오면 연결한다
	slot.Delete.Visible = false
	slot.NameText.Text = def.name
	slot.LevelText.Text = if def.kind == "Work"
		then string.format("Lv. %d  x%d", group.level, group.count)
		else string.format("x%d", group.count)

	local button = Ui.make("TextButton", {
		Name = "Equip",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = slot.ZIndex + 5,
		Parent = slot,
	})
	button.Activated:Connect(function()
		Hud.equipTool(group.key)
	end)

	slot.Parent = scroll
end

local function placedCount(): number
	local plot = myPlot()
	local folder = plot and plot:FindFirstChild("Village")
	return if folder then #folder:GetChildren() else 0
end

local function render()
	if not active then
		return
	end

	for _, child in scroll:GetChildren() do
		if child.Name == "BuildingSlot" then
			child:Destroy()
		end
	end

	local wanted = CATEGORIES[category]
	local count = 0
	for _, group in State.data.stored do
		if not wanted.kind or Buildings.ById[group.id].kind == wanted.kind then
			count += 1
			addSlot(count, group)
		end
	end

	local width = scroll.AbsoluteSize.X * SLOT_WIDTH
	local rows = math.ceil(count / #SLOT_COLUMNS)
	scroll.CanvasSize = UDim2.fromOffset(0, SLOT_GAP + rows * (width + SLOT_GAP))

	owned.CategoryText.Text = wanted.title
	owned.PlacedNumber.Text = "Placed Buildings : " .. placedCount()
end

local function hideOthers()
	table.clear(hiddenObjects)

	local function hide(object: GuiObject)
		if object.Visible then
			object.Visible = false
			table.insert(hiddenObjects, object)
		end
	end

	local side = hammer.Parent
	for _, child in normal:GetChildren() do
		if child:IsA("GuiObject") and child ~= side then
			hide(child)
		end
	end
	for _, child in side:GetChildren() do
		if child:IsA("GuiObject") and child ~= hammer and child.Name ~= "Shadow" then
			hide(child)
		end
	end
end

local function restoreOthers()
	for _, object in hiddenObjects do
		object.Visible = true
	end
	table.clear(hiddenObjects)
end

function BuildModeUi.exit()
	if not active then
		return
	end

	active = false
	owned.Visible = false
	restoreOthers()
	EditMenu.setEnabled(false)
	BuildMode.cancel()
	editingEvent:FireServer(false)
end

local function enter()
	local plot = myPlot()
	if not plot or not isInVillage(plot) then
		Hud.toast("You need to be in your village to use Build Mode.", Color3.fromRGB(235, 70, 60))
		return
	end

	active = true
	Hud.showOnly(owned)
	hideOthers()
	owned.Visible = true
	EditMenu.setEnabled(true)
	editingEvent:FireServer(true)
	task.defer(render)
end

function BuildModeUi.toggle()
	if active then
		BuildModeUi.exit()
	else
		enter()
	end
end

function BuildModeUi.start()
	local gui = player:WaitForChild("PlayerGui")
	normal = gui:WaitForChild("Normal")
	hammer = normal:WaitForChild("Frame"):WaitForChild("BulildMode")
	owned = gui:WaitForChild("BuildMode"):WaitForChild("OwnedBuildings")
	scroll = owned:WaitForChild("ScrollingFrame")

	slotTemplate = scroll:WaitForChild("Slot"):Clone()
	for _, child in scroll:GetChildren() do
		if child.Name == "Slot" then
			child:Destroy()
		end
	end

	owned.Supports.Visible = false
	owned.Decorations.Visible = false
	for name in CATEGORIES do
		owned[name].Activated:Connect(function()
			category = name
			render()
		end)
	end

	Hud.onBuildButton(BuildModeUi.toggle)

	-- 건물 정보 창과 겹치므로 선택 중에는 목록을 숨긴다
	EditMenu.onSelectionChanged(function(hasSelection)
		if active then
			owned.Visible = not hasSelection
		end
	end)

	State.Changed:Connect(function()
		local step = State.data.tutorial
		if step == FIRST_FIELD_STEP and lastTutorial ~= step then
			BuildModeUi.exit()
		end
		lastTutorial = step
		render()
	end)
end

return BuildModeUi
