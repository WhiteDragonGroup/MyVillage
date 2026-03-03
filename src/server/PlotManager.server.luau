-- PlotManager.server.luau
-- 플레이어 접속 시 빈 플롯 배정 + 데이터 로드/저장 + 건물 복원

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local plotsFolder = workspace:WaitForChild("Plots")
local itemsFolder = ReplicatedStorage:WaitForChild("Items")

local serverScript = script.Parent
local InventoryManager = require(serverScript:WaitForChild("InventoryManager"))
local PetManager = require(serverScript:WaitForChild("PetManager"))
local UpgradeManager = require(serverScript:WaitForChild("UpgradeManager"))
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local DataStoreManager = require(serverScript:WaitForChild("DataStoreManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

-- 업그레이드 완료 시 펫 자동 해제 연결
UpgradeManager.setOnCompleteCallback(function(player, petId)
	PetManager.onUpgradeComplete(player, petId)
end)

-- 업그레이드에 코인 함수 연결
UpgradeManager.setCurrencyFunctions(
	function(player, amount) return CurrencyManager.hasCoins(player, amount) end,
	function(player, amount) return CurrencyManager.spendCoins(player, amount) end
)

-- GetCurrency Remote
local getCurrencyFunc = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GetCurrency")
getCurrencyFunc.OnServerInvoke = function(player)
	return CurrencyManager.getCoins(player)
end

----------------------------------------------------------------
-- DataStore 수집 콜백 등록
----------------------------------------------------------------
DataStoreManager.registerGatherCallback("coins", function(player)
	return CurrencyManager.getSaveData(player)
end)

DataStoreManager.registerGatherCallback("inventory", function(player)
	return InventoryManager.getSaveData(player)
end)

DataStoreManager.registerGatherCallback("pets", function(player)
	return PetManager.getSaveData(player)
end)

DataStoreManager.registerGatherCallback("buildings", function(player)
	return gatherBuildingData(player)
end)

----------------------------------------------------------------
-- 건물 데이터 수집 (플롯에서)
----------------------------------------------------------------
function gatherBuildingData(player): { any }
	local plot = getPlayerPlot(player)
	if not plot then return {} end

	-- BuildZone 기준 상대좌표로 저장 (플롯이 바뀌어도 올바른 위치 복원)
	local buildZone = plot:FindFirstChild("BuildZone", true)

	local buildings = {}
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") ~= nil then
			local cf = child.CFrame
			-- BuildZone 기준 상대 CFrame 변환
			local saveCFrame = if buildZone then buildZone.CFrame:ToObjectSpace(cf) else cf
			table.insert(buildings, {
				buildingId = child:GetAttribute("BuildingId"),
				itemName = child:GetAttribute("ItemName") or "",
				level = child:GetAttribute("Level") or 1,
				cframe = DataStoreManager.serializeCFrame(saveCFrame),
				dataVersion = 2, -- 상대좌표 표시
				upgradeState = child:GetAttribute("UpgradeState") or "",
				upgradeProgress = child:GetAttribute("UpgradeProgress") or 0,
			})
		end
	end
	return buildings
end

----------------------------------------------------------------
-- 건물 복원 (저장된 데이터 → 플롯에 배치)
----------------------------------------------------------------
local function restoreBuildings(player, plot, savedBuildings: { any })
	if not savedBuildings or #savedBuildings == 0 then return end

	-- 새 플롯의 BuildZone (상대좌표 → 월드좌표 변환용)
	local buildZone = plot:FindFirstChild("BuildZone", true)

	for _, bData in savedBuildings do
		local itemName = bData.itemName
		if not itemName or itemName == "" then continue end

		-- 템플릿 확인
		local template = itemsFolder:FindFirstChild(itemName)
		if not template then
			warn("건물 복원 실패 - 템플릿 없음: " .. itemName)
			continue
		end

		-- CFrame 복원 (상대좌표 → 월드좌표)
		local savedCF = DataStoreManager.deserializeCFrame(bData.cframe)
		if not savedCF then
			warn("건물 복원 실패 - CFrame 없음: " .. itemName)
			continue
		end

		local cf
		if bData.dataVersion == 2 and buildZone then
			-- v2: BuildZone 기준 상대좌표 → 새 플롯 기준 월드좌표
			cf = buildZone.CFrame:ToWorldSpace(savedCF)
		else
			-- v1(구버전): 절대좌표 → 인벤토리로 반환 (플롯 변경 시 위치가 맞지 않음)
			warn("구버전 건물 데이터 → 인벤토리로 반환: " .. itemName)
			InventoryManager.addItem(player, itemName, 1, bData.level or 1)
			continue
		end

		-- 복원 위치가 BuildZone 범위 밖이면 인벤토리로 반환
		if buildZone then
			local localPos = buildZone.CFrame:PointToObjectSpace(cf.Position)
			local halfSize = buildZone.Size / 2
			if math.abs(localPos.X) > halfSize.X or math.abs(localPos.Z) > halfSize.Z then
				warn("건물 복원 위치가 BuildZone 밖 → 인벤토리로 반환: " .. itemName)
				InventoryManager.addItem(player, itemName, 1, bData.level or 1)
				continue
			end
		end

		local level = bData.level or 1

		-- 레벨별 모델이 있으면 사용, 없으면 기본 템플릿
		local buildingsFolder = ReplicatedStorage:FindFirstChild("Buildings")
		local useModel = nil

		if buildingsFolder then
			local itemFolder = buildingsFolder:FindFirstChild(itemName)
			if itemFolder then
				-- "Level1" 또는 "Mine_1" 형식 모두 지원
				useModel = itemFolder:FindFirstChild("Level" .. level)
					or itemFolder:FindFirstChild(itemName .. "_" .. level)
			end
		end

		local item
		if useModel then
			item = useModel:Clone()
		else
			item = template:Clone()
		end

		-- 위치/부모 설정 (BasePart vs Model 분기)
		local mainPart: BasePart
		if item:IsA("BasePart") then
			item.CFrame = cf
			item.Anchored = true
			item.Parent = plot
			mainPart = item
		elseif item:IsA("Model") then
			mainPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
			if not mainPart then
				warn("건물 복원 실패 - BasePart 없음: " .. itemName)
				item:Destroy()
				continue
			end
			-- PivotTo 보정: mainPart가 정확히 cf에 오도록
			local pivotCF = item:GetPivot()
			local mainToPivot = mainPart.CFrame:ToObjectSpace(pivotCF)
			item:PivotTo(cf * mainToPivot)
			item.Parent = plot
			mainPart.Anchored = true
		end

		-- 속성 설정
		local buildingId = bData.buildingId or HttpService:GenerateGUID(false)

		mainPart:SetAttribute("BuildingId", buildingId)
		mainPart:SetAttribute("ItemName", itemName)
		mainPart:SetAttribute("OwnerId", player.UserId)
		mainPart:SetAttribute("Level", level)
		-- 업그레이드 상태 복원 (진행중이었으면 상태 유지, 펫은 해제)
		mainPart:SetAttribute("UpgradeState", bData.upgradeState or "")
		mainPart:SetAttribute("UpgradeProgress", bData.upgradeProgress or 0)
		mainPart:SetAttribute("AssignedPetId", "")

		-- CollisionBox 생성
		local collisionSize = Constants.getCollisionSize(itemName)
		local box = Instance.new("Part")
		box.Name = "CollisionBox"
		box.Size = collisionSize
		box.Transparency = 1
		box.Anchored = true
		box.CanCollide = false
		box.CanQuery = true
		box.CanTouch = false
		box.CFrame = mainPart.CFrame
		box:SetAttribute("IsCollisionBox", true)
		box.Parent = mainPart

		-- 레벨별 외형 적용 (모델 스왑이 아닌 경우만)
		if not useModel and level > 1 then
			UpgradeManager.applyVisualUpgrade(mainPart, level)
		end

		-- 업그레이드 진행중이었으면 루프 재시작
		if bData.upgradeState == Constants.UpgradeState.Upgrading then
			UpgradeManager._startProgressLoop(player, mainPart, buildingId)
		end
	end

	print(player.Name .. " - 건물 " .. #savedBuildings .. "개 복원 완료")
end

----------------------------------------------------------------
-- 유틸리티
----------------------------------------------------------------

-- 빈 플롯 랜덤으로 찾기
local function findEmptyPlot()
	local emptyPlots = {}

	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == "" or plot:GetAttribute("Owner") == nil then
			table.insert(emptyPlots, plot)
		end
	end

	if #emptyPlots == 0 then
		return nil
	end

	return emptyPlots[math.random(1, #emptyPlots)]
end

-- 플레이어의 플롯 찾기
function getPlayerPlot(player)
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == player.Name then
			return plot
		end
	end
	return nil
end

----------------------------------------------------------------
-- 플레이어 접속
----------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	-- 1. DataStore에서 데이터 로드
	local savedData = DataStoreManager.loadPlayer(player)

	-- 2. 각 매니저 초기화 (저장된 데이터 전달)
	InventoryManager.initPlayer(player, savedData.inventory)
	PetManager.initPlayer(player, savedData.pets)
	CurrencyManager.initPlayer(player, savedData.coins)

	-- 3. 플롯 배정
	local plot = findEmptyPlot()

	if plot then
		plot:SetAttribute("Owner", player.Name)
		print(player.Name .. " → " .. plot.Name .. " 배정됨")

		-- 4. 저장된 건물 복원
		restoreBuildings(player, plot, savedData.buildings)

		-- 5. 플레이어가 스폰되면 자기 땅으로 이동
		local function teleportToPlot(character)
			task.wait(BalanceConfig.Spawn.DELAY)
			local buildZone = plot:FindFirstChild("BuildZone", true)
			if buildZone and character:FindFirstChild("HumanoidRootPart") then
				character.HumanoidRootPart.CFrame = buildZone.CFrame + Vector3.new(0, BalanceConfig.Spawn.HEIGHT_OFFSET, 0)
			end
		end

		player.CharacterAdded:Connect(teleportToPlot)

		-- DataStore 로드 중 이미 캐릭터가 스폰됐으면 즉시 텔레포트
		if player.Character then
			task.spawn(teleportToPlot, player.Character)
		end
	else
		print(player.Name .. " - 빈 플롯 없음!")
	end

	-- 채팅 명령어: !reset → DataStore 초기화 + 기본 인벤토리 재지급
	-- (Roblox TextChatService가 "/" 접두사를 가로채므로 "!" 사용)
	player.Chatted:Connect(function(msg)
		if msg:lower() == "!reset" then
			-- 1. DataStore 삭제
			DataStoreManager.saveOverride(player, {})

			-- 2. 현재 배치된 건물 모두 제거
			local resetPlot = getPlayerPlot(player)
			if resetPlot then
				UpgradeManager.cleanupPlayer(resetPlot)
				local toDestroy = {}
				for _, child in resetPlot:GetDescendants() do
					if child:IsA("BasePart") and child:GetAttribute("BuildingId") ~= nil then
						-- Model이면 Model 통째로, 아니면 파트만
						local root = if child.Parent and child.Parent:IsA("Model") then child.Parent else child
						toDestroy[root] = true
					end
				end
				for obj in toDestroy do
					obj:Destroy()
				end
			end

			-- 3. 인벤토리/펫/코인 초기화 (기본값)
			InventoryManager.initPlayer(player, nil)
			PetManager.initPlayer(player, nil)
			CurrencyManager.initPlayer(player, nil)

			print(player.Name .. " - !reset 완료! 기본 상태로 초기화됨")
		end
	end)
end)

----------------------------------------------------------------
-- 플레이어 퇴장
----------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	-- 1. DataStore에 저장 (건물 제거 전에!)
	DataStoreManager.savePlayer(player)

	local plot = getPlayerPlot(player)
	if plot then
		-- 업그레이드 루프 정리
		UpgradeManager.cleanupPlayer(plot)

		-- 배치된 건물 제거 (Model이면 전체 제거)
		local toDestroy = {}
		for _, child in plot:GetDescendants() do
			if child:IsA("BasePart") and child:GetAttribute("BuildingId") ~= nil then
				local root = if child.Parent and child.Parent:IsA("Model") then child.Parent else child
				toDestroy[root] = true
			end
		end
		for obj in toDestroy do
			obj:Destroy()
		end

		plot:SetAttribute("Owner", "")
		print(player.Name .. " 퇴장 → " .. plot.Name .. " 비움")
	end

	-- 펫 제거
	PetManager.removePlayer(player)

	-- 코인 제거
	CurrencyManager.removePlayer(player)

	-- 인벤토리 제거
	InventoryManager.removePlayer(player)

	-- DataStore 캐시 제거
	DataStoreManager.removePlayer(player)
end)

print("PlotManager 로드됨 (DataStore 통합)")
