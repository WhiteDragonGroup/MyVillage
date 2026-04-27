-- CodeServer.server.luau
-- Promo code redemption system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local serverScript = script.Parent
local EggManager = require(serverScript:WaitForChild("EggManager"))

-- Create RemoteFunction
local redeemCodeFunc = remotes:FindFirstChild("RedeemCode")
if not redeemCodeFunc then
	redeemCodeFunc = Instance.new("RemoteFunction")
	redeemCodeFunc.Name = "RedeemCode"
	redeemCodeFunc.Parent = remotes
end

-- Code definitions: code (lowercase) → reward
local CODES = {
	["betaopen"] = {
		description = "Beta Open Reward",
		reward = function(player)
			local ok = EggManager.addEgg(player, "Egg_Legendary", 1)
			if ok then
				return true, "You received a Legendary Egg!"
			end
			return false, "Failed to add egg"
		end,
	},
}

-- Track redeemed codes per player (in-memory + DataStore)
local _redeemedCodes = {} -- { [UserId] = { ["betaopen"] = true } }

local codeStore = nil
pcall(function()
	codeStore = DataStoreService:GetDataStore("RedeemedCodes_v1")
end)

local function loadRedeemedCodes(player)
	if _redeemedCodes[player.UserId] then return end
	_redeemedCodes[player.UserId] = {}
	if codeStore then
		local ok, data = pcall(function()
			return codeStore:GetAsync("Player_" .. player.UserId)
		end)
		if ok and data then
			_redeemedCodes[player.UserId] = data
		end
	end
end

local function saveRedeemedCode(player, code)
	_redeemedCodes[player.UserId][code] = true
	if codeStore then
		pcall(function()
			codeStore:SetAsync("Player_" .. player.UserId, _redeemedCodes[player.UserId])
		end)
	end
end

-- Handle redemption
redeemCodeFunc.OnServerInvoke = function(player, code)
	if typeof(code) ~= "string" then return false, "Invalid code" end

	loadRedeemedCodes(player)

	local normalizedCode = code:lower()

	-- Check if code exists
	local codeDef = CODES[normalizedCode]
	if not codeDef then
		return false, "Invalid code"
	end

	-- Check if already redeemed
	if _redeemedCodes[player.UserId][normalizedCode] then
		return false, "Code already used"
	end

	-- Execute reward
	local ok, message = codeDef.reward(player)
	if ok then
		saveRedeemedCode(player, normalizedCode)
		return true, message
	end

	return false, message or "Failed to redeem"
end

-- Cleanup
game:GetService("Players").PlayerRemoving:Connect(function(player)
	_redeemedCodes[player.UserId] = nil
end)

print("[CodeServer] loaded")
