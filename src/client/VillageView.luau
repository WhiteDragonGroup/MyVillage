-- 건물 위 상태 표시와 주민 이동 연출. 생산·수확 판정과 무관한 표시 전용 코드다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared:WaitForChild("Buildings"))
local BuildingModels = require(Shared:WaitForChild("BuildingModels"))
local Items = require(Shared:WaitForChild("Items"))
local Production = require(Shared:WaitForChild("Production"))
local Ui = require(script.Parent.Ui)
local BuildEffect = require(script.Parent.BuildEffect)

local player = Players.LocalPlayer

local VILLAGER_HEIGHT = 1.25 -- 플레이어의 1/4
local VILLAGER_SPEED = 5
local LABEL_DISTANCE = 45

local VillageView = {}

local villagerFolder

----------------------------------------------------------------
-- 일터 상태 표시
----------------------------------------------------------------
local function labelText(model: Model, def): string
	local level = model:GetAttribute("Level") or 1
	local workers = model:GetAttribute("Workers") or 0
	local lines = { string.format("%s Lv%d  (%d/%d)", def.name, level, workers, def.capacity) }
	local allFull = true

	for _, itemId in def.outputs do
		local cap = Production.capacityOf(itemId, level)
		local stored = model:GetAttribute("Store_" .. itemId) or 0
		local full = stored >= cap
		allFull = allFull and full
		table.insert(lines, string.format("%s %d/%d%s", Items.ById[itemId].name, stored, cap, if full then " FULL" else ""))
	end

	if workers < def.capacity then
		table.insert(lines, "Place more homes for workers")
	end

	if allFull then
		lines[1] = "! " .. lines[1]
	end
	return table.concat(lines, "\n")
end

local function attachLabel(model: Model, def)
	local root = model:WaitForChild("Root")
	local _, size = model:GetBoundingBox()

	local billboard = Ui.make("BillboardGui", {
		Name = "Status",
		Adornee = root,
		AlwaysOnTop = true,
		ExtentsOffsetWorldSpace = Vector3.new(0, size.Y + 1, 0),
		MaxDistance = LABEL_DISTANCE,
		Size = UDim2.fromOffset(210, 42 + 18 * #def.outputs),
		Parent = root, -- 파츠 아래에 있어야 화면에 그려진다
	})
	local label = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Ui.Colors.White,
		TextSize = 14,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = billboard,
	})

	local function refresh()
		label.Text = labelText(model, def)
	end
	model.AttributeChanged:Connect(refresh)
	refresh()
end

local function attachHomeLabel(model: Model, def)
	local _, size = model:GetBoundingBox()
	local root = model:WaitForChild("Root")
	local billboard = Ui.make("BillboardGui", {
		Name = "Status",
		Adornee = root,
		AlwaysOnTop = true,
		ExtentsOffsetWorldSpace = Vector3.new(0, size.Y + 1, 0),
		MaxDistance = LABEL_DISTANCE,
		Size = UDim2.fromOffset(190, 40),
		Parent = root,
	})
	local label = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Ui.Colors.White,
		TextSize = 14,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = billboard,
	})

	local function refresh()
		local resting = 0
		for _, job in HttpService:JSONDecode(model:GetAttribute("Jobs") or "[]") do
			if not job then
				resting += 1
			end
		end
		label.Text = string.format("%s (%d)", def.name, def.residents)
		if resting > 0 then
			label.Text ..= string.format("\n%d resting · add a workplace", resting)
		end
	end
	model:GetAttributeChangedSignal("Jobs"):Connect(refresh)
	refresh()
end

----------------------------------------------------------------
-- 입구 표지판 (플레이어 이름·아바타)
----------------------------------------------------------------
local function refreshSign(plot: Instance)
	local signs = player.PlayerGui:FindFirstChild("VillageSigns")
	local sign = signs and signs:FindFirstChild((plot.Name:gsub("_", "")))
	if not sign then
		return
	end

	local ownerId = plot:GetAttribute("OwnerId")
	local owner = ownerId and Players:GetPlayerByUserId(ownerId)

	-- 자식 이름이 Name이라 속성과 겹치므로 FindFirstChild로 찾는다
	sign:FindFirstChild("Name").TextLabel.Text = if owner then owner.DisplayName else ""
	sign.ProfileIcon.ImageLabel.Image = if ownerId
		then string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", ownerId)
		else ""
