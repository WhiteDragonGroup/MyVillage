-- PlotManager.server.luau
-- 플레이어 접속 시 빈 플롯 배정

local Players = game:GetService("Players")

local plotsFolder = workspace:WaitForChild("Plots")

-- 빈 플롯 찾기
local function findEmptyPlot()
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Owner") == "" or plot:GetAttribute("Owner") == nil then
			return plot
		end
	end
	return nil -- 빈 플롯 없음
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
	local plot = findEmptyPlot()

	if plot then
		plot:SetAttribute("Owner", player.Name)
		print(player.Name .. " → " .. plot.Name .. " 배정됨")

		-- 플레이어가 스폰되면 자기 땅으로 이동
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5)
			local buildZone = plot:FindFirstChild("BuildZone", true) -- true = 하위까지 검색
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
		plot:SetAttribute("Owner", "")
		print(player.Name .. " 퇴장 → " .. plot.Name .. " 비움")
	end
end)

print("PlotManager 로드됨")
