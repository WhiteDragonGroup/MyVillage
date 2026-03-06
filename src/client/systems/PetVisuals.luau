-- PetVisuals.luau
-- 펫 이름표 BillboardGui, 상태별 VFX (땀/Zzz/말풍선/레벨업)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local petUpdateEvent = remotes:WaitForChild("PetUpdate")

local PetVisuals = {}

local _activeLabels = {} -- { [BasePart]: BillboardGui }
local _activeVFX = {}    -- { [BasePart]: { [vfxName]: Instance } }

----------------------------------------------------------------
-- 상태별 표시 설정
----------------------------------------------------------------
local STATUS_MAP = {
	Working   = { text = "작업중",   color = Color3.fromRGB(100, 220, 100) },
	Fatigued  = { text = "피곤...",  color = Color3.fromRGB(220, 200, 100) },
	Resting   = { text = "휴식중",  color = Color3.fromRGB(100, 180, 255) },
	Wandering = { text = "산책중",  color = Color3.fromRGB(180, 180, 180) },
	Chatting  = { text = "대화중",  color = Color3.fromRGB(255, 200, 100) },
	Sleeping  = { text = "수면중",  color = Color3.fromRGB(150, 150, 200) },
	Assigned  = { text = "건설중...", color = Color3.fromRGB(100, 220, 100) },
	Idle      = { text = "대기중",  color = Color3.fromRGB(180, 180, 180) },
}

----------------------------------------------------------------
-- VFX 생성 헬퍼
----------------------------------------------------------------

local function clearVFX(pet: BasePart, vfxName: string)
	local vfxMap = _activeVFX[pet]
	if not vfxMap then return end
	local existing = vfxMap[vfxName]
	if existing and existing.Parent then
		existing:Destroy()
	end
	vfxMap[vfxName] = nil
end

local function clearAllVFX(pet: BasePart)
	local vfxMap = _activeVFX[pet]
	if not vfxMap then return end
	for name, inst in vfxMap do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
	_activeVFX[pet] = nil
end

-- 땀 VFX (Fatigued) — 작은 물방울 파티클
local function createSweatVFX(pet: BasePart)
	clearVFX(pet, "sweat")

	local attachment = Instance.new("Attachment")
	attachment.Name = "SweatAttachment"
	attachment.Position = Vector3.new(0, pet.Size.Y / 2 + 0.5, 0)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SweatVFX"
	emitter.Texture = "rbxassetid://241685484" -- 기본 파티클
	emitter.Color = ColorSequence.new(Color3.fromRGB(100, 180, 255))
	emitter.Size = NumberSequence.new(0.15, 0.05)
	emitter.Lifetime = NumberRange.new(0.5, 1.0)
	emitter.Rate = 4
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment

	attachment.Parent = pet

	if not _activeVFX[pet] then _activeVFX[pet] = {} end
	_activeVFX[pet]["sweat"] = attachment
end

-- Zzz VFX (Sleeping) — "Z" 텍스트 파티클
local function createZzzVFX(pet: BasePart)
	clearVFX(pet, "zzz")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZzzVFX"
	billboard.Size = UDim2.new(0, 40, 0, 20)
	billboard.StudsOffset = Vector3.new(0.8, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = pet

	local label = Instance.new("TextLabel")
	label.Name = "ZzzLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(180, 180, 230)
	label.TextStrokeColor3 = Color3.fromRGB(50, 50, 80)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Text = "Zzz"
	label.Parent = billboard

	billboard.Parent = pet

	-- 부드러운 위아래 흔들림
	task.spawn(function()
		local baseOffset = 2.5
		local t = 0
		while billboard and billboard.Parent do
			t = t + task.wait()
			billboard.StudsOffset = Vector3.new(0.8, baseOffset + math.sin(t * 2) * 0.3, 0)
		end
	end)

	if not _activeVFX[pet] then _activeVFX[pet] = {} end
	_activeVFX[pet]["zzz"] = billboard
end

-- 말풍선 VFX (Chatting) — "..." 텍스트
local function createChatBubbleVFX(pet: BasePart)
	clearVFX(pet, "chat")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ChatBubbleVFX"
	billboard.Size = UDim2.new(0, 50, 0, 24)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = pet

	local bg = Instance.new("Frame")
	bg.Name = "BubbleBG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bg.BackgroundTransparency = 0.2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg

	local label = Instance.new("TextLabel")
	label.Name = "ChatText"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(60, 60, 60)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Text = "..."
	label.Parent = bg

	bg.Parent = billboard
	billboard.Parent = pet

	if not _activeVFX[pet] then _activeVFX[pet] = {} end
	_activeVFX[pet]["chat"] = billboard
end

-- 레벨업 VFX — 반짝 이펙트
local function createLevelUpVFX(pet: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.Name = "LevelUpAttachment"

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LevelUpVFX"
	emitter.Texture = "rbxassetid://241685484"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 50)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.0)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = attachment

	attachment.Parent = pet
	emitter:Emit(20)

	-- 2초 후 자동 제거
	task.delay(2, function()
		if attachment and attachment.Parent then
			attachment:Destroy()
		end
	end)
end

