-- InventoryManager.luau
-- 서버 인벤토리 관리 (ModuleScript)
-- 플레이어별 인벤토리 CRUD

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local InventoryManager = {}

-- 플레이어별 인벤토리 저장소 { [Player]: { [itemName]: count } }
local inventories = {}

-- 플레이어 인벤토리 초기화
function InventoryManager.initPlayer(player: Player)
	inventories[player] = {}

	-- 기본 인벤토리 지급
	for _, item in Constants.DEFAULT_INVENTORY do
		inventories[player][item.itemName] = item.count
	end

	InventoryManager._notifyClient(player)
end

-- 플레이어 인벤토리 제거
function InventoryManager.removePlayer(player: Player)
	inventories[player] = nil
end

-- 인벤토리 조회 (배열 형태로 반환)
function InventoryManager.getInventory(player: Player): { { itemName: string, count: number } }
	local inv = inventories[player]
	if not inv then return {} end

	local result = {}
	for itemName, count in inv do
		if count > 0 then
			table.insert(result, { itemName = itemName, count = count })
		end
	end
	return result
end

-- 아이템 추가
function InventoryManager.addItem(player: Player, itemName: string, amount: number?)
	local inv = inventories[player]
	if not inv then return false end

	amount = amount or 1
	inv[itemName] = (inv[itemName] or 0) + amount

	InventoryManager._notifyClient(player)
	return true
end

-- 아이템 차감 (수량 부족 시 실패)
function InventoryManager.removeItem(player: Player, itemName: string, amount: number?): boolean
	local inv = inventories[player]
	if not inv then return false end

	amount = amount or 1
	local current = inv[itemName] or 0
	if current < amount then return false end

	inv[itemName] = current - amount
	if inv[itemName] <= 0 then
		inv[itemName] = nil
	end

	InventoryManager._notifyClient(player)
	return true
end

-- 아이템 보유 여부 확인
function InventoryManager.hasItem(player: Player, itemName: string, amount: number?): boolean
	local inv = inventories[player]
	if not inv then return false end

	amount = amount or 1
	return (inv[itemName] or 0) >= amount
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
