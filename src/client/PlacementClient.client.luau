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
	preview.Name = "PlacementPreview"
	preview.Transparency = 0.5
	preview.CanCollide = false
	preview.Anchored = true
	preview.CanQuery = false -- 레이캐스트에서 제외
	preview.CanTouch = false -- 터치 이벤트 제외
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

-- BuildZone 찾기 (직접 클릭한 파트만)
local function findBuildZone(target)
	if not target then return nil end

	-- 미리보기 블록 무시
	if target.Name == "PlacementPreview" then return nil end

	-- 직접 BuildZone인 경우
	if target.Name == "BuildZone" then
		return target
	end

	return nil
end

-- 플롯의 소유자 확인
local function getPlotOwner(buildZone)
	if not buildZone then return nil end

	-- BuildZone의 부모들 중에서 Plot 찾기
	local current = buildZone.Parent
	while current and current ~= workspace do
		local owner = current:GetAttribute("Owner")
		if owner ~= nil then
			return owner
		end
		current = current.Parent
	end

	return nil
end

-- 현재 미리보기 CFrame 저장
local currentPreviewCFrame = nil
local lastRotation = CFrame.Angles(0, 0, 0) -- 마지막 회전값 유지

-- 마우스 이동 시 미리보기 업데이트
mouse.Move:Connect(function()
	if not placementMode or not preview then return end

	local target = mouse.Target
	local buildZone = findBuildZone(target)

	if buildZone then
		-- 내 땅인지 확인
		local owner = getPlotOwner(buildZone)
		local isMyPlot = (owner == player.Name)

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

		-- BuildZone 회전만 가져와서 적용
		local _, yRot, _ = bzCFrame:ToEulerAnglesYXZ()
		lastRotation = CFrame.Angles(0, yRot, 0) -- 회전값 저장
		currentPreviewCFrame = CFrame.new(bzCFrame:PointToWorldSpace(snappedLocal)) * lastRotation
		preview.CFrame = currentPreviewCFrame

		if isMyPlot then
			preview.BrickColor = BrickColor.new("Lime green") -- 내 땅 = 설치 가능
		else
			preview.BrickColor = BrickColor.new("New Yeller") -- 남의 땅 = 노란색
			currentPreviewCFrame = nil -- 설치 불가
		end
	else
		currentPreviewCFrame = nil
		if mouse.Hit then
			-- 마지막 회전값 유지
			preview.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 2, 0)) * lastRotation
		end
		preview.BrickColor = BrickColor.new("Really red") -- BuildZone 아님
	end
end)

-- 클릭해서 설치
mouse.Button1Down:Connect(function()
	if not placementMode or not preview then return end

	if currentPreviewCFrame then
		-- 서버에 설치 요청 (CFrame 전송)
		placeItemEvent:FireServer("DummyBlock", currentPreviewCFrame)
		print("설치 요청!")
	else
		print("BuildZone 위에만 설치 가능!")
	end
end)

print("PlacementClient 로드됨 - E키로 설치 모드")
