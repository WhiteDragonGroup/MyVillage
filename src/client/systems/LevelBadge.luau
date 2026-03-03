-- LevelBadge.luau
-- 건물 위에 "Lv.X" 뱃지 표시 (레벨 2 이상부터)

local LevelBadge = {}

local _activeBadges = {} -- { [BasePart]: BillboardGui }
local _connections = {}  -- { [BasePart]: RBXScriptConnection }

----------------------------------------------------------------
-- 뱃지 생성
----------------------------------------------------------------
local function createBadge(building: BasePart, level: number): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelBadge"
	billboard.Size = UDim2.new(0, 46, 0, 22)
	billboard.StudsOffset = Vector3.new(0, building.Size.Y / 2 + 0.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = building
	billboard.Parent = building

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 80)
	stroke.Thickness = 1
	stroke.Parent = bg

	local label = Instance.new("TextLabel")
	label.Name = "LevelLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 220, 100)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 13
	label.Font = Enum.Font.GothamBold
	label.Text = "Lv." .. level
	label.Parent = billboard

	return billboard
end

----------------------------------------------------------------
-- 뱃지 업데이트
----------------------------------------------------------------
local function updateBadge(building: BasePart)
	local level = building:GetAttribute("Level") or 1

	-- Lv.1이면 뱃지 숨김
	if level <= 1 then
		local badge = _activeBadges[building]
		if badge then
			badge:Destroy()
			_activeBadges[building] = nil
		end
		return
	end

	-- 뱃지가 이미 있으면 텍스트만 업데이트
	local badge = _activeBadges[building]
	if badge then
		local label = badge:FindFirstChild("LevelLabel")
		if label then
			label.Text = "Lv." .. level
		end
		return
	end

	-- 새 뱃지 생성
	badge = createBadge(building, level)
	_activeBadges[building] = badge
end

----------------------------------------------------------------
-- 건물 감시
----------------------------------------------------------------
function LevelBadge.watchBuilding(building: BasePart)
	if _connections[building] then return end

	updateBadge(building)

	_connections[building] = building:GetAttributeChangedSignal("Level"):Connect(function()
		updateBadge(building)
	end)
end

----------------------------------------------------------------
-- 감시 해제
----------------------------------------------------------------
function LevelBadge.unwatchBuilding(building: BasePart)
	local conn = _connections[building]
	if conn then
		conn:Disconnect()
		_connections[building] = nil
	end

	local badge = _activeBadges[building]
	if badge then
		badge:Destroy()
		_activeBadges[building] = nil
	end
end

----------------------------------------------------------------
-- 플롯 스캔
----------------------------------------------------------------
function LevelBadge.scanPlot(plot: Instance)
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") then
			LevelBadge.watchBuilding(child)
		end
	end

	plot.DescendantAdded:Connect(function(child)
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") then
			task.wait()
			LevelBadge.watchBuilding(child)
		end
	end)

	plot.DescendantRemoving:Connect(function(child)
		if _activeBadges[child] or _connections[child] then
			LevelBadge.unwatchBuilding(child)
		end
	end)
end

----------------------------------------------------------------
-- 정리
----------------------------------------------------------------
function LevelBadge.cleanup()
	for building, _ in _connections do
		LevelBadge.unwatchBuilding(building)
	end
	_activeBadges = {}
	_connections = {}
end

return LevelBadge
