-- CollisionDetector.luau
-- CollisionBox 기반 건물 겹침 감지
-- 건물 종류별 고정 사이즈(collisionSize)를 사용하여 판정

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local CollisionDetector = {}

-- 고정 사이즈 기반 충돌 체크
-- targetCFrame: 배치할 위치
-- itemName: 건물 종류 (collisionSize 조회용)
-- ignoreParts: 무시할 파트 목록
function CollisionDetector.checkCollisionBySize(targetCFrame: CFrame, itemName: string, ignoreParts: { Instance }?): (boolean, { BasePart })
	local collisionSize = Constants.getCollisionSize(itemName)

	-- 임시 프로브 파트 생성
	local probe = Instance.new("Part")
	probe.Name = "_CollisionProbe"
	probe.Size = collisionSize
	probe.CFrame = targetCFrame
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = true
	probe.Transparency = 1
	probe.Parent = workspace

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local combined = { probe }

	if ignoreParts then
		for _, p in ignoreParts do
			table.insert(combined, p)
		end
	end

	-- PlacementPreview 무시
	for _, p in workspace:GetDescendants() do
		if p.Name == "PlacementPreview" and p:IsA("BasePart") then
			table.insert(combined, p)
		end
	end

	-- 플레이어 캐릭터 무시
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(combined, plr.Character)
		end
	end

	params.FilterDescendantsInstances = combined

	local touchingParts = workspace:GetPartsInPart(probe, params)
	probe:Destroy()

	-- CollisionBox 파트만 충돌로 판정
	local collidingParts = {}
	for _, p in touchingParts do
		if p:GetAttribute("IsCollisionBox") == true then
			table.insert(collidingParts, p)
		end
	end

	return #collidingParts > 0, collidingParts
end

-- 기존 호환용: 파트 기반 체크 (폴백)
function CollisionDetector.checkCollision(part: BasePart, ignoreParts: { Instance }?): (boolean, { BasePart })
	local itemName = part:GetAttribute("ItemName")
	if itemName then
		return CollisionDetector.checkCollisionBySize(part.CFrame, itemName, ignoreParts)
	end

	-- itemName 없으면 레거시 방식 (프리뷰 파트 자체 사이즈 사용)
	return CollisionDetector.checkCollisionBySize(part.CFrame, "", ignoreParts)
end

return CollisionDetector
