-- GridSnap.luau
-- BuildZone 로컬좌표 기준 그리드 스냅

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local GridSnap = {}

-- BuildZone 로컬좌표 기준 스냅
-- buildZone: BasePart (BuildZone 파트)
-- worldPosition: Vector3 (월드 좌표 위치)
-- objectHeight: number (건물 높이, Y 오프셋 용)
-- 반환: CFrame (스냅된 월드 좌표, BuildZone 회전 포함)
function GridSnap.snapToGrid(buildZone: BasePart, worldPosition: Vector3, objectHeight: number): CFrame
	local gridSize = Constants.GRID_SIZE
	local bzCFrame = buildZone.CFrame

	-- 월드 → 로컬 변환
	local localPos = bzCFrame:PointToObjectSpace(worldPosition)

	-- 그리드 스냅 (로컬 좌표)
	local snappedLocal = Vector3.new(
		math.floor(localPos.X / gridSize + 0.5) * gridSize,
		buildZone.Size.Y / 2 + objectHeight / 2,
		math.floor(localPos.Z / gridSize + 0.5) * gridSize
	)

	-- BuildZone 범위 제한
	local halfSize = buildZone.Size / 2
	snappedLocal = Vector3.new(
		math.clamp(snappedLocal.X, -halfSize.X + gridSize / 2, halfSize.X - gridSize / 2),
		snappedLocal.Y,
		math.clamp(snappedLocal.Z, -halfSize.Z + gridSize / 2, halfSize.Z - gridSize / 2)
	)

	-- 로컬 → 월드 변환 (BuildZone 회전만 포함)
	local worldPos = bzCFrame:PointToWorldSpace(snappedLocal)
	return CFrame.new(worldPos)
end

-- 스냅된 회전 적용
-- baseCFrame: CFrame (스냅된 위치 CFrame)
-- rotationY: number (Y축 회전 각도, 라디안)
-- 반환: CFrame (위치 + 회전)
function GridSnap.applyRotation(baseCFrame: CFrame, rotationY: number): CFrame
	return baseCFrame * CFrame.Angles(0, rotationY, 0)
end

-- 회전 스냅 (15도 단위)
function GridSnap.snapRotation(angleRad: number): number
	local stepRad = math.rad(Constants.ROTATION_STEP)
	return math.floor(angleRad / stepRad + 0.5) * stepRad
end

return GridSnap
