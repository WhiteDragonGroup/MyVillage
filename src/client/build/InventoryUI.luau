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
	All = "All",
	WorkSpots = "Work",
	RestSpots = "Rest",
	Supports = "Support",
	Decorations = "Decoration",
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

	local filterType = FILTER_MAP[_activeFilter] or "All"
	local filteredIndex = 0

	for i, item in _inventory do
		local isEgg = item.isEgg == true
		local building = if not isEgg then Constants.BUILDINGS[item.itemName] else nil
		local eggInfo = if isEgg then (BalanceConfig.Egg and BalanceConfig.Egg.EGGS[item.itemName]) else nil

		if not building and not eggInfo then continue end

		-- 필터 적용
		if filterType ~= "All" and not isEgg then
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
		local displayRarity = if building then building.rarity elseif eggInfo then eggInfo.rarity else "Common"
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

		-- 2열 그리드: 패딩 + 간격 균등 배치
		local PADDING = 6
		local GAP = 6
		local frameW = scrollingFrame.AbsoluteSize.X
		if frameW < 50 then frameW = 160 end
		local slotW = math.floor((frameW - PADDING * 2 - GAP) / 2)
		slot.Size = UDim2.new(0, slotW, 0, slotW)
		slot.Parent = scrollingFrame

		local col = (filteredIndex - 1) % 2
		local row = math.floor((filteredIndex - 1) / 2)
		slot.Position = UDim2.new(0, PADDING + col * (slotW + GAP), 0, PADDING + row * (slotW + GAP))

		-- NameText 업데이트
		local nameText = slot:FindFirstChild("NameText")
		if nameText then
			nameText.Text = displayName
		end

		-- LevelText 업데이트
		local levelText = slot:FindFirstChild("LevelText")
		if levelText then
			levelText.Text = "Lv." .. (item.level or 1)
		end

		-- Icon 이미지 업데이트 (레벨별 아이콘)
		local iconLabel = slot:FindFirstChild("Icon")
		if iconLabel and building then
			local iconId = Constants.getBuildingIcon(item.itemName, item.level or 1)
			if iconId ~= "" then
				iconLabel.Image = iconId
			end
		end

		-- Count 표시 (2개 이상일 때)
		local count = item.count or 1
		if count > 1 then
			local countLabel = slot:FindFirstChild("CountText")
			if not countLabel then
				countLabel = Instance.new("TextLabel")
				countLabel.Name = "CountText"
				countLabel.Size = UDim2.new(0, 28, 0, 18)
				countLabel.Position = UDim2.new(0, 2, 0, 2)
				countLabel.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
				countLabel.BackgroundTransparency = 0.3
				countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				countLabel.TextSize = 11
				countLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
				countLabel.ZIndex = 5
				countLabel.Parent = slot

				local cCorner = Instance.new("UICorner")
				cCorner.CornerRadius = UDim.new(0, 4)
				cCorner.Parent = countLabel
			end
			countLabel.Text = "x" .. count
		end

		-- 클릭 이벤트 (투명 버튼 추가)
		local clickBtn = Instance.new("TextButton")
		clickBtn.Name = "ClickArea"
		clickBtn.Size = UDim2.new(1, 0, 1, 0)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.ZIndex = 10
		clickBtn.Parent = slot
		clickBtn.MouseButton1Click:Connect(function()
			if _onItemSelected then
				_onItemSelected(item.itemName, item.level or 1)
			end
		end)
	end

	-- CanvasSize 업데이트 (2열 그리드 기준)
	local PADDING = 6
	local GAP = 6
	local frameW = scrollingFrame.AbsoluteSize.X
	if frameW < 50 then frameW = 160 end
	local slotW = math.floor((frameW - PADDING * 2 - GAP) / 2)
	local rows = math.ceil(filteredIndex / 2)
	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, PADDING * 2 + rows * (slotW + GAP))

	-- PlacedNumber 업데이트 (배치된 건물 수)
	InventoryUI._updatePlacedCount()
end

function InventoryUI._updatePlacedCount()
	local placedNum = ownedFrame and ownedFrame:FindFirstChild("PlacedNumber")
	if not placedNum then return end

	local count = 0
	local plotsFolder = workspace:FindFirstChild("Plots")
	if plotsFolder then
		local player = game:GetService("Players").LocalPlayer
		for _, plot in plotsFolder:GetChildren() do
			if plot:GetAttribute("Owner") == player.Name then
				for _, desc in plot:GetDescendants() do
					if desc:IsA("BasePart") and desc:GetAttribute("BuildingId") then
						count = count + 1
					end
				end
				break
			end
		end
	end
	placedNum.Text = "Placed Buildings : " .. count .. "/25"
end

function InventoryUI.show()
	if _visible or not ownedFrame then return end
	_visible = true

	-- Slide in from right
	local origPos = ownedFrame.Position
	ownedFrame.Position = UDim2.new(origPos.X.Scale + 0.3, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset)
	ownedFrame.Visible = true
	TweenService:Create(ownedFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = origPos,
	}):Play()

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
