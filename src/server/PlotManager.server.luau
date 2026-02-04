-- PlotManager.server.luau
-- 플레이어 접속 시 빈 플롯 배정 + 인벤토리 초기화

local Players = game:GetService("Players")

local plotsFolder = workspace:WaitForChild("Plots")

local serverScript = script.Parent
local InventoryManager = require(serverScript:WaitForChild("InventoryManager"))

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
local function getPlayerPlot(player)
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == player.Name then
			return plot
		end
	end
	return nil
end

-- 플레이어 접속
Players.PlayerAdded:Connect(function(player)
	-- 인벤토리 초기화 (플롯 배정 전에 실행)
	InventoryManager.initPlayer(player)

	local plot = findEmptyPlot()

	if plot then
		plot:SetAttribute("Owner", player.Name)
		print(player.Name .. " → " .. plot.Name .. " 배정됨")

		-- 플레이어가 스폰되면 자기 땅으로 이동
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5)
			local buildZone = plot:FindFirstChild("BuildZone", true)
			if buildZone and character:FindFirstChild("HumanoidRootPart") then
				character.HumanoidRootPart.CFrame = buildZone.CFrame + Vector3.new(0, 5, 0)
			end
		end)
	else
		print(player.Name .. " - 빈 플롯 없음!")
	end
end)

-- 플레이어 퇴장
Players.PlayerRemoving:Connect(function(player)
	local plot = getPlayerPlot(player)
	if plot then
		-- 배치된 건물 제거
		for _, child in plot:GetDescendants() do
			if child:IsA("BasePart") and child:GetAttribute("BuildingId") ~= nil then
				child:Destroy()
			end
		end

		plot:SetAttribute("Owner", "")
		print(player.Name .. " 퇴장 → " .. plot.Name .. " 비움")
	end

	-- 인벤토리 제거
	InventoryManager.removePlayer(player)
end)

print("PlotManager 로드됨")
