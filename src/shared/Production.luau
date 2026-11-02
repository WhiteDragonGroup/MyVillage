-- 일터 생산 계산. 접속 중 틱과 오프라인 정산이 같은 함수를 쓴다.

local Items = require(script.Parent.Items)
local Buildings = require(script.Parent.Buildings)

local Production = {}

-- 레벨별 저장 배수: 1·2·4·8·16
function Production.capacityOf(itemId: string, level: number): number
	return Items.ById[itemId].storage * 2 ^ (level - 1)
end

-- rec.store / rec.progress를 dt초만큼 진행한다. 저장량이 바뀌면 true.
-- 가득 찬 자원은 시간을 쌓지 않고, 다른 자원은 계속 생산한다.
function Production.advance(rec, workers: number, dt: number): boolean
	if workers <= 0 or dt <= 0 then
		return false
	end

	local def = Buildings.ById[rec.id]
	local changed = false

	for _, itemId in def.outputs do
		local cap = Production.capacityOf(itemId, rec.level)
		local stored = rec.store[itemId] or 0

		if stored < cap then
			local cycle = Items.ById[itemId].cycle
			local progress = (rec.progress[itemId] or 0) + workers * dt
			local batches = math.floor(progress / cycle)

			if batches > 0 then
				local gained = batches * rec.level
				if stored + gained >= cap then
					rec.store[itemId] = cap
					progress = 0
				else
					rec.store[itemId] = stored + gained
					progress -= batches * cycle
				end
				changed = true
			end

			rec.progress[itemId] = progress
		end
	end

	return changed
end

return Production
