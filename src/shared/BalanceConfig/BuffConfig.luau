-- BuffConfig.luau
-- 버프 정의: 이름/설명/효과. 레벨별 수치는 levels 배열로 정의.
-- BuffManager (server) + BuffUI (client) + 휴식/일터 버프 후크에서 참조.

local BuffConfig = {}

-- 같은 버프가 중첩될 때 더 높은 레벨만 적용. 만료되면 남은 낮은 레벨로 폴백.
-- effect: { workEfficiency, moveSpeed, gemChance, restDecay, sleepless, workDuration, ... }
-- levels[level] = 적용 수치 (n%)

BuffConfig.BUFFS = {
	Vitality = {
		name = "Vitality",
		nameKr = "활력",
		description = "Your pet is overflowing with vitality! Work efficiency increases by {n}%.",
		descriptionKr = "펫이 활력으로 가득 찹니다 ! 일의 효율이 {n}% 증가합니다.",
		icon = "",
		color = Color3.fromRGB(255, 100, 100),
		effect = "workEfficiency",
		levels = { [1] = 10, [2] = 20, [3] = 35 },
	},
	Haste = {
		name = "Haste",
		nameKr = "신속",
		description = "Pet's steps feel lighter! Reach your destination {n}% faster.",
		descriptionKr = "발걸음이 가벼워졌습니다! {n}% 더 빠르게 목적지에 도착합니다!",
		icon = "",
		color = Color3.fromRGB(120, 220, 255),
		effect = "moveSpeed",
		levels = { [1] = 10, [2] = 25, [3] = 50 },
	},
	Blessing = {
		name = "Blessing",
		nameKr = "축복",
		description = "A powerful blessing has taken hold! Work efficiency increases by {n}%.",
		descriptionKr = "강력한 축복이 깃들었습니다! 일의 효율이 {n}% 상승합니다 !",
		icon = "",
		color = Color3.fromRGB(255, 220, 120),
		effect = "workEfficiency",
		levels = { [1] = 30, [2] = 50, [3] = 80 },
	},
	Fortune = {
		name = "Fortune",
		nameKr = "행운",
		description = "Luck has increased! Pet is {n}% more likely to discover gems while mining.",
		descriptionKr = "행운이 증가합니다 ! 채굴 도중 보석을 {n}% 더 잘 발견합니다",
		icon = "",
		color = Color3.fromRGB(180, 240, 130),
		effect = "gemChance",
		levels = { [1] = 25, [2] = 50, [3] = 100 },
	},
	Satiation = {
		name = "Satiation",
		nameKr = "포만감",
		description = "Well-fed and ready to go! Work efficiency increases by {n}%.",
		descriptionKr = "든든하게 배를 채웠습니다 ! 일의 효율이 {n}% 증가합니다.",
		icon = "",
		color = Color3.fromRGB(255, 180, 100),
		effect = "workEfficiency",
		levels = { [1] = 15, [2] = 30, [3] = 50 },
	},
	Energy = {
		name = "Energy",
		nameKr = "에너지",
		description = "Energy is overflowing! Your pet can keep working without sleep.",
		descriptionKr = "에너지가 마구 넘치네요. 잠 없이도 계속 일할 수 있습니다 !",
		icon = "",
		color = Color3.fromRGB(255, 240, 100),
		effect = "sleepless",
		levels = { [1] = 1 }, -- 레벨 의미 없음
	},
	Serenity = {
		name = "Serenity",
		nameKr = "평온",
		description = "Your pet feels at peace. The pet can work {n}% longer before rest.",
		descriptionKr = "펫이 평안함을 느낍니다. 휴식 전까지 {n}% 더 오래 일 합니다.",
		icon = "",
		color = Color3.fromRGB(180, 220, 230),
		effect = "workDuration",
		levels = { [1] = 25, [2] = 50, [3] = 100 },
	},

	-- 펫 고유 버프
	AllyEncouragement = {
		name = "Ally's Encouragement",
		nameKr = "동료의 응원",
		description = "Your allies are cheering you on! Work efficiency increases by {n}%!",
		icon = "", color = Color3.fromRGB(255, 200, 200),
		effect = "workEfficiency",
		levels = { [1] = 15, [2] = 30 },
	},
	GhostsSong = {
		name = "Ghost's Song",
		nameKr = "유령의 노래",
		description = "A mysterious song echoes... Work efficiency increases by {n}%!",
		icon = "", color = Color3.fromRGB(200, 200, 255),
		effect = "workEfficiency",
		levels = { [1] = 20 },
	},
	Charge = {
		name = "Charge",
		nameKr = "충전",
		description = "Fully charged and ready to go! Work efficiency increases by {n}%!",
		icon = "", color = Color3.fromRGB(255, 255, 130),
		effect = "workEfficiency",
		levels = { [1] = 25 },
	},
	DemonicPower = {
		name = "Demonic Power",
		nameKr = "악마의 힘",
		description = "A forbidden power surges through you... Work efficiency increases by {n}%!",
		icon = "", color = Color3.fromRGB(180, 60, 80),
		effect = "workEfficiency",
		levels = { [1] = 40 },
	},
	DragonsPower = {
		name = "Dragon's Power",
		nameKr = "용의 힘",
		description = "The mighty power of a dragon surrounds you! Work efficiency increases by {n}%!",
		icon = "", color = Color3.fromRGB(220, 100, 60),
		effect = "workEfficiency",
		levels = { [1] = 50 },
	},
	BurningHeart = {
		name = "Burning Heart",
		nameKr = "불타는 심장",
		description = "Your heart burns with passion! Work efficiency increases by {n}%!",
		icon = "", color = Color3.fromRGB(255, 120, 80),
		effect = "workEfficiency",
		levels = { [1] = 35, [2] = 60 },
	},
}

