-- BuffManager.luau
-- 펫 단위 + 플레이어 단위 활성 버프 관리.
-- 같은 buffId의 다른 레벨 동시 추적: 가장 높은 레벨이 활성, 낮은 레벨은 만료 시 폴백.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local BuffCfg = BalanceConfig.Buff

local BuffManager = {}

-- 펫 단위 버프: _petBuffs[petId][buffId][level] = expireTime
local _petBuffs: { [string]: { [string]: { [number]: number } } } = {}

-- 플레이어 단위 버프 (일부 시스템용): _playerBuffs[Player][buffId][level] = expireTime
local _playerBuffs: { [Player]: { [string]: { [number]: number } } } = {}

local _onBuffsChanged = nil
function BuffManager.setBuffsChangedHandler(fn)
	_onBuffsChanged = fn
end

local function notifyPlayer(player: Player)
	if _onBuffsChanged then
		_onBuffsChanged(player, BuffManager.getPlayerBuffs(player))
	end
end

----------------------------------------------------------------
-- 플레이어 라이프사이클
----------------------------------------------------------------
function BuffManager.initPlayer(player: Player)
	_playerBuffs[player] = {}
end

function BuffManager.removePlayer(player: Player)
	_playerBuffs[player] = nil
end

----------------------------------------------------------------
-- 펫 단위
----------------------------------------------------------------
function BuffManager.applyPetBuff(petId: string, buffId: string, level: number, duration: number)
	if not BuffCfg.BUFFS[buffId] then return end
	level = level or 1
	local now = tick()
	local petTable = _petBuffs[petId]
	if not petTable then
		petTable = {}
		_petBuffs[petId] = petTable
	end
	local buffTable = petTable[buffId]
	if not buffTable then
		buffTable = {}
		petTable[buffId] = buffTable
	end
	-- 같은 레벨이면 만료시간 갱신 (더 긴 쪽으로)
	local newExpire = now + duration
	if not buffTable[level] or buffTable[level] < newExpire then
		buffTable[level] = newExpire
	end
end

-- 펫의 활성 버프(가장 높은 레벨) 조회: { [buffId] = level }
function BuffManager.getPetActiveBuffs(petId: string): { [string]: number }
	local petTable = _petBuffs[petId]
	if not petTable then return {} end
	local now = tick()
	local result = {}
	for buffId, levels in petTable do
		local highest = nil
		for level, expire in levels do
			if expire > now then
				if not highest or level > highest then highest = level end
			end
		end
		if highest then
			result[buffId] = highest
		end
	end
	return result
end

function BuffManager.removePetBuffs(petId: string)
	_petBuffs[petId] = nil
end

----------------------------------------------------------------
-- 플레이어 단위 (호환용)
----------------------------------------------------------------
function BuffManager.applyBuff(player: Player, buffId: string, duration: number, level: number?)
	if not BuffCfg.BUFFS[buffId] then return end
	level = level or 1
	local buffs = _playerBuffs[player]
	if not buffs then
		buffs = {}
		_playerBuffs[player] = buffs
	end
	local lvls = buffs[buffId]
	if not lvls then
		lvls = {}
		buffs[buffId] = lvls
	end
	local newExpire = tick() + duration
	if not lvls[level] or lvls[level] < newExpire then
		lvls[level] = newExpire
	end
	notifyPlayer(player)
end

function BuffManager.removeBuff(player: Player, buffId: string)
	local buffs = _playerBuffs[player]
	if not buffs or not buffs[buffId] then return end
	buffs[buffId] = nil
	notifyPlayer(player)
end

function BuffManager.hasBuff(player: Player, buffId: string): boolean
	local buffs = _playerBuffs[player]
	if not buffs or not buffs[buffId] then return false end
	local now = tick()
	for _, expire in buffs[buffId] do
		if expire > now then return true end
	end
	return false
end

-- 클라 동기화용 (단일 레벨 + 남은시간) — 가장 높은 레벨만 노출
function BuffManager.getPlayerBuffs(player: Player): { { buffId: string, level: number, remaining: number } }
	local buffs = _playerBuffs[player]
	if not buffs then return {} end
	local now = tick()
	local result = {}
	for buffId, lvls in buffs do
		local highest = nil
		local highestExp = nil
		for level, expire in lvls do
			if expire > now then
				if not highest or level > highest then
					highest = level
					highestExp = expire
				end
			end
		end
		if highest then
			table.insert(result, { buffId = buffId, level = highest, remaining = highestExp - now })
		end
	end
	return result
end

-- 호환 alias
function BuffManager.getBuffs(player: Player)
	return BuffManager.getPlayerBuffs(player)
end

----------------------------------------------------------------
-- 만료 정리 루프
----------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		local now = tick()
		-- 펫 버프 정리
		for petId, petTable in _petBuffs do
			for buffId, lvls in petTable do
				for level, expire in lvls do
					if expire <= now then
						lvls[level] = nil
					end
				end
				if next(lvls) == nil then
					petTable[buffId] = nil
				end
			end
			if next(petTable) == nil then
				_petBuffs[petId] = nil
			end
		end
		-- 플레이어 버프 정리
		for player, buffs in _playerBuffs do
			local changed = false
			for buffId, lvls in buffs do
				for level, expire in lvls do
					if expire <= now then
						lvls[level] = nil
						changed = true
					end
				end
				if next(lvls) == nil then
					buffs[buffId] = nil
				end
			end
			if changed then
				notifyPlayer(player)
			end
		end
	end
end)

return BuffManager
