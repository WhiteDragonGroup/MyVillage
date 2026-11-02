-- 건물 외형과 바닥면적. 서버 배치와 클라이언트 미리보기가 같은 코드를 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Buildings = require(script.Parent.Buildings)

local HOUSE_FOLDER = "HouseTemplates"
local PLACEHOLDER_SIZE = Vector3.new(8, 4, 8)
local PLACEHOLDER_COLOR = Color3.fromRGB(200, 190, 170)

local BuildingModels = {}

local footprintCache = {}

-- 집 모델은 Workspace에 있어 스트리밍과 무관하게 쓰도록 서버 시작 시 복사한다
function BuildingModels.prepareServer()
	local folder = Instance.new("Folder")
	folder.Name = HOUSE_FOLDER

	local source = workspace:FindFirstChild("House")
	for _, def in Buildings.ById do
		local template = def.houseModel and source and source:FindFirstChild(def.houseModel)
		if template then
			template:Clone().Parent = folder
		elseif def.houseModel then
			warn("집 모델 없음: " .. def.houseModel)
		end
	end

	folder.Parent = ReplicatedStorage
end

local function templateFor(id: string, level: number): Model?
	local def = Buildings.ById[id]

	if def.houseModel then
		local folder = if RunService:IsServer()
			then ReplicatedStorage:FindFirstChild(HOUSE_FOLDER)
			else ReplicatedStorage:WaitForChild(HOUSE_FOLDER)
		return folder and folder:FindFirstChild(def.houseModel)
	end

	if def.model then
		local root = ReplicatedStorage:FindFirstChild("Buildings")
		local folder = root and root:FindFirstChild(def.model)
		if folder then
			return folder:FindFirstChild(string.format("%s_%d", def.model, level))
				or folder:FindFirstChild(string.format("%s_%02d", def.model, level))
		end
	end

	return nil
end

-- 레벨이 올라도 면적이 유지되도록 전 레벨 중 가장 큰 크기를 쓴다
function BuildingModels.footprint(id: string): (number, number)
	local cached = footprintCache[id]
	if cached then
		return cached[1], cached[2]
	end

	local width, depth = 0, 0
	local levels = Buildings.ById[id].kind == "Home" and 1 or Buildings.MAX_LEVEL

	for level = 1, levels do
		local template = templateFor(id, level)
		if template then
			local _, size = template:GetBoundingBox()
			width = math.max(width, math.ceil(size.X - 0.01))
			depth = math.max(depth, math.ceil(size.Z - 0.01))
		end
	end

	if width == 0 then
		width, depth = PLACEHOLDER_SIZE.X, PLACEHOLDER_SIZE.Z
	end

	footprintCache[id] = { width, depth }
	return width, depth
end

local function makeVisual(id: string, level: number): Instance
	local template = templateFor(id, level)
	if template then
		return template:Clone()
	end

	local part = Instance.new("Part")
	part.Name = "Placeholder"
	part.Size = PLACEHOLDER_SIZE
	part.Color = Buildings.ById[id].color or PLACEHOLDER_COLOR
	part.Material = Enum.Material.SmoothPlastic

	local model = Instance.new("Model")
	model.Name = "Placeholder"
	part.Parent = model
	model.PrimaryPart = part
	return model
end

function BuildingModels.isVisiblePart(instance: Instance): boolean
	return instance:IsA("BasePart") and instance.Transparency < 0.99
end

function BuildingModels.visiblePartCount(model: Model): number
	local count = 0
	for _, descendant in model:WaitForChild("Visual"):GetDescendants() do
		if BuildingModels.isVisiblePart(descendant) then
			count += 1
		end
	end
	return count
end

local function lowestPoint(part: BasePart): number
	local cframe, size = part.CFrame, part.Size
	local lowest = math.huge
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local corner = cframe:PointToWorldSpace(Vector3.new(x * size.X, y * size.Y, z * size.Z) / 2)
				lowest = math.min(lowest, corner.Y)
			end
		end
	end
	return lowest
end

local function widestPart(visual: Instance): BasePart?
	local widest, widestArea = nil, 0
	for _, descendant in visual:GetDescendants() do
		if BuildingModels.isVisiblePart(descendant) then
			local area = descendant.Size.X * descendant.Size.Z
			if area > widestArea then
				widest, widestArea = descendant, area
			end
		end
	end
	return widest
end

-- groundCFrame: 바닥 중앙. 반환 모델의 PrimaryPart가 바닥 기준점이다.
function BuildingModels.build(id: string, level: number, groundCFrame: CFrame): Model
	local width, depth = BuildingModels.footprint(id)

	local wrapper = Instance.new("Model")

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(width, 0.2, depth)
	root.CFrame = groundCFrame
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = wrapper
	wrapper.PrimaryPart = root

	local visual = makeVisual(id, level)
	visual.Name = "Visual"
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	local box, size = visual:GetBoundingBox()
	local pivotOffset = box:ToObjectSpace(visual:GetPivot())
	visual:PivotTo(groundCFrame * CFrame.new(0, size.Y / 2, 0) * pivotOffset)

	if Buildings.ById[id].groundOnWidestPart then
		local widest = widestPart(visual)
		if widest then
			visual:PivotTo(visual:GetPivot() - Vector3.new(0, lowestPoint(widest) - groundCFrame.Y, 0))
		end
	end

	visual.Parent = wrapper

	return wrapper
end

return BuildingModels
