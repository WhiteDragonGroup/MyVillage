-- CollisionDetector.luau
-- workspace:GetPartsInPart() 기반 건물 겹침 감지

local Players = game:GetService("Players")

local CollisionDetector = {}

-- 충돌 체크
-- part: BasePart (체크할 건물 파트)
-- ignoreParts: {Instance}? (무시할 파트/모델 목록 - 자기 자신 등)
-- 반환: boolean (충돌 여부), {BasePart} (충돌 파트 목록)
function CollisionDetector.checkCollision(part: BasePart, ignoreParts: { Instance }?): (boolean, { BasePart })
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local combined = {}

	-- 무시할 파트/모델 추가
	if ignoreParts then
		for _, p in ignoreParts do
			table.insert(combined, p)
		end
	end

	-- 프리뷰 파트 무시
	for _, p in workspace:GetDescendants() do
		if p.Name == "PlacementPreview" and p:IsA("BasePart") then
			table.insert(combined, p)
		end
	end

	-- 모든 플레이어 캐릭터 무시
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(combined, plr.Character)
		end
	end

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

return CollisionDetector
