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

	-- 기존 박혀있는 ImageLabel/Image 비우기
	if iconHost:IsA("ImageLabel") then
		iconHost.Image = ""
	end
	-- 기존 ViewportFrame 제거
	local oldVP = iconHost:FindFirstChild("_PetSellVP")
	if oldVP then oldVP:Destroy() end
	-- 슬롯에 박혀있는 다른 ImageLabel(예: 마녀 박힌)도 숨기기
	for _, desc in iconHost:GetDescendants() do
		if desc:IsA("ImageLabel") and desc.Image ~= "" then
			desc.Image = ""
		end
	end

	local model = findPetModelByPetId(pet.petId)
	if not model or not model:IsA("Model") then return end

	local vpf = Instance.new("ViewportFrame")
	vpf.Name = "_PetSellVP"
	vpf.Size = UDim2.new(1, 0, 1, 0)
	vpf.BackgroundTransparency = 1
	vpf.LightDirection = Vector3.new(-0.4, -1, -0.3).Unit
	vpf.Ambient = Color3.fromRGB(160, 160, 160)
	vpf.ZIndex = 5
	vpf.Parent = iconHost

	local clone = model:Clone()
	for _, p in clone:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	clone.Parent = vpf

	local camera = Instance.new("Camera")
	vpf.CurrentCamera = camera
	camera.Parent = vpf

	local cf, size = clone:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	camera.CFrame = CFrame.lookAt(
		cf.Position + Vector3.new(maxDim * 0.6, maxDim * 0.3, maxDim * 0.9),
		cf.Position
	)
end

local function populateSlot(slot: GuiObject, pet, sellPrice: number)
	local petInfo = Constants.PETS[pet.petName]
	local displayName = (petInfo and petInfo.name) or pet.petName

	setText(slot, { "NameText", "Name", "PetName", "TitleText" }, displayName)
	setText(slot, { "RarityText", "Rarity" }, pet.rarity or "Common")
	setText(slot, { "PriceText", "Price", "SellPriceText" }, "$" .. sellPrice)
	setText(slot, { "LevelText", "Level" }, "Lv." .. (pet.level or 1))
	setText(slot, { "WeightText", "Weight" }, string.format("%.1fkg", pet.weight or 0))

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
	setText(_sellFrame, { "TotalCountText", "TotalText", "Count" }, "Total Pets: " .. count)
	setText(_sellFrame, { "TotalCashText", "CashText", "TotalPrice" }, "Total Cash: $" .. total)
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

	-- 미배정 펫만 필터
	local sellablePets = {}
	for _, pet in allPets do
		if pet.assignedBuildingId == "" or pet.assignedBuildingId == nil then
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

	-- 슬롯 채우기
	if _slotTemplate then
		for i, pet in sellablePets do
			local sellPrice = calcSellPrice(pet)
			totalCash = totalCash + sellPrice

			local slot = _slotTemplate:Clone()
			slot.Name = "Slot_" .. i
			slot.LayoutOrder = i
			slot.Visible = true
			slot.Parent = _scrollFrame
			if _slotHeight then
				slot.Size = UDim2.new(slot.Size.X.Scale, slot.Size.X.Offset, 0, _slotHeight)
			end

			populateSlot(slot, pet, sellPrice)
		end
	end

	-- 합계 텍스트
	setText(_sellFrame, { "TotalCountText", "TotalText", "Count" }, "Total Pets: " .. totalCount)
	setText(_sellFrame, { "TotalCashText", "CashText", "TotalPrice" }, "Total Cash: $" .. totalCash)

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
