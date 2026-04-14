-- InventoryUI.luau
-- 디자인 UI 사용 (StarterGui/BuildMode/OwnedBuildings)
-- ScrollingFrame(Slot), 카테고리(All/Decorations/RestSpots/Supports/WorkSpots)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local InventoryUI = {}

local ownedFrame = nil
local scrollingFrame = nil
local slotTemplate = nil
local _onItemSelected = nil
local _onExit = nil
local _visible = false
local _inventory = {}
local _activeFilter = "All"

-- 디자인 카테고리 → 게임 유형 매핑
local FILTER_MAP = {
	All = "전체",
	WorkSpots = "일터",
	RestSpots = "쉼터",
	Supports = "지원",
	Decorations = "장식",
}

function InventoryUI.init(onItemSelected: (string, number) -> (), onExit: (() -> ())?)
	_onItemSelected = onItemSelected
	_onExit = onExit

	local buildModeGui = playerGui:WaitForChild("BuildMode", 10)
	if not buildModeGui then
		warn("[InventoryUI] BuildMode ScreenGui를 찾을 수 없음")
		return
	end

	ownedFrame = buildModeGui:FindFirstChild("OwnedBuildings")
	if not ownedFrame then
		warn("[InventoryUI] OwnedBuildings를 찾을 수 없음")
		return
	end

	ownedFrame.Visible = false

	-- ScrollingFrame 찾기
	scrollingFrame = ownedFrame:FindFirstChild("ScrollingFrame")

	-- Slot 템플릿 저장 후 숨기기
	if scrollingFrame then
		for _, child in scrollingFrame:GetChildren() do
			if child.Name == "Slot" and child:IsA("GuiObject") then
				if not slotTemplate then
					slotTemplate = child:Clone()
				end
				child.Visible = false
			end
		end
	end

	-- 카테고리 버튼 연결
	for filterName, _ in FILTER_MAP do
		local catBtn = ownedFrame:FindFirstChild(filterName)
		if catBtn and (catBtn:IsA("GuiButton") or catBtn:IsA("ImageButton")) then
			catBtn.MouseButton1Click:Connect(function()
				_activeFilter = filterName
				InventoryUI._renderSlots()
			end)
		end
	end

	-- CategoryText 업데이트
	local catText = ownedFrame:FindFirstChild("CategoryText")
	if catText then
		catText.Text = "All"
	end
end

function InventoryUI.updateInventory(inventory: { any })
	_inventory = inventory
	if _visible then
		InventoryUI._renderSlots()
	end
end

function InventoryUI._renderSlots()
	if not scrollingFrame then return end

	-- 기존 동적 슬롯 제거
	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("GuiObject") and child:GetAttribute("_dynamic") then
			child:Destroy()
		end
	end

	-- 기존 템플릿 슬롯 숨기기
	for _, child in scrollingFrame:GetChildren() do
		if child.Name == "Slot" and child:IsA("GuiObject") then
			child.Visible = false
		end
	end

	-- CategoryText 업데이트
	local catText = ownedFrame and ownedFrame:FindFirstChild("CategoryText")
	if catText then
		catText.Text = _activeFilter
	end

	local filterType = FILTER_MAP[_activeFilter] or "전체"
	local filteredIndex = 0

	for i, item in _inventory do
		local isEgg = item.isEgg == true
		local building = if not isEgg then Constants.BUILDINGS[item.itemName] else nil
		local eggInfo = if isEgg then (BalanceConfig.Egg and BalanceConfig.Egg.EGGS[item.itemName]) else nil

		if not building and not eggInfo then continue end

		-- 필터 적용
		if filterType ~= "전체" and not isEgg then
			local matchesFilter = false
			if building then
				for _, t in building.types do
					if t == filterType then matchesFilter = true; break end
				end
			end
			if not matchesFilter then continue end
		end

		filteredIndex = filteredIndex + 1

		local displayName = if building then building.name elseif eggInfo then eggInfo.name else item.itemName
		local displayRarity = if building then building.rarity elseif eggInfo then eggInfo.rarity else "일반"
		local rarityColor = Constants.RARITY_COLORS[displayRarity] or Color3.fromRGB(180, 180, 180)

		-- 슬롯 생성 (템플릿 복제 또는 새로 생성)
		local slot
		if slotTemplate then
			slot = slotTemplate:Clone()
		else
			slot = Instance.new("TextButton")
			slot.Size = UDim2.new(0, 70, 0, 70)
		end

		slot.Name = "Slot_" .. item.itemName
		slot.Visible = true
		slot.LayoutOrder = filteredIndex
		slot:SetAttribute("_dynamic", true)
		slot.Parent = scrollingFrame

		-- 이름 텍스트 업데이트
		local nameLabel = slot:FindFirstChild("TextLabel") or slot:FindFirstChildWhichIsA("TextLabel")
		if nameLabel then
			nameLabel.Text = displayName
		end

		-- 수량 표시 (있으면)
		local countLabel = slot:FindFirstChild("Count") or slot:FindFirstChild("CountLabel")
		if countLabel then
			countLabel.Text = "x" .. item.count
		end

		-- 클릭 이벤트
		if slot:IsA("GuiButton") then
			slot.MouseButton1Click:Connect(function()
				if _onItemSelected then
					_onItemSelected(item.itemName, item.level or 1)
				end
			end)
		else
			-- Frame이면 내부 버튼 찾기
			local btn = slot:FindFirstChildWhichIsA("TextButton") or slot:FindFirstChildWhichIsA("ImageButton")
			if btn then
				btn.MouseButton1Click:Connect(function()
					if _onItemSelected then
						_onItemSelected(item.itemName, item.level or 1)
					end
				end)
			end
		end
	end

	-- PlacedNumber 업데이트
	local placedNum = ownedFrame and ownedFrame:FindFirstChild("PlacedNumber")
	if placedNum then
		placedNum.Text = tostring(filteredIndex)
	end
end

function InventoryUI.show()
	if _visible or not ownedFrame then return end
	_visible = true
	ownedFrame.Visible = true
	InventoryUI._renderSlots()
end

function InventoryUI.hide()
	if not _visible or not ownedFrame then return end
	_visible = false
	ownedFrame.Visible = false
end

function InventoryUI.selectByIndex(index: number)
	if not _visible or not _onItemSelected then return end
	local item = _inventory[index]
	if item then
		_onItemSelected(item.itemName, item.level or 1)
	end
end

function InventoryUI.isVisible(): boolean
	return _visible
end

function InventoryUI.destroy()
end

return InventoryUI
