-- 우측 현재 목표 한 줄과 튜토리얼 강조

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared:WaitForChild("Buildings"))
local Net = require(Shared:WaitForChild("Net"))
local Production = require(Shared:WaitForChild("Production"))
local Ui = require(script.Parent.Ui)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)

local player = Players.LocalPlayer

local PULSE_SCALE = 1.2
local PULSE_TIME = 0.45
local GUIDE_COLOR = Color3.fromRGB(255, 230, 90)
local ARROW_SIZE = 64
local ARROW_HEIGHT = 5
local ARROW_BOUNCE = 1
local ARROW_BOUNCE_TIME = 0.5
local HINT_SECONDS = 4
local HINT_CHECK_SECONDS = 2

local HINTS = {
	edit = "Use the hammer to move, store or upgrade buildings",
	clock = "You can upgrade your Clock Tower with the hammer",
	full = "Touch a full workplace to harvest it",
}

-- button: Normal.Frame에서 강조할 버튼, farm: 내 농장 강조
local STEPS = {
	{ text = "Place your 2-Resident Cottage", button = "BulildMode" },
	{ text = "Place your Farm", button = "BulildMode" },
	{ text = "Your villagers are heading to work" },
	{ text = "Touch the Farm to harvest", farm = true },
	{ text = "Sell your Wheat", button = "Pets" },
	{ text = "Buy a Lumberyard in the shop", button = "Shop" },
	{ text = "Place the Lumberyard and your new Cottage", button = "BulildMode" },
}

local hintSeenEvent = Net.event("HintSeen")

local Guide = {}

local goal, pulse, pulseTarget, farmHighlight, arrowImage
local guideObjects = {}
local hintShown = {}

local function stopPulse()
	if pulse then
		pulse:Cancel()
		pulse = nil
	end
	if pulseTarget then
		pulseTarget:Destroy()
		pulseTarget = nil
	end
end

local function startPulse(button: GuiObject)
	pulseTarget = Instance.new("UIScale")
	pulseTarget.Parent = button
	pulse = TweenService:Create(
		pulseTarget,
		TweenInfo.new(PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = PULSE_SCALE }
	)
	pulse:Play()
end

local function myVillage(): Instance?
	for _, plot in workspace:WaitForChild("Plots"):GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot:FindFirstChild("Village")
		end
	end
	return nil
end

local function myFarm(): Model?
	local folder = myVillage()
	if folder then
		for _, model in folder:GetChildren() do
			if model:GetAttribute("BuildingId") == "Farm" then
				return model
			end
		end
	end
	return nil
end

local function clearFarmGuide()
	for _, object in guideObjects do
		object:Destroy()
	end
	table.clear(guideObjects)
	farmHighlight = nil
end

-- 강조, 위에서 튀는 화살표, 캐릭터에서 농장까지 이어지는 안내선
local function showFarmGuide()
	if farmHighlight and farmHighlight.Parent then
		return
	end
	clearFarmGuide()

	local farm = myFarm()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not farm or not root then
		return
	end

	farmHighlight = Ui.make("Highlight", {
		FillColor = GUIDE_COLOR,
		FillTransparency = 0.7,
		OutlineColor = GUIDE_COLOR,
		Parent = farm,
	})
	table.insert(guideObjects, farmHighlight)

	local billboard = Ui.make("BillboardGui", {
		Adornee = farm.PrimaryPart,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE),
		StudsOffsetWorldSpace = Vector3.new(0, ARROW_HEIGHT, 0),
		Parent = farm.PrimaryPart,
	})
	Ui.make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = arrowImage,
		ImageColor3 = GUIDE_COLOR,
		Rotation = 90,
		Size = UDim2.fromScale(1, 1),
		Parent = billboard,
	})
	table.insert(guideObjects, billboard)

	local bounce = TweenService:Create(
		billboard,
		TweenInfo.new(ARROW_BOUNCE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffsetWorldSpace = Vector3.new(0, ARROW_HEIGHT + ARROW_BOUNCE, 0) }
	)
	bounce:Play()

	local from = Ui.make("Attachment", { Parent = root })
	local to = Ui.make("Attachment", { Parent = farm.PrimaryPart })
	local beam = Ui.make("Beam", {
		Attachment0 = from,
		Attachment1 = to,
		Color = ColorSequence.new(GUIDE_COLOR),
		FaceCamera = true,
		LightEmission = 1,
		Transparency = NumberSequence.new(0.35),
		Width0 = 0.4,
		Width1 = 0.4,
		Parent = root,
	})
	table.insert(guideObjects, from)
	table.insert(guideObjects, to)
	table.insert(guideObjects, beam)
end

local function showHint(id: string)
	if hintShown[id] or (State.data.hints and State.data.hints[id]) then
		return
	end
	hintShown[id] = true
	hintSeenEvent:FireServer(id)
	Hud.toast(HINTS[id], GUIDE_COLOR, HINT_SECONDS)
end

local function anyWorkplaceFull(): boolean
	local folder = myVillage()
	if not folder then
		return false
	end

	for _, model in folder:GetChildren() do
		local def = Buildings.ById[model:GetAttribute("BuildingId")]
		if def and def.kind == "Work" then
			local level = model:GetAttribute("Level") or 1
			for _, itemId in def.outputs do
				if (model:GetAttribute("Store_" .. itemId) or 0) >= Production.capacityOf(itemId, level) then
					return true
				end
			end
		end
	end
	return false
end

-- 튜토리얼이 끝난 뒤, 기능이 필요해지는 순간에 한 번씩 알려 준다
local function checkHints()
	if State.data.tutorial then
		return
	end

	showHint("edit")

	local cost = Buildings.ClockTowerUpgrade[State.data.clockTower]
	if cost and State.data.coins >= cost then
		showHint("clock")
	end
	if anyWorkplaceFull() then
		showHint("full")
	end
end

local function refresh()
	stopPulse()

	local step = State.data.tutorial and STEPS[State.data.tutorial]
	if step then
		goal.Text = step.text
		if step.farm then
			showFarmGuide()
		else
			clearFarmGuide()
		end
		if step.button then
			startPulse(player.PlayerGui.Normal.Frame[step.button])
		end
		return
	end

	clearFarmGuide()

	local cost = Buildings.ClockTowerUpgrade[State.data.clockTower]
	goal.Text = if cost
		then string.format("Next : Clock Tower Lv.%d · $%s", State.data.clockTower + 1, Hud.formatNumber(cost))
		else "Your Clock Tower is at max level"
end

function Guide.start()
	local gui = Ui.make("ScreenGui", {
		Name = "VillageGoal",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	goal = Ui.label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.2, 0), -- 빌드 모드 목록과 겹치지 않는 높이
		Size = UDim2.new(0.3, 0, 0, 30),
		TextColor3 = Ui.Colors.White,
		TextScaled = true,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = gui,
	})

	-- 판매 확인창의 화살표를 안내 화살표로 쓴다
	local popUp = player.PlayerGui:WaitForChild("Features"):WaitForChild("PopUp")
	local arrow = popUp:FindFirstChildWhichIsA("ImageLabel", true)
	for _, descendant in popUp:GetDescendants() do
		if descendant:IsA("ImageLabel") and descendant.Parent:IsA("TextLabel") then
			arrow = descendant
		end
	end
	arrowImage = arrow.Image

	State.Changed:Connect(refresh)
	refresh()

	task.spawn(function()
		while true do
			task.wait(HINT_CHECK_SECONDS)
			checkHints()
		end
	end)
end

return Guide
