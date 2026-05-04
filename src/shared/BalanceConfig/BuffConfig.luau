-- BuffConfig.luau
-- 버프 정의: 아이콘, 설명, 효과
-- BuffManager (server) + BuffUI (client)에서 참조

local BuffConfig = {}

-- 버프 카탈로그
-- icon: rbxassetid:// or 빈 문자열(폴백 색상 사용)
-- description: 마우스오버 시 HUD에 표시될 설명
-- color: 폴백 아이콘 색상
BuffConfig.BUFFS = {
	FarmingBoost = {
		name = "Farming Boost",
		description = "Farming pets work 50% faster.",
		icon = "",
		color = Color3.fromRGB(120, 220, 120),
	},
	MiningBoost = {
		name = "Mining Boost",
		description = "Mining pets work 50% faster.",
		icon = "",
		color = Color3.fromRGB(200, 180, 100),
	},
	CoinBoost = {
		name = "Coin Boost",
		description = "All coin earnings doubled.",
		icon = "",
		color = Color3.fromRGB(255, 215, 0),
	},
	XpBoost = {
		name = "XP Boost",
		description = "Pet XP gain doubled.",
		icon = "",
		color = Color3.fromRGB(120, 180, 255),
	},
}

return BuffConfig
