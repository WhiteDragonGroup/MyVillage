-- BuffServer.server.luau
-- BuffManager의 변경사항을 클라이언트로 전송 (BuffUpdate Remote)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverScript = script.Parent
local BuffManager = require(serverScript:WaitForChild("BuffManager"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buffUpdateEvent = remotes:WaitForChild("BuffUpdate")
local getBuffsFunc = remotes:WaitForChild("GetBuffs")
local getPetBuffsFunc = remotes:WaitForChild("GetPetBuffs")

BuffManager.setBuffsChangedHandler(function(player, buffs)
	buffUpdateEvent:FireClient(player, buffs)
end)

getBuffsFunc.OnServerInvoke = function(player)
	return BuffManager.getBuffs(player)
end

-- 펫별 활성 버프 조회 (상세 UI가 1초마다 폴링)
getPetBuffsFunc.OnServerInvoke = function(player, petId)
	if typeof(petId) ~= "string" then return {} end
	return BuffManager.getPetBuffsDetailed(petId)
end

Players.PlayerAdded:Connect(function(player)
	BuffManager.initPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	BuffManager.removePlayer(player)
end)

print("BuffServer 로드됨")
