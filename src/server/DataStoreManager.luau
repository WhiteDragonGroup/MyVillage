-- DataStoreManager.luau
-- 플레이어 데이터 영속 저장/로드 (ModuleScript)
-- DataStore 키: "PlayerData_v1_{UserId}"

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DATA_STORE_NAME = "MyVillage_v1"
local AUTO_SAVE_INTERVAL = 120 -- 자동 저장 간격 (초)

local DataStoreManager = {}

-- DataStore 인스턴스 (Studio에서는 실패할 수 있으므로 pcall)
local _dataStore = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(DATA_STORE_NAME)
	end)
	if ok then
		_dataStore = store
	else
		warn("DataStore 접근 실패 (Studio 모드?): " .. tostring(store))
	end
end

-- 데이터 수집 콜백 { [string]: (Player) -> any }
local _gatherCallbacks = {}

-- 플레이어별 로드된 데이터 캐시
local _loadedData = {}

-- 자동 저장 루프 활성 상태
local _autoSaveActive = true

----------------------------------------------------------------
-- 데이터 수집 콜백 등록
-- 각 매니저가 자신의 데이터를 반환하는 함수를 등록
----------------------------------------------------------------
function DataStoreManager.registerGatherCallback(key: string, callback: (Player) -> any)
	_gatherCallbacks[key] = callback
end

----------------------------------------------------------------
-- DataStore 키 생성
----------------------------------------------------------------
local function getKey(player: Player): string
	return "PlayerData_v1_" .. player.UserId
end

----------------------------------------------------------------
-- 플레이어 데이터 로드
----------------------------------------------------------------
function DataStoreManager.loadPlayer(player: Player): { [string]: any }
	if not _dataStore then
		_loadedData[player] = {}
		return {}
	end

	local key = getKey(player)
	local success, data = pcall(function()
		return _dataStore:GetAsync(key)
	end)

	if success and data and typeof(data) == "table" then
		print("DataStore 로드 성공: " .. player.Name)
		_loadedData[player] = data
		return data
	end

	if not success then
		warn("DataStore 로드 실패: " .. player.Name .. " - " .. tostring(data))
	end

	_loadedData[player] = {}
	return {}
end

----------------------------------------------------------------
-- 플레이어 데이터 수집 (각 매니저에서 모아서 하나의 테이블로)
----------------------------------------------------------------
function DataStoreManager.gatherData(player: Player): { [string]: any }
	local data = { version = 1 }

	for key, callback in _gatherCallbacks do
		local ok, result = pcall(callback, player)
		if ok then
			data[key] = result
		else
			warn("데이터 수집 실패 [" .. key .. "]: " .. tostring(result))
		end
	end

	return data
end

----------------------------------------------------------------
-- 플레이어 데이터 저장
----------------------------------------------------------------
function DataStoreManager.savePlayer(player: Player): boolean
	if not _dataStore then
		return false
	end

	local data = DataStoreManager.gatherData(player)
	local key = getKey(player)

	local success, err = pcall(function()
		_dataStore:SetAsync(key, data)
	end)

	if success then
		print("DataStore 저장 성공: " .. player.Name)
	else
		warn("DataStore 저장 실패: " .. player.Name .. " - " .. tostring(err))
	end

	return success
end

----------------------------------------------------------------
-- 플레이어 데이터 제거 (메모리에서만)
----------------------------------------------------------------
function DataStoreManager.removePlayer(player: Player)
	_loadedData[player] = nil
end

----------------------------------------------------------------
-- 로드된 데이터 조회
----------------------------------------------------------------
function DataStoreManager.getLoadedData(player: Player): { [string]: any }
	return _loadedData[player] or {}
end

----------------------------------------------------------------
-- CFrame 직렬화/역직렬화 유틸
----------------------------------------------------------------
function DataStoreManager.serializeCFrame(cf: CFrame): { number }
	return { cf:GetComponents() } -- {x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22}
end

function DataStoreManager.deserializeCFrame(data: { number }): CFrame?
	if not data or #data < 12 then return nil end
	return CFrame.new(unpack(data))
end

----------------------------------------------------------------
-- 자동 저장 루프
----------------------------------------------------------------
task.spawn(function()
	while _autoSaveActive do
		task.wait(AUTO_SAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			task.spawn(function()
				DataStoreManager.savePlayer(player)
			end)
		end
	end
end)

----------------------------------------------------------------
-- 서버 종료 시 모든 플레이어 저장
----------------------------------------------------------------
game:BindToClose(function()
	_autoSaveActive = false

	local threads = {}
	for _, player in Players:GetPlayers() do
		local t = task.spawn(function()
			DataStoreManager.savePlayer(player)
		end)
		table.insert(threads, t)
	end

	-- 최대 30초 대기
	task.wait(math.min(30, #threads * 2))
end)

return DataStoreManager
