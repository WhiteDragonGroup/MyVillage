-- HarvestServer.server.luau
-- Work 건물 터치 → 저장량을 Money/Diamond 모델로 사방에 시차 토스 →
-- 플레이어 접근 시 빨려와 흡수 (코인 먼저, 다이아 나중·더 멀리·길게 노출).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local serverScript = script.Parent
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

----------------------------------------------------------------
-- 공통 설정
----------------------------------------------------------------
local HARVEST_COOLDOWN   = 2
local MAX_DROPS          = 12
local PICKUP_RANGE       = 8
local DROP_LIFETIME      = 30

-- 같은 종류 드롭 사이 시차 (각 드롭이 한 박자씩 튀어나오게)
local SPAWN_INTERVAL_MIN = 0.04
local SPAWN_INTERVAL_MAX = 0.10
-- 코인 다 토스한 뒤 다이아 시작 전 쉼 (다이아 등장 강조)
local KIND_SWITCH_PAUSE  = 0.30

-- 종류별 모션 설정 (다이아는 더 멀리·높이·길게 노출)
local DROP_CONFIG = {
	coin = {
		scatterRadius   = { min = 3, max = 5.5 },
		arcHeight       = 2.6,
		scatterDuration = 0.55,
		bounceHeight    = 0.35,
		bounceDuration  = 0.22,
		pickupDelay     = 0.15, -- 안착 후 픽업 가능까지
		flySpeed        = 55,
	},
	gem = {
		scatterRadius   = { min = 5.5, max = 10 },
		arcHeight       = 4.5,
		scatterDuration = 0.85,
		bounceHeight    = 0.6,
		bounceDuration  = 0.32,
		pickupDelay     = 0.75, -- 사이에서 시각적으로 잘 보이도록 길게
		flySpeed        = 50,
	},
}

----------------------------------------------------------------
-- Remotes
----------------------------------------------------------------
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local harvestEffectEvent = remotes:FindFirstChild("HarvestEffect")
if not harvestEffectEvent then
	harvestEffectEvent = Instance.new("RemoteEvent")
	harvestEffectEvent.Name = "HarvestEffect"
	harvestEffectEvent.Parent = remotes
end
local coinPickupEvent = remotes:FindFirstChild("CoinPickup")
if not coinPickupEvent then
	coinPickupEvent = Instance.new("RemoteEvent")
	coinPickupEvent.Name = "CoinPickup"
	coinPickupEvent.Parent = remotes
end

----------------------------------------------------------------
-- VFX 자원
----------------------------------------------------------------
local vfxFolder = ReplicatedStorage:WaitForChild("VFX")
local resourceFolder = vfxFolder:WaitForChild("Resource")
local moneyTemplate = resourceFolder:WaitForChild("Money")
local diamondTemplate = resourceFolder:WaitForChild("Diamond")

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function isWorkBuilding(building: BasePart): boolean
	local itemName = building:GetAttribute("ItemName")
	if not itemName then return false end
	local info = Constants.BUILDINGS[itemName]
	if not info or not info.types then return false end
	for _, t in info.types do
		if t == "Work" then return true end
	end
	return false
end

local function setupDropParts(model: Model)
	local first
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if not first then first = d end
		end
	end
	if not model.PrimaryPart and first then
		model.PrimaryPart = first
	end
	return model.PrimaryPart
end

local function splitAmount(amount: number, chunks: number): { number }
	chunks = math.max(1, math.min(chunks, amount))
	local base = math.floor(amount / chunks)
	local rem = amount - base * chunks
	local out = {}
	for i = 1, chunks do
		table.insert(out, base + (i <= rem and 1 or 0))
	end
	return out
end

-- 좀 더 균등한 랜덤 각 — i/N 기반 슬롯에 약간의 랜덤 오프셋
local function pickAngle(i: number, n: number): number
	local slot = (i - 1) / n
	local jitter = (math.random() - 0.5) * (1 / n)
	return (slot + jitter) * math.pi * 2
end

----------------------------------------------------------------
-- Drop Manager
----------------------------------------------------------------
local _drops: { [Model]: any } = {}

