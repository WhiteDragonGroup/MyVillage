-- WeatherVFX.luau
-- 스크린스페이스 날씨 VFX 시스템
-- 카메라 앞에 이펙트 파트를 띄워서 최적화된 날씨 표현

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local BalanceConfig = require(shared:WaitForChild("BalanceConfig"))

local WeatherCfg = BalanceConfig.Weather
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local weatherChangedEvent = remotes:WaitForChild("WeatherChanged")
local getWeatherFunc = remotes:WaitForChild("GetWeather")
local weatherFolder = ReplicatedStorage:WaitForChild("Weather")

local camera = workspace.CurrentCamera

local WeatherVFX = {}

local currentWeather: string = "Sunny"
local effectContainer: Folder? = nil
local renderConnection: RBXScriptConnection? = nil
local lightFlickerThread: thread? = nil

----------------------------------------------------------------
-- 폴백 파티클 생성 (Weather 폴더에 에셋이 없을 때)
----------------------------------------------------------------

local function createFallbackPart(): Part
	local part = Instance.new("Part")
	part.Name = "WeatherEffect"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = WeatherCfg.EFFECT_SIZE
	return part
end

local function createRainFallback(): Part
	local part = createFallbackPart()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RainParticle"
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 160, 220))
	emitter.Size = NumberSequence.new(0.05, 0.05)
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Rate = 500
	emitter.Speed = NumberRange.new(60, 80)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
	return part
end

local function createFrostFallback(): Part
	local part = createFallbackPart()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FrostParticle"
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 230, 255))
	emitter.Size = NumberSequence.new(0.15, 0.3)
	emitter.Lifetime = NumberRange.new(2, 4)
	emitter.Rate = 120
	emitter.Speed = NumberRange.new(8, 20)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
	return part
end

local function createThunderStormFallback(): Part
	local part = createRainFallback() -- 비 파티클 재사용
	-- 비 파티클 Rate 증가 (폭풍)
	local emitter = part:FindFirstChildWhichIsA("ParticleEmitter")
	if emitter then
		emitter.Rate = 800
		emitter.Speed = NumberRange.new(80, 100)
		emitter.Color = ColorSequence.new(Color3.fromRGB(100, 130, 180))
	end
	-- 번개용 PointLight
	local light = Instance.new("PointLight")
	light.Name = "ThunderLight"
	light.Color = Color3.fromRGB(200, 210, 255)
	light.Brightness = 0
	light.Range = 60
	light.Parent = part
	return part
end

-- 번개 깜빡임 루프
local function startLightFlicker(light: PointLight)
	lightFlickerThread = task.spawn(function()
		while light and light.Parent do
			-- 랜덤 간격으로 번개
			task.wait(math.random() * 4 + 2)
			if not light or not light.Parent then break end

			-- 번쩍 (2~3회 빠른 깜빡임)
			local flashes = math.random(2, 3)
			for _ = 1, flashes do
				light.Brightness = math.random(3, 8)
				task.wait(0.05 + math.random() * 0.05)
				light.Brightness = 0
				task.wait(0.03 + math.random() * 0.05)
			end
		end
	end)
end

----------------------------------------------------------------
-- 이펙트 관리
----------------------------------------------------------------

-- 기존 이펙트 페이드아웃 후 제거
local function clearEffects(onDone: (() -> ())?)
	if lightFlickerThread then
		task.cancel(lightFlickerThread)
		lightFlickerThread = nil
	end

	if not effectContainer or #effectContainer:GetChildren() == 0 then
		if effectContainer then
			effectContainer:Destroy()
			effectContainer = nil
		end
		if onDone then onDone() end
		return
	end

	-- 파티클 이미터 Enabled = false (새 파티클 중단)
	for _, child in effectContainer:GetChildren() do
		for _, emitter in child:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = false
			end
		end
	end

	-- 투명도 트윈으로 페이드아웃 (파트가 보이는 경우)
	local tweenInfo = TweenInfo.new(WeatherCfg.TRANSITION_TIME, Enum.EasingStyle.Linear)
	local tweensRemaining = 0

	for _, child in effectContainer:GetChildren() do
		if child:IsA("BasePart") and child.Transparency < 1 then
			tweensRemaining += 1
			local tween = TweenService:Create(child, tweenInfo, { Transparency = 1 })
			tween.Completed:Connect(function()
				tweensRemaining -= 1
				if tweensRemaining <= 0 then
					if effectContainer then
						effectContainer:Destroy()
						effectContainer = nil
					end
					if onDone then onDone() end
				end
			end)
			tween:Play()
		end
	end

	-- 모든 파트가 이미 투명이면 바로 제거
	if tweensRemaining == 0 then
		-- 파티클 잔여 시간 대기 후 제거
		task.delay(WeatherCfg.TRANSITION_TIME, function()
			if effectContainer then
				effectContainer:Destroy()
				effectContainer = nil
			end
			if onDone then onDone() end
		end)
	end
