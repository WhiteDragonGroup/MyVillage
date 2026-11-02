-- 건물이 지어지는 연출. 반짝이 속에서 파츠가 빛나며 날아와 조립된다.
-- 실제 건물은 제자리에 두고 이 클라이언트에서만 숨긴 뒤, 충돌 없는 복제본을 날린다.
-- 복제본은 출발할 때 하나씩 만들어 첫 프레임 부하를 나눈다.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BuildingModels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BuildingModels"))

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local BUILD_SPREAD = 1.1 -- 첫 파츠부터 마지막 파츠가 출발할 때까지(초)
local PART_FLIGHT = 0.45 -- 파츠 하나가 날아오는 시간(초)
local RANDOM_DELAY = 0.1
local DROP_HEIGHT = Vector2.new(5, 10)
local SCATTER_RADIUS = 5
local MAX_SPIN = math.rad(120)
local ARC_HEIGHT = 0.65
local RECENT_SECONDS = 2 -- 이보다 오래된 건물은 입장 시 복원으로 보고 재생하지 않는다

-- 모바일 값은 시작값이다. 실제 기기에서 측정해 조정한다.
local MAX_FLYING_PARTS = if IS_MOBILE then 100 else 250 -- 초과분은 날지 않고 차례가 되면 나타난다
local UPDATE_INTERVAL = if IS_MOBILE then 1 / 30 else 0
local SPARKLE_RATE = if IS_MOBILE then 12 else 40

local GLOW_COLOR = Color3.fromRGB(255, 225, 130)
local GLOW_FADE_START = 0.5 -- 이 지점부터 원래 색으로 돌아간다
local MATERIAL_SWITCH = 0.78 -- 이 지점에서 네온을 원래 재질로 바꾼다
local FADE_IN_SPEED = 5
local HEIGHT_BAND = 0.5 -- 같은 층으로 묶는 높이(스터드)
local SAME_FLOOR_JITTER = 0.2
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local ARRIVAL_TIMEOUT = 1 -- 파츠가 다 오지 않아도 이 시간이 지나면 시작한다

local BuildEffect = {}

local effectFolder
local active = {} -- [Model] = true

local function easeOutCubic(t: number): number
	local left = 1 - t
	return 1 - left * left * left
end

local function randomBetween(low: number, high: number): number
	return low + math.random() * (high - low)
end

-- 아래층부터 쌓되 같은 층 안의 순서는 섞는다
local function collectParts(visual: Instance)
	local entries = {}

	for _, part in visual:GetDescendants() do
		if BuildingModels.isVisiblePart(part) then
			local angle = math.random() * math.pi * 2
			local radius = math.sqrt(math.random()) * SCATTER_RADIUS
			local position = part.Position

			table.insert(entries, {
				part = part,
				target = part.CFrame,
				offset = Vector3.new(
					math.cos(angle) * radius,
					randomBetween(DROP_HEIGHT.X, DROP_HEIGHT.Y),
					math.sin(angle) * radius
				),
				spinX = randomBetween(-MAX_SPIN, MAX_SPIN),
				spinY = randomBetween(-MAX_SPIN, MAX_SPIN),
				spinZ = randomBetween(-MAX_SPIN, MAX_SPIN),
				sortKey = math.floor(position.Y / HEIGHT_BAND + 0.5) * HEIGHT_BAND
					+ math.random() * SAME_FLOOR_JITTER,
			})
		end
	end

	table.sort(entries, function(a, b)
		return a.sortKey < b.sortKey
	end)

	local count = #entries
	local flyingCount = math.min(count, MAX_FLYING_PARTS)

	for index, entry in entries do
		entry.delay = (index - 1) / math.max(count - 1, 1) * BUILD_SPREAD + math.random() * RANDOM_DELAY
		-- 날아오는 파츠를 건물 전체에 고르게 나눈다
		entry.flies = math.floor(index * flyingCount / count) > math.floor((index - 1) * flyingCount / count)
	end

	table.sort(entries, function(a, b)
		return a.delay < b.delay
	end)

	return entries
end

local function flightCFrame(entry, t: number): CFrame
	local left = 1 - easeOutCubic(t)
	local arc = math.sin(t * math.pi) * ARC_HEIGHT * (1 - t)
	local position = entry.target.Position + entry.offset * left + Vector3.new(0, arc, 0)

	return CFrame.new(position)
		* entry.target.Rotation
		* CFrame.Angles(entry.spinX * left, entry.spinY * left, entry.spinZ * left)
end

