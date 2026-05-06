-- UpgradeVisual.luau
-- 업그레이드 중인 건물 주위에 ConstructionLine 모델을 표시하고 크기에 맞게 스케일

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local UpgradeVisual = {}

local _attached: { [BasePart]: Instance } = {}
local _connections: { [BasePart]: RBXScriptConnection } = {}

local function getConstructionTemplate(): Instance?
	local models = ReplicatedStorage:FindFirstChild("Models")
	if not models then return nil end
	local folder = models:FindFirstChild("ConstructionLine")
	if not folder then return nil end
	-- 자식 Model 중 첫 번째 사용 (디자이너가 여러 변형 둠)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			return child
		end
	end
	-- BasePart 폴백
	return folder:FindFirstChildWhichIsA("BasePart")
end

local function getBuildingModel(building: BasePart): Instance
	-- 건물의 최상위 Model 찾기 (플롯에 도달하기 전까지)
	local topModel = nil
	local current = building.Parent
	while current and current ~= workspace do
		if current:GetAttribute("Owner") ~= nil then break end
		if current.Name == "Plots" then break end
		if current:IsA("Model") then
			topModel = current
		end
		current = current.Parent
	end
	return topModel or building
end

local function getBoundingBox(target: Instance): (CFrame, Vector3)
	if target:IsA("Model") then
		return target:GetBoundingBox()
	elseif target:IsA("BasePart") then
		return target.CFrame, target.Size
	end
	return CFrame.new(), Vector3.zero
end

local function attach(building: BasePart)
	if _attached[building] then return end

	local template = getConstructionTemplate()
	if not template then return end

	local clone = template:Clone()
	-- 원본 라인의 바운딩박스
	local origCF, origSize
	if clone:IsA("Model") then
		origCF, origSize = clone:GetBoundingBox()
	elseif clone:IsA("BasePart") then
		origCF, origSize = clone.CFrame, clone.Size
	end

	-- 건물 바운딩박스에 맞춰 스케일 계산
	local target = getBuildingModel(building)
	local targetCF, targetSize = getBoundingBox(target)

	-- 균등 스케일 (가장 큰 차원 기준 + 약간 여유)
	local maxOrig = math.max(origSize.X, origSize.Y, origSize.Z)
	local maxTarget = math.max(targetSize.X, targetSize.Y, targetSize.Z)
	if maxOrig <= 0 then maxOrig = 1 end
	local scaleFactor = (maxTarget / maxOrig) * 1.05

	if clone:IsA("Model") and clone.ScaleTo then
		clone:ScaleTo(scaleFactor)
		clone:PivotTo(targetCF)
	elseif clone:IsA("BasePart") then
		clone.Size = origSize * scaleFactor
		clone.CFrame = targetCF
		clone.Anchored = true
	end

	-- 라인이 충돌/터치 일으키지 않도록
	for _, p in (clone:IsA("Model") and clone:GetDescendants() or { clone }) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end

	clone.Name = "_ConstructionLine"
	clone.Parent = workspace
	_attached[building] = clone
end

local function detach(building: BasePart)
	local existing = _attached[building]
	if existing then
		existing:Destroy()
		_attached[building] = nil
	end
end

local function watchBuilding(building: BasePart)
	if _connections[building] then return end

	-- 현재 상태 즉시 반영
	if building:GetAttribute("UpgradeState") == "Upgrading" then
		attach(building)
	end

	_connections[building] = building:GetAttributeChangedSignal("UpgradeState"):Connect(function()
		local state = building:GetAttribute("UpgradeState")
		if state == "Upgrading" then
			attach(building)
		else
			detach(building)
		end
	end)

	building.AncestryChanged:Connect(function(_, parent)
		if not parent then
			detach(building)
			if _connections[building] then
				_connections[building]:Disconnect()
				_connections[building] = nil
			end
		end
	end)
end

local function scanBuildings()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end
	for _, desc in plots:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") then
			watchBuilding(desc)
		end
	end
end

function UpgradeVisual.init()
	scanBuildings()
	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") then
			watchBuilding(desc)
		end
	end)
end

return UpgradeVisual
