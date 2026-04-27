-- PetSellUI.luau
-- Pet sell popup: scrollable list of unassigned pets with sell buttons

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local PetCfg = BalanceConfig.Pet

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local PetSellUI = {}

local _screenGui = nil
local _visible = false
local _onSold = nil -- callback after selling

function PetSellUI.init(callbacks: { onSold: (() -> ())? }?)
	_onSold = callbacks and callbacks.onSold or nil
end

-- Calculate sell price on client (for display)
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

function PetSellUI.show()
	PetSellUI.hide()
	_visible = true

	-- Fetch pets from server
	local getPetsFunc = remotes:FindFirstChild("GetPets")
	if not getPetsFunc then return end
	local allPets = getPetsFunc:InvokeServer()
	if not allPets then return end

	-- Filter unassigned pets only
	local sellablePets = {}
	for _, pet in allPets do
		if pet.assignedBuildingId == "" or pet.assignedBuildingId == nil then
			table.insert(sellablePets, pet)
		end
	end

	-- Create UI
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "PetSellUI"
	_screenGui.DisplayOrder = 50
	_screenGui.Parent = playerGui

	-- Background overlay
	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Parent = _screenGui
	overlay.MouseButton1Click:Connect(function()
		PetSellUI.hide()
	end)

	-- Main frame
	local frame = Instance.new("Frame")
	frame.Name = "SellFrame"
	frame.Size = UDim2.new(0, 360, 0, 440)
	frame.Position = UDim2.new(0.5, -180, 0.5, -220)
	frame.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
	frame.BorderSizePixel = 0
	frame.Parent = _screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 140, 80)
	stroke.Thickness = 2
	stroke.Parent = frame

	-- Header
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(255, 220, 130)
	header.TextSize = 16
	header.Font = Enum.Font.GothamBold
	header.Text = "Sell Pets"
	header.Parent = frame

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -33, 0, 3)
	closeBtn.BackgroundTransparency = 1
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.Parent = frame
	closeBtn.MouseButton1Click:Connect(function()
		PetSellUI.hide()
	end)

	-- Scroll frame
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -16, 1, -90)
	scrollFrame.Position = UDim2.new(0, 8, 0, 38)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(180, 140, 80)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scrollFrame

	if #sellablePets == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 0, 40)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		emptyLabel.TextSize = 12
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.Text = "No pets available to sell"
		emptyLabel.Parent = scrollFrame
	end

	for i, pet in sellablePets do
		local petInfo = Constants.PETS[pet.petName]
		local rarityColor = Constants.RARITY_COLORS[pet.rarity] or Color3.fromRGB(180, 180, 180)
		local sellPrice = calcSellPrice(pet)

		local slot = Instance.new("Frame")
		slot.Name = "Slot_" .. i
		slot.Size = UDim2.new(1, -4, 0, 70)
		slot.BackgroundColor3 = Color3.fromRGB(50, 45, 35)
		slot.BackgroundTransparency = 0.3
		slot.LayoutOrder = i
		slot.Parent = scrollFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slot

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = rarityColor
		slotStroke.Thickness = 1
		slotStroke.Parent = slot

		-- Pet name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 160, 0, 18)
		nameLabel.Position = UDim2.new(0, 8, 0, 4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = (petInfo and petInfo.name) or pet.petName
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- Rarity
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(0, 80, 0, 14)
		rarityLabel.Position = UDim2.new(0, 8, 0, 22)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.TextColor3 = rarityColor
		rarityLabel.TextSize = 10
		rarityLabel.Font = Enum.Font.GothamBold
		rarityLabel.Text = pet.rarity or "Common"
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
		rarityLabel.Parent = slot

		-- Info: Level, Weight, Mutations
		local infoText = "Lv." .. (pet.level or 1) .. " | " .. string.format("%.1fkg", pet.weight or 0)
		if pet.mutations and #pet.mutations > 0 then
			local mutNames = {}
			for _, m in pet.mutations do
				table.insert(mutNames, Constants.MUTATION_NAMES[m] or m)
			end
			infoText = infoText .. " | " .. table.concat(mutNames, ", ")
		end

		local infoLabel = Instance.new("TextLabel")
		infoLabel.Size = UDim2.new(0, 200, 0, 14)
		infoLabel.Position = UDim2.new(0, 8, 0, 38)
		infoLabel.BackgroundTransparency = 1
		infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		infoLabel.TextSize = 9
		infoLabel.Font = Enum.Font.Gotham
		infoLabel.Text = infoText
		infoLabel.TextXAlignment = Enum.TextXAlignment.Left
		infoLabel.Parent = slot

		-- Price
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(0, 70, 0, 16)
		priceLabel.Position = UDim2.new(0, 8, 0, 52)
		priceLabel.BackgroundTransparency = 1
		priceLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
		priceLabel.TextSize = 11
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.Text = "$" .. sellPrice
		priceLabel.TextXAlignment = Enum.TextXAlignment.Left
		priceLabel.Parent = slot

		-- Sell button
		local sellBtn = Instance.new("TextButton")
		sellBtn.Size = UDim2.new(0, 60, 0, 28)
		sellBtn.Position = UDim2.new(1, -68, 0.5, -14)
		sellBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		sellBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		sellBtn.TextSize = 12
		sellBtn.Font = Enum.Font.GothamBold
		sellBtn.Text = "Sell"
		sellBtn.AutoButtonColor = true
		sellBtn.Parent = slot

		local sellBtnCorner = Instance.new("UICorner")
		sellBtnCorner.CornerRadius = UDim.new(0, 6)
		sellBtnCorner.Parent = sellBtn

		sellBtn.MouseButton1Click:Connect(function()
			local sellFunc = remotes:FindFirstChild("SellPet")
			if sellFunc then
				local ok, price = sellFunc:InvokeServer(pet.petId)
				if ok then
					slot:Destroy()
					if _onSold then _onSold() end
				end
			end
		end)
	end

	-- Sell All button (bottom)
	local sellAllBtn = Instance.new("TextButton")
	sellAllBtn.Size = UDim2.new(1, -16, 0, 36)
	sellAllBtn.Position = UDim2.new(0, 8, 1, -44)
	sellAllBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	sellAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellAllBtn.TextSize = 14
	sellAllBtn.Font = Enum.Font.GothamBold
	sellAllBtn.Text = "Sell All"
	sellAllBtn.AutoButtonColor = true
	sellAllBtn.Parent = frame

	local sellAllCorner = Instance.new("UICorner")
	sellAllCorner.CornerRadius = UDim.new(0, 8)
	sellAllCorner.Parent = sellAllBtn

	sellAllBtn.MouseButton1Click:Connect(function()
		PetSellUI._showConfirm()
	end)
end

function PetSellUI._showConfirm()
	if not _screenGui then return end

	-- Confirmation popup
	local confirmOverlay = Instance.new("TextButton")
	confirmOverlay.Name = "ConfirmOverlay"
	confirmOverlay.Size = UDim2.new(1, 0, 1, 0)
	confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	confirmOverlay.BackgroundTransparency = 0.6
	confirmOverlay.Text = ""
	confirmOverlay.AutoButtonColor = false
	confirmOverlay.ZIndex = 10
	confirmOverlay.Parent = _screenGui

	local confirmFrame = Instance.new("Frame")
	confirmFrame.Size = UDim2.new(0, 280, 0, 140)
	confirmFrame.Position = UDim2.new(0.5, -140, 0.5, -70)
	confirmFrame.BackgroundColor3 = Color3.fromRGB(45, 38, 30)
	confirmFrame.BorderSizePixel = 0
	confirmFrame.ZIndex = 11
	confirmFrame.Parent = _screenGui

	local cfCorner = Instance.new("UICorner")
	cfCorner.CornerRadius = UDim.new(0, 12)
	cfCorner.Parent = confirmFrame

	local cfStroke = Instance.new("UIStroke")
	cfStroke.Color = Color3.fromRGB(255, 80, 80)
	cfStroke.Thickness = 2
	cfStroke.Parent = confirmFrame

	local cfText = Instance.new("TextLabel")
	cfText.Size = UDim2.new(1, -20, 0, 60)
	cfText.Position = UDim2.new(0, 10, 0, 15)
	cfText.BackgroundTransparency = 1
	cfText.TextColor3 = Color3.fromRGB(255, 255, 255)
	cfText.TextSize = 13
	cfText.Font = Enum.Font.GothamBold
	cfText.Text = "Are you sure you want to\nsell ALL unassigned pets?"
	cfText.TextWrapped = true
	cfText.ZIndex = 12
	cfText.Parent = confirmFrame

	-- Sell All confirm
	local yesBtn = Instance.new("TextButton")
	yesBtn.Size = UDim2.new(0, 110, 0, 34)
	yesBtn.Position = UDim2.new(0, 20, 1, -48)
	yesBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	yesBtn.TextSize = 13
	yesBtn.Font = Enum.Font.GothamBold
	yesBtn.Text = "Sell All"
	yesBtn.ZIndex = 12
	yesBtn.Parent = confirmFrame

	local yesBtnCorner = Instance.new("UICorner")
	yesBtnCorner.CornerRadius = UDim.new(0, 6)
	yesBtnCorner.Parent = yesBtn

	-- Cancel
	local noBtn = Instance.new("TextButton")
	noBtn.Size = UDim2.new(0, 110, 0, 34)
	noBtn.Position = UDim2.new(1, -130, 1, -48)
	noBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	noBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	noBtn.TextSize = 13
	noBtn.Font = Enum.Font.GothamBold
	noBtn.Text = "Cancel"
	noBtn.ZIndex = 12
	noBtn.Parent = confirmFrame

	local noBtnCorner = Instance.new("UICorner")
	noBtnCorner.CornerRadius = UDim.new(0, 6)
	noBtnCorner.Parent = noBtn

	local function closeConfirm()
		confirmOverlay:Destroy()
		confirmFrame:Destroy()
	end

	confirmOverlay.MouseButton1Click:Connect(closeConfirm)
	noBtn.MouseButton1Click:Connect(closeConfirm)

	yesBtn.MouseButton1Click:Connect(function()
		local sellAllFunc = remotes:FindFirstChild("SellAllPets")
		if sellAllFunc then
			local soldCount, totalPrice = sellAllFunc:InvokeServer()
			closeConfirm()
			PetSellUI.hide()
			if _onSold then _onSold() end
		end
	end)
end

function PetSellUI.hide()
	_visible = false
	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end
end

function PetSellUI.isVisible(): boolean
	return _visible
end

return PetSellUI