----------------------------------------------------------------
-- 수면 외형 (투명도 변경)
----------------------------------------------------------------
local function setSleepingAppearance(pet: BasePart, sleeping: boolean)
	if sleeping then
		pet.Transparency = 0.2
	else
		pet.Transparency = 0
	end
end

----------------------------------------------------------------
-- 상태 VFX 업데이트 (상태 변경 시 호출)
----------------------------------------------------------------
local function updateStateVFX(pet: BasePart, newState: string)
	-- 기존 VFX 정리
	clearVFX(pet, "sweat")
	clearVFX(pet, "zzz")
	clearVFX(pet, "chat")

	-- 수면 외형 복원
	setSleepingAppearance(pet, false)

	-- 새 VFX 적용
	if newState == "Fatigued" then
		createSweatVFX(pet)
	elseif newState == "Sleeping" then
		createZzzVFX(pet)
		setSleepingAppearance(pet, true)
	elseif newState == "Chatting" then
		createChatBubbleVFX(pet)
	end
end

----------------------------------------------------------------
-- 이름표 생성
----------------------------------------------------------------
local function createNameTag(pet: BasePart): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PetNameTag"
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = pet
	billboard.Parent = pet

	-- 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = pet:GetAttribute("PetName") or "펫"
	nameLabel.Parent = billboard

	-- 상태 라벨
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0, 14)
	statusLabel.Position = UDim2.new(0, 0, 0, 15)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	statusLabel.TextStrokeTransparency = 0.5
	statusLabel.TextSize = 10
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Text = ""
	statusLabel.Parent = billboard

	-- 레벨 라벨
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, 0, 0, 12)
	levelLabel.Position = UDim2.new(0, 0, 0, 28)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	levelLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	levelLabel.TextStrokeTransparency = 0.5
	levelLabel.TextSize = 9
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Text = "Lv." .. (pet:GetAttribute("PetLevel") or 1)
	levelLabel.Parent = billboard

	return billboard
end

----------------------------------------------------------------
-- 상태 업데이트
----------------------------------------------------------------
local function updateStatus(billboard: BillboardGui, petState: string)
	local statusLabel = billboard:FindFirstChild("StatusLabel")
	if not statusLabel then return end

	local info = STATUS_MAP[petState]
	if info then
		statusLabel.Text = info.text
		statusLabel.TextColor3 = info.color
	else
		statusLabel.Text = ""
		statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end
end

local function updateLevel(billboard: BillboardGui, level: number)
	local levelLabel = billboard:FindFirstChild("LevelLabel")
	if levelLabel then
		levelLabel.Text = "Lv." .. level
	end
end

----------------------------------------------------------------
-- 펫 감시
----------------------------------------------------------------
function PetVisuals.watchPet(pet: BasePart)
	if _activeLabels[pet] then return end

	local billboard = createNameTag(pet)
	_activeLabels[pet] = billboard

	-- 초기 상태 적용
	local currentState = pet:GetAttribute("PetState") or "Idle"
	updateStatus(billboard, currentState)
	updateStateVFX(pet, currentState)

	-- PetState 변경 감지
	pet:GetAttributeChangedSignal("PetState"):Connect(function()
		local newState = pet:GetAttribute("PetState") or "Idle"
		updateStatus(billboard, newState)
		updateStateVFX(pet, newState)
	end)

	-- AssignedBuildingId 변경 감지 (기존 호환)
	pet:GetAttributeChangedSignal("AssignedBuildingId"):Connect(function()
		local assignedId = pet:GetAttribute("AssignedBuildingId") or ""
		if assignedId ~= "" then
			updateStatus(billboard, "Assigned")
		end
	end)

	-- PetLevel 변경 감지
	pet:GetAttributeChangedSignal("PetLevel"):Connect(function()
		local level = pet:GetAttribute("PetLevel") or 1
		updateLevel(billboard, level)
	end)
end

----------------------------------------------------------------
-- 플롯 내 펫 스캔
----------------------------------------------------------------
function PetVisuals.scanPlot(plot: Instance)
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("PetId") then
			PetVisuals.watchPet(child)
		end
	end

	plot.DescendantAdded:Connect(function(child)
		if child:IsA("BasePart") and child:GetAttribute("PetId") then
			task.wait()
			PetVisuals.watchPet(child)
		end
	end)

	plot.DescendantRemoving:Connect(function(child)
		if _activeLabels[child] then
			_activeLabels[child]:Destroy()
			_activeLabels[child] = nil
		end
		clearAllVFX(child)
	end)
end

----------------------------------------------------------------
-- PetUpdate 이벤트 수신 (레벨업 VFX)
----------------------------------------------------------------
function PetVisuals.init()
	petUpdateEvent.OnClientEvent:Connect(function(eventType, data)
		if eventType == "levelup" then
			-- 레벨업 VFX를 해당 펫 모델에 적용
			local petId = data.petId
			for pet, _ in _activeLabels do
				if pet:IsA("BasePart") and pet:GetAttribute("PetId") == petId then
					createLevelUpVFX(pet)
					break
				end
			end
		end
	end)
end

----------------------------------------------------------------
-- 정리
----------------------------------------------------------------
function PetVisuals.cleanup()
	for pet, billboard in _activeLabels do
		billboard:Destroy()
		clearAllVFX(pet)
	end
	_activeLabels = {}
	_activeVFX = {}
end

return PetVisuals
