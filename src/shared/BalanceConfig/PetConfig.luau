-- PetConfig.luau
-- 펫 시스템 밸런스 수치
-- 참조: PetManager / PetServer / PetVisuals

local PetConfig = {}

-- 건설 속도: 펫이 매 틱(1초)마다 올리는 진행도 (%)
PetConfig.BUILD_SPEED = 2 -- 기본 2%/초 → 50초에 완료

-- 배회 파라미터
PetConfig.WANDER_RADIUS = 8       -- 배회 반경 (stud)
PetConfig.WANDER_INTERVAL = 3     -- 배회 이동 간격 (초)
PetConfig.WANDER_SPEED = 8        -- 배회 이동 속도 (stud/s)
PetConfig.PET_HEIGHT = 3          -- 지면 위 떠다니는 높이 (stud)

-- 펫 외형
PetConfig.PET_SIZE = Vector3.new(2, 2, 2)
PetConfig.PET_MATERIAL = Enum.Material.SmoothPlastic

-- 행동 타이밍
PetConfig.WORK_DURATION_MIN = 120    -- 일 최소 시간 (초, 2분)
PetConfig.WORK_DURATION_MAX = 240    -- 일 최대 시간 (초, 4분)
PetConfig.REST_DURATION_MIN = 60     -- 휴식 최소 (초, 1분)
PetConfig.REST_DURATION_MAX = 90     -- 휴식 최대 (초, 1분30초)
PetConfig.FATIGUE_DURATION = 3       -- 피로→휴식 전환 (초)
PetConfig.WALK_CHANCE = 0.25         -- 쉼터 대신 산책 확률
PetConfig.PREV_WORK_PREFERENCE = 0.5 -- 이전 일터 선호 확률
PetConfig.CHAT_DURATION = 5          -- 대화 지속 (초)
PetConfig.CHAT_DISTANCE = 6          -- 대화 감지 거리 (stud)
PetConfig.MOVE_SPEED = 12            -- 일터/쉼터 이동 (stud/s)

-- 사이즈별 표준 무게 (kg)
PetConfig.SIZE_STANDARD_WEIGHT = {
	Small = 5, Medium = 10, Big = 25, Huge = 60, Ultra = 150,
}

-- 무게 범위 (표준 x 배율)
PetConfig.WEIGHT_MIN_MULT = 0.7
PetConfig.WEIGHT_MAX_MULT = 2.0

-- 레벨 시스템
PetConfig.MAX_LEVEL = 10
PetConfig.XP_PER_SECOND = 1          -- 매초 XP 획득

-- 레벨별 필요 XP
PetConfig.XP_REQUIRED = {
	[1] = 100, [2] = 250, [3] = 500, [4] = 900, [5] = 1500,
	[6] = 2500, [7] = 4000, [8] = 6000, [9] = 9000,
}

-- 레벨별 효율 배율 (레벨10 = 2배)
PetConfig.LEVEL_EFFICIENCY = {
	[1]=1.0, [2]=1.11, [3]=1.22, [4]=1.33, [5]=1.44,
	[6]=1.56, [7]=1.67, [8]=1.78, [9]=1.89, [10]=2.0,
}

-- 기본 지급 펫 (플레이어 최초 접속 시)
PetConfig.DEFAULT_PETS = {
	{ petName = "초보 건설 슬라임", petType = "Construction", rarity = "일반",
	  size = "Small", race = "인간", traits = {} },
}

-- 펫 카탈로그 (petType별 작업 효율 배율)
PetConfig.TYPE_MULTIPLIER = {
	Construction = 1.0,
	Farming = 1.0,
	Mining = 1.0,
	Buff = 0.5,
}

-- 등급별 건설 속도 배율
PetConfig.RARITY_MULTIPLIER = {
	["일반"] = 1.0,
	["희귀"] = 1.5,
	["에픽"] = 2.0,
	["전설"] = 3.0,
	["신화"] = 5.0,
}

-- 등급별 펫 색상
PetConfig.RARITY_COLORS = {
	["일반"] = Color3.fromRGB(140, 200, 140),
	["희귀"] = Color3.fromRGB(100, 180, 255),
	["에픽"] = Color3.fromRGB(200, 130, 255),
	["전설"] = Color3.fromRGB(255, 200, 80),
	["신화"] = Color3.fromRGB(255, 100, 100),
}

return PetConfig
