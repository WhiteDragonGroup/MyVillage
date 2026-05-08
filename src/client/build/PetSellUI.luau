-- PetSellUI.luau
-- Features.SellPets 디자인 UI에 펫 데이터 채워넣기
-- 슬롯은 ScrollingFrame의 첫 자식을 템플릿으로 사용

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local PetCfg = BalanceConfig.Pet

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local PetSellUI = {}

local _featuresGui: ScreenGui? = nil
local _sellFrame: GuiObject? = nil
local _scrollFrame: ScrollingFrame? = nil
local _slotTemplate: GuiObject? = nil
local _slotHeight: number? = nil
local _onSold = nil
local _visible = false
local _connected = false

local function calcSellPrice(pet): number
	local rarity = pet.rarity or "Common"
	local basePrice = PetCfg.SELL_BASE_PRICE[rarity] or 100

	local weightMult = pet.weightMult or 1.0
	local weightRange = PetCfg.WEIGHT_MAX_MULT - PetCfg.WEIGHT_MIN_MULT
	local weightRatio = if weightRange > 0 then math.clamp((weightMult - PetCfg.WEIGHT_MIN_MULT) / weightRange, 0, 1) else 0.5
	local sellWeightMult = PetCfg.SELL_WEIGHT_MULT_MIN + weightRatio * (PetCfg.SELL_WEIGHT_MULT_MAX - PetCfg.SELL_WEIGHT_MULT_MIN)

	local level = pet.level or 1
	local levelRatio = math.clamp((level - 1) / (PetCfg.MAX_LEVEL - 1), 0, 1)
	local sellLevelMult = PetCfg.SELL_LEVEL_MULT_MIN + levelRatio * (PetCfg.SELL_LEVEL_MULT_MAX - PetCfg.SELL_LEVEL_MULT_MIN)

	local mutationTotal = 0
	if pet.mutations then
		for _, mutName in pet.mutations do
			mutationTotal = mutationTotal + (PetCfg.SELL_MUTATION_BONUS[mutName] or 0)
		end
	end
	local mutMult = if mutationTotal > 0 then mutationTotal else 1

	return math.floor(basePrice * sellWeightMult * sellLevelMult * mutMult)
end

local function findFirst(parent: Instance, names: { string }): Instance?
	for _, n in names do
		local c = parent:FindFirstChild(n, true)
		if c then return c end
	end
	return nil
end

local function setText(parent: Instance, names: { string }, text: string)
	local c = findFirst(parent, names)
	if c and (c:IsA("TextLabel") or c:IsA("TextButton") or c:IsA("TextBox")) then
		c.Text = text
	end
end

local function getOrCaptureSlotTemplate()
	if _slotTemplate or not _scrollFrame then return end
	for _, child in _scrollFrame:GetChildren() do
		if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("TextButton") then
			if child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" and child.Name ~= "UIGridLayout" then
				_slotHeight = child.AbsoluteSize.Y
				_slotTemplate = child:Clone()
				break
			end
		end
	end
end

local function clearSlots()
	if not _scrollFrame then return end
	for _, child in _scrollFrame:GetChildren() do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

local function findPetModelByPetId(petId: string): Instance?
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end
	for _, plot in plotsFolder:GetChildren() do
		for _, desc in plot:GetDescendants() do
			if desc:GetAttribute("PetId") == petId then
				local mdl = desc
				local cur = desc.Parent
				while cur and cur ~= plot do
					if cur:IsA("Model") then mdl = cur end
					cur = cur.Parent
				end
				return mdl
			end
		end
	end
	return nil
end

local function setPetIcon(slot: GuiObject, pet)
	local iconHost = findFirst(slot, { "Icon", "PetIcon", "Image" })
	if not iconHost then return end

	-- 기존 ViewportFrame 잔재 제거
	local oldVP = iconHost:FindFirstChild("_PetSellVP")
	if oldVP then oldVP:Destroy() end

	local iconId = Constants.getPetIcon and Constants.getPetIcon(pet.petName) or ""
	if iconHost:IsA("ImageLabel") or iconHost:IsA("ImageButton") then
		iconHost.Image = iconId
		iconHost.ScaleType = Enum.ScaleType.Stretch
	else
		local img = iconHost:FindFirstChild("_PetSellIcon")
		if not img then
			img = Instance.new("ImageLabel")
			img.Name = "_PetSellIcon"
			img.Size = UDim2.new(1, 0, 1, 0)
			img.BackgroundTransparency = 1
			img.ScaleType = Enum.ScaleType.Stretch
			img.ZIndex = 5
			img.Parent = iconHost
		end
		img.Image = iconId
	end
