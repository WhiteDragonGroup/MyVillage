-- CollisionDetector.luau
-- GetPartsInPart 기반 건물 겹침 감지

local Players = game:GetService("Players")

local CollisionDetector = {}

function CollisionDetector.checkCollision(part: BasePart, ignoreParts: { Instance }?): (boolean, { BasePart })
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local combined = {}

	if ignoreParts then
		for _, p in ignoreParts do
			table.insert(combined, p)
		end
	end

	for _, p in workspace:GetDescendants() do
		if p.Name == "PlacementPreview" and p:IsA("BasePart") then
			table.insert(combined, p)
		end
	end

	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(combined, plr.Character)
		end
	end

	params.FilterDescendantsInstances = combined

	-- GetPartsInPart: 임시로 CanCollide/CanQuery 활성화
	local origCanCollide = part.CanCollide
	local origCanQuery = part.CanQuery
	part.CanCollide = true
	part.CanQuery = true

	local touchingParts = workspace:GetPartsInPart(part, params)

	part.CanCollide = origCanCollide
	part.CanQuery = origCanQuery

	-- 배치된 건물(BuildingId 있는 것)만 충돌로 판정
	local collidingParts = {}
	for _, p in touchingParts do
		if p:GetAttribute("BuildingId") ~= nil then
			table.insert(collidingParts, p)
		end
	end

	return #collidingParts > 0, collidingParts
end

return CollisionDetector