-- 휴식 건물별 부여 버프 (휴식 시작 시 적용)
-- buildingName: { buffId, level, durationSec, restDecayMultiplier? }
BuffConfig.REST_BUILDING_BUFFS = {
	HotSpring = {
		buffId = "Serenity", level = 1, durationSec = 60,
		restDecayMultiplier = 1.5,  -- 남은 휴식 시간 1.5배 빠르게 줄어듦
	},
	Crystal = {
		buffId = "Blessing", level = 1, durationSec = 90,
	},
	-- TreeOfGrowth: 휴식 동안 경험치 5배 (별도 처리)
	TreeOfGrowth = {
		xpMultiplier = 5,
	},
}

-- Laboratory: 알 부화 속도 증가율 (건물 레벨별)
BuffConfig.LABORATORY_HATCH_BOOST = {
	[1] = 0.10, [2] = 0.20, [3] = 0.35, [4] = 0.50, [5] = 0.75,
}

-- Giant Furnace: 발사 간격 + 용암 효과 지속/범위
BuffConfig.GIANT_FURNACE = {
	shootInterval = 8,            -- 8초마다 용암 발사
	projectileSpeed = 60,
	splashRadius = 12,
	splashDurationSec = 1,
	buffOnSplash = { buffId = "BurningHeart", level = 1, durationSec = 30 },
}

-- 버프 효과 적용 헬퍼 (PetManager 등에서 호출)
-- 활성 버프 리스트에서 가장 높은 레벨의 effect 값을 합산
function BuffConfig.computeEffect(activeBuffs: { [string]: number }, effectName: string): number
	-- activeBuffs: { [buffId] = level }
	-- effectName이 같은 모든 버프의 levels 합 (% 단위)
	local total = 0
	for buffId, level in activeBuffs do
		local def = BuffConfig.BUFFS[buffId]
		if def and def.effect == effectName and def.levels then
			total = total + (def.levels[level] or 0)
		end
	end
	return total
end

return BuffConfig
