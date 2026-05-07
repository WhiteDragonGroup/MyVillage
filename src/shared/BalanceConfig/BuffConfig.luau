-- BuffConfig.luau
-- 버프 정의: 이름/설명/효과. 레벨별 수치는 levels 배열로 정의.
-- BuffManager (server) + BuffUI (client) + 휴식/일터 버프 후크에서 참조.

local BuffConfig = {}

-- 같은 버프가 중첩될 때 더 높은 레벨만 적용. 만료되면 남은 낮은 레벨로 폴백.
-- effect: { workEfficiency, moveSpeed, gemChance, restDecay, sleepless, workDuration, ... }
-- levels[level] = 적용 수치 (n%)

-- icon 값은 팀원이 제공한 이미지에서 옮겨 적음. 디지트 일부가 작은 이미지에서
-- 정확하지 않을 수 있음 → 실제 Asset ID와 비교 후 수정 필요.
BuffConfig.BUFFS = {
	Vitality = {
		name = "Vitality",
		nameKr = "활력",
		description = "Your pet is overflowing with vitality! Work efficiency increases by {n}%.",
		descriptionKr = "펫이 활력으로 가득 찹니다 ! 일의 효율이 {n}% 증가합니다.",
		icon = "rbxassetid://7332675943101",
		color = Color3.fromRGB(255, 100, 100),
		effect = "workEfficiency",
		value = 10,
	},
	Haste = {
		name = "Haste",
		nameKr = "신속",
		description = "Pet's steps feel lighter! Reach your destination {n}% faster.",
		descriptionKr = "발걸음이 가벼워졌습니다! {n}% 더 빠르게 목적지에 도착합니다!",
		icon = "rbxassetid://7359965909027",
		color = Color3.fromRGB(120, 220, 255),
		effect = "moveSpeed",
		value = 10,
	},
	Blessing = {
		name = "Blessing",
		nameKr = "축복",
		description = "A powerful blessing has taken hold! Work efficiency increases by {n}%.",
		descriptionKr = "강력한 축복이 깃들었습니다! 일의 효율이 {n}% 상승합니다 !",
		icon = "rbxassetid://75207170833091",
		color = Color3.fromRGB(255, 220, 120),
		effect = "workEfficiency",
		value = 30,
	},
	Fortune = {
		name = "Fortune",
		nameKr = "행운",
		description = "Luck has increased! Pet is {n}% more likely to discover gems while mining.",
		descriptionKr = "행운이 증가합니다 ! 채굴 도중 보석을 {n}% 더 잘 발견합니다",
		icon = "rbxassetid://7196659985405",
		color = Color3.fromRGB(180, 240, 130),
		effect = "gemChance",
		value = 25,
	},
	Satiation = {
		name = "Satiation",
		nameKr = "포만감",
		description = "Well-fed and ready to go! Work efficiency increases by {n}%.",
		descriptionKr = "든든하게 배를 채웠습니다 ! 일의 효율이 {n}% 증가합니다.",
		icon = "rbxassetid://9433611845158",
		color = Color3.fromRGB(255, 180, 100),
		effect = "workEfficiency",
		value = 15,
	},
	Energy = {
		name = "Energy",
		nameKr = "에너지",
		description = "Energy is overflowing! Your pet can keep working without sleep.",
		descriptionKr = "에너지가 마구 넘치네요. 잠 없이도 계속 일할 수 있습니다 !",
		icon = "rbxassetid://1318945478220",
		color = Color3.fromRGB(255, 240, 100),
		effect = "sleepless",
		value = 1,
	},
	Serenity = {
		name = "Serenity",
		nameKr = "평온",
		description = "Your pet feels at peace. The pet can work {n}% longer before rest.",
		descriptionKr = "펫이 평안함을 느낍니다. 휴식 전까지 {n}% 더 오래 일 합니다.",
		icon = "rbxassetid://7480292072562",
		color = Color3.fromRGB(180, 220, 230),
		effect = "workDuration",
		value = 25,
	},

	-- 펫 고유 버프
	AllyEncouragement = {
		name = "Ally's Encouragement",
		nameKr = "동료의 응원",
		description = "Your allies are cheering you on! Work efficiency increases by {n}%!",
		icon = "rbxassetid://10535369273907",
		color = Color3.fromRGB(255, 200, 200),
		effect = "workEfficiency",
		value = 15,
	},
	GhostsSong = {
		name = "Ghost's Song",
		nameKr = "유령의 노래",
		description = "A mysterious song echoes... Work efficiency increases by {n}%!",
		icon = "rbxassetid://7359965909027",
		color = Color3.fromRGB(200, 200, 255),
		effect = "workEfficiency",
		value = 20,
	},
	Charge = {
		name = "Charge",
		nameKr = "충전",
		description = "Fully charged and ready to go! Work efficiency increases by {n}%!",
		icon = "rbxassetid://7280996972142",
		color = Color3.fromRGB(255, 255, 130),
		effect = "workEfficiency",
		value = 25,
	},
	DemonicPower = {
		name = "Demonic Power",
		nameKr = "악마의 힘",
		description = "A forbidden power surges through you... Work efficiency increases by {n}%!",
		icon = "rbxassetid://11860226787052",
		color = Color3.fromRGB(180, 60, 80),
		effect = "workEfficiency",
		value = 40,
	},
	DragonsPower = {
		name = "Dragon's Power",
		nameKr = "용의 힘",
		description = "The mighty power of a dragon surrounds you! Work efficiency increases by {n}%!",
		icon = "rbxassetid://7350697566332",
		color = Color3.fromRGB(220, 100, 60),
		effect = "workEfficiency",
		value = 50,
	},
	BurningHeart = {
		name = "Burning Heart",
		nameKr = "불타는 심장",
		description = "Your heart burns with passion! Work efficiency increases by {n}%!",
		icon = "rbxassetid://11168226756916",
		color = Color3.fromRGB(255, 120, 80),
		effect = "workEfficiency",
		value = 35,
	},
}

-- 휴식 건물별 부여 버프 (휴식 시작 시 적용)
-- buildingName: { buffId, level, durationSec, restDecayMultiplier? }
BuffConfig.REST_BUILDING_BUFFS = {
	HotSpring = {
		buffId = "Serenity", durationSec = 60,
		restDecayMultiplier = 1.5,  -- 남은 휴식 시간 1.5배 빠르게 줄어듦
	},
	Crystal = {
		buffId = "Blessing", durationSec = 90,
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
	buffOnSplash = { buffId = "BurningHeart", durationSec = 30 },
}

-- 버프 효과 적용 헬퍼 (PetManager 등에서 호출)
-- 활성 버프 리스트에서 effect 값을 합산
function BuffConfig.computeEffect(activeBuffs: { [string]: boolean | number }, effectName: string): number
	-- activeBuffs: { [buffId] = true } 또는 { [buffId] = anything }
	-- effectName이 같은 모든 버프의 value 합 (% 단위)
	local total = 0
	for buffId, _ in activeBuffs do
		local def = BuffConfig.BUFFS[buffId]
		if def and def.effect == effectName then
			total = total + (def.value or 0)
		end
	end
	return total
end

return BuffConfig
