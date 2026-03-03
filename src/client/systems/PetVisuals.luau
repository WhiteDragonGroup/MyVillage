-- PetVisuals.luau
-- 펫 이름표 BillboardGui, 작업중 표시

local PetVisuals = {}

local _activeLabels = {} -- { [BasePart]: BillboardGui }

----------------------------------------------------------------
-- 이름표 생성
----------------------------------------------------------------
local function createNameTag(pet: BasePart): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PetNameTag"
	billboard.Size = UDim2.new(0, 100, 0, 32)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = pet
	billboard.Parent = pet

	-- 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = pet:GetAttribute("PetName") or "펫"
	nameLabel.Parent = billboard

	-- 상태 라벨 (작업중 / 배회중)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0, 14)
	statusLabel.Position = UDim2.new(0, 0, 0, 15)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	statusLabel.TextStrokeTransparency = 0.5
	statusLabel.TextSize = 10
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Text = ""
	statusLabel.Parent = billboard

	return billboard
end

----------------------------------------------------------------
-- 상태 업데이트
----------------------------------------------------------------
local function updateStatus(billboard: BillboardGui, assignedBuildingId: string)
	local statusLabel = billboard:FindFirstChild("StatusLabel")
	if not statusLabel then return end

	if assignedBuildingId ~= "" then
		statusLabel.Text = "건설중..."
		statusLabel.TextColor3 = Color3.fromRGB(100, 220, 100)
	else
		statusLabel.Text = "배회중"
		statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end
end

----------------------------------------------------------------
-- 펫 감시
----------------------------------------------------------------
function PetVisuals.watchPet(pet: BasePart)
	if _activeLabels[pet] then return end

	local billboard = createNameTag(pet)
	_activeLabels[pet] = billboard

	local assignedId = pet:GetAttribute("AssignedBuildingId") or ""
	updateStatus(billboard, assignedId)

	-- 속성 변경 감지
	pet:GetAttributeChangedSignal("AssignedBuildingId"):Connect(function()
		local newId = pet:GetAttribute("AssignedBuildingId") or ""
		updateStatus(billboard, newId)
	end)
end

----------------------------------------------------------------
-- 플롯 내 펫 스캔
----------------------------------------------------------------
function PetVisuals.scanPlot(plot: Instance)
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("PetId") then
			PetVisuals.watchPet(child)
		end
	end

	plot.DescendantAdded:Connect(function(child)
		if child:IsA("BasePart") and child:GetAttribute("PetId") then
			task.wait()
			PetVisuals.watchPet(child)
		end
	end)

	plot.DescendantRemoving:Connect(function(child)
		if _activeLabels[child] then
			_activeLabels[child]:Destroy()
			_activeLabels[child] = nil
		end
	end)
end

----------------------------------------------------------------
-- 정리
----------------------------------------------------------------
function PetVisuals.cleanup()
	for pet, billboard in _activeLabels do
		billboard:Destroy()
	end
	_activeLabels = {}
end

return PetVisuals
