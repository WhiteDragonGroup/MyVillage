-- 배치 규칙. BuildZone 로컬 좌표(스터드)에서 계산하며 서버와 클라이언트가 같은 판정을 쓴다.

local BuildingModels = require(script.Parent.BuildingModels)

local Placement = {}

-- 회전 단계 rot(0~3)을 반영한 가로·세로
function Placement.extent(id: string, rot: number): (number, number)
	local width, depth = BuildingModels.footprint(id)
	if rot % 2 == 1 then
		return depth, width
	end
	return width, depth
end

-- 건물 가장자리가 1스터드 격자에 맞도록 중심을 맞춘다
local function snapAxis(value: number, extent: number): number
	if extent % 2 == 0 then
		return math.floor(value + 0.5)
	end
	return math.floor(value) + 0.5
end

function Placement.snap(id: string, x: number, z: number, rot: number): (number, number)
	local width, depth = Placement.extent(id, rot)
	return snapAxis(x, width), snapAxis(z, depth)
end

-- others: { { id, x, z, rot } }, zoneX/zoneZ: 부지 크기
-- 반환: 가능 여부, 불가 사유
function Placement.check(id, x, z, rot, zoneX, zoneZ, others): (boolean, string?)
	local width, depth = Placement.extent(id, rot)

	if math.abs(x) + width / 2 > zoneX / 2 or math.abs(z) + depth / 2 > zoneZ / 2 then
		return false, "Outside your plot"
	end

	for _, other in others do
		local otherWidth, otherDepth = Placement.extent(other.id, other.rot)
		if
			math.abs(x - other.x) < (width + otherWidth) / 2
			and math.abs(z - other.z) < (depth + otherDepth) / 2
		then
			return false, "Overlapping another building"
		end
	end

	return true, nil
end

-- BuildZone 로컬 좌표 → 바닥 CFrame
function Placement.toWorld(zone: BasePart, x: number, z: number, rot: number): CFrame
	return zone.CFrame * CFrame.new(x, zone.Size.Y / 2, z) * CFrame.Angles(0, rot * math.pi / 2, 0)
end

return Placement
