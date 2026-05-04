-- SettingsManager.luau
-- 플레이어 클라이언트 설정 (Music/SFX 볼륨, LowDetail) 관리

local SettingsManager = {}

local DEFAULTS = {
	music = 1,
	sfx = 1,
	lowDetail = false,
}

local _playerSettings: { [Player]: { [string]: any } } = {}

local function clone(t)
	local out = {}
	for k, v in t do out[k] = v end
	return out
end

function SettingsManager.initPlayer(player: Player, savedSettings: { [string]: any }?)
	local s = clone(DEFAULTS)
	if savedSettings then
		for k, v in savedSettings do
			if DEFAULTS[k] ~= nil then
				s[k] = v
			end
		end
	end
	_playerSettings[player] = s
end

function SettingsManager.getSettings(player: Player): { [string]: any }
	return _playerSettings[player] or clone(DEFAULTS)
end

function SettingsManager.setSetting(player: Player, key: string, value: any): boolean
	local s = _playerSettings[player]
	if not s then return false end
	if DEFAULTS[key] == nil then return false end
	if typeof(value) ~= typeof(DEFAULTS[key]) then return false end
	s[key] = value
	return true
end

function SettingsManager.getSaveData(player: Player): { [string]: any }
	return _playerSettings[player] or clone(DEFAULTS)
end

function SettingsManager.removePlayer(player: Player)
	_playerSettings[player] = nil
end

return SettingsManager