end

-- 새 이펙트 생성
local function spawnEffects(weatherType: string)
	if weatherType == "Sunny" then
		-- 맑음: 이펙트 없음
		return
	end

	effectContainer = Instance.new("Folder")
	effectContainer.Name = "WeatherEffects"
	effectContainer.Parent = workspace

	-- Weather 폴더에서 에셋 확인
	local assetFolder = weatherFolder:FindFirstChild(weatherType)
	local hasAssets = assetFolder and #assetFolder:GetChildren() > 0

	if hasAssets then
		-- 에셋 클론
		for _, child in assetFolder:GetChildren() do
			local clone = child:Clone()
			clone.Parent = effectContainer
		end
	else
		-- 폴백 파티클 생성
		local fallbackPart
		if weatherType == "Rain" then
			fallbackPart = createRainFallback()
		elseif weatherType == "Frost" then
			fallbackPart = createFrostFallback()
		elseif weatherType == "ThunderStorm" then
			fallbackPart = createThunderStormFallback()
			-- 번개 깜빡임 시작
			local light = fallbackPart:FindFirstChild("ThunderLight")
			if light then
				startLightFlicker(light)
			end
		end

		if fallbackPart then
			fallbackPart.Parent = effectContainer
			print("[WeatherVFX] 폴백 파티클 생성: " .. weatherType .. " | 파트크기=" .. tostring(fallbackPart.Size))
		else
			warn("[WeatherVFX] 폴백 파티클 생성 실패: " .. weatherType)
		end
	end

	-- ThunderStorm 에셋에 ThunderLight가 있으면 깜빡임 시작
	if hasAssets and weatherType == "ThunderStorm" then
		for _, child in effectContainer:GetDescendants() do
			if child:IsA("PointLight") and child.Name == "ThunderLight" then
				startLightFlicker(child)
				break
			end
		end
	end
end

-- 카메라 기준 위치 업데이트 (위쪽에서 넓게 덮음)
local function updateEffectPositions()
	if not effectContainer then return end

	-- 카메라 참조 갱신 (씬 전환 시 변경될 수 있음)
	camera = workspace.CurrentCamera
	if not camera then return end
	local camCFrame = camera.CFrame
	local targetCFrame = camCFrame * WeatherCfg.EFFECT_OFFSET

	for _, child in effectContainer:GetChildren() do
		if child:IsA("BasePart") then
			child.CFrame = targetCFrame
		elseif child:IsA("Model") then
			local primary = child.PrimaryPart
			if primary then
				child:PivotTo(targetCFrame)
			else
				-- PrimaryPart 없으면 첫 번째 BasePart 사용
				for _, desc in child:GetDescendants() do
					if desc:IsA("BasePart") then
						local offset = desc.CFrame:ToObjectSpace(child:GetPivot())
						child:PivotTo(targetCFrame * offset:Inverse())
						break
					end
				end
			end
		end
	end
end

----------------------------------------------------------------
-- 날씨 전환
----------------------------------------------------------------

local isTransitioning = false

local function onWeatherChanged(weatherType: string)
	if weatherType == currentWeather and effectContainer then return end
	currentWeather = weatherType
	print("[WeatherVFX] 날씨 전환:", weatherType)

	if isTransitioning then return end
	isTransitioning = true

	clearEffects(function()
		spawnEffects(weatherType)
		isTransitioning = false
	end)
end

----------------------------------------------------------------
-- 공개 API
----------------------------------------------------------------

function WeatherVFX.init()
	-- 렌더 루프: 매 프레임 이펙트 위치 업데이트
	if renderConnection then
		renderConnection:Disconnect()
	end
	renderConnection = RunService.RenderStepped:Connect(updateEffectPositions)

	-- 날씨 변경 이벤트 수신
	weatherChangedEvent.OnClientEvent:Connect(onWeatherChanged)

	-- 서버에서 현재 날씨 가져오기 (PlayerAdded 이벤트를 놓칠 수 있으므로)
	task.spawn(function()
		local weather = getWeatherFunc:InvokeServer()
		if weather then
			print("[WeatherVFX] 서버에서 현재 날씨 수신:", weather)
			onWeatherChanged(weather)
		end
	end)

	print("[WeatherVFX] 초기화 완료")
end

return WeatherVFX
