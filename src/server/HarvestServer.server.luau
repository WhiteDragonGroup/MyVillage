-- HarvestServer.server.luau
-- Work 타입 건물(광산/농장 등)에 ProximityPrompt를 부착해 수확 가능하게 함

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverScript = script.Parent
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

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

local function attachHarvestPrompt(building: BasePart)
	if building:FindFirstChild("HarvestPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HarvestPrompt"
	prompt.ActionText = "Harvest"
	prompt.ObjectText = building:GetAttribute("ItemName") or "Building"
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = building

	prompt.Triggered:Connect(function(player)
		local ownerId = building:GetAttribute("OwnerId")
		if ownerId and ownerId ~= player.UserId then return end

		local stored = building:GetAttribute("StoredCoins") or 0
		if stored <= 0 then return end

		CurrencyManager.addCoins(player, stored)
		building:SetAttribute("StoredCoins", 0)
	end)
end

local function scanBuildings()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return end
	for _, plot in plotsFolder:GetDescendants() do
		if plot:IsA("BasePart") and plot:GetAttribute("BuildingId") and isWorkBuilding(plot) then
			attachHarvestPrompt(plot)
		end
	end
end

scanBuildings()
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") and isWorkBuilding(desc) then
		attachHarvestPrompt(desc)
	end
end)

print("HarvestServer 로드됨")
