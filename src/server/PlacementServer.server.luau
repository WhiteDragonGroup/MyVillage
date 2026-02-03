-- PlacementServer.server.luau
-- 서버: 내 땅인지 확인 후 설치

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placeItemEvent = remotes:WaitForChild("PlaceItem")
local itemsFolder = ReplicatedStorage:WaitForChild("Items")
local plotsFolder = workspace:WaitForChild("Plots")

-- 위치가 어느 플롯의 BuildZone인지 찾기 (회전 고려)
local function findPlotAtPosition(position)
	for _, plot in plotsFolder:GetChildren() do
		local buildZone = plot:FindFirstChild("BuildZone", true)
		if buildZone then
			-- 월드 좌표를 BuildZone 로컬 좌표로 변환
			local localPos = buildZone.CFrame:PointToObjectSpace(position)
			local halfSize = buildZone.Size / 2

			-- 로컬 좌표에서 범위 체크
			if math.abs(localPos.X) <= halfSize.X
				and math.abs(localPos.Z) <= halfSize.Z then
				return plot
			end
		end
	end
	return nil
end

-- 설치 요청 처리
placeItemEvent.OnServerEvent:Connect(function(player, itemName, cframe)
	print("설치 요청 받음:", player.Name, itemName)

	-- 1. 아이템 템플릿 확인
	local template = itemsFolder:FindFirstChild(itemName)
	if not template then
		warn("아이템 없음: " .. itemName)
		return
	end

	-- 2. 해당 위치의 플롯 찾기
	local position = cframe.Position
	local plot = findPlotAtPosition(position)
	if not plot then
		warn(player.Name .. " - BuildZone 밖에 설치 시도")
		return
	end

	print("플롯 찾음:", plot.Name)

	-- 3. 내 땅인지 확인
	local owner = plot:GetAttribute("Owner")
	print("플롯 소유자:", owner, "/ 플레이어:", player.Name)

	if owner ~= player.Name then
		warn(player.Name .. " - 남의 땅(" .. plot.Name .. ", 소유자: " .. tostring(owner) .. ")에 설치 시도!")
		return
	end

	-- 4. 설치! (CFrame으로 위치+회전 적용)
	local item = template:Clone()
	item.CFrame = cframe
	item.Parent = plot -- 플롯 안에 저장

	print(player.Name .. " → " .. plot.Name .. "에 " .. itemName .. " 설치 완료!")
end)

print("PlacementServer 로드됨")
