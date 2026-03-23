-- ShopManager.luau
-- 서버 상점 관리: 재고 관리, 재입고 타이머, 구매 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local ShopCfg = BalanceConfig.Shop

local ShopManager = {}

-- 플레이어별 상점 상태 { [Player]: { stocks: {[itemName]: number}, lastRestock: number } }
local _shops = {}

-- 코인 함수 (외부 주입)
local _hasCoins = nil
local _spendCoins = nil

function ShopManager.setCurrencyFunctions(hasFn, spendFn)
	_hasCoins = hasFn
	_spendCoins = spendFn
end

-- 인벤토리 추가 함수 (외부 주입)
local _addItem = nil

function ShopManager.setInventoryFunction(addFn)
	_addItem = addFn
end

-- 플레이어 초기화
function ShopManager.initPlayer(player: Player)
	local stocks = {}
	for _, item in ShopCfg.SHOP_ITEMS do
		stocks[item.itemName] = item.maxStock
	end
	_shops[player] = {
		stocks = stocks,
		lastRestock = tick(),
	}
end

-- 플레이어 제거
function ShopManager.removePlayer(player: Player)
	_shops[player] = nil
end

-- 재입고 체크 + 수행
function ShopManager._checkRestock(player: Player)
	local shop = _shops[player]
	if not shop then return end

	local elapsed = tick() - shop.lastRestock
	if elapsed >= ShopCfg.RESTOCK_INTERVAL then
		-- 재고 리필
		for _, item in ShopCfg.SHOP_ITEMS do
			shop.stocks[item.itemName] = item.maxStock
		end
		shop.lastRestock = tick()
	end
end

-- 상점 데이터 조회 (클라이언트 전송용)
function ShopManager.getShopData(player: Player): ({ any }, number)
	ShopManager._checkRestock(player)

	local shop = _shops[player]
	if not shop then return {}, 0 end

	local result = {}
	for _, item in ShopCfg.SHOP_ITEMS do
		table.insert(result, {
			itemName = item.itemName,
			price = item.price,
			stock = shop.stocks[item.itemName] or 0,
			maxStock = item.maxStock,
		})
	end

	local restockTime = math.max(0, ShopCfg.RESTOCK_INTERVAL - (tick() - shop.lastRestock))
	return result, restockTime
end

-- 구매 처리
function ShopManager.buyItem(player: Player, itemName: string): (boolean, string)
	ShopManager._checkRestock(player)

	local shop = _shops[player]
	if not shop then return false, "상점 없음" end

	-- 상품 찾기
	local shopItem = nil
	for _, item in ShopCfg.SHOP_ITEMS do
		if item.itemName == itemName then
			shopItem = item
			break
		end
	end
	if not shopItem then return false, "존재하지 않는 상품" end

	-- 재고 확인
	local stock = shop.stocks[itemName] or 0
	if stock <= 0 then return false, "품절" end

	-- 코인 확인 + 차감
	if not _hasCoins or not _spendCoins then return false, "코인 시스템 미연결" end
	if not _hasCoins(player, shopItem.price) then return false, "코인 부족" end
	if not _spendCoins(player, shopItem.price) then return false, "코인 차감 실패" end

	-- 재고 차감
	shop.stocks[itemName] = stock - 1

	-- 인벤토리에 추가
	if _addItem then
		_addItem(player, itemName, 1, 1)
	end

	return true, "구매 완료"
end

-- 선물 구매 (구매자가 결제, 수신자에게 아이템 추가)
function ShopManager.buyGift(buyer: Player, itemName: string, receiver: Player): (boolean, string)
	ShopManager._checkRestock(buyer)

	local shop = _shops[buyer]
	if not shop then return false, "상점 없음" end

	local shopItem = nil
	for _, item in ShopCfg.SHOP_ITEMS do
		if item.itemName == itemName then
			shopItem = item
			break
		end
	end
	if not shopItem then return false, "존재하지 않는 상품" end

	local stock = shop.stocks[itemName] or 0
	if stock <= 0 then return false, "품절" end

	if not _hasCoins or not _spendCoins then return false, "코인 시스템 미연결" end
	if not _hasCoins(buyer, shopItem.price) then return false, "코인 부족" end
	if not _spendCoins(buyer, shopItem.price) then return false, "코인 차감 실패" end

	shop.stocks[itemName] = stock - 1

	-- 수신자 인벤토리에 추가
	if _addItem then
		_addItem(receiver, itemName, 1, 1)
	end

	return true, "선물 완료"
end

return ShopManager
