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

-- 기본 지급 펫 (플레이어 최초 접속 시)
PetConfig.DEFAULT_PETS = {
	{ petName = "초보 건설 슬라임", petType = "Construction", rarity = "일반" },
}

-- 펫 카탈로그 (petType별 건설 속도 배율)
PetConfig.TYPE_MULTIPLIER = {
	Construction = 1.0,
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
