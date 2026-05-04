-- HarvestServer.server.luau
-- Work 타입 건물(광산/농장)에 터치 감지 부착. 플레이어가 건물에 닿으면
-- 누적된 코인/보석을 자동으로 수확.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverScript = script.Parent
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local HARVEST_COOLDOWN = 0.3 -- 동일 플레이어가 같은 건물에 연속 터치 시 디바운스

local function isWorkBuilding(building: BasePart): boolean
	local itemName = building:GetAttribute("ItemName")
	if not itemName then return false end
	local info = Constants.BUILDINGS[itemName]
	if not info or not info.types then return false end
	for _, t in info.types do
		if t == "Work" then return true end
	end
	return false
end

local function tryHarvest(player: Player, building: BasePart)
	-- 디바운스
	local now = tick()
	local lastKey = "_LastHarvest_" .. player.UserId
	local last = building:GetAttribute(lastKey) or 0
	if now - last < HARVEST_COOLDOWN then return end
	building:SetAttribute(lastKey, now)

	-- 소유자 확인
	local ownerId = building:GetAttribute("OwnerId")
	if ownerId and ownerId ~= player.UserId then return end

	local stored = building:GetAttribute("StoredCoins") or 0
	local gems = building:GetAttribute("StoredGems") or 0
	if stored <= 0 and gems <= 0 then return end

	if stored > 0 then
		CurrencyManager.addCoins(player, stored)
		building:SetAttribute("StoredCoins", 0)
	end
	if gems > 0 then
		CurrencyManager.addGems(player, gems)
		building:SetAttribute("StoredGems", 0)
	end
end

local function attachTouchHandler(building: BasePart)
	if building:GetAttribute("_HarvestWired") then return end
	building:SetAttribute("_HarvestWired", true)

	building.Touched:Connect(function(otherPart)
		local character = otherPart and otherPart.Parent
		if not character then return end
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		tryHarvest(player, building)
	end)
end

local function scanBuildings()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return end
	for _, desc in plotsFolder:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") and isWorkBuilding(desc) then
			attachTouchHandler(desc)
		end
	end
end

scanBuildings()
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") and isWorkBuilding(desc) then
		attachTouchHandler(desc)
	end
end)

print("HarvestServer 로드됨 (터치 기반)")
