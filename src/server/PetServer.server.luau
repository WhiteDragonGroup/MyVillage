-- PetServer.server.luau
-- AssignPet / UnassignPet / GetPets Remote 핸들러

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local assignPetEvent = remotes:WaitForChild("AssignPet")
local unassignPetEvent = remotes:WaitForChild("UnassignPet")
local getPetsFunc = remotes:WaitForChild("GetPets")

local serverScript = script.Parent
local PetManager = require(serverScript:WaitForChild("PetManager"))

----------------------------------------------------------------
-- AssignPet: 펫을 건물에 배치
----------------------------------------------------------------
assignPetEvent.OnServerEvent:Connect(function(player, petId, buildingId)
	if typeof(petId) ~= "string" or typeof(buildingId) ~= "string" then
		warn(player.Name .. " - AssignPet 잘못된 요청 형식")
		return
	end

	local ok, reason = PetManager.assignPet(player, petId, buildingId)
	if not ok then
		warn(player.Name .. " - 펫 배치 실패: " .. (reason or ""))
	end
end)

----------------------------------------------------------------
-- UnassignPet: 펫 회수
----------------------------------------------------------------
unassignPetEvent.OnServerEvent:Connect(function(player, petId)
	if typeof(petId) ~= "string" then
		warn(player.Name .. " - UnassignPet 잘못된 요청 형식")
		return
	end

	local ok, reason = PetManager.unassignPet(player, petId)
	if not ok then
		warn(player.Name .. " - 펫 회수 실패: " .. (reason or ""))
	end
end)

----------------------------------------------------------------
-- GetPets: 펫 목록 조회
----------------------------------------------------------------
getPetsFunc.OnServerInvoke = function(player)
	return PetManager.getPets(player)
end

print("PetServer 로드됨")
