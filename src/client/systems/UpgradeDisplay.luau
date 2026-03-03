-- UpgradeDisplay.luau
-- 수리중 건물 위에 BillboardGui 게이지바 + 퍼센트 표시
-- 건물 속성(UpgradeState, UpgradeProgress) 변경 감지

local UpgradeDisplay = {}

local _activeDisplays = {} -- { [BasePart]: BillboardGui }
local _connections = {}    -- { [BasePart]: { RBXScriptConnection } }

local BAR_WIDTH = 120
local BAR_HEIGHT = 14
local BILLBOARD_OFFSET = Vector3.new(0, 2, 0)

----------------------------------------------------------------
-- BillboardGui 생성
----------------------------------------------------------------
local function createGaugeBar(building: BasePart): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "UpgradeGauge"
	billboard.Size = UDim2.new(0, BAR_WIDTH + 10, 0, 36)
	billboard.StudsOffset = BILLBOARD_OFFSET + Vector3.new(0, building.Size.Y / 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = building
	billboard.Parent = building

	-- 배경 바
	local bgBar = Instance.new("Frame")
	bgBar.Name = "BgBar"
	bgBar.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	bgBar.Position = UDim2.new(0.5, -BAR_WIDTH / 2, 0, 0)
	bgBar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	bgBar.BorderSizePixel = 0
	bgBar.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 6)
	bgCorner.Parent = bgBar

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(80, 80, 100)
	bgStroke.Thickness = 1
	bgStroke.Parent = bgBar

	-- 진행도 바
	local fillBar = Instance.new("Frame")
	fillBar.Name = "FillBar"
	fillBar.Size = UDim2.new(0, 0, 1, -2)
	fillBar.Position = UDim2.new(0, 1, 0, 1)
	fillBar.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
	fillBar.BorderSizePixel = 0
	fillBar.Parent = bgBar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fillBar

	-- 퍼센트 텍스트
	local label = Instance.new("TextLabel")
	label.Name = "PercentLabel"
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Position = UDim2.new(0, 0, 0, BAR_HEIGHT + 2)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 12
	label.Font = Enum.Font.GothamBold
	label.Text = "0%"
	label.Parent = billboard

	return billboard
end

----------------------------------------------------------------
-- 게이지 업데이트
----------------------------------------------------------------
local function updateGauge(billboard: BillboardGui, progress: number)
	local bgBar = billboard:FindFirstChild("BgBar")
	if not bgBar then return end

	local fillBar = bgBar:FindFirstChild("FillBar")
	if fillBar then
		local fillWidth = math.clamp(progress / 100, 0, 1) * (BAR_WIDTH - 2)
		fillBar.Size = UDim2.new(0, fillWidth, 1, -2)
	end

	local label = billboard:FindFirstChild("PercentLabel")
	if label then
		label.Text = math.floor(progress) .. "%"
	end
end

----------------------------------------------------------------
-- 건물 감시 시작
----------------------------------------------------------------
function UpgradeDisplay.watchBuilding(building: BasePart)
	if _activeDisplays[building] then return end

	local state = building:GetAttribute("UpgradeState") or ""
	if state == "Upgrading" then
		UpgradeDisplay._showGauge(building)
	end

	local conns = {}

	-- UpgradeState 변경 감지
	table.insert(conns, building:GetAttributeChangedSignal("UpgradeState"):Connect(function()
		local newState = building:GetAttribute("UpgradeState") or ""
		if newState == "Upgrading" then
			UpgradeDisplay._showGauge(building)
		else
			UpgradeDisplay._hideGauge(building)
		end
	end))

	-- UpgradeProgress 변경 감지
	table.insert(conns, building:GetAttributeChangedSignal("UpgradeProgress"):Connect(function()
		local billboard = _activeDisplays[building]
		if billboard then
			local progress = building:GetAttribute("UpgradeProgress") or 0
			updateGauge(billboard, progress)
		end
	end))

	_connections[building] = conns
end

----------------------------------------------------------------
-- 감시 해제
----------------------------------------------------------------
function UpgradeDisplay.unwatchBuilding(building: BasePart)
	UpgradeDisplay._hideGauge(building)

	local conns = _connections[building]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		_connections[building] = nil
	end
end

----------------------------------------------------------------
-- 게이지 표시/숨기기
----------------------------------------------------------------
function UpgradeDisplay._showGauge(building: BasePart)
	if _activeDisplays[building] then return end

	local billboard = createGaugeBar(building)
	_activeDisplays[building] = billboard

	local progress = building:GetAttribute("UpgradeProgress") or 0
	updateGauge(billboard, progress)
end

function UpgradeDisplay._hideGauge(building: BasePart)
	local billboard = _activeDisplays[building]
	if billboard then
		billboard:Destroy()
		_activeDisplays[building] = nil
	end
end

----------------------------------------------------------------
-- 전체 건물 스캔 (플롯 내 모든 건물 감시 시작)
----------------------------------------------------------------
function UpgradeDisplay.scanPlot(plot: Instance)
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") then
			UpgradeDisplay.watchBuilding(child)
		end
	end

	-- 새 건물 추가 감지
	plot.DescendantAdded:Connect(function(child)
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") then
			task.wait() -- 속성 설정 대기
			UpgradeDisplay.watchBuilding(child)
		end
	end)

	plot.DescendantRemoving:Connect(function(child)
		if child:IsA("BasePart") and _activeDisplays[child] then
			UpgradeDisplay.unwatchBuilding(child)
		end
	end)
end

----------------------------------------------------------------
-- 정리
----------------------------------------------------------------
function UpgradeDisplay.cleanup()
	for building, _ in _activeDisplays do
		UpgradeDisplay.unwatchBuilding(building)
	end
	_activeDisplays = {}
	_connections = {}
end

return UpgradeDisplay
