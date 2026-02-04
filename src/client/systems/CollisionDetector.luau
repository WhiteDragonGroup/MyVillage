-- CollisionDetector.luau
-- workspace:GetPartsInPart() 기반 건물 겹침 감지

local CollisionDetector = {}

-- OverlapParams 캐시
local _overlapParams = nil

local function getOverlapParams()
	if not _overlapParams then
		_overlapParams = OverlapParams.new()
		_overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		_overlapParams.FilterDescendantsInstances = {}
	end
	return _overlapParams
end

-- 충돌 체크
-- part: BasePart (체크할 건물 파트)
-- ignoreParts: {BasePart}? (무시할 파트 목록 - 자기 자신 등)
-- 반환: boolean (충돌 여부), {BasePart} (충돌 파트 목록)
function CollisionDetector.checkCollision(part: BasePart, ignoreParts: { BasePart }?): (boolean, { BasePart })
	local params = getOverlapParams()

	-- 무시할 파트 설정
	local filterList = ignoreParts or {}
	-- 프리뷰/PlacementPreview 파트도 무시
	local previewParts = {}
	for _, p in workspace:GetDescendants() do
		if p.Name == "PlacementPreview" and p:IsA("BasePart") then
			table.insert(previewParts, p)
		end
	end
	local combined = {}
	for _, p in filterList do table.insert(combined, p) end
	for _, p in previewParts do table.insert(combined, p) end
	params.FilterDescendantsInstances = combined

	local touchingParts = workspace:GetPartsInPart(part, params)

	-- BuildZone과 Baseplate는 충돌에서 제외
	local collidingParts = {}
	for _, p in touchingParts do
		if p.Name ~= "BuildZone"
			and p.Name ~= "Baseplate"
			and p.Name ~= "Lobby"
			and p.Name ~= "Terrain"
			and not p:IsA("Terrain")
			and p.CanCollide then
			table.insert(collidingParts, p)
		end
	end

	return #collidingParts > 0, collidingParts
end

-- 서버용 충돌 체크 (같은 로직)
function CollisionDetector.checkCollisionServer(part: BasePart, ignoreParts: { BasePart }?): (boolean, { BasePart })
	return CollisionDetector.checkCollision(part, ignoreParts)
end

return CollisionDetector
