-- 플레이어 마을: 플롯 배정, 건물 배치, 주민 배정, 생산, 수확, 판매, 건물 툴.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Buildings = require(Shared.Buildings)
local BuildingModels = require(Shared.BuildingModels)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Placement = require(Shared.Placement)
local Production = require(Shared.Production)
local Workforce = require(Shared.Workforce)
local PlayerStore = require(script.Parent.PlayerStore)
local Shop = require(script.Parent.Shop)

local HttpService = game:GetService("HttpService")

local CLOCK_TOWER_SPOT = Vector2.new(25, 0) -- 입구 반대쪽
local ENTRY_SPOT = Vector3.new(-34, 5, 0)
local SHOP_STAND_DISTANCE = 8
local WORKBENCH_NPC = "PetDealer" -- 작업대 모델이 들어오기 전 임시 위치
local FIRST_SALE_COINS = 1200 -- 튜토리얼 첫 판매 후 벌목장을 살 수 있게 보충
local HARVEST_MARGIN = 2.5
local MAX_HINT_ID_LENGTH = 32
local HARVEST_INTERVAL = 0.2
local SAVE_INTERVAL = 60
local RESIDENT_NAMES = {
	"Barley", "Bean", "Maple", "Sky", "Cloud", "Acorn", "Pine", "Star", "Oak", "Moon",
	"Rain", "Lantern", "Tofu", "Walnut", "Potato", "Berry", "Hazel", "Sunset", "Breeze", "Sprout",
}

local snapshotEvent = Net.event("Snapshot")
local placeResultEvent = Net.event("PlaceResult")
local harvestedEvent = Net.event("Harvested")
local placeEvent = Net.event("Place")
local sellEvent = Net.event("Sell")
local travelEvent = Net.event("Travel")
local buyEvent = Net.event("Buy")
local buyResultEvent = Net.event("BuyResult")
local craftEvent = Net.event("Craft")
local moveEvent = Net.event("Move")
local storeEvent = Net.event("Store")
local upgradeEvent = Net.event("Upgrade")
local editingEvent = Net.event("SetEditing")
local hintSeenEvent = Net.event("HintSeen")

local Village = {}

local villages = {} -- [Player] = village
local savesInFlight = 0

----------------------------------------------------------------
-- 프로필 도우미
----------------------------------------------------------------
local function nextSeq(profile): number
	local seq = profile.nextSeq
	profile.nextSeq += 1
	return seq
end

