-- PlacementClient.client.luau
-- 클라이언트: 클릭하면 더미 블록 설치 요청

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placeItemEvent = remotes:WaitForChild("PlaceItem")

-- 설치 모드 (E키로 토글)
local placementMode = false

-- 미리보기 블록
local preview = nil

local function createPreview()
	local items = ReplicatedStorage:WaitForChild("Items")
	local dummy = items:WaitForChild("DummyBlock")
	preview = dummy:Clone()
	preview.Transparency = 0.5
	preview.CanCollide = false
	preview.Parent = workspace
end

local function removePreview()
	if preview then
		preview:Destroy()
		preview = nil
	end
end

-- E키로 설치 모드 토글
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.E then
		placementMode = not placementMode

		if placementMode then
			createPreview()
			print("설치 모드 ON (클릭해서 설치, E로 취소)")
		else
			removePreview()
			print("설치 모드 OFF")
		end
	end
end)

-- BuildZone 찾기 (클릭한 파트 또는 부모에서)
local function findBuildZone(target)
	if not target then return nil end

	-- 직접 BuildZone인 경우
	if target.Name == "BuildZone" then
		return target
	end

	-- 부모 중에 BuildZone이 있는지 확인
	local current = target.Parent
	while current and current ~= workspace do
		if current.Name == "BuildZone" then
			return current
		end
		-- 같은 레벨에 BuildZone이 있는지
		local bz = current:FindFirstChild("BuildZone")
		if bz then
			return bz
		end
		current = current.Parent
	end

	return nil
end

-- 마우스 이동 시 미리보기 업데이트
mouse.Move:Connect(function()
	if not placementMode or not preview then return end

	local target = mouse.Target
	local buildZone = findBuildZone(target)

	if buildZone then
		-- BuildZone의 회전에 맞춰서 위치 계산
		local hitPos = mouse.Hit.Position
		local bzCFrame = buildZone.CFrame

		-- 로컬 좌표로 변환 후 그리드 스냅, 다시 월드 좌표로
		local localPos = bzCFrame:PointToObjectSpace(hitPos)
		local snappedLocal = Vector3.new(
			math.floor(localPos.X / 4 + 0.5) * 4,
			buildZone.Size.Y / 2 + 2,
			math.floor(localPos.Z / 4 + 0.5) * 4
		)
		local worldPos = bzCFrame:PointToWorldSpace(snappedLocal)

		preview.CFrame = CFrame.new(worldPos) * CFrame.Angles(0, bzCFrame:ToEulerAnglesYXZ())
		preview.BrickColor = BrickColor.new("Lime green") -- 설치 가능
	else
		if mouse.Hit then
			preview.Position = mouse.Hit.Position + Vector3.new(0, 2, 0)
		end
		preview.BrickColor = BrickColor.new("Really red") -- 설치 불가
	end
end)

-- 클릭해서 설치
mouse.Button1Down:Connect(function()
	if not placementMode or not preview then return end

	local target = mouse.Target
	local buildZone = findBuildZone(target)

	if buildZone then
		-- 서버에 설치 요청
		placeItemEvent:FireServer("DummyBlock", preview.Position)
		print("설치 요청!")
	else
		print("BuildZone 위에만 설치 가능!")
	end
end)

print("PlacementClient 로드됨 - E키로 설치 모드")
