-- CurrencyConfig.luau
-- 재화 시스템 밸런스 수치
-- 참조: CurrencyManager / UpgradeManager / CurrencyUI

local CurrencyConfig = {}

-- 시작 코인
CurrencyConfig.STARTING_COINS = 500

-- 자동 수입 (추후 건물 효과 등으로 확장)
CurrencyConfig.PASSIVE_INCOME = 0 -- 초당 코인 (현재 비활성)

return CurrencyConfig
