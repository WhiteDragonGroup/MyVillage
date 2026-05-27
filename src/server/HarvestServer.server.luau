-- HarvestServer.server.luau
-- Work 타입 건물(광산/농장)에 터치 감지 부착. 플레이어가 건물에 닿으면
-- 누적된 코인/보석을 자동으로 수확.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverScript = script.Parent
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local HARVEST_COOLDOWN = 2 -- 같은 건물에서 다음 수확까지 대기 시간 (초)

-- 수확 이펙트 RemoteEvent
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local harvestEffectEvent = remotes:FindFirstChild("HarvestEffect")
if not harvestEffectEvent then
	harvestEffectEvent = Instance.new("RemoteEvent")
	harvestEffectEvent.Name = "HarvestEffect"
	harvestEffectEvent.Parent = remotes
end

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

	-- 클라이언트 이펙트
	harvestEffectEvent:FireClient(player, {
		coins = stored,
		gems = gems,
		position = building.Position + Vector3.new(0, building.Size.Y / 2 + 1, 0),
		building = building, -- 수확 시 건물 초록 하이라이트용
	})
end

local function attachTouchHandler(building: BasePart)
	if building:GetAttribute("_HarvestWired") then return end
	building:SetAttribute("_HarvestWired", true)

	local function onTouched(otherPart)
		local character = otherPart and otherPart.Parent
		if not character then return end
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		tryHarvest(player, building)
	end

	-- mainPart 본인 + 같은 모델의 모든 파트에 Touched 부착
	building.Touched:Connect(onTouched)
	local model = building:FindFirstAncestorWhichIsA("Model")
	if model then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= building and not part:GetAttribute("IsCollisionBox") then
				part.Touched:Connect(onTouched)
			end
		end
		model.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and not d:GetAttribute("IsCollisionBox") then
				d.Touched:Connect(onTouched)
			end
		end)
	end
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
