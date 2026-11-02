-- 주민 자동 근무 배정. 집 → 주민 순서로 한 명씩 가장 가까운 빈 일터를 찾는다.

local Buildings = require(script.Parent.Buildings)

local Workforce = {}

local function bySeq(a, b)
	return a.seq < b.seq
end

-- placed: { [uid] = rec }
-- 반환: workers { [workUid] = 인원 }, jobs { [homeUid] = { 주민별 workUid 또는 false } }
function Workforce.assign(placed)
	local homes, works = {}, {}
	local workers, jobs = {}, {}

	for _, rec in placed do
		local kind = Buildings.ById[rec.id].kind
		if kind == "Home" then
			table.insert(homes, rec)
		elseif kind == "Work" then
			table.insert(works, rec)
			workers[rec.uid] = 0
		end
	end

	table.sort(homes, bySeq)
	table.sort(works, bySeq)

	for _, home in homes do
		local homeJobs = {}

		for residentIndex = 1, Buildings.ById[home.id].residents do
			local best, bestDistance = nil, math.huge

			for _, work in works do
				if workers[work.uid] < Buildings.ById[work.id].capacity then
					local dx, dz = work.x - home.x, work.z - home.z
					local distance = dx * dx + dz * dz
					-- works가 배치 순서라 거리가 같으면 먼저 놓은 일터가 남는다
					if distance < bestDistance then
						best, bestDistance = work, distance
					end
				end
			end

			if best then
				workers[best.uid] += 1
				homeJobs[residentIndex] = best.uid
			else
				homeJobs[residentIndex] = false
			end
		end

		jobs[home.uid] = homeJobs
	end

	return workers, jobs
end

return Workforce
