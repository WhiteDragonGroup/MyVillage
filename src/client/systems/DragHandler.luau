-- DragHandler.luau
-- 드래그 입력 처리 (이동/회전 시 마우스 레이캐스트 → 그리드 스냅)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local DragHandler = {}

local _active = false
local _buildZone = nil
local _targetPart = nil
local _currentRotationY = 0
local _onPositionUpdate = nil  -- (cframe: CFrame) -> ()
local _renderConnection = nil
local _gridSnap = nil

function DragHandler.init(gridSnapModule)
	_gridSnap = gridSnapModule
end

-- 드래그 시작
-- buildZone: BuildZone 파트
-- targetPart: 이동 중인 건물 파트
-- initialRotationY: 초기 Y 회전 (라디안)
-- onPositionUpdate: 매 프레임 위치 업데이트 콜백
function DragHandler.startDrag(
	buildZone: BasePart,
	targetPart: BasePart,
	initialRotationY: number,
	onPositionUpdate: (CFrame) -> ()
)
	if _active then
		DragHandler.stopDrag()
	end

	_active = true
	_buildZone = buildZone
	_targetPart = targetPart
	_currentRotationY = initialRotationY
	_onPositionUpdate = onPositionUpdate

	-- 매 프레임 위치 업데이트
	_renderConnection = RunService.RenderStepped:Connect(function()
		if not _active or not _buildZone or not _targetPart then return end

		-- 마우스 → BuildZone 레이캐스트
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { _buildZone }

		local unitRay = mouse.UnitRay
		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rayParams)

		if result then
			local objectHeight = _targetPart.Size.Y
			local snappedCFrame = _gridSnap.snapToGrid(_buildZone, result.Position, objectHeight)
			local finalCFrame = _gridSnap.applyRotation(snappedCFrame, _currentRotationY)

			if _onPositionUpdate then
				_onPositionUpdate(finalCFrame)
			end
		end
	end)
end

-- 회전 적용
function DragHandler.rotate(direction: number) -- direction: 1 (오른쪽) / -1 (왼쪽)
	if not _active then return end

	local stepRad = math.rad(require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants")).ROTATION_STEP)
	_currentRotationY = _currentRotationY + (stepRad * direction)
	_currentRotationY = _gridSnap.snapRotation(_currentRotationY)
end

-- 현재 회전값 반환
function DragHandler.getCurrentRotation(): number
	return _currentRotationY
end

-- 드래그 종료
function DragHandler.stopDrag()
	_active = false
	if _renderConnection then
		_renderConnection:Disconnect()
		_renderConnection = nil
	end
	_buildZone = nil
	_targetPart = nil
	_onPositionUpdate = nil
end

function DragHandler.isActive(): boolean
	return _active
end

return DragHandler
