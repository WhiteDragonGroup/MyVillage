-- PlotSetup.server.luau
-- 6개의 플롯을 원형으로 배치하는 스크립트

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plotTemplate = ReplicatedStorage:WaitForChild("PlotTemplate")
local plotsFolder = workspace:WaitForChild("Plots")

-- 설정
local PLOT_COUNT = 6
local RADIUS = 120  -- 중심에서 플롯까지 거리
local CENTER = Vector3.new(0, 0, 0)

-- 원형으로 플롯 배치
for i = 1, PLOT_COUNT do
	local angle = math.rad(360 / PLOT_COUNT * i)
	local x = math.cos(angle) * RADIUS
	local z = math.sin(angle) * RADIUS

	local plot = plotTemplate:Clone()
	plot.Name = "Plot" .. i

	-- 플롯 위치 설정
	local plotPosition = CENTER + Vector3.new(x, 0, z)
	plot:PivotTo(CFrame.new(plotPosition))

	-- 플롯이 중심을 바라보도록 회전
	local lookAt = CFrame.lookAt(plotPosition, CENTER)
	plot:PivotTo(lookAt)

	-- 소유자 정보 저장용 속성 추가
	local ownerValue = Instance.new("StringValue")
	ownerValue.Name = "Owner"
	ownerValue.Value = ""  -- 비어있으면 빈 플롯
	ownerValue.Parent = plot

	plot.Parent = plotsFolder
end

print("✅ " .. PLOT_COUNT .. "개 플롯 배치 완료!")