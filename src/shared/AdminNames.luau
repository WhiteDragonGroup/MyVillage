-- 관리자 패널 전용 한글 이름. 게임 화면 문구는 영어 그대로 쓴다.

local AdminNames = {}

AdminNames.Items = {
	Wheat = "밀",
	Corn = "옥수수",
	Timber = "목재",
	TreeSap = "수액",
	Mushroom = "버섯",
	Charcoal = "숯",
	Meat = "고기",
	Petal = "꽃잎",
	Herb = "약초",
	Stone = "돌",
	IronOre = "철광석",
	GoldOre = "금광석",
	Gem = "보석",
	Diamond = "다이아몬드",
	HotSpringEgg = "온천 달걀",
	Beeswax = "밀랍",
	Honey = "꿀",
	GoldenLeaf = "황금 잎",
	GoldenApple = "황금 사과",
	ArcaneDust = "신비한 가루",
	Crystal = "수정",
	IronIngot = "철 주괴",
	GoldIngot = "금 주괴",
	StarlightShard = "별빛 조각",
	ToolCrate = "도구 상자",
	SupplyCrate = "보급 상자",
}

AdminNames.Buildings = {
	ClockTower = "시계탑",
	Cottage2 = "2인 오두막",
	Cottage3 = "3인 오두막",
	House4 = "4인 주택",
	House5 = "5인 주택",
	House6 = "6인 주택",
	Farm = "농장",
	Lumberyard = "벌목장",
	MushroomFarm = "버섯 농장",
	Campfire = "모닥불",
	HerbGarden = "약초 정원",
	Mine = "광산",
	HotSpring = "온천",
	Apiary = "양봉장",
	TreeOfGrowth = "성장의 나무",
	CrystalMine = "수정 광산",
	GrandSmelter = "대형 제련소",
	BlessingAltar = "축복의 제단",
	LargeWarehouse = "대형 창고",
}

function AdminNames.item(id: string): string
	return AdminNames.Items[id] or id
end

function AdminNames.building(id: string): string
	return AdminNames.Buildings[id] or id
end

return AdminNames
