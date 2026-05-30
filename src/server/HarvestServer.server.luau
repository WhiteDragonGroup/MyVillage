-- HarvestServer.server.luau
-- Work 건물 터치 시 코인/보석 드롭 모델을 사방으로 흩뿌리고,
-- 플레이어가 가까이 가면 빨려들어와 흡수(addCoins/addGems + 클라 이펙트).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local serverScript = script.Parent
local CurrencyManager = require(serverScript:WaitForChild("CurrencyManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

----------------------------------------------------------------
-- 설정값 (튜닝 가능)
----------------------------------------------------------------
local HARVEST_COOLDOWN  = 2     -- 같은 건물에서 다음 수확까지 대기 (초)
local MAX_DROPS         = 12    -- 한 번 터치당 최대 드롭 개수 (액수가 많으면 청크로 분할)
local SCATTER_DURATION  = 0.5   -- 흩뿌려져 안착하기까지 (초)
local SCATTER_RADIUS    = { min = 3, max = 6 } -- 건물 중심 기준 흩어지는 거리 (stud)
local SCATTER_ARC_HEIGHT = 2.5  -- 포물선 정점 높이 (stud)
local PICKUP_RANGE      = 8     -- 플레이어 접근 시 빨려오기 시작 거리 (stud)
local FLY_SPEED         = 55    -- 흡수 비행 속도 (stud/s)
local DROP_LIFETIME     = 30    -- 안 먹으면 자동 소멸 (초)

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
-- VFX 자원 (Studio 전용 자산)
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

-- 모델 안 모든 파트 자세 정리 (anchored, no-collide, no-touch)
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

-- 금액을 chunks 개수로 나눠 각 청크 금액 배열 반환 (잔여는 앞쪽에 +1)
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

----------------------------------------------------------------
-- Drop Manager
----------------------------------------------------------------
-- _drops[model] = { state, player, kind, amount, startPos, target, scatterStart, settleTime, spawnTime, flyStartPos }
local _drops: { [Model]: any } = {}

local function spawnDrop(building: BasePart, kind: string, amount: number, player: Player)
	local template = (kind == "gem") and diamondTemplate or moneyTemplate
	if not template then return end

	local drop = template:Clone()
	drop.Name = (kind == "gem" and "DiamondDrop" or "MoneyDrop")
	local pp = setupDropParts(drop)
	if not pp then drop:Destroy(); return end

	-- 초기 위치: 건물 위쪽
	local startPos = building.Position + Vector3.new(0, building.Size.Y / 2 + 1.2, 0)

	-- 흩어질 목표(수평 랜덤 방향, 건물 바닥 = 지면에 안착)
	local angle = math.random() * math.pi * 2
	local dist = SCATTER_RADIUS.min + math.random() * (SCATTER_RADIUS.max - SCATTER_RADIUS.min)
	local groundY = building.Position.Y - building.Size.Y / 2
	local targetPos = Vector3.new(
		building.Position.X + math.cos(angle) * dist,
		groundY + 0.6, -- 지면에 살짝 떠 있게
		building.Position.Z + math.sin(angle) * dist
	)

	-- 드롭 식별용 어트리뷰트
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
	}
end

-- Heartbeat 업데이트: 모든 드롭의 상태 진행 / 픽업 처리
RunService.Heartbeat:Connect(function(dt)
	local now = tick()
	for drop, info in _drops do
		-- 파괴됨 → 정리
		if not drop or not drop.Parent then
			_drops[drop] = nil
			continue
		end
		-- 수명 초과 → 정리
		if now - info.spawnTime > DROP_LIFETIME then
			drop:Destroy()
			_drops[drop] = nil
			continue
		end
		-- 소유 플레이어 나감 → 정리
		if not info.player or not info.player.Parent then
			drop:Destroy()
			_drops[drop] = nil
			continue
		end

		if info.state == "scatter" then
			local t = math.min(1, (now - info.scatterStart) / SCATTER_DURATION)
			local pos = info.startPos:Lerp(info.target, t)
			-- 포물선 아치
			pos = pos + Vector3.new(0, math.sin(t * math.pi) * SCATTER_ARC_HEIGHT, 0)
			drop:PivotTo(CFrame.new(pos) * CFrame.Angles(0, t * math.pi * 2, 0))
			if t >= 1 then
				info.state = "settled"
				info.settleTime = now
			end
		elseif info.state == "settled" then
			-- 가만히 둥실 + 천천히 회전
			local elapsed = now - info.settleTime
			local bob = math.sin(elapsed * 3) * 0.15
			drop:PivotTo(CFrame.new(info.target + Vector3.new(0, bob, 0)) * CFrame.Angles(0, elapsed * 1.5, 0))

			-- 플레이어 접근 체크
			local character = info.player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				if (info.target - hrp.Position).Magnitude <= PICKUP_RANGE then
					info.state = "flying"
					info.flyStartPos = drop:GetPivot().Position
				end
			end
		elseif info.state == "flying" then
			local character = info.player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				-- 캐릭터 사라짐 → 다시 안착
				info.state = "settled"
				info.settleTime = now
				continue
			end
			local cur = drop:GetPivot().Position
			local target = hrp.Position + Vector3.new(0, 1.5, 0)
			local toTarget = target - cur
			local step = FLY_SPEED * dt
			if toTarget.Magnitude <= step or toTarget.Magnitude < 0.5 then
				-- 도착 → 흡수
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
				drop:PivotTo(CFrame.new(newPos) * CFrame.Angles(0, (now - info.scatterStart) * 4, 0))
			end
		end
	end
end)

-- 플레이어 퇴장 시 그 사람 소유 드롭 정리
Players.PlayerRemoving:Connect(function(player)
	for drop, info in _drops do
		if info.player == player then
			if drop.Parent then drop:Destroy() end
			_drops[drop] = nil
		end
	end
end)

----------------------------------------------------------------
-- 수확 트리거 (터치)
----------------------------------------------------------------
local function tryHarvest(player: Player, building: BasePart)
	-- 디바운스
	local now = tick()
	local lastKey = "_LastHarvest_" .. player.UserId
	local last = building:GetAttribute(lastKey) or 0
	if now - last < HARVEST_COOLDOWN then return end
	building:SetAttribute(lastKey, now)

	-- 소유자 확인
	local ownerId = building:GetAttribute("OwnerId")
	if ownerId and ownerId ~= player.UserId then return end

	local stored = building:GetAttribute("StoredCoins") or 0
	local gems = building:GetAttribute("StoredGems") or 0
	if stored <= 0 and gems <= 0 then return end

	-- 저장량 즉시 0 → 드롭으로 분할
	if stored > 0 then
		building:SetAttribute("StoredCoins", 0)
		for _, amt in splitAmount(stored, MAX_DROPS) do
			if amt > 0 then spawnDrop(building, "coin", amt, player) end
		end
	end
	if gems > 0 then
		building:SetAttribute("StoredGems", 0)
		for _, amt in splitAmount(gems, MAX_DROPS) do
			if amt > 0 then spawnDrop(building, "gem", amt, player) end
		end
	end

	-- 건물 초록 하이라이트(터치 피드백)만 트리거 (수치 텍스트는 픽업 시 별도)
	harvestEffectEvent:FireClient(player, {
		building = building,
	})
end

----------------------------------------------------------------
-- Touch 부착 (기존과 동일)
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

print("HarvestServer 로드됨 (드롭/픽업 시스템)")