local function spawnDrop(building: BasePart, kind: string, amount: number, player: Player, spawnIndex: number, spawnCount: number)
	local template = (kind == "gem") and diamondTemplate or moneyTemplate
	local cfg = DROP_CONFIG[kind] or DROP_CONFIG.coin
	if not template then return end

	local drop = template:Clone()
	drop.Name = (kind == "gem" and "DiamondDrop" or "MoneyDrop")
	local pp = setupDropParts(drop)
	if not pp then drop:Destroy(); return end

	-- 시작 위치: 건물 위쪽
	local startPos = building.Position + Vector3.new(0, building.Size.Y / 2 + 1.2, 0)

	-- 흩어질 목표 (균등 분할 + 약간의 지터로 각자 다른 각도)
	local angle = pickAngle(spawnIndex, math.max(1, spawnCount))
	local dist = cfg.scatterRadius.min + math.random() * (cfg.scatterRadius.max - cfg.scatterRadius.min)
	local groundY = building.Position.Y - building.Size.Y / 2
	local targetPos = Vector3.new(
		building.Position.X + math.cos(angle) * dist,
		groundY + 0.6,
		building.Position.Z + math.sin(angle) * dist
	)

	drop:SetAttribute("Kind", kind)
	drop:SetAttribute("Amount", amount)
	drop:SetAttribute("OwnerId", player.UserId)
	drop:SetAttribute("IsHarvestDrop", true)

	drop:PivotTo(CFrame.new(startPos))
	drop.Parent = workspace

	_drops[drop] = {
		state = "scatter",
		player = player,
		kind = kind,
		amount = amount,
		startPos = startPos,
		target = targetPos,
		scatterStart = tick(),
		spawnTime = tick(),
		cfg = cfg,
		-- 회전 시드를 각자 다르게 (방향감 보너스)
		spinOffset = math.random() * math.pi * 2,
		spinSpeed = 1.2 + math.random() * 1.5,
	}
end

-- Easing helpers
local function easeOutCubic(t)
	t = math.clamp(t, 0, 1)
	local u = 1 - t
	return 1 - u * u * u
end

-- Heartbeat 업데이트
RunService.Heartbeat:Connect(function(dt)
	local now = tick()
	for drop, info in _drops do
		if not drop or not drop.Parent then
			_drops[drop] = nil
			continue
		end
		if now - info.spawnTime > DROP_LIFETIME then
			drop:Destroy()
			_drops[drop] = nil
			continue
		end
		if not info.player or not info.player.Parent then
			drop:Destroy()
			_drops[drop] = nil
			continue
		end

		local cfg = info.cfg

		if info.state == "scatter" then
			local elapsed = now - info.scatterStart
			local t = math.min(1, elapsed / cfg.scatterDuration)
			-- 수평은 자연스럽게 감속해서 도착 (easeOutCubic)
			local te = easeOutCubic(t)
			local pos = info.startPos:Lerp(info.target, te)
			-- 포물선 아치 (대칭 sin)
			pos = pos + Vector3.new(0, math.sin(t * math.pi) * cfg.arcHeight, 0)
			drop:PivotTo(CFrame.new(pos) * CFrame.Angles(0, info.spinOffset + t * info.spinSpeed * math.pi * 2, 0))
			if t >= 1 then
				info.state = "bounce"
				info.bounceStart = now
			end
		elseif info.state == "bounce" then
			local elapsed = now - info.bounceStart
			local t = math.min(1, elapsed / cfg.bounceDuration)
			-- 작은 바운스: 0→peak→0 (sin)
			local by = math.sin(t * math.pi) * cfg.bounceHeight
			drop:PivotTo(CFrame.new(info.target + Vector3.new(0, by, 0))
				* CFrame.Angles(0, info.spinOffset + t * info.spinSpeed * math.pi, 0))
			if t >= 1 then
				info.state = "settled"
				info.settleTime = now
			end
		elseif info.state == "settled" then
			local elapsed = now - info.settleTime
			-- 천천히 둥실 + 미세 회전
			local bob = math.sin(elapsed * 3) * 0.12
			drop:PivotTo(CFrame.new(info.target + Vector3.new(0, bob, 0))
				* CFrame.Angles(0, info.spinOffset + elapsed * 1.0, 0))
			-- 픽업 가능 대기 후 플레이어 근접 체크
			if elapsed >= cfg.pickupDelay then
				local character = info.player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp and (info.target - hrp.Position).Magnitude <= PICKUP_RANGE then
					info.state = "flying"
					info.flyStartPos = drop:GetPivot().Position
				end
			end
		elseif info.state == "flying" then
			local character = info.player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				info.state = "settled"
				info.settleTime = now
				continue
			end
			local cur = drop:GetPivot().Position
			local target = hrp.Position + Vector3.new(0, 1.5, 0)
			local toTarget = target - cur
			local step = cfg.flySpeed * dt
			if toTarget.Magnitude <= step or toTarget.Magnitude < 0.5 then
				drop:Destroy()
				_drops[drop] = nil
				if info.kind == "gem" then
					CurrencyManager.addGems(info.player, info.amount)
				else
					CurrencyManager.addCoins(info.player, info.amount)
				end
				coinPickupEvent:FireClient(info.player, {
					kind = info.kind,
					amount = info.amount,
				})
			else
				local newPos = cur + toTarget.Unit * step
				drop:PivotTo(CFrame.new(newPos)
					* CFrame.Angles(0, info.spinOffset + (now - info.scatterStart) * 4, 0))
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for drop, info in _drops do
		if info.player == player then
			if drop.Parent then drop:Destroy() end
			_drops[drop] = nil
		end
	end
end)

