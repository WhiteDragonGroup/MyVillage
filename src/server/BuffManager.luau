-- BuffManager.luau
-- 플레이어별 활성 버프 관리. 만료 시 자동 제거 + 클라 알림.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local BuffCfg = BalanceConfig.Buff

local BuffManager = {}

-- { [Player]: { [buffId]: { expireTime: number } } }
local _activeBuffs: { [Player]: { [string]: { expireTime: number } } } = {}

-- 클라 동기화 콜백 (BuffServer에서 등록)
local _onBuffsChanged = nil
function BuffManager.setBuffsChangedHandler(fn)
	_onBuffsChanged = fn
end

local function notifyClient(player: Player)
	if _onBuffsChanged then
		_onBuffsChanged(player, BuffManager.getBuffs(player))
	end
end

function BuffManager.initPlayer(player: Player)
	_activeBuffs[player] = {}
end

function BuffManager.removePlayer(player: Player)
	_activeBuffs[player] = nil
end

function BuffManager.applyBuff(player: Player, buffId: string, duration: number)
	if not BuffCfg.BUFFS[buffId] then return end
	local buffs = _activeBuffs[player]
	if not buffs then
		buffs = {}
		_activeBuffs[player] = buffs
	end
	buffs[buffId] = { expireTime = tick() + duration }
	notifyClient(player)
end

function BuffManager.removeBuff(player: Player, buffId: string)
	local buffs = _activeBuffs[player]
	if not buffs or not buffs[buffId] then return end
	buffs[buffId] = nil
	notifyClient(player)
end

function BuffManager.hasBuff(player: Player, buffId: string): boolean
	local buffs = _activeBuffs[player]
	if not buffs or not buffs[buffId] then return false end
	if buffs[buffId].expireTime <= tick() then
		buffs[buffId] = nil
		return false
	end
	return true
end

function BuffManager.getBuffs(player: Player): { { buffId: string, remaining: number } }
	local buffs = _activeBuffs[player]
	if not buffs then return {} end
	local now = tick()
	local result = {}
	for buffId, info in buffs do
		local remaining = info.expireTime - now
		if remaining > 0 then
			table.insert(result, { buffId = buffId, remaining = remaining })
		end
	end
	return result
end

-- 만료 체크 루프
task.spawn(function()
	while true do
		task.wait(1)
		local now = tick()
		for player, buffs in _activeBuffs do
			local changed = false
			for buffId, info in buffs do
				if info.expireTime <= now then
					buffs[buffId] = nil
					changed = true
				end
			end
			if changed then
				notifyClient(player)
			end
		end
	end
end)

return BuffManager
