-- HarvestEffect.luau
-- 광산/농장 등 Work 건물에서 수확 시 플로팅 텍스트 + 사운드

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local harvestEffectEvent = remotes:WaitForChild("HarvestEffect")

local HarvestEffect = {}

-- 사운드는 사용자 게임 자산에 업로드한 ID로 교체 권장
-- 임시로 비활성화 (권한 없는 ID는 에러를 발생시킴)
local COIN_SOUND = ""
local GEM_SOUND = ""

local function playSound(soundId: string, volume: number?)
	if not soundId or soundId == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.6
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
	task.delay(3, function() if s.Parent then s:Destroy() end end)
end

-- 코인이 사방으로 펑 튀어오르는 이펙트
local function spawnCoinBurst(position: Vector3, count: number, color: Color3)
	for i = 1, count do
		local coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.2, 0.6, 0.6)
		coin.Material = Enum.Material.Neon
		coin.Color = color
		coin.Anchored = false
		coin.CanCollide = false
		coin.CanQuery = false
		coin.CanTouch = false
		coin.Massless = false
		coin.TopSurface = Enum.SurfaceType.Smooth
		coin.BottomSurface = Enum.SurfaceType.Smooth
		coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		coin.Parent = workspace

		-- 사방으로 랜덤 속도
		local angle = math.rad(math.random(0, 360))
		local horizPower = 8 + math.random() * 8
		coin.AssemblyLinearVelocity = Vector3.new(
			math.cos(angle) * horizPower,
			18 + math.random() * 6,
			math.sin(angle) * horizPower
		)
		coin.AssemblyAngularVelocity = Vector3.new(
			math.random(-15, 15),
			math.random(-15, 15),
			math.random(-15, 15)
		)

		-- 0.8초 후 페이드, 1.2초 후 destroy
		task.delay(0.8, function()
			if not coin.Parent then return end
			coin.Anchored = true
			local tween = TweenService:Create(
				coin,
				TweenInfo.new(0.4, Enum.EasingStyle.Linear),
				{ Transparency = 1 }
			)
			tween:Play()
		end)
		task.delay(1.2, function()
			if coin.Parent then coin:Destroy() end
		end)
	end
end

local function spawnFloatingText(position: Vector3, text: string, color: Color3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = workspace

	local bb = Instance.new("BillboardGui")
	bb.Name = "_HarvestFloat"
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.StudsOffset = Vector3.new(0, 0, 0)
	bb.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.Parent = bb

	-- 위로 떠오르며 페이드아웃
	local goalPart = { Position = position + Vector3.new(0, 4, 0) }
	local goalLabel = { TextTransparency = 1, TextStrokeTransparency = 1 }

	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, tweenInfo, goalPart):Play()
	TweenService:Create(label, tweenInfo, goalLabel):Play()

	task.delay(1.3, function() if part.Parent then part:Destroy() end end)
end

-- 수확 시 해당 건물을 순간적으로 밝은 초록색으로 하이라이트
local function flashGreen(target: Instance?)
	if not target then return end
	local adornee = target:FindFirstAncestorWhichIsA("Model") or target
	-- 중복 방지: 이미 하이라이트 중이면 제거 후 새로
	local existing = adornee:FindFirstChild("_HarvestHighlight")
	if existing then existing:Destroy() end

	local hl = Instance.new("Highlight")
	hl.Name = "_HarvestHighlight"
	hl.FillColor = Color3.fromRGB(80, 255, 120)
	hl.FillTransparency = 0.45
	hl.OutlineColor = Color3.fromRGB(150, 255, 180)
	hl.OutlineTransparency = 0
	hl.Adornee = adornee
	hl.Parent = adornee

	task.spawn(function()
		task.wait(0.15)
		if not hl.Parent then return end
		local tween = TweenService:Create(hl, TweenInfo.new(0.45), {
			FillTransparency = 1,
			OutlineTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		hl:Destroy()
	end)
end

function HarvestEffect.init()
	harvestEffectEvent.OnClientEvent:Connect(function(data)
		if not data or not data.position then return end

		-- 건물 초록 하이라이트
		if data.building then
			flashGreen(data.building)
		end

		if data.coins and data.coins > 0 then
			spawnFloatingText(data.position, "+$" .. data.coins, Color3.fromRGB(255, 230, 80))
			-- 금액 비례하여 동전 개수 (8~25개)
			local burstCount = math.clamp(math.floor(math.sqrt(data.coins) * 0.6), 8, 25)
			spawnCoinBurst(data.position, burstCount, Color3.fromRGB(255, 215, 50))
			playSound(COIN_SOUND, 0.5)
		end
		if data.gems and data.gems > 0 then
			-- 코인 텍스트와 겹치지 않도록 약간 위
			local pos = data.coins and data.coins > 0
				and (data.position + Vector3.new(0, 1.5, 0))
				or data.position
			spawnFloatingText(pos, "+" .. data.gems .. " Gems", Color3.fromRGB(120, 220, 255))
			spawnCoinBurst(data.position, math.min(data.gems * 2, 12), Color3.fromRGB(120, 220, 255))
			playSound(GEM_SOUND, 0.5)
		end
	end)
end

return HarvestEffect