----------------------------------------------------------------
-- 수확 트리거 (터치) — 시차 토스 (코인 먼저 → 다이아 나중)
----------------------------------------------------------------
local function tryHarvest(player: Player, building: BasePart)
	local now = tick()
	local lastKey = "_LastHarvest_" .. player.UserId
	local last = building:GetAttribute(lastKey) or 0
	if now - last < HARVEST_COOLDOWN then return end
	building:SetAttribute(lastKey, now)

	local ownerId = building:GetAttribute("OwnerId")
	if ownerId and ownerId ~= player.UserId then return end

	local stored = building:GetAttribute("StoredCoins") or 0
	local gems = building:GetAttribute("StoredGems") or 0
	if stored <= 0 and gems <= 0 then return end

	-- 즉시 저장량 0 (남은 처리는 비동기 스폰)
	if stored > 0 then building:SetAttribute("StoredCoins", 0) end
	if gems > 0 then building:SetAttribute("StoredGems", 0) end

	-- 코인 청크
	local coinAmounts = (stored > 0) and splitAmount(stored, MAX_DROPS) or {}
	local gemAmounts  = (gems > 0)   and splitAmount(gems, MAX_DROPS)  or {}

	-- 시퀀스 토스 (시차)
	task.spawn(function()
		local n = #coinAmounts
		for i, amt in coinAmounts do
			if amt > 0 then
				spawnDrop(building, "coin", amt, player, i, n)
			end
			task.wait(SPAWN_INTERVAL_MIN + math.random() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN))
		end
		if #gemAmounts > 0 then
			task.wait(KIND_SWITCH_PAUSE)
			local gn = #gemAmounts
			for i, amt in gemAmounts do
				if amt > 0 then
					spawnDrop(building, "gem", amt, player, i, gn)
				end
				task.wait(SPAWN_INTERVAL_MIN + math.random() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN))
			end
		end
	end)

	-- 건물 초록 하이라이트 (터치 피드백)
	harvestEffectEvent:FireClient(player, { building = building })
end

----------------------------------------------------------------
-- Touch 부착
----------------------------------------------------------------
local function attachTouchHandler(building: BasePart)
	if building:GetAttribute("_HarvestWired") then return end
	building:SetAttribute("_HarvestWired", true)

	local function onTouched(otherPart)
		local character = otherPart and otherPart.Parent
		if not character then return end
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		tryHarvest(player, building)
	end

	building.Touched:Connect(onTouched)
	local model = building:FindFirstAncestorWhichIsA("Model")
	if model then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= building and not part:GetAttribute("IsCollisionBox") then
				part.Touched:Connect(onTouched)
			end
		end
		model.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and not d:GetAttribute("IsCollisionBox") then
				d.Touched:Connect(onTouched)
			end
		end)
	end
end

local function scanBuildings()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return end
	for _, desc in plotsFolder:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") and isWorkBuilding(desc) then
			attachTouchHandler(desc)
		end
	end
end

scanBuildings()
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") and isWorkBuilding(desc) then
		attachTouchHandler(desc)
	end
end)

print("HarvestServer 로드됨 (드롭/픽업 + 시차 토스 + 바운스)")
