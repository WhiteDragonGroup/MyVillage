-- 건물 툴을 들면 열리는 배치 모드: 미리보기, 격자 이동, 회전, 확정

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingModels = require(Shared:WaitForChild("BuildingModels"))
local Net = require(Shared:WaitForChild("Net"))
local Placement = require(Shared:WaitForChild("Placement"))
local Ui = require(script.Parent.Ui)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local placeEvent = Net.event("Place")
local moveEvent = Net.event("Move")

local RED = Color3.fromRGB(235, 70, 60)
local GREEN = Color3.fromRGB(80, 220, 110)

local BuildMode = {}

local session -- { tool, id, level, rot, x, z, ok, ghost, highlight, zone, others, connections }
local pointer = Vector2.new()
local hint, moveButtons
local pointerOnButton = false -- 버튼을 누르러 갈 때 미리보기가 따라가지 않게 멈춘다

local function myPlot(): Model?
	for _, plot in workspace:WaitForChild("Plots"):GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function collectOthers(plot: Model, exceptUid: string?)
	local others = {}
	local folder = plot:FindFirstChild("Village")
	if folder then
		for _, model in folder:GetChildren() do
			if model.Name ~= exceptUid then
				table.insert(others, {
					id = model:GetAttribute("BuildingId"),
					x = model:GetAttribute("X"),
					z = model:GetAttribute("Z"),
					rot = model:GetAttribute("Rot"),
				})
			end
		end
	end
	return others
end

-- 카메라 광선과 부지 바닥 평면의 교차점 (BuildZone 로컬 좌표)
local function pointerOnZone(zone: BasePart): Vector3?
	local ray = camera:ViewportPointToRay(pointer.X, pointer.Y)
	local groundY = zone.Position.Y + zone.Size.Y / 2
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local distance = (groundY - ray.Origin.Y) / ray.Direction.Y
	if distance < 0 then
		return nil
	end
	return zone.CFrame:PointToObjectSpace(ray.Origin + ray.Direction * distance)
end

local function rebuildGhost()
	if session.ghost then
		session.ghost:Destroy()
	end

	local ghost = BuildingModels.build(session.id, session.level, CFrame.new())
	ghost.Name = "BuildPreview"
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if part.Name ~= "Root" then
				part.Transparency = math.max(part.Transparency, 0.35)
			end
		end
	end
	ghost.Parent = workspace

	session.ghost = ghost
	session.highlight = Ui.make("Highlight", {
		FillTransparency = 0.6,
		OutlineTransparency = 0.2,
		Parent = ghost,
	})
end

local function update()
	if not session then
		return
	end

	local position = if pointerOnButton then nil else pointerOnZone(session.zone)
	if position then
		session.x, session.z = Placement.snap(session.id, position.X, position.Z, session.rot)
	end
	if not session.x then
		return
	end

	local size = session.zone.Size
	local ok, reason = Placement.check(session.id, session.x, session.z, session.rot, size.X, size.Z, session.others)
	session.ok = ok

	session.ghost:PivotTo(Placement.toWorld(session.zone, session.x, session.z, session.rot))
	session.highlight.FillColor = if ok then GREEN else RED
	session.highlight.OutlineColor = session.highlight.FillColor

	hint.Text = if ok then "Can place here" else reason
	hint.TextColor3 = if ok then GREEN else RED
end

local function rotate(direction: number)
	if session then
		session.rot = (session.rot + direction) % 4
	end
end

local function setButtonsVisible(visible: boolean)
	for _, button in moveButtons:GetChildren() do
		button.Visible = visible
	end
	if not visible then
		pointerOnButton = false
	end
end

local function confirm()
	if not session then
		return
	end
	if session.ok then
		if session.uid then
			moveEvent:FireServer(session.uid, session.x, session.z, session.rot)
		else
			placeEvent:FireServer(session.id, session.level, session.x, session.z, session.rot)
		end
	else
		Hud.toast(hint.Text, RED)
	end
end

local stop

local function cancel()
	if session and session.uid then
		stop()
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

function stop()
	if not session then
		return
	end
	for _, connection in session.connections do
		connection:Disconnect()
	end
	session.ghost:Destroy()
	session = nil
	hint.Visible = false
	setButtonsVisible(false)
	ContextActionService:UnbindAction("BuildRotate")
	ContextActionService:UnbindAction("BuildCancel")
end

-- spec: { tool?, uid?, id, level, rot, x?, z? }
local function begin(spec)
	stop()

	local plot = myPlot()
	if not plot then
		return
	end

	session = spec
	session.zone = plot:WaitForChild("BuildZone")
	session.others = collectOthers(plot, spec.uid)
	session.connections = {}
	rebuildGhost()

	local folder = plot:FindFirstChild("Village")
	if folder then
		table.insert(session.connections, folder.ChildAdded:Connect(function()
			task.defer(function()
				if session then
					session.others = collectOthers(plot, session.uid)
				end
			end)
		end))
	end
	if spec.tool then
		table.insert(session.connections, spec.tool.Activated:Connect(confirm))
	else
		table.insert(session.connections, UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
				confirm()
			end
		end))
	end
	table.insert(session.connections, RunService.RenderStepped:Connect(update))

	ContextActionService:BindAction("BuildRotate", function(_, state)
		if state == Enum.UserInputState.Begin then
			rotate(1)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonR1)
	ContextActionService:BindAction("BuildCancel", function(_, state)
		if state == Enum.UserInputState.Begin then
			cancel()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)

	hint.Visible = true
	setButtonsVisible(true)
end

local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("BuildingKey") then
			begin({
				tool = child,
				id = child:GetAttribute("BuildingId"),
				level = child:GetAttribute("BuildingLevel"),
				rot = 0,
			})
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if session and session.tool == child then
			stop()
		end
	end)
end

local function buildGui()
	local gui = Ui.make("ScreenGui", {
		Name = "BuildModeHud",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	hint = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.8), -- 배치 버튼 줄 위
		Size = UDim2.fromOffset(420, 32),
		TextSize = 20,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})

	moveButtons = Hud.placementButtons()

	local actions = {
		Place = confirm,
		Cancle = cancel,
		RotationCW = function()
			rotate(1)
		end,
		RotationCCW = function()
			rotate(-1)
		end,
	}
	for name, action in actions do
		local button = moveButtons:WaitForChild(name)
		button.Activated:Connect(action)
		button.MouseEnter:Connect(function()
			pointerOnButton = true
		end)
		button.MouseLeave:Connect(function()
			pointerOnButton = false
		end)
	end
end

-- 진행 중인 배치·이동을 끝낸다
function BuildMode.cancel()
	if session then
		cancel()
	end
end

function BuildMode.isActive(): boolean
	return session ~= nil
end

-- 배치된 건물의 이동·회전. 확정할 때까지 원래 자리에서 계속 생산한다.
function BuildMode.startMove(model: Model)
	begin({
		uid = model.Name,
		id = model:GetAttribute("BuildingId"),
		level = model:GetAttribute("Level"),
		rot = model:GetAttribute("Rot"),
		x = model:GetAttribute("X"),
		z = model:GetAttribute("Z"),
	})
end

function BuildMode.start()
	buildGui()

	pointer = UserInputService:GetMouseLocation()
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			pointer = UserInputService:GetMouseLocation()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch and not processed then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	Net.event("PlaceResult").OnClientEvent:Connect(function(ok, reason)
		if not ok and reason then
			Hud.toast(reason, RED)
		elseif ok and session and session.uid then
			stop()
		end
	end)

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return BuildMode
