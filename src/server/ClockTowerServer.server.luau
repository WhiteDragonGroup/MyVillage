-- ClockTowerServer.server.luau
-- ClockTower에 ProximityPrompt 부착, E 입력 시 종 울리며 펫들을 모음

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

local serverScript = script.Parent
local PetManager = require(serverScript:WaitForChild("PetManager"))

local BELL_COOLDOWN = 30 -- 30초 쿨다운
local _lastRingTime: { [Player]: number } = {}

local function ringBell(tower: Model)
	-- 종(Bell) 자식을 찾아서 좌우로 흔드는 트윈
	local bell = tower:FindFirstChild("Bell", true)
	if bell and bell:IsA("BasePart") then
		local origCFrame = bell.CFrame
		local swing = math.rad(20)
		local tweenIn = TweenService:Create(bell, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 6, true),
			{ CFrame = origCFrame * CFrame.Angles(0, 0, swing) })
		tweenIn:Play()
		tweenIn.Completed:Connect(function()
			bell.CFrame = origCFrame
		end)
	end
end

local function gatherPets(player: Player, tower: Model)
	local towerPos = tower:GetPivot().Position
	-- 플레이어의 모든 펫 모델을 ClockTower 근처로 이동
	for _, desc in workspace:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("PetId") and desc:GetAttribute("OwnerId") == player.UserId then
			local model = desc.Parent
			if model and model:IsA("Model") then
				local target = towerPos + Vector3.new(
					math.random(-5, 5),
					0,
					math.random(-5, 5)
				)
				task.spawn(function()
					if model.PrimaryPart then
						local startCFrame = model:GetPivot()
						local endCFrame = CFrame.new(target.X, startCFrame.Position.Y, target.Z)
						local steps = 30
						for i = 1, steps do
							if not model.Parent then return end
							local alpha = i / steps
							model:PivotTo(startCFrame:Lerp(endCFrame, alpha))
							task.wait(0.05)
						end
					end
				end)
			end
		end
	end
end

local function attachPrompt(tower: Model)
	if tower:FindFirstChildWhichIsA("ProximityPrompt") then return end

	-- ProximityPrompt를 PrimaryPart 또는 첫 BasePart에 부착
	local target = tower.PrimaryPart or tower:FindFirstChildWhichIsA("BasePart", true)
	if not target then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RingBellPrompt"
	prompt.ActionText = "Ring Bell"
	prompt.ObjectText = "Clock Tower"
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = target

	prompt.Triggered:Connect(function(player)
		local now = tick()
		if _lastRingTime[player] and now - _lastRingTime[player] < BELL_COOLDOWN then
			return
		end
		_lastRingTime[player] = now

		ringBell(tower)
		gatherPets(player, tower)
	end)
end

local function scanTowers()
	for _, desc in workspace:GetDescendants() do
		if desc:IsA("Model") and desc.Name == "ClockTower" then
			attachPrompt(desc)
		end
	end
end

scanTowers()
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Model") and desc.Name == "ClockTower" then
		task.wait(0.5) -- 모델 자식 다 들어올 때까지 대기
		attachPrompt(desc)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	_lastRingTime[player] = nil
end)

print("ClockTowerServer 로드됨")