end

----------------------------------------------------------------
-- 주민
----------------------------------------------------------------
local function makeVillager(): Model
	local source = BuildingModels.villagerTemplate()
	local model

	if source then
		model = source:Clone()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
	else
		model = Instance.new("Model")
		local body = Ui.make("Part", {
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Color = Color3.fromRGB(240, 200, 150),
			Size = Vector3.new(0.6, VILLAGER_HEIGHT, 0.6),
			Parent = model,
		})
		model.PrimaryPart = body
	end

	model.Parent = villagerFolder
	return model
end

local function walkTo(villager, target: Vector3)
	local mover = villager.mover
	local start = mover.Value.Position
	local flat = Vector3.new(target.X, start.Y, target.Z)
	local distance = (flat - start).Magnitude
	if distance < 0.1 then
		return
	end

	local tween = TweenService:Create(
		mover,
		TweenInfo.new(distance / VILLAGER_SPEED, Enum.EasingStyle.Linear),
		{ Value = CFrame.lookAt(flat, flat + (flat - start).Unit) }
	)
	tween:Play()
	tween.Completed:Wait()
end

local function runVillager(home: Model, index: number)
	local model = makeVillager()
	local mover = Instance.new("CFrameValue")
	local homeRoot = home:WaitForChild("Root")
	local _, size = model:GetBoundingBox()
	local groundOffset = Vector3.new(0, size.Y / 2, 0)

	local connection = mover.Changed:Connect(function(value)
		model:PivotTo(value)
	end)

	mover.Value = CFrame.new(homeRoot.Position + groundOffset)
	local villager = { mover = mover }
	local alive = true

	home.Destroying:Connect(function()
		alive = false
		connection:Disconnect()
		model:Destroy()
		mover:Destroy()
	end)

	local folder = home.Parent
	while alive do
		local jobs = HttpService:JSONDecode(home:GetAttribute("Jobs") or "[]")
		local workplace = jobs[index] and folder and folder:FindFirstChild(jobs[index])
		local anchor = if workplace then workplace.PrimaryPart else homeRoot
		local radius = if workplace then 3 else 2.5
		local angle = math.random() * math.pi * 2
		local target = anchor.Position + groundOffset + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		walkTo(villager, target)
		task.wait(1 + math.random() * 2)
	end
end

----------------------------------------------------------------
-- 마을 감시
----------------------------------------------------------------
local function onBuilding(model: Model)
	local id = model:GetAttribute("BuildingId")
	if not id then
		model:GetAttributeChangedSignal("BuildingId"):Wait()
		id = model:GetAttribute("BuildingId")
	end

	local def = Buildings.ById[id]
	if def.kind == "Work" then
		attachLabel(model, def)
	elseif def.kind == "Home" then
		attachHomeLabel(model, def)
		for index = 1, def.residents do
			task.spawn(runVillager, model, index)
		end
	end

	if BuildEffect.shouldPlay(model:GetAttribute("BuiltAt")) then
		BuildEffect.play(model)
	end
end

local function watchPlot(plot: Instance)
	plot:GetAttributeChangedSignal("OwnerId"):Connect(function()
		refreshSign(plot)
	end)
	refreshSign(plot)

	local function watchFolder(folder: Instance)
		folder.ChildAdded:Connect(function(model)
			task.spawn(onBuilding, model)
		end)
		for _, model in folder:GetChildren() do
			task.spawn(onBuilding, model)
		end
	end

	plot.ChildAdded:Connect(function(child)
		if child.Name == "Village" then
			watchFolder(child)
		end
	end)
	local existing = plot:FindFirstChild("Village")
	if existing then
		watchFolder(existing)
	end
end

function VillageView.start()
	BuildEffect.start()

	villagerFolder = Instance.new("Folder")
	villagerFolder.Name = "ClientVillagers"
	villagerFolder.Parent = workspace

	local plots = workspace:WaitForChild("Plots")
	plots.ChildAdded:Connect(watchPlot)
	for _, plot in plots:GetChildren() do
		watchPlot(plot)
	end
end

return VillageView
