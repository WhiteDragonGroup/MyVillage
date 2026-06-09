-- BuffManager.luau
-- 펫 단위 + 플레이어 단위 활성 버프 관리.
-- 같은 buffId가 다시 들어오면 만료 시간을 더 긴 쪽으로 갱신.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local BuffCfg = BalanceConfig.Buff

local BuffManager = {}

-- 펫 단위 버프: _petBuffs[petId][buffId] = expireTime
local _petBuffs: { [string]: { [string]: number } } = {}

-- 플레이어 단위 버프: _playerBuffs[Player][buffId] = expireTime
local _playerBuffs: { [Player]: { [string]: number } } = {}

local _onBuffsChanged = nil
function BuffManager.setBuffsChangedHandler(fn)
	_onBuffsChanged = fn
end

local function notifyPlayer(player: Player)
	if _onBuffsChanged then
		_onBuffsChanged(player, BuffManager.getPlayerBuffs(player))
	end
end

-- 펫 단위 버프 변경 알림 (모든 클라이언트가 펫 VFX 동기화에 사용)
local _onPetBuffsChanged = nil
function BuffManager.setPetBuffsChangedHandler(fn)
	_onPetBuffsChanged = fn
end

local function notifyPet(petId: string)
	if _onPetBuffsChanged then
		_onPetBuffsChanged(petId, BuffManager.getPetBuffsDetailed(petId))
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
function BuffManager.applyPetBuff(petId: string, buffId: string, duration: number)
	if not BuffCfg.BUFFS[buffId] then
		warn(string.format("[Buff] applyPetBuff: BuffCfg.BUFFS[%q] 없음. petId=%s", tostring(buffId), tostring(petId)))
		return
	end
	print(string.format("[Buff] applyPetBuff petId=%s buffId=%q duration=%d", tostring(petId), tostring(buffId), duration))
	local petTable = _petBuffs[petId]
	if not petTable then
		petTable = {}
		_petBuffs[petId] = petTable
	end
	local newExpire = tick() + duration
	if not petTable[buffId] or petTable[buffId] < newExpire then
		petTable[buffId] = newExpire
	end
	notifyPet(petId)
end

-- 펫의 활성 버프: { [buffId] = true }
function BuffManager.getPetActiveBuffs(petId: string): { [string]: boolean }
	local petTable = _petBuffs[petId]
	if not petTable then return {} end
	local now = tick()
	local result = {}
	for buffId, expire in petTable do
		if expire > now then result[buffId] = true end
	end
	return result
end

function BuffManager.removePetBuffs(petId: string)
	if _petBuffs[petId] == nil then return end
	_petBuffs[petId] = nil
	notifyPet(petId)
end

-- 펫의 활성 버프 상세 (클라 동기화/표시용): { { buffId, remaining } }
function BuffManager.getPetBuffsDetailed(petId: string): { { buffId: string, remaining: number } }
	local petTable = _petBuffs[petId]
	if not petTable then return {} end
	local now = tick()
	local result = {}
	for buffId, expire in petTable do
		if expire > now then
			table.insert(result, { buffId = buffId, remaining = expire - now })
		end
	end
	return result
end

----------------------------------------------------------------
-- 플레이어 단위
----------------------------------------------------------------
function BuffManager.applyBuff(player: Player, buffId: string, duration: number)
	if not BuffCfg.BUFFS[buffId] then return end
	local buffs = _playerBuffs[player]
	if not buffs then
		buffs = {}
		_playerBuffs[player] = buffs
	end
	local newExpire = tick() + duration
	if not buffs[buffId] or buffs[buffId] < newExpire then
		buffs[buffId] = newExpire
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
	return buffs[buffId] > tick()
end

-- 클라 동기화용
function BuffManager.getPlayerBuffs(player: Player): { { buffId: string, remaining: number } }
	local buffs = _playerBuffs[player]
	if not buffs then return {} end
	local now = tick()
	local result = {}
	for buffId, expire in buffs do
		if expire > now then
			table.insert(result, { buffId = buffId, remaining = expire - now })
		end
	end
	return result
end

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
		for petId, petTable in _petBuffs do
			local changed = false
			for buffId, expire in petTable do
				if expire <= now then
					petTable[buffId] = nil
					changed = true
				end
			end
			if next(petTable) == nil then _petBuffs[petId] = nil end
			if changed then notifyPet(petId) end
		end
		for player, buffs in _playerBuffs do
			local changed = false
			for buffId, expire in buffs do
				if expire <= now then
					buffs[buffId] = nil
					changed = true
				end
			end
			if changed then notifyPlayer(player) end
		end
	end
end)

return BuffManager
