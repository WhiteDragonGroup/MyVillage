-- GridSnap.luau
-- BuildZone 로컬좌표 기준 그리드 스냅

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local GridSnap = {}

-- BuildZone 로컬좌표 기준 스냅 (오브젝트 크기 + 회전 반영)
function GridSnap.snapToGrid(buildZone: BasePart, worldPosition: Vector3, objectSize: Vector3, rotationY: number?): CFrame
	local gridSize = Constants.GRID_SIZE
	local bzCFrame = buildZone.CFrame
	local rot = rotationY or 0

	-- 월드 → 로컬 변환
	local localPos = bzCFrame:PointToObjectSpace(worldPosition)

	-- 그리드 스냅 (로컬 좌표)
	local snappedLocal = Vector3.new(
		math.floor(localPos.X / gridSize + 0.5) * gridSize,
		buildZone.Size.Y / 2 + objectSize.Y / 2,
		math.floor(localPos.Z / gridSize + 0.5) * gridSize
	)

	-- 회전 반영한 바운딩 박스 (블록이 밖으로 안 나가게)
	local cosR = math.abs(math.cos(rot))
	local sinR = math.abs(math.sin(rot))
	local halfX = (objectSize.X * cosR + objectSize.Z * sinR) / 2
	local halfZ = (objectSize.X * sinR + objectSize.Z * cosR) / 2

	-- BuildZone 범위 제한 (그리드에 맞는 최대 위치로 제한)
	local halfSize = buildZone.Size / 2
	local maxGridX = math.floor((halfSize.X - halfX) / gridSize) * gridSize
	local maxGridZ = math.floor((halfSize.Z - halfZ) / gridSize) * gridSize
	snappedLocal = Vector3.new(
		math.clamp(snappedLocal.X, -maxGridX, maxGridX),
		snappedLocal.Y,
		math.clamp(snappedLocal.Z, -maxGridZ, maxGridZ)
	)

	-- 로컬 → 월드 변환 (BuildZone 위치 + 회전 포함)
	return bzCFrame * CFrame.new(snappedLocal)
end

-- Model 바닥 보정: Model 배치 후 바닥이 buildZone 위에 놓이도록 Y 보정
-- mainPart를 snappedCFrame에 놓았을 때, 모델 바닥이 buildZone 상단에 맞도록 조정
function GridSnap.adjustModelY(model: Model, mainPart: BasePart, buildZone: BasePart)
	local buildZoneTop = buildZone.Position.Y + buildZone.Size.Y / 2
	local _, modelSize = model:GetBoundingBox()
	-- 현재 모델 바닥의 Y (= 바운딩박스 중심 - 높이/2)
	local bbCF, _ = model:GetBoundingBox()
	local currentBottom = bbCF.Position.Y - modelSize.Y / 2
	local yAdjust = buildZoneTop - currentBottom
	if math.abs(yAdjust) > 0.01 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, yAdjust, 0))
	end
end

-- 스냅된 회전 적용
function GridSnap.applyRotation(baseCFrame: CFrame, rotationY: number): CFrame
	return baseCFrame * CFrame.Angles(0, rotationY, 0)
end

-- 회전 스냅 (90도 단위)
function GridSnap.snapRotation(angleRad: number): number
	local stepRad = math.rad(Constants.ROTATION_STEP)
	return math.floor(angleRad / stepRad + 0.5) * stepRad
end

return GridSnap
