-- CurrencyManager.luau
-- 서버 코인 관리 (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local CurrencyCfg = BalanceConfig.Currency

local CurrencyManager = {}

-- 플레이어별 재화
local _coins = {}
local _gems = {}

-- 플레이어 초기화
function CurrencyManager.initPlayer(player: Player, savedCoins: number?, savedGems: number?)
	_coins[player] = savedCoins or CurrencyCfg.STARTING_COINS
	_gems[player] = savedGems or 0
	CurrencyManager._notifyClient(player)
end

-- 플레이어 제거
function CurrencyManager.removePlayer(player: Player)
	_coins[player] = nil
	_gems[player] = nil
end

-- 코인 조회
function CurrencyManager.getCoins(player: Player): number
	return _coins[player] or 0
end

-- 코인 추가
function CurrencyManager.addCoins(player: Player, amount: number): boolean
	if not _coins[player] then return false end
	if amount <= 0 then return false end

	_coins[player] = _coins[player] + amount
	CurrencyManager._notifyClient(player)
	return true
end

-- 코인 차감 (부족 시 실패)
function CurrencyManager.spendCoins(player: Player, amount: number): boolean
	if not _coins[player] then return false end
	if amount <= 0 then return true end

	if _coins[player] < amount then
		return false
	end

	_coins[player] = _coins[player] - amount
	CurrencyManager._notifyClient(player)
	return true
end

-- 코인 충분한지 확인
function CurrencyManager.hasCoins(player: Player, amount: number): boolean
	return (_coins[player] or 0) >= amount
end

-- 저장용 데이터 반환
function CurrencyManager.getSaveData(player: Player): number
	return _coins[player] or 0
end

-- 코인 직접 설정 (DataStore 로드용)
function CurrencyManager.setCoins(player: Player, amount: number)
	_coins[player] = amount
	CurrencyManager._notifyClient(player)
end

----------------------------------------------------------------
-- 보석 (Gems)
----------------------------------------------------------------
function CurrencyManager.getGems(player: Player): number
	return _gems[player] or 0
end

function CurrencyManager.addGems(player: Player, amount: number): boolean
	if not _gems[player] and _gems[player] ~= 0 then return false end
	if amount <= 0 then return false end
	_gems[player] = (_gems[player] or 0) + amount
	CurrencyManager._notifyClient(player)
	return true
end

function CurrencyManager.spendGems(player: Player, amount: number): boolean
	if amount <= 0 then return true end
	if (_gems[player] or 0) < amount then return false end
	_gems[player] = _gems[player] - amount
	CurrencyManager._notifyClient(player)
	return true
end

function CurrencyManager.hasGems(player: Player, amount: number): boolean
	return (_gems[player] or 0) >= amount
end

function CurrencyManager.getGemsSaveData(player: Player): number
	return _gems[player] or 0
end

-- 클라이언트에 코인/보석 업데이트 전송
function CurrencyManager._notifyClient(player: Player)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end

	local currencyUpdate = remotes:FindFirstChild("CurrencyUpdate")
	if currencyUpdate then
		currencyUpdate:FireClient(player, _coins[player] or 0, _gems[player] or 0)
	end
end

return CurrencyManager
