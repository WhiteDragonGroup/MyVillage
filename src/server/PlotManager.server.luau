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

	local buildings = {}
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") ~= nil then
			local cf = child.CFrame
			table.insert(buildings, {
				buildingId = child:GetAttribute("BuildingId"),
				itemName = child:GetAttribute("ItemName") or "",
				level = child:GetAttribute("Level") or 1,
				cframe = DataStoreManager.serializeCFrame(cf),
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

	for _, bData in savedBuildings do
		local itemName = bData.itemName
		if not itemName or itemName == "" then continue end

		-- 템플릿 확인
		local template = itemsFolder:FindFirstChild(itemName)
		if not template then
			warn("건물 복원 실패 - 템플릿 없음: " .. itemName)
			continue
		end

		-- CFrame 복원
		local cf = DataStoreManager.deserializeCFrame(bData.cframe)
		if not cf then
			warn("건물 복원 실패 - CFrame 없음: " .. itemName)
			continue
		end

		local level = bData.level or 1

		-- 레벨별 모델이 있으면 사용, 없으면 기본 템플릿
		local ServerStorage = game:GetService("ServerStorage")
		local buildingsFolder = ServerStorage:FindFirstChild("Buildings")
		local useModel = nil

		if buildingsFolder and level > 1 then
			local itemFolder = buildingsFolder:FindFirstChild(itemName)
			if itemFolder then
				useModel = itemFolder:FindFirstChild("Level" .. level)
			end
		end

		local item
		if useModel then
			item = useModel:Clone()
		else
			item = template:Clone()
		end

		if item:IsA("BasePart") then
			item.CFrame = cf
		elseif item:IsA("Model") then
			item:PivotTo(cf)
		end
		item.Anchored = true
		item.Parent = plot

		-- 속성 설정
		local buildingId = bData.buildingId or HttpService:GenerateGUID(false)
		local mainPart = if item:IsA("BasePart") then item else (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart"))
		if not mainPart then
			warn("건물 복원 실패 - BasePart 없음: " .. itemName)
			item:Destroy()
			continue
		end

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
		player.CharacterAdded:Connect(function(character)
			task.wait(BalanceConfig.Spawn.DELAY)
			local buildZone = plot:FindFirstChild("BuildZone", true)
			if buildZone and character:FindFirstChild("HumanoidRootPart") then
				character.HumanoidRootPart.CFrame = buildZone.CFrame + Vector3.new(0, BalanceConfig.Spawn.HEIGHT_OFFSET, 0)
			end
		end)
	else
		print(player.Name .. " - 빈 플롯 없음!")
	end
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

		-- 배치된 건물 제거
		for _, child in plot:GetDescendants() do
			if child:IsA("BasePart") and child:GetAttribute("BuildingId") ~= nil then
				child:Destroy()
			end
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
