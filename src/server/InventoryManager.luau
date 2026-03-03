-- InventoryManager.luau
-- 서버 인벤토리 관리 (ModuleScript)
-- 플레이어별 인벤토리 CRUD

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local InventoryManager = {}

-- 플레이어별 인벤토리 저장소 { [Player]: { [key]: count } }
-- key = "itemName" (Lv1) 또는 "itemName:Lv2" (Lv2+)
local inventories = {}

-- 레벨 포함 키 생성/파싱
local function makeKey(itemName: string, level: number?): string
	local lvl = level or 1
	if lvl > 1 then
		return itemName .. ":Lv" .. lvl
	end
	return itemName
end

local function parseKey(key: string): (string, number)
	local name, lvl = key:match("^(.+):Lv(%d+)$")
	if name then
		return name, tonumber(lvl)
	end
	return key, 1
end

-- 플레이어 인벤토리 초기화 (저장된 데이터가 있으면 복원)
function InventoryManager.initPlayer(player: Player, savedInventory: { { itemName: string, count: number, level: number? } }?)
	inventories[player] = {}

	if savedInventory and #savedInventory > 0 then
		-- 저장된 인벤토리 복원
		for _, item in savedInventory do
			if item.itemName and item.count then
				local key = makeKey(item.itemName, item.level or 1)
				inventories[player][key] = item.count
			end
		end
	else
		-- 기본 인벤토리 지급
		for _, item in Constants.DEFAULT_INVENTORY do
			inventories[player][item.itemName] = item.count
		end
	end

	InventoryManager._notifyClient(player)
end

-- 플레이어 인벤토리 제거
function InventoryManager.removePlayer(player: Player)
	inventories[player] = nil
end

-- 인벤토리 조회 (배열 형태로 반환, 레벨 포함)
function InventoryManager.getInventory(player: Player): { { itemName: string, count: number, level: number } }
	local inv = inventories[player]
	if not inv then return {} end

	local result = {}
	for key, count in inv do
		if count > 0 then
			local itemName, level = parseKey(key)
			table.insert(result, { itemName = itemName, count = count, level = level })
		end
	end
	return result
end

-- 아이템 추가 (레벨 지원)
function InventoryManager.addItem(player: Player, itemName: string, amount: number?, level: number?)
	local inv = inventories[player]
	if not inv then return false end

	amount = amount or 1
	local key = makeKey(itemName, level)
	inv[key] = (inv[key] or 0) + amount

	InventoryManager._notifyClient(player)
	return true
end

-- 아이템 차감 (레벨 지원, 수량 부족 시 실패)
function InventoryManager.removeItem(player: Player, itemName: string, amount: number?, level: number?): boolean
	local inv = inventories[player]
	if not inv then return false end

	amount = amount or 1
	local key = makeKey(itemName, level)
	local current = inv[key] or 0
	if current < amount then return false end

	inv[key] = current - amount
	if inv[key] <= 0 then
		inv[key] = nil
	end

	InventoryManager._notifyClient(player)
	return true
end

-- 아이템 보유 여부 확인 (레벨 지원)
function InventoryManager.hasItem(player: Player, itemName: string, amount: number?, level: number?): boolean
	local inv = inventories[player]
	if not inv then return false end

	amount = amount or 1
	local key = makeKey(itemName, level)
	return (inv[key] or 0) >= amount
end

-- 저장용 데이터 반환
function InventoryManager.getSaveData(player: Player): { { itemName: string, count: number } }
	return InventoryManager.getInventory(player)
end

-- 클라이언트에 인벤토리 업데이트 전송
function InventoryManager._notifyClient(player: Player)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end

	local inventoryUpdate = remotes:FindFirstChild("InventoryUpdate")
	if inventoryUpdate then
		inventoryUpdate:FireClient(player, InventoryManager.getInventory(player))
	end
end

return InventoryManager