-- 모양과 표면만 남긴 충돌 없는 복제본. 복제할 수 없는 파츠는 nil을 돌려 그대로 나타나게 한다.
local function launchClone(entry): BasePart?
	local part = entry.part
	if not part.Parent or not part.Archivable then
		return nil
	end

	local clone = part:Clone()
	for _, child in clone:GetChildren() do
		local keep = child:IsA("DataModelMesh")
			or child:IsA("FaceInstance")
			or child:IsA("SurfaceAppearance")
		if not keep then
			child:Destroy()
		end
	end

	entry.color = part.Color
	entry.material = part.Material
	entry.transparency = part.Transparency

	clone.Anchored = true
	clone.CanCollide = false
	clone.CanTouch = false
	clone.CanQuery = false
	clone.CastShadow = false
	clone.Material = Enum.Material.Neon
	clone.Color = GLOW_COLOR
	clone.Transparency = 1
	clone.CFrame = flightCFrame(entry, 0)
	clone.Parent = effectFolder

	return clone
end

local function reveal(entry)
	entry.part.LocalTransparencyModifier = 0
	if entry.clone then
		entry.clone:Destroy()
		entry.clone = nil
	end
end

local function updateAppearance(entry, t: number)
	local clone = entry.clone
	clone.Transparency = entry.transparency + (1 - entry.transparency) * math.max(0, 1 - t * FADE_IN_SPEED)
	clone.Color = GLOW_COLOR:Lerp(entry.color, math.clamp((t - GLOW_FADE_START) / (1 - GLOW_FADE_START), 0, 1))
	if t >= MATERIAL_SWITCH and clone.Material ~= entry.material then
		clone.Material = entry.material
	end
end

local function makeSparkles(ground: CFrame): (Part, ParticleEmitter)
	local anchor = Instance.new("Part")
	anchor.Name = "BuildSparkles"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = ground + Vector3.new(0, 1, 0)
	anchor.Parent = effectFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(GLOW_COLOR)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(6, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Rate = SPARKLE_RATE
	emitter.Parent = anchor

	return anchor, emitter
end

-- 큰 건물은 파츠가 여러 프레임에 나눠 도착한다. 먼저 온 파츠가 보이지 않게 숨기면서 기다린다.
local function hideUntilArrived(model: Model, visual: Instance)
	local expected = model:GetAttribute("PartCount") or 0
	local arrived = 0

	local function hide(instance: Instance)
		if BuildingModels.isVisiblePart(instance) then
			instance.LocalTransparencyModifier = 1
			arrived += 1
		end
	end

	local connection = visual.DescendantAdded:Connect(hide)
	for _, descendant in visual:GetDescendants() do
		hide(descendant)
	end

	local deadline = os.clock() + ARRIVAL_TIMEOUT
	while arrived < expected and os.clock() < deadline and model.Parent do
		task.wait()
	end
	connection:Disconnect()
end

-- builtAt: 서버가 건물을 만든 시각. 입장 시 복원되는 건물에는 없다.
function BuildEffect.shouldPlay(builtAt: number?): boolean
	return builtAt ~= nil and workspace:GetServerTimeNow() - builtAt < RECENT_SECONDS
end

function BuildEffect.play(model: Model)
	local visual = model:FindFirstChild("Visual")
	local root = model.PrimaryPart
	if active[model] or not visual or not root then
		return
	end

	active[model] = true
	hideUntilArrived(model, visual)

	local entries = collectParts(visual)
	if #entries == 0 or not model.Parent then
		active[model] = nil
		return
	end

	local anchor, emitter = makeSparkles(root.CFrame)
	local flying = {}
	local nextIndex = 1
	local elapsed = 0
	local sinceUpdate = 0
	local connection

	local function finish(interrupted: boolean)
		connection:Disconnect()
		active[model] = nil

		for _, entry in entries do
			reveal(entry)
		end

		if interrupted then
			anchor:Destroy()
		else
			-- 이미 나온 입자는 수명이 다할 때까지 둔다
			emitter.Rate = 0
			task.delay(emitter.Lifetime.Max, function()
				anchor:Destroy()
			end)
		end
	end

	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		sinceUpdate += deltaTime

		if not model.Parent then
			finish(true)
			return
		end
		if sinceUpdate < UPDATE_INTERVAL then
			return
		end
		sinceUpdate = 0

		while nextIndex <= #entries and elapsed >= entries[nextIndex].delay do
			local entry = entries[nextIndex]
			nextIndex += 1

			entry.clone = if entry.flies then launchClone(entry) else nil
			if entry.clone then
				table.insert(flying, entry)
			else
				reveal(entry)
			end
		end

		local parts, cframes = {}, {}

		for index = #flying, 1, -1 do
			local entry = flying[index]
			local t = (elapsed - entry.delay) / PART_FLIGHT

			if t >= 1 then
				reveal(entry)
				flying[index] = flying[#flying]
				flying[#flying] = nil
			else
				updateAppearance(entry, t)
				table.insert(parts, entry.clone)
				table.insert(cframes, flightCFrame(entry, t))
			end
		end

		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end

		if nextIndex > #entries and #flying == 0 then
			finish(false)
		end
	end)
end

function BuildEffect.start()
	effectFolder = Instance.new("Folder")
	effectFolder.Name = "ClientBuildEffects"
	effectFolder.Parent = workspace
end

return BuildEffect