end

local function populateSlot(slot: GuiObject, pet, sellPrice: number)
	local petInfo = Constants.PETS[pet.petName]
	local displayName = (petInfo and petInfo.name) or pet.petName
	local rarityText = pet.rarity or "Common"

	-- Name + Shadow
	local nameLabel = slot:FindFirstChild("NameText")
	if nameLabel and (nameLabel:IsA("TextLabel") or nameLabel:IsA("TextButton")) then
		nameLabel.Text = displayName
	end
	local nameShadow = slot:FindFirstChild("NameTextShadow")
	if nameShadow and nameShadow:IsA("TextLabel") then
		nameShadow.Text = displayName
	end

	-- Rarity (Frame > TextLabel)
	local rarityFrame = slot:FindFirstChild("Rarity")
	if rarityFrame then
		local rarityLabel = rarityFrame:FindFirstChildWhichIsA("TextLabel")
		if rarityLabel then rarityLabel.Text = rarityText end
	end

	-- Level / Weight
	local levelLabel = slot:FindFirstChild("LevelText")
	if levelLabel and levelLabel:IsA("TextLabel") then
		levelLabel.Text = string.format("Level : %d", pet.level or 1)
	end
	local weightLabel = slot:FindFirstChild("WeightText")
	if weightLabel and weightLabel:IsA("TextLabel") then
		weightLabel.Text = string.format("Weight : %.1fkg", pet.weight or 0)
	end

	-- Mutation
	local mutLabel = slot:FindFirstChild("MutationText")
	if mutLabel and mutLabel:IsA("TextLabel") then
		local mutText = "None"
		if pet.mutations and #pet.mutations > 0 then
			local names = {}
			for _, m in pet.mutations do
				table.insert(names, (Constants.MUTATION_NAMES and Constants.MUTATION_NAMES[m]) or m)
			end
			mutText = table.concat(names, ", ")
		end
		mutLabel.Text = "Mutations : " .. mutText
	end

	-- Price (디자인 라벨명 AcountText / AmountText / PriceText)
	local priceLabel = slot:FindFirstChild("AcountText") or slot:FindFirstChild("AmountText") or slot:FindFirstChild("PriceText")
	if priceLabel and priceLabel:IsA("TextLabel") then
		priceLabel.Text = "$" .. sellPrice
	end

	setPetIcon(slot, pet)

	-- Sell 버튼: 흔한 이름들 시도
	local sellBtn = findFirst(slot, { "SellButton", "Sell", "BuyButton", "Buy", "Confirm" })
	if sellBtn and sellBtn:IsA("GuiButton") then
		sellBtn.MouseButton1Click:Connect(function()
			local sellFunc = remotes:FindFirstChild("SellPet")
			if sellFunc then
				local ok = sellFunc:InvokeServer(pet.petId)
				if ok and slot.Parent then
					slot:Destroy()
					if _onSold then _onSold() end
					-- 합계 갱신
					PetSellUI._refreshTotals()
				end
			end
		end)
	end
end

function PetSellUI._refreshTotals()
	if not _sellFrame then return end
	-- 슬롯 다시 카운트해서 합계 계산
	local total = 0
	local count = 0
	if _scrollFrame then
		for _, child in _scrollFrame:GetChildren() do
			if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				count = count + 1
			end
		end
	end
	local bottomFrame = _sellFrame:FindFirstChild("Bottom")
	if bottomFrame then
		for _, c in bottomFrame:GetChildren() do
			if c:IsA("TextLabel") then
				local lt = (c.Text or ""):lower()
				if lt:find("cash") then
					c.Text = "Total cash : $" .. total
				elseif lt:find("pets") then
					c.Text = "Total Pets : " .. count
				end
			end
		end
	end
end

