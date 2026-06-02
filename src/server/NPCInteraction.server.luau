-- NPCInteraction.server.luau
-- NPC ProximityPrompt: E키로 상점 열기

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- NPC 폴더 찾기
local npcFolder = workspace:FindFirstChild("NPC")
if not npcFolder then
	warn("[NPCInteraction] NPC folder not found")
	return
end

-- ProximityPrompt Remote 생성 또는 찾기
local openShopEvent = remotes:FindFirstChild("OpenShop")
if not openShopEvent then
	openShopEvent = Instance.new("RemoteEvent")
	openShopEvent.Name = "OpenShop"
	openShopEvent.Parent = remotes
end

-- NPC에 ProximityPrompt 붙이기
local function setupNPC(npc, shopType, actionText)
	-- HumanoidRootPart 또는 첫 번째 BasePart 찾기
	local targetPart = npc:FindFirstChild("HumanoidRootPart")
		or npc:FindFirstChildWhichIsA("BasePart", true)

	if not targetPart then
		warn("[NPCInteraction] No BasePart in " .. npc.Name)
		return
	end

	-- 기존 ProximityPrompt 제거
	local existing = targetPart:FindFirstChildWhichIsA("ProximityPrompt")
	if existing then existing:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = npc.Name
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = targetPart

	prompt.Triggered:Connect(function(player)
		openShopEvent:FireClient(player, shopType, npc.Name)
	end)

	print("[NPCInteraction] " .. npc.Name .. " → " .. shopType .. " prompt added")
end

-- BuildingDealer
local buildingDealer = npcFolder:FindFirstChild("BuildingDealer")
if buildingDealer then
	setupNPC(buildingDealer, "buildings", "Shop")
end

-- PetDealer
local petDealer = npcFolder:FindFirstChild("PetDealer")
if petDealer then
	setupNPC(petDealer, "eggs", "Shop")
end

-- NPC idle 애니메이션 재생 (ReplicatedStorage.Animations.{NPCName}.Idle).
-- Animation의 Looped=true 가정 → 한 번만 :Play() 호출.
local animationsFolder = ReplicatedStorage:FindFirstChild("Animations")

local function playIdleAnim(npc: Instance?)
	if not npc then return end
	local humanoid = npc:FindFirstChildWhichIsA("Humanoid", true)
	if not humanoid then
		warn("[NPCInteraction] " .. npc.Name .. ": Humanoid 없음, idle anim 스킵")
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	-- ReplicatedStorage.Animations.{NPCName}.Idle 위치에서 가져옴
	if not animationsFolder then
		warn("[NPCInteraction] ReplicatedStorage.Animations 폴더 없음")
		return
	end
	local npcAnimFolder = animationsFolder:FindFirstChild(npc.Name)
	local anim = npcAnimFolder and npcAnimFolder:FindFirstChild("Idle")
	if not anim or not anim:IsA("Animation") then
		warn("[NPCInteraction] " .. npc.Name .. ": Idle Animation 없음 (Animations." .. npc.Name .. ".Idle)")
		return
	end
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if ok and track then
		track:Play()
		print("[NPCInteraction] " .. npc.Name .. " idle anim 재생")
	else
		warn("[NPCInteraction] " .. npc.Name .. ": LoadAnimation 실패")
	end
end

playIdleAnim(buildingDealer)
playIdleAnim(petDealer)

print("[NPCInteraction] NPC interaction loaded")
