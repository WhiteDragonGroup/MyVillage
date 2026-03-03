-- BalanceConfig (init.luau)
-- 게임플레이 밸런스 수치 전용 모듈
-- 여기 숫자만 바꾸면 게임 전체에 즉시 반영됨
-- 구조적 상수(건물 카탈로그, enum 등)는 Constants.luau에 유지
--
-- 사용법: BalanceConfig.Building.GRID_SIZE, BalanceConfig.Time.TIME_SCALE 등

local BalanceConfig = {}

BalanceConfig.Time = require(script:WaitForChild("TimeConfig"))
BalanceConfig.Building = require(script:WaitForChild("BuildingConfig"))
BalanceConfig.Spawn = require(script:WaitForChild("SpawnConfig"))
BalanceConfig.Pet = require(script:WaitForChild("PetConfig"))
BalanceConfig.Upgrade = require(script:WaitForChild("UpgradeConfig"))
BalanceConfig.Currency = require(script:WaitForChild("CurrencyConfig"))
BalanceConfig.Weather = require(script:WaitForChild("WeatherConfig"))

return BalanceConfig