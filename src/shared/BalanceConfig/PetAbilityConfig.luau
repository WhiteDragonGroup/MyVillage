-- PetAbilityConfig.luau
-- 펫별 능동/수동 능력 정의
-- PetAbilityManager(server)가 주기적으로 처리

local PetAbilityConfig = {}

PetAbilityConfig.ABILITIES = {
	-- 같은 종 5스터드 내 스켈레톤 발견 시 인사 → 동료의 응원 (주변 스켈레톤 수만큼 레벨)
	Skeleton = {
		kind = "buff_kin",
		cooldown = 30,
		range = 5,
		buffId = "AllyEncouragement",
		levelByKinCount = true,
		duration = 30,
	},
	-- 5스터드 내 다른 펫 발견 시 주술 → 악마의 힘 1
	Imp = {
		kind = "buff_others",
		cooldown = 40,
		range = 5,
		buffId = "DemonicPower",
		level = 1,
		duration = 30,
	},
	-- 5스터드 내 다른 펫 발견 시 전기 → Energy/Haste/Charge
	Zipbit = {
		kind = "buff_others_multi",
		cooldown = 30,
		range = 5,
		buffs = {
			{ buffId = "Energy", level = 1, duration = 60 },
			{ buffId = "Haste", level = 2, duration = 60 },
			{ buffId = "Charge", level = 1, duration = 60 },
		},
	},
	-- 7스터드 내 다른 펫 발견 시 투사체 → 용의 힘 1
	BabyDragon = {
		kind = "buff_others",
		cooldown = 40,
		range = 7,
		buffId = "DragonsPower",
		level = 1,
		duration = 30,
	},
	-- 일정시간마다 노래 → 음파 범위 내 펫
	Ghost = {
		kind = "buff_aoe",
		cooldown = 25,
		range = 8,
		buffId = "GhostsSong",
		level = 1,
		duration = 20,
	},
	-- 맑은 날씨 + 일하지 않을 때 해바라기 심기 → 활력
	Sunflowie = {
		kind = "buff_aoe_conditional",
		cooldown = 45,
		range = 6,
		buffId = "Vitality",
		level = 1,
		duration = 30,
		requireWeather = "Sunny",
		requireIdle = true,
	},
	-- 알이 있으면 알에 다가가서 부화시간 3분 단축
	Yeti = {
		kind = "egg_pet",
		cooldown = 90,
		hatchReductionSec = 180,
	},
	-- 일정시간마다 푸른 스켈레톤 2마리 소환 (30초)
	Witch = {
		kind = "summon",
		cooldown = 120,
		summonPet = "Skeleton",
		summonCount = 2,
		summonDuration = 30,
		summonOpacity = 0.5,
	},
}

-- 수동 효과 (working loop에서 직접 참조)
PetAbilityConfig.PASSIVE = {
	-- 채굴 시 보석 확률 +200% (보너스 = 3배)
	CrystalGolem = { gemChanceBonus = 2.0 },
	-- 눈 날씨에 일 효율 +100%
	IceGolem = { snowEfficiencyBonus = 1.0 },
	-- 밤에도 잠 안 자고 농사/채굴 효율 + (현재 30%)
	ZombieNewbie = { nightWorkBonus = 0.30 },
}

return PetAbilityConfig
