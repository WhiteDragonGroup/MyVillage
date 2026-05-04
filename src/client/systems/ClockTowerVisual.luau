-- ClockTowerVisual.luau
-- ClockTower의 시침/분침을 게임 시간(Lighting.ClockTime)에 맞춰 회전

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local ClockTowerVisual = {}

local _trackedTowers: { [Model]: { hourHand: BasePart?, minuteHand: BasePart? } } = {}

local function findTowerHands(model: Model)
	local hourHand = model:FindFirstChild("HourHand", true)
	local minuteHand = model:FindFirstChild("MinuteHand", true)
	return
		(hourHand and hourHand:IsA("BasePart")) and hourHand or nil,
		(minuteHand and minuteHand:IsA("BasePart")) and minuteHand or nil
end

local function trackTower(model: Model)
	if _trackedTowers[model] then return end
	local h, m = findTowerHands(model)
	if not h and not m then return end

	-- 원본 회전 저장
	local hOrig = h and h.CFrame
	local mOrig = m and m.CFrame

	_trackedTowers[model] = {
		hourHand = h,
		minuteHand = m,
		hOrig = hOrig,
		mOrig = mOrig,
	}

	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			_trackedTowers[model] = nil
		end
	end)
end

local function scanWorkspace()
	for _, desc in workspace:GetDescendants() do
		if desc:IsA("Model") and desc.Name == "ClockTower" then
			trackTower(desc)
		end
	end
end

function ClockTowerVisual.init()
	scanWorkspace()
	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("Model") and desc.Name == "ClockTower" then
			trackTower(desc)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local clockTime = Lighting.ClockTime
		-- 시침: 12시간 = 360도, 1시간 = 30도
		local hourAngle = math.rad(((clockTime % 12) / 12) * 360)
		-- 분침: 60분 = 360도, ClockTime 소수부 = 분
		local minutes = (clockTime % 1) * 60
		local minuteAngle = math.rad((minutes / 60) * 360)

		for model, info in _trackedTowers do
			if info.hourHand and info.hourHand.Parent then
				if info.hOrig then
					info.hourHand.CFrame = info.hOrig * CFrame.Angles(0, 0, -hourAngle)
				end
			end
			if info.minuteHand and info.minuteHand.Parent then
				if info.mOrig then
					info.minuteHand.CFrame = info.mOrig * CFrame.Angles(0, 0, -minuteAngle)
				end
			end
		end
	end)
end

return ClockTowerVisual