function PetSellUI.init(callbacks: { onSold: (() -> ())? }?)
	_onSold = callbacks and callbacks.onSold or nil

	_featuresGui = playerGui:WaitForChild("Features", 10)
	if not _featuresGui then
		warn("[PetSellUI] Features ScreenGui 못 찾음")
		return
	end

	_sellFrame = _featuresGui:FindFirstChild("SellPets")
	if not _sellFrame then
		warn("[PetSellUI] SellPets 프레임 없음")
		return
	end
	_sellFrame.Visible = false

	_scrollFrame = _sellFrame:FindFirstChild("ScrollingFrame", true)
	if not _scrollFrame then
		warn("[PetSellUI] ScrollingFrame 없음")
		return
	end

	-- 닫기 버튼
	local header = _sellFrame:FindFirstChild("Header")
	local closeBtn = (header and (header:FindFirstChild("Close") or header:FindFirstChild("CloseButton")))
		or _sellFrame:FindFirstChild("Close", true)
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.MouseButton1Click:Connect(function()
			PetSellUI.hide()
		end)
	end

	-- Sell All 버튼 (Bottom 영역)
	local bottom = _sellFrame:FindFirstChild("Bottom")
	local sellAllBtn = (bottom and (bottom:FindFirstChild("SellAll") or bottom:FindFirstChild("SellAllButton")))
		or _sellFrame:FindFirstChild("SellAll", true)
	if sellAllBtn and sellAllBtn:IsA("GuiButton") then
		sellAllBtn.MouseButton1Click:Connect(function()
			local sellAllFunc = remotes:FindFirstChild("SellAllPets")
			if sellAllFunc then
				sellAllFunc:InvokeServer()
				PetSellUI.hide()
				if _onSold then _onSold() end
			end
		end)
	end

	_connected = true
end

function PetSellUI.show()
	if not _connected or not _sellFrame or not _scrollFrame then
		warn("[PetSellUI] init 실패 - show 무시")
		return
	end

	_visible = true

	local getPetsFunc = remotes:FindFirstChild("GetPets")
	if not getPetsFunc then return end
	local allPets = getPetsFunc:InvokeServer()
	if not allPets then allPets = {} end

	-- 인벤토리(Backpack/Character의 Pet Tool)에 있는 펫만 표시
	local heldPetIds = {} :: { [string]: boolean }
	local containers = { player:FindFirstChild("Backpack"), player.Character }
	for _, c in containers do
		if not c then continue end
		for _, child in c:GetChildren() do
			if child:IsA("Tool") then
				local pid = child:GetAttribute("PetId")
				if pid then heldPetIds[pid] = true end
			end
		end
	end
	local sellablePets = {}
	for _, pet in allPets do
		if heldPetIds[pet.petId] then
			table.insert(sellablePets, pet)
		end
	end

	-- 슬롯 템플릿 캡처 (최초 1회)
	getOrCaptureSlotTemplate()

	-- 기존 슬롯 제거
	clearSlots()

	-- 합계
	local totalCash = 0
	local totalCount = #sellablePets

	-- ScrollingFrame에 UIListLayout 보장 (슬롯 세로 정렬)
	local listLayout = _scrollFrame:FindFirstChildWhichIsA("UIListLayout")
	if not listLayout and not _scrollFrame:FindFirstChildWhichIsA("UIGridLayout") then
		listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 4)
		listLayout.Parent = _scrollFrame
	end
	-- 캔버스 자동 확장
	_scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	_scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

	-- 슬롯 채우기
	if _slotTemplate then
		local slotH = _slotHeight or 80
		for i, pet in sellablePets do
			local sellPrice = calcSellPrice(pet)
			totalCash = totalCash + sellPrice

			local slot = _slotTemplate:Clone()
			slot.Name = "Slot_" .. i
			slot.LayoutOrder = i
			slot.Visible = true
			-- 슬롯 높이 고정 + 위치는 UIListLayout이 결정
			slot.Size = UDim2.new(1, 0, 0, slotH)
			slot.Position = UDim2.new(0, 0, 0, 0)
			slot.Parent = _scrollFrame

			populateSlot(slot, pet, sellPrice)
		end
	end

	-- 합계 텍스트
	-- Bottom 영역 합계 (디자인이 두 라벨 모두 NameText로 같은 이름 → 현재 텍스트 패턴으로 구분)
	local bottomFrame = _sellFrame:FindFirstChild("Bottom")
	if bottomFrame then
		for _, c in bottomFrame:GetChildren() do
			if c:IsA("TextLabel") then
				local lt = (c.Text or ""):lower()
				if lt:find("cash") then
					c.Text = "Total cash : $" .. totalCash
				elseif lt:find("pets") then
					c.Text = "Total Pets : " .. totalCount
				end
			end
		end
	end

	_sellFrame.Visible = true
end

function PetSellUI.hide()
	_visible = false
	if _sellFrame then _sellFrame.Visible = false end
end

function PetSellUI.isVisible(): boolean
	return _visible
end

return PetSellUI
