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

local Lighting = game:GetService("Lighting")
local camera = workspace.CurrentCamera

local WeatherVFX = {}

local currentWeather: string = "Sunny"
local effectContainer: Folder? = nil
local renderConnection: RBXScriptConnection? = nil
local lightFlickerThread: thread? = nil
local _appliedEnvInstances: { Instance } = {} -- Lighting/Terrain에 배치한 환경 인스턴스 추적

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
	emitter.Size = NumberSequence.new(0.08, 0.15)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Rate = 600
	emitter.Speed = NumberRange.new(60, 80)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SquashAmount = 3 -- 세로로 늘려서 빗줄기 형태
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

-- 환경 인스턴스 제거 (Lighting/Terrain에 배치한 것들)
local function clearEnvInstances()
	for _, inst in _appliedEnvInstances do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
	_appliedEnvInstances = {}
end

-- 기존 이펙트 페이드아웃 후 제거
local function clearEffects(onDone: (() -> ())?)
	if lightFlickerThread then
		task.cancel(lightFlickerThread)
		lightFlickerThread = nil
	end

	-- 환경 인스턴스 즉시 제거
	clearEnvInstances()

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

-- 환경 에셋을 올바른 부모에 배치 (Atmosphere/Sky → Lighting, Cloud → Terrain, ScreenSpaceEffect 자식 → Lighting)
local function applyEnvAssets(weatherType: string)
	local assetFolder = weatherFolder:FindFirstChild(weatherType)
	if not assetFolder then return end

	for _, child in assetFolder:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Sky") then
			-- 기존 동일 타입 제거 후 배치
			local existing = Lighting:FindFirstChildWhichIsA(child.ClassName)
			if existing then
				existing:Destroy()
			end
			local clone = child:Clone()
			clone.Parent = Lighting
			table.insert(_appliedEnvInstances, clone)

		elseif child:IsA("Clouds") then
			local terrain = workspace:FindFirstChildWhichIsA("Terrain")
			if terrain then
				local existing = terrain:FindFirstChildWhichIsA("Clouds")
				if existing then
					existing:Destroy()
				end
				local clone = child:Clone()
				clone.Parent = terrain
				table.insert(_appliedEnvInstances, clone)
			end

		elseif child:IsA("PostEffect") then
			local clone = child:Clone()
			clone.Parent = Lighting
			table.insert(_appliedEnvInstances, clone)
		end
	end
end

