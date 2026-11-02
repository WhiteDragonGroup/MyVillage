-- 건물 상점. 입고 목록은 시각에서 정해져 모든 서버가 같고, 구매 수량만 플레이어별로 저장한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buildings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Buildings"))

-- 플레이테스트용 초기값. 입고 확률·수량은 기획 확정 후 교체한다.
local RESTOCK_SECONDS = 300
local SLOT_COUNT = 6
local MAX_STOCK = 3
local UNLOCK_WEIGHT_BASE = 6 -- 해금 레벨이 낮을수록 자주 입고된다

local FIRST_PURCHASE_ID = "Lumberyard" -- 구매할 때까지 매물 1개 보장

local Shop = {}

-- 순서가 서버마다 같아야 같은 목록이 나온다
local catalog = {}
for id, def in Buildings.ById do
	if def.coins then
		table.insert(catalog, id)
	end
end
table.sort(catalog)

function Shop.currentCycle(): number
	return math.floor(os.time() / RESTOCK_SECONDS)
end

local function stockOf(cycle: number)
	local rng = Random.new(cycle)
	local pool = table.clone(catalog)
	local stock = {}

	for _ = 1, SLOT_COUNT do
		local total = 0
		for _, id in pool do
			total += UNLOCK_WEIGHT_BASE - Buildings.ById[id].unlock
		end

		local roll = rng:NextNumber() * total
		for index, id in pool do
			roll -= UNLOCK_WEIGHT_BASE - Buildings.ById[id].unlock
			if roll <= 0 then
				stock[id] = rng:NextInteger(1, MAX_STOCK)
				table.remove(pool, index)
				break
			end
		end
	end

	return stock
end

local function syncCycle(profile, cycle: number)
	if profile.shopCycle ~= cycle then
		profile.shopCycle = cycle
		profile.shopBought = {}
	end
end

-- 이 플레이어에게 보일 현재 매물
function Shop.view(profile)
	local cycle = Shop.currentCycle()
	syncCycle(profile, cycle)

	local stock = stockOf(cycle)
	if not profile.firstPurchaseDone and not stock[FIRST_PURCHASE_ID] then
		stock[FIRST_PURCHASE_ID] = 1
	end

	local entries = {}
	for id, amount in stock do
		table.insert(entries, {
			id = id,
			stock = amount,
			left = math.max(0, amount - (profile.shopBought[id] or 0)),
		})
	end
	table.sort(entries, function(a, b)
		local coinsA, coinsB = Buildings.ById[a.id].coins, Buildings.ById[b.id].coins
		if coinsA ~= coinsB then
			return coinsA < coinsB
		end
		return a.id < b.id
	end)

	return { cycle = cycle, endsAt = (cycle + 1) * RESTOCK_SECONDS, entries = entries }
end

-- 코인 구매. 성공하면 true, 실패하면 false와 사유. 건물 지급은 호출한 쪽에서 한다.
function Shop.buy(profile, id, cycle): (boolean, string?)
	local view = Shop.view(profile)
	if cycle ~= view.cycle then
		return false, "The shop has restocked"
	end

	local entry
	for _, candidate in view.entries do
		if candidate.id == id then
			entry = candidate
			break
		end
	end

	if not entry then
		return false, "This building is not in stock"
	end
	if entry.left <= 0 then
		return false, "Sold out"
	end

	local def = Buildings.ById[id]
	if def.unlock > profile.clockTower then
		return false, string.format("Requires Clock Tower Lv.%d", def.unlock)
	end
	if profile.coins < def.coins then
		return false, "Not enough coins"
	end

	profile.coins -= def.coins
	profile.shopBought[id] = (profile.shopBought[id] or 0) + 1
	if id == FIRST_PURCHASE_ID then
		profile.firstPurchaseDone = true
	end

	return true, nil
end

return Shop
