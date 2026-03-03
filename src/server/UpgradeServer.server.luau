-- UpgradeServer.server.luau
-- StartUpgrade / CancelUpgrade RemoteEvent 핸들러

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startUpgradeEvent = remotes:WaitForChild("StartUpgrade")
local cancelUpgradeEvent = remotes:WaitForChild("CancelUpgrade")

local plotsFolder = workspace:WaitForChild("Plots")

local serverScript = script.Parent
local UpgradeManager = require(serverScript:WaitForChild("UpgradeManager"))

----------------------------------------------------------------
-- 유틸리티
----------------------------------------------------------------

local function getPlayerPlot(player: Player)
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == player.Name then
			return plot
		end
	end
	return nil
end

local function findBuildingById(plot, buildingId: string): BasePart?
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") == buildingId then
			return child
		end
	end
	return nil
end

local function validateRequest(player, buildingId)
	if typeof(buildingId) ~= "string" then
		return nil, nil, "잘못된 요청 형식"
	end

	local plot = getPlayerPlot(player)
	if not plot then
		return nil, nil, "배정된 플롯 없음"
	end

	local building = findBuildingById(plot, buildingId)
	if not building then
		return nil, nil, "건물 찾을 수 없음"
	end

	if building:GetAttribute("OwnerId") ~= player.UserId then
		return nil, nil, "소유하지 않은 건물"
	end

	return plot, building
end

----------------------------------------------------------------
-- StartUpgrade
----------------------------------------------------------------
startUpgradeEvent.OnServerEvent:Connect(function(player, buildingId)
	local plot, building, err = validateRequest(player, buildingId)
	if not building then
		warn(player.Name .. " - StartUpgrade 실패: " .. (err or ""))
		return
	end

	local ok, reason = UpgradeManager.startUpgrade(player, building)
	if not ok then
		warn(player.Name .. " - 업그레이드 시작 실패: " .. (reason or ""))
	end
end)

----------------------------------------------------------------
-- CancelUpgrade
----------------------------------------------------------------
cancelUpgradeEvent.OnServerEvent:Connect(function(player, buildingId)
	local plot, building, err = validateRequest(player, buildingId)
	if not building then
		warn(player.Name .. " - CancelUpgrade 실패: " .. (err or ""))
		return
	end

	local ok, reason = UpgradeManager.cancelUpgrade(player, building)
	if not ok then
		warn(player.Name .. " - 업그레이드 취소 실패: " .. (reason or ""))
	end
end)

print("UpgradeServer 로드됨")
