-- WeatherManager.server.luau
-- 서버 날씨 관리: 쿨다운 → 날씨 발생 → 지속시간 → Sunny 복귀 사이클

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local WeatherState = require(script.Parent:WaitForChild("WeatherState"))

local WeatherCfg = BalanceConfig.Weather
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local weatherChangedEvent = remotes:WaitForChild("WeatherChanged")

-- 현재 날씨
local currentWeather = "Sunny"
local currentMessage = ""

-- 가중치 랜덤 선택 (Sunny 제외)
local function pickWeather(): string
	local totalWeight = 0
	for _, w in WeatherCfg.WEIGHTS do
		totalWeight += w
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for weatherType, w in WeatherCfg.WEIGHTS do
		cumulative += w
		if roll <= cumulative then
			return weatherType
		end
	end

	return "Rain" -- 폴백
end

-- 랜덤 범위
local function randomRange(min: number, max: number): number
	return min + math.random() * (max - min)
end

-- 날씨 변경 + 클라이언트 알림
local function setWeather(weatherType: string, message: string)
	currentWeather = weatherType
	currentMessage = message
	WeatherState.set(weatherType)
	print("[WeatherManager] 날씨 변경:", weatherType, message ~= "" and ("| " .. message) or "")
	weatherChangedEvent:FireAllClients(weatherType, message)
end

-- 신규 접속자에게 현재 날씨 전송
Players.PlayerAdded:Connect(function(player)
	weatherChangedEvent:FireClient(player, currentWeather, "")
end)

-- 클라이언트 요청 시 현재 날씨 반환
local getWeatherFunc = remotes:WaitForChild("GetWeather")
getWeatherFunc.OnServerInvoke = function(_player)
	return currentWeather
end

-- 시작: Sunny
setWeather("Sunny", "")
print("[WeatherManager] 초기 상태: Sunny (쿨다운 대기)")

----------------------------------------------------------------
-- 번개 로직 (ThunderStorm)
----------------------------------------------------------------
local lightningStrikeEvent = remotes:WaitForChild("LightningStrike")
local PetManager = nil -- 지연 로드 (순환 참조 방지)

local function getPetManager()
	if not PetManager then
		PetManager = require(ServerScriptService:WaitForChild("Server"):WaitForChild("PetManager"))
	end
	return PetManager
end

-- 플롯에서 랜덤 위치 선택
local function getRandomPlotPosition(): Vector3?
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end

	local plots = plotsFolder:GetChildren()
	if #plots == 0 then return nil end

	local plot = plots[math.random(1, #plots)]
	local buildZone = plot:FindFirstChild("BuildZone", true)
	if not buildZone then return nil end

	local center = buildZone.Position
	local halfSize = buildZone.Size / 2
	local x = center.X + (math.random() * 2 - 1) * halfSize.X
	local z = center.Z + (math.random() * 2 - 1) * halfSize.Z
	return Vector3.new(x, center.Y, z)
end

-- 번개 위치 주변 펫 감지 및 돌연변이 부여
local function strikeLightning(position: Vector3)
	local radius = WeatherCfg.LIGHTNING_RADIUS
	local region = CFrame.new(position)
	local size = Vector3.new(radius * 2, radius * 2, radius * 2)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	-- 월드 전체에서 감지 (제외 없음)
	local parts = workspace:GetPartBoundsInBox(region, size, overlapParams)

	for _, part in parts do
		local petId = part:GetAttribute("PetId")
		if petId and petId ~= "" then
			local ownerId = part:GetAttribute("OwnerId")
			if ownerId then
				-- 펫 소유자 찾기
				for _, player in Players:GetPlayers() do
					if player.UserId == ownerId then
						local pm = getPetManager()
						if pm and not pm.hasMutation(player, petId, "Shocked") then
							pm.addMutation(player, petId, "Shocked")
							print("[WeatherManager] 번개 적중! 펫", petId, "→ Shocked 돌연변이")
						end
						break
					end
				end
			end
		end
	end

	-- 클라이언트에 번개 VFX 전송
	lightningStrikeEvent:FireAllClients(position)
end

-- 번개 루프 (ThunderStorm 동안 실행)
local _lightningThread: thread? = nil

local function startLightningLoop()
	if _lightningThread then return end
	_lightningThread = task.spawn(function()
		while currentWeather == "ThunderStorm" do
			local interval = randomRange(WeatherCfg.LIGHTNING_INTERVAL_MIN, WeatherCfg.LIGHTNING_INTERVAL_MAX)
			task.wait(interval)

			if currentWeather ~= "ThunderStorm" then break end

			local pos = getRandomPlotPosition()
			if pos then
				strikeLightning(pos)
			end
		end
		_lightningThread = nil
	end)
end

local function stopLightningLoop()
	if _lightningThread then
		task.cancel(_lightningThread)
		_lightningThread = nil
	end
end

----------------------------------------------------------------
-- 날씨 사이클 루프
----------------------------------------------------------------
task.spawn(function()
	while true do
		-- 1. 쿨다운 대기 (Sunny 상태)
		local cooldown = randomRange(WeatherCfg.COOLDOWN_MIN, WeatherCfg.COOLDOWN_MAX)
		print("[WeatherManager] 쿨다운:", math.floor(cooldown) .. "초")
		task.wait(cooldown)

		-- 2. 날씨 발생
		local weather = pickWeather()
		local msgData = WeatherCfg.MESSAGES[weather]
		local startMsg = msgData and msgData.start or ""
		setWeather(weather, startMsg)

		-- ThunderStorm이면 번개 루프 시작
		if weather == "ThunderStorm" then
			startLightningLoop()
		end

		-- 3. 지속시간 대기
		local duration = randomRange(WeatherCfg.DURATION_MIN, WeatherCfg.DURATION_MAX)
		print("[WeatherManager] 지속시간:", math.floor(duration) .. "초")
		task.wait(duration)

		-- 번개 루프 중단
		stopLightningLoop()

		-- 4. 날씨 종료 → Sunny 복귀
		local endMsg = msgData and msgData.finish or ""
		setWeather("Sunny", endMsg)
	end
end)