local function newRecord(profile, id: string)
	local seq = nextSeq(profile)
	local rec = { uid = "b" .. seq, id = id, seq = seq, level = 1 }
	local def = Buildings.ById[id]

	if def.kind == "Home" then
		rec.residents = {}
		for i = 1, def.residents do
			rec.residents[i] = RESIDENT_NAMES[math.random(#RESIDENT_NAMES)]
		end
	elseif def.kind == "Work" then
		rec.store = {}
		rec.progress = {}
	end

	return rec
end

local function placedList(village, exceptUid: string?)
	local list = {}
	for uid, rec in village.profile.placed do
		if uid ~= exceptUid then
			table.insert(list, rec)
		end
	end
	return list
end

----------------------------------------------------------------
-- 클라이언트 동기화
----------------------------------------------------------------
local function storedGroups(profile)
	local groups, order = {}, {}
	for _, rec in profile.stored do
		local key = rec.id .. ":" .. rec.level
		if not groups[key] then
			groups[key] = { id = rec.id, level = rec.level, count = 0, key = key }
			table.insert(order, groups[key])
		end
		groups[key].count += 1
	end
	return order, groups
end

local function pushSnapshot(village)
	local groups = storedGroups(village.profile)
	snapshotEvent:FireClient(village.player, {
		coins = village.profile.coins,
		resources = village.profile.resources,
		stored = groups,
		clockTower = village.profile.clockTower,
		shop = Shop.view(village.profile),
		tutorial = village.profile.tutorial,
		hints = village.profile.hints or {},
	})
end

local function toolLabel(group): string
	local def = Buildings.ById[group.id]
	local label = def.name
	if def.kind == "Work" and group.level > 1 then
		label ..= " Lv" .. group.level
	end
	if group.count > 1 then
		label ..= " x" .. group.count
	end
	return label
end

-- 같은 종류·레벨은 툴 하나로 묶는다
local function syncTools(village)
	local player = village.player
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local _, groups = storedGroups(village.profile)
	local seen = {}

	local containers = { backpack, player.Character }
	for _, container in containers do
		for _, tool in container:GetChildren() do
			local key = tool:IsA("Tool") and tool:GetAttribute("BuildingKey")
			if key then
				local group = groups[key]
				if group and not seen[key] then
					seen[key] = true
					tool.Name = toolLabel(group)
				else
					tool:Destroy()
				end
			end
		end
	end

	for key, group in groups do
		if not seen[key] then
			local tool = Instance.new("Tool")
			tool.Name = toolLabel(group)
			tool.RequiresHandle = false
			tool.CanBeDropped = false
			tool:SetAttribute("BuildingKey", key)
			tool:SetAttribute("BuildingId", group.id)
			tool:SetAttribute("BuildingLevel", group.level)
			tool.Parent = backpack
		end
	end
end

----------------------------------------------------------------
-- 건물 모델
----------------------------------------------------------------
local function refreshStoreAttributes(model: Model, rec)
	for _, itemId in Buildings.ById[rec.id].outputs do
		model:SetAttribute("Store_" .. itemId, rec.store[itemId] or 0)
	end
end

-- justBuilt: 방금 지은 건물이면 클라이언트가 건설 연출을 재생한다
-- 자원별 다음 생산까지 남은 초. 멈춘 자원은 -1이다.
local function refreshTimers(model: Model, rec, workers: number)
	for _, itemId in Buildings.ById[rec.id].outputs do
		local full = (rec.store[itemId] or 0) >= Production.capacityOf(itemId, rec.level)
		local remaining = -1
		if workers > 0 and not full then
			remaining = math.ceil((Items.ById[itemId].cycle - (rec.progress[itemId] or 0)) / workers)
		end
		model:SetAttribute("Next_" .. itemId, remaining)
	end
end

local function spawnModel(village, rec, justBuilt: boolean?)
	local cframe = Placement.toWorld(village.zone, rec.x, rec.z, rec.rot)
	local model = BuildingModels.build(rec.id, rec.level, cframe)

	model.Name = rec.uid
	model:SetAttribute("BuildingId", rec.id)
	model:SetAttribute("Level", rec.level)
	model:SetAttribute("X", rec.x)
	model:SetAttribute("Z", rec.z)
	model:SetAttribute("Rot", rec.rot)
	if justBuilt then
		model:SetAttribute("BuiltAt", workspace:GetServerTimeNow())
		model:SetAttribute("PartCount", BuildingModels.visiblePartCount(model))
	end

	if rec.store then
		refreshStoreAttributes(model, rec)
	end

	model.Parent = village.folder
	village.models[rec.uid] = model
end

local function reassignWorkers(village)
	local workers, jobs = Workforce.assign(village.profile.placed)
	village.workers = workers

	for uid, count in workers do
		village.models[uid]:SetAttribute("Workers", count)
	end
	for uid, homeJobs in jobs do
		village.models[uid]:SetAttribute("Jobs", HttpService:JSONEncode(homeJobs))
	end
end

local function respawnModel(village, rec)
	village.models[rec.uid]:Destroy()
	spawnModel(village, rec, true)
end

----------------------------------------------------------------
-- 튜토리얼 (단계는 Guide.luau의 STEPS와 순서가 같다)
----------------------------------------------------------------
local function countPlaced(profile, predicate): number
	local count = 0
	for _, rec in profile.placed do
		if predicate(rec) then
			count += 1
		end
	end
	return count
end

local function isHome(rec): boolean
	return Buildings.ById[rec.id].kind == "Home"
end

local function isFarm(rec): boolean
	return rec.id == "Farm"
end

local function isLumberyard(rec): boolean
	return rec.id == "Lumberyard"
end

local function farmHasStock(rec): boolean
	if rec.id == "Farm" then
		for _, amount in rec.store do
			if amount > 0 then
				return true
			end
		end
	end
	return false
end

local function tutorialStepDone(profile): boolean
	local step = profile.tutorial
	if step == 1 then
		return countPlaced(profile, isHome) >= 1
	elseif step == 2 then
		return countPlaced(profile, isFarm) >= 1
	elseif step == 3 then
		return profile.tutorialHarvested or countPlaced(profile, farmHasStock) >= 1
	elseif step == 4 then
		return profile.tutorialHarvested
	elseif step == 5 then
		return profile.tutorialSold
	elseif step == 6 then
		return profile.firstPurchaseDone
	end
	return countPlaced(profile, isLumberyard) >= 1 and countPlaced(profile, isHome) >= 2
end

local function updateTutorial(village)
	local profile = village.profile
	local changed = false

	while profile.tutorial and tutorialStepDone(profile) do
		local step = profile.tutorial
		changed = true

		if step == 5 and profile.coins < FIRST_SALE_COINS then
			profile.coins = FIRST_SALE_COINS
		elseif step == 6 then
			table.insert(profile.stored, newRecord(profile, "Cottage2"))
			syncTools(village)
		end

		profile.tutorial = if step < 7 then step + 1 else nil
	end

	if changed then
		pushSnapshot(village)
	end
end

----------------------------------------------------------------
-- 입장·퇴장
----------------------------------------------------------------
local function findFreePlot(): Model?
	local plots = workspace:WaitForChild("Plots"):GetChildren()
	table.sort(plots, function(a, b)
		return a.Name < b.Name
	end)
	for _, plot in plots do
		if not plot:GetAttribute("OwnerId") then
			return plot
		end
	end
	return nil
end

local function moveToVillage(village, character: Model)
	local cframe = village.zone.CFrame * CFrame.new(ENTRY_SPOT + Vector3.new(0, village.zone.Size.Y / 2, 0))
	character:PivotTo(CFrame.new(cframe.Position))
end

local function setupNewProfile(profile)
	local x, z = Placement.snap("ClockTower", CLOCK_TOWER_SPOT.X, CLOCK_TOWER_SPOT.Y, 0)
	local tower = newRecord(profile, "ClockTower")
	tower.x, tower.z, tower.rot = x, z, 0
	profile.placed[tower.uid] = tower

	table.insert(profile.stored, newRecord(profile, "Cottage2"))
	table.insert(profile.stored, newRecord(profile, "Farm"))
	profile.isNew = nil
	profile.tutorial = 1
end

function Village.onPlayerAdded(player: Player)
	local plot = findFreePlot()
	if not plot then
		warn("빈 플롯 없음: " .. player.Name)
		return
	end
	plot:SetAttribute("OwnerId", player.UserId) -- 로드 중 다른 플레이어가 잡지 못하게 먼저 점유

	local profile, canSave = PlayerStore.load(player)
	if not player.Parent then
		plot:SetAttribute("OwnerId", nil)
		return
	end

	if profile.isNew then
		setupNewProfile(profile)
	end

	local folder = Instance.new("Folder")
	folder.Name = "Village"
	folder.Parent = plot

	local village = {
		player = player,
		profile = profile,
		canSave = canSave,
		plot = plot,
		zone = plot:WaitForChild("BuildZone"),
		folder = folder,
		models = {},
		workers = {},
	}
	villages[player] = village

	for _, rec in profile.placed do
		spawnModel(village, rec)
	end
	reassignWorkers(village)

	-- 오프라인 생산 정산
	local elapsed = math.max(0, os.time() - profile.lastSeen)
	for uid, rec in profile.placed do
		if rec.store then
			Production.advance(rec, village.workers[uid] or 0, elapsed)
			refreshStoreAttributes(village.models[uid], rec)
		end
	end

	player.CharacterAdded:Connect(function(character)
		syncToolsAfterSpawn(village, character)
	end)
	if player.Character then
		syncToolsAfterSpawn(village, player.Character)
	end

	pushSnapshot(village)
end

function syncToolsAfterSpawn(village, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait()
	moveToVillage(village, character)
	syncTools(village)
	pushSnapshot(village)
end

function Village.onPlayerRemoving(player: Player)
	local village = villages[player]
	if not village then
		return
	end

	villages[player] = nil
	if village.canSave then
		savesInFlight += 1
		PlayerStore.save(player, village.profile)
		savesInFlight -= 1
	end

	village.folder:Destroy()
	village.plot:SetAttribute("OwnerId", nil)
end

-- 서버 종료 시 호출. 퇴장 처리에서 시작된 저장도 끝날 때까지 기다린다.
function Village.saveAll()
	for player, village in villages do
		if village.canSave then
			savesInFlight += 1
			task.spawn(function()
				PlayerStore.save(player, village.profile)
				savesInFlight -= 1
			end)
		end
	end
	while savesInFlight > 0 do
		task.wait()
	end
end

----------------------------------------------------------------
-- 배치
----------------------------------------------------------------
local function isFiniteNumber(value): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < 1e6
end

local function handlePlace(player: Player, id, level, x, z, rot)
	local village = villages[player]
	if not village then
		return
	end

	local def = typeof(id) == "string" and Buildings.ById[id]
	if not def or not isFiniteNumber(x) or not isFiniteNumber(z) or not isFiniteNumber(rot) then
		return
	end
	if rot % 1 ~= 0 or rot < 0 or rot > 3 then
		return
	end

	local index
	for i, rec in village.profile.stored do
		if rec.id == id and rec.level == level then
			index = i
			break
		end
	end
	if not index then
		placeResultEvent:FireClient(player, false, "You don't own this building")
		return
	end

	local snappedX, snappedZ = Placement.snap(id, x, z, rot)
	local size = village.zone.Size
	local ok, reason = Placement.check(id, snappedX, snappedZ, rot, size.X, size.Z, placedList(village))
	if not ok then
		placeResultEvent:FireClient(player, false, reason)
		return
	end

	local rec = table.remove(village.profile.stored, index)
	rec.x, rec.z, rec.rot = snappedX, snappedZ, rot
	rec.seq = nextSeq(village.profile) -- 거리가 같을 때 먼저 놓은 일터 우선
	village.profile.placed[rec.uid] = rec

	spawnModel(village, rec, true)
	reassignWorkers(village)
	syncTools(village)
	pushSnapshot(village)
	placeResultEvent:FireClient(player, true)
	updateTutorial(village)
end

local function ownedRecord(village, uid)
	local rec = typeof(uid) == "string" and village.profile.placed[uid]
	return rec or nil
end

-- 이동·회전. 저장량과 진행분은 그대로 두고 위치만 바꾼다.
local function handleMove(player: Player, uid, x, z, rot)
	local village = villages[player]
	local rec = village and ownedRecord(village, uid)
	if not rec or Buildings.ById[rec.id].kind == "Landmark" then
		return
	end
	if not isFiniteNumber(x) or not isFiniteNumber(z) or not isFiniteNumber(rot) then
		return
	end
	if rot % 1 ~= 0 or rot < 0 or rot > 3 then
		return
	end

	local snappedX, snappedZ = Placement.snap(rec.id, x, z, rot)
	local size = village.zone.Size
	local ok, reason = Placement.check(rec.id, snappedX, snappedZ, rot, size.X, size.Z, placedList(village, uid))
	if not ok then
		placeResultEvent:FireClient(player, false, reason)
		return
	end

	rec.x, rec.z, rec.rot = snappedX, snappedZ, rot
	respawnModel(village, rec)
	reassignWorkers(village)
	placeResultEvent:FireClient(player, true)
end

----------------------------------------------------------------
-- 수확
----------------------------------------------------------------
local function isHoldingBuildingTool(character: Model): boolean
	local tool = character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("BuildingKey") ~= nil
end

local function harvest(village, rec)
	local gained = {}
	for itemId, amount in rec.store do
		if amount > 0 then
			gained[itemId] = amount
			rec.store[itemId] = 0
			village.profile.resources[itemId] = (village.profile.resources[itemId] or 0) + amount
		end
	end

	if next(gained) then
		village.profile.tutorialHarvested = true
		refreshStoreAttributes(village.models[rec.uid], rec)
		pushSnapshot(village)
		harvestedEvent:FireClient(village.player, gained)
		updateTutorial(village)
	end
end

local function checkHarvest(village)
	local character = village.player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or village.editing or isHoldingBuildingTool(character) then
		return
	end

	local position = village.zone.CFrame:PointToObjectSpace(rootPart.Position)

	for _, rec in village.profile.placed do
		if rec.store then
			local width, depth = Placement.extent(rec.id, rec.rot)
			if
				math.abs(position.X - rec.x) <= width / 2 + HARVEST_MARGIN
				and math.abs(position.Z - rec.z) <= depth / 2 + HARVEST_MARGIN
			then
				harvest(village, rec)
			end
		end
	end
end

-- 보관. 일터에 남은 자원은 자동 회수한다.
local function handleStore(player: Player, uid)
	local village = villages[player]
	local rec = village and ownedRecord(village, uid)
	if not rec or Buildings.ById[rec.id].kind == "Landmark" then
		return
	end

	if rec.store then
		harvest(village, rec)
	end

	village.profile.placed[uid] = nil
	village.models[uid]:Destroy()
	village.models[uid] = nil
	rec.x, rec.z, rec.rot = nil, nil, nil
	table.insert(village.profile.stored, rec)

	reassignWorkers(village)
	syncTools(village)
	pushSnapshot(village)
end

----------------------------------------------------------------
-- 강화
----------------------------------------------------------------
local function handleUpgrade(player: Player, uid)
	local village = villages[player]
	local rec = village and ownedRecord(village, uid)
	if not rec then
		return
	end

	local profile = village.profile
	local def = Buildings.ById[rec.id]
	local cost

	if def.kind == "Landmark" then
		cost = Buildings.ClockTowerUpgrade[rec.level]
	elseif def.kind == "Work" then
		cost = def.upgrade[rec.level]
		if cost and rec.level >= profile.clockTower then
			buyResultEvent:FireClient(player, false, string.format("Requires Clock Tower Lv.%d", rec.level + 1))
			return
		end
	else
		return
	end

	if not cost then
		buyResultEvent:FireClient(player, false, "Already at max level")
		return
	end
	if profile.coins < cost then
		buyResultEvent:FireClient(player, false, "Not enough coins")
		return
	end

	profile.coins -= cost
	rec.level += 1
	if def.kind == "Landmark" then
		profile.clockTower = rec.level
	end

	respawnModel(village, rec)
	reassignWorkers(village)
	buyResultEvent:FireClient(player, true, string.format("%s upgraded to Lv.%d", def.name, rec.level))
	pushSnapshot(village)
end

----------------------------------------------------------------
-- 제작. 재료를 모두 확인한 뒤 한꺼번에 차감한다.
----------------------------------------------------------------
local function handleCraft(player: Player, id)
	local village = villages[player]
	local def = typeof(id) == "string" and Buildings.ById[id]
	if not village or not def or not def.recipe then
		return
	end

	local profile = village.profile
	if def.unlock > profile.clockTower then
		buyResultEvent:FireClient(player, false, string.format("Requires Clock Tower Lv.%d", def.unlock))
		return
	end

	for itemId, need in def.recipe do
		if (profile.resources[itemId] or 0) < need then
			buyResultEvent:FireClient(player, false, "Not enough materials")
			return
		end
	end

	for itemId, need in def.recipe do
		profile.resources[itemId] -= need
	end

	table.insert(profile.stored, newRecord(profile, id))
	syncTools(village)
	pushSnapshot(village)
	buyResultEvent:FireClient(player, true, "Crafted " .. def.name)
end

----------------------------------------------------------------
-- 판매
----------------------------------------------------------------
-- request: "all" 또는 { [itemId] = 수량 }
local function handleSell(player: Player, request)
	local village = villages[player]
	if not village then
		return
	end

	local resources = village.profile.resources
	local earned = 0

	local function sell(itemId, amount)
		local item = Items.ById[itemId]
		local owned = resources[itemId] or 0
		if item and typeof(amount) == "number" and amount % 1 == 0 and amount > 0 and amount <= owned then
			resources[itemId] = owned - amount
			earned += amount * item.price
		end
	end

	if request == "all" then
		for itemId, amount in table.clone(resources) do
			sell(itemId, amount)
		end
	elseif typeof(request) == "table" then
		for itemId, amount in request do
			sell(itemId, amount)
		end
	end

	if earned > 0 then
		village.profile.coins += earned
		village.profile.tutorialSold = true
		buyResultEvent:FireClient(player, true, "Sold for $" .. earned)
		pushSnapshot(village)
		updateTutorial(village)
	end
end

----------------------------------------------------------------
-- 상점
----------------------------------------------------------------
local function handleBuy(player: Player, id, cycle)
	local village = villages[player]
	if not village or typeof(id) ~= "string" or typeof(cycle) ~= "number" then
		return
	end

	local ok, reason = Shop.buy(village.profile, id, cycle)
	if ok then
		table.insert(village.profile.stored, newRecord(village.profile, id))
		syncTools(village)
		buyResultEvent:FireClient(player, true, "Purchased " .. Buildings.ById[id].name)
	else
		buyResultEvent:FireClient(player, false, reason)
	end
	pushSnapshot(village)
	updateTutorial(village)
end

local function addPrompt(npcName: string, promptName: string, action: string, object: string)
	local npcs = workspace:FindFirstChild("NPC")
	local npc = npcs and npcs:FindFirstChild(npcName)
	local part = npc and (npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true))
	if not part then
		warn("NPC를 찾을 수 없음: " .. npcName)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = promptName
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
end

----------------------------------------------------------------
-- 빠른 이동
----------------------------------------------------------------
local function handleTravel(player: Player, destination)
	local village = villages[player]
	local character = player.Character
	if not village or not character then
		return
	end

	if destination == "Home" then
		moveToVillage(village, character)
	elseif destination == "Shop" or destination == "Workbench" then
		local npcName = if destination == "Shop" then "BuildingDealer" else WORKBENCH_NPC
		local npc = workspace:FindFirstChild("NPC") and workspace.NPC:FindFirstChild(npcName)
		if npc then
			local pivot = npc:GetPivot()
			local stand = pivot.Position + pivot.LookVector * SHOP_STAND_DISTANCE + Vector3.new(0, 3, 0)
			if destination == "Workbench" then
				-- 작업대를 바라보며 도착한다
				character:PivotTo(CFrame.lookAt(stand, Vector3.new(pivot.Position.X, stand.Y, pivot.Position.Z)))
			else
				character:PivotTo(CFrame.new(stand))
			end
		end
	end
end

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------
function Village.start()
	BuildingModels.prepareServer()

	placeEvent.OnServerEvent:Connect(handlePlace)
	sellEvent.OnServerEvent:Connect(handleSell)
	travelEvent.OnServerEvent:Connect(handleTravel)
	buyEvent.OnServerEvent:Connect(handleBuy)
	craftEvent.OnServerEvent:Connect(handleCraft)
	moveEvent.OnServerEvent:Connect(handleMove)
	storeEvent.OnServerEvent:Connect(handleStore)
	upgradeEvent.OnServerEvent:Connect(handleUpgrade)
	hintSeenEvent.OnServerEvent:Connect(function(player, hintId)
		local village = villages[player]
		if village and typeof(hintId) == "string" and #hintId <= MAX_HINT_ID_LENGTH then
			village.profile.hints = village.profile.hints or {}
			village.profile.hints[hintId] = true
		end
	end)
	editingEvent.OnServerEvent:Connect(function(player, editing)
		local village = villages[player]
		if village then
			village.editing = editing == true
		end
	end)
	addPrompt("BuildingDealer", "ShopPrompt", "Shop", "Buildings")
	addPrompt(WORKBENCH_NPC, "WorkbenchPrompt", "Craft", "Workbench")

	Players.PlayerAdded:Connect(Village.onPlayerAdded)
	Players.PlayerRemoving:Connect(Village.onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(Village.onPlayerAdded, player)
	end

	-- 생산: 초당 1회
	task.spawn(function()
		while true do
			task.wait(1)
			for _, village in villages do
				for uid, rec in village.profile.placed do
					if rec.store then
						local workers = village.workers[uid] or 0
						if Production.advance(rec, workers, 1) then
							refreshStoreAttributes(village.models[uid], rec)
						end
						refreshTimers(village.models[uid], rec, workers)
					end
				end
				updateTutorial(village)
			end
		end
	end)

	-- 재입고: 주기가 바뀌면 모든 플레이어에게 새 매물을 보낸다
	task.spawn(function()
		local cycle = Shop.currentCycle()
		while true do
			task.wait(1)
			if Shop.currentCycle() ~= cycle then
				cycle = Shop.currentCycle()
				for _, village in villages do
					pushSnapshot(village)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(HARVEST_INTERVAL)
			for _, village in villages do
				checkHarvest(village)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			for player, village in villages do
				if village.canSave then
					task.spawn(PlayerStore.save, player, village.profile)
				end
			end
		end
	end)

	game:BindToClose(Village.saveAll)
end

return Village
