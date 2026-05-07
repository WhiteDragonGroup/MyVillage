-- UpgradeVisual.luau
-- 업그레이드 중인 건물 주위에 ConstructionLine 모델을 표시하고 크기에 맞게 스케일

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local UpgradeVisual = {}

local _attached: { [BasePart]: Instance } = {}
local _connections: { [BasePart]: RBXScriptConnection } = {}

local _logged = false
local function getConstructionTemplate(): Instance?
	local models = ReplicatedStorage:FindFirstChild("Models")
	if not models then
		warn("[UpgradeVisual] ReplicatedStorage.Models 없음")
		return nil
	end
	local folder = models:FindFirstChild("ConstructionLine")
	if not folder then
		warn("[UpgradeVisual] ReplicatedStorage.Models.ConstructionLine 없음")
		return nil
	end

	-- 디버그: 첫 호출 시 폴더 구조 출력
	if not _logged then
		_logged = true
		print("[UpgradeVisual] ConstructionLine 폴더 ClassName=" .. folder.ClassName)
		for i, child in folder:GetChildren() do
			print("  [" .. i .. "] " .. child.Name .. " (" .. child.ClassName .. ")")
			if child:IsA("Model") then
				local cf, sz = child:GetBoundingBox()
				print("       bbox size=" .. tostring(sz))
			end
		end
	end

	-- folder 자체가 Model이면 folder 사용, 아니면 첫 Model 자식
	if folder:IsA("Model") then
		return folder
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			return child
		end
	end
	local fallback = folder:FindFirstChildWhichIsA("BasePart")
	if not fallback then
		warn("[UpgradeVisual] ConstructionLine 안에 Model/BasePart 없음")
	end
	return fallback
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
	print("[UpgradeVisual] attaching ConstructionLine to " .. (building:GetAttribute("ItemName") or "?"))

	local clone = template:Clone()

	-- 건물 바운딩박스 (목표 크기)
	local target = getBuildingModel(building)
	local targetCF, targetSize = getBoundingBox(target)
	local margin = 1.05

	if clone:IsA("Model") then
		-- 원본 모델을 원점에 두고 축별 비율 스케일 적용
		local origCF, origSize = clone:GetBoundingBox()
		if origSize.X <= 0 or origSize.Y <= 0 or origSize.Z <= 0 then
			clone:Destroy()
			return
		end
		local sx = (targetSize.X / origSize.X) * margin
		local sy = (targetSize.Y / origSize.Y) * margin
		local sz = (targetSize.Z / origSize.Z) * margin
		-- 원점 정렬: 각 파트에서 origCF.Position 빼고 축별 스케일 후 다시 더함
		for _, p in clone:GetDescendants() do
			if p:IsA("BasePart") then
				local rel = p.Position - origCF.Position
				local scaledPos = Vector3.new(rel.X * sx, rel.Y * sy, rel.Z * sz)
				p.Size = Vector3.new(
					math.max(0.05, p.Size.X * sx),
					math.max(0.05, p.Size.Y * sy),
					math.max(0.05, p.Size.Z * sz)
				)
				-- 회전 유지하면서 위치 갱신
				p.CFrame = CFrame.new(origCF.Position + scaledPos) * (p.CFrame - p.Position)
			end
		end
		-- 건물 위치/회전에 맞추기
		local newCF, _ = clone:GetBoundingBox()
		local relativePivot = newCF:Inverse() * clone:GetPivot()
		clone:PivotTo(targetCF * relativePivot)
	elseif clone:IsA("BasePart") then
		clone.Size = Vector3.new(
			targetSize.X * margin,
			targetSize.Y * margin,
			targetSize.Z * margin
		)
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