-- 새 이펙트 생성
local function spawnEffects(weatherType: string)
	-- 1. 환경 에셋 배치 (Atmosphere, Sky, Cloud, ScreenSpaceEffect → Lighting/Terrain)
	applyEnvAssets(weatherType)
	print("[WeatherVFX] spawnEffects 호출:", weatherType)

	if weatherType == "Sunny" then
		-- 맑음: 환경만 적용, 파티클 없음
		print("[WeatherVFX] Sunny → 파티클 스킵")
		return
	end

	-- 2. 카메라 앞 파티클 이펙트 (항상 폴백 파티클 사용)
	effectContainer = Instance.new("Folder")
	effectContainer.Name = "WeatherEffects"
	effectContainer.Parent = workspace

	-- Weather 폴더에서 BasePart/Model 에셋 확인
	local assetFolder = weatherFolder:FindFirstChild(weatherType)
	local hasParticleAssets = false
	print("[WeatherVFX] assetFolder:", tostring(assetFolder))

	if assetFolder then
		print("[WeatherVFX] assetFolder 자식 목록:")
		for _, child in assetFolder:GetChildren() do
			print("  →", child.Name, "(" .. child.ClassName .. ")", "IsBasePart:", child:IsA("BasePart"), "IsModel:", child:IsA("Model"))
			-- 환경 에셋은 스킵, ScreenSpaceEffect(Part)는 카메라 앞 파티클 에셋
			local isEnvAsset = child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("Clouds")
				or child:IsA("PostEffect")
			if not isEnvAsset and (child:IsA("BasePart") or child:IsA("Model")) then
				local clone = child:Clone()
				if clone:IsA("BasePart") then
					clone.Anchored = true
					clone.CanCollide = false
					clone.CanQuery = false
					clone.CanTouch = false
				end
				clone.Parent = effectContainer
				hasParticleAssets = true
				print("[WeatherVFX] 클론된 에셋:", clone.Name, "→", clone.Parent and clone.Parent.Name)
			end
		end
	end

	print("[WeatherVFX] hasParticleAssets:", hasParticleAssets)

	-- 폴백 파티클 항상 생성 (위에서 내리는 비/눈)
	do
		local fallbackPart
		if weatherType == "Rain" then
			fallbackPart = createRainFallback()
			print("[WeatherVFX] Rain 폴백 파티클 생성")
		elseif weatherType == "Frost" then
			fallbackPart = createFrostFallback()
			print("[WeatherVFX] Frost 폴백 파티클 생성")
		elseif weatherType == "ThunderStorm" then
			fallbackPart = createThunderStormFallback()
			print("[WeatherVFX] ThunderStorm 폴백 파티클 생성")
			local light = fallbackPart:FindFirstChild("ThunderLight")
			if light then
				startLightFlicker(light)
			end
		end

		if fallbackPart then
			fallbackPart.Parent = effectContainer
			print("[WeatherVFX] 폴백 파트 배치 완료, Size:", fallbackPart.Size, "Position:", fallbackPart.Position)
			local emitter = fallbackPart:FindFirstChildWhichIsA("ParticleEmitter")
			if emitter then
				print("[WeatherVFX] 파티클 이미터:", emitter.Name, "Rate:", emitter.Rate, "Size:", tostring(emitter.Size), "Enabled:", emitter.Enabled)
			else
				print("[WeatherVFX] 파티클 이미터 없음!")
			end
		else
			print("[WeatherVFX] 폴백 파트 nil! weatherType:", weatherType)
		end
	end

	-- ThunderStorm: ThunderLight 깜빡임 시작
	if weatherType == "ThunderStorm" then
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
	local camCF = camera.CFrame
	local camPos = camCF.Position
	-- 수평 방향(yaw)만 유지 (폴백 파티클용)
	local lookDir = camCF.LookVector
	local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
	if flatLook.Magnitude < 0.001 then
		flatLook = Vector3.new(0, 0, -1)
	end
	local yawCFrame = CFrame.lookAt(camPos, camPos + flatLook.Unit)
	local fallbackCFrame = yawCFrame * WeatherCfg.EFFECT_OFFSET
	local screenCFrame = camCF * CFrame.new(0, 0, -8)

	for _, child in effectContainer:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "ScreenSpaceEffect" then
				child.CFrame = screenCFrame
			else
				child.CFrame = fallbackCFrame
			end
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

----------------------------------------------------------------
-- 알림 UI
----------------------------------------------------------------

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local notifyGui = nil

local function showWeatherNotify(message: string)
	if not message or message == "" then return end

	-- 기존 알림 제거
	if notifyGui then
		notifyGui:Destroy()
		notifyGui = nil
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WeatherNotify"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = playerGui
	notifyGui = gui

	local frame = Instance.new("Frame")
	frame.Name = "NotifyFrame"
	frame.Size = UDim2.new(0, 400, 0, 60)
	frame.Position = UDim2.new(0.5, -200, 0, -70)
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 180, 220)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.Size = UDim2.new(1, -20, 1, -10)
	label.Position = UDim2.new(0, 10, 0, 5)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.Font = Enum.Font.GothamMedium
	label.Text = message
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = frame

	-- 슬라이드 인 애니메이션
	TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -200, 0, 20)
	}):Play()

	-- 5초 후 페이드아웃
	task.delay(5, function()
		if gui and gui.Parent then
			TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, -200, 0, -70)
			}):Play()
			task.delay(0.6, function()
				if gui and gui.Parent then
					gui:Destroy()
				end
				if notifyGui == gui then
					notifyGui = nil
				end
			end)
		end
	end)
end

local function onWeatherChanged(weatherType: string, message: string?)
	if weatherType == currentWeather and effectContainer then return end
	currentWeather = weatherType
	print("[WeatherVFX] 날씨 전환:", weatherType)

	-- 알림 메시지 표시
	if message and message ~= "" then
		showWeatherNotify(message)
	end

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
