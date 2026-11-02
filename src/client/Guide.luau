-- 우측 현재 목표 한 줄과 튜토리얼 강조

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared:WaitForChild("Buildings"))
local Ui = require(script.Parent.Ui)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)

local player = Players.LocalPlayer

local PULSE_SCALE = 1.2
local PULSE_TIME = 0.45

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

local Guide = {}

local goal, pulse, pulseTarget, farmHighlight

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

local function setFarmHighlight(enabled: boolean)
	if farmHighlight then
		farmHighlight:Destroy()
		farmHighlight = nil
	end
	if not enabled then
		return
	end

	for _, plot in workspace:WaitForChild("Plots"):GetChildren() do
		local folder = plot:GetAttribute("OwnerId") == player.UserId and plot:FindFirstChild("Village")
		if folder then
			for _, model in folder:GetChildren() do
				if model:GetAttribute("BuildingId") == "Farm" then
					farmHighlight = Ui.make("Highlight", {
						FillColor = Color3.fromRGB(255, 230, 90),
						FillTransparency = 0.7,
						OutlineColor = Color3.fromRGB(255, 230, 90),
						Parent = model,
					})
					return
				end
			end
		end
	end
end

local function refresh()
	stopPulse()

	local step = State.data.tutorial and STEPS[State.data.tutorial]
	if step then
		goal.Text = step.text
		setFarmHighlight(step.farm == true)
		if step.button then
			startPulse(player.PlayerGui.Normal.Frame[step.button])
		end
		return
	end

	setFarmHighlight(false)

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

	State.Changed:Connect(refresh)
	refresh()
end

return Guide
