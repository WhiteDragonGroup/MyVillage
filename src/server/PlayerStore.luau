-- 플레이어 저장. 로드에 실패한 프로필은 빈 데이터로 덮어쓰지 않도록 저장을 막는다.

local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME = "MyVillage_v2"
local SCHEMA = 1
local RETRIES = 3

local store = DataStoreService:GetDataStore(STORE_NAME)

local PlayerStore = {}

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function PlayerStore.newProfile()
	return {
		schema = SCHEMA,
		coins = 0,
		resources = {},
		clockTower = 1,
		nextSeq = 1,
		stored = {},
		placed = {},
		lastSeen = os.time(),
		isNew = true,
	}
end

-- 반환: 프로필, 저장 가능 여부
function PlayerStore.load(player: Player)
	for attempt = 1, RETRIES do
		local ok, data = pcall(function()
			return store:GetAsync(keyFor(player))
		end)

		if ok then
			return data or PlayerStore.newProfile(), true
		end

		warn(string.format("저장 데이터 로드 실패 (%d/%d): %s", attempt, RETRIES, tostring(data)))
		task.wait(attempt)
	end

	return PlayerStore.newProfile(), false
end

function PlayerStore.save(player: Player, profile): boolean
	profile.lastSeen = os.time()

	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), profile)
	end)

	if not ok then
		warn("저장 실패: " .. tostring(err))
	end
	return ok
end

return PlayerStore
