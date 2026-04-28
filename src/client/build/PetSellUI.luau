-- PetSellUI.luau
-- Pet sell popup: polished design with filters, totals, sell all

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local PetCfg = BalanceConfig.Pet

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local PetSellUI = {}

local _screenGui = nil
local _visible = false
local _onSold = nil
local _activeFilter = "All"

function PetSellUI.init(callbacks: { onSold: (() -> ())? }?)
	_onSold = callbacks and callbacks.onSold or nil
end

local function formatPrice(n): string
	if n >= 1000 then
		return string.format("$%.1fK", n / 1000)
	end
	return "$" .. n
end

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

local function createRoundedFrame(props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.color or Color3.fromRGB(35, 30, 25)
	frame.BackgroundTransparency = props.transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.size or UDim2.new(1, 0, 0, 40)
	frame.Position = props.position or UDim2.new(0, 0, 0, 0)
	if props.parent then frame.Parent = props.parent end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, props.radius or 8)
	corner.Parent = frame

	return frame
end

function PetSellUI.show()
	PetSellUI.hide()
	_visible = true
	_activeFilter = "All"

	local getPetsFunc = remotes:FindFirstChild("GetPets")
	if not getPetsFunc then return end
	local allPets = getPetsFunc:InvokeServer()
	if not allPets then return end

	-- Filter unassigned pets
	local sellablePets = {}
	for _, pet in allPets do
		if pet.assignedBuildingId == "" or pet.assignedBuildingId == nil then
			table.insert(sellablePets, pet)
		end
	end

	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "PetSellUI"
	_screenGui.DisplayOrder = 50
	_screenGui.Parent = playerGui

	-- Overlay
	local overlay = Instance.new("TextButton")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Parent = _screenGui
	overlay.MouseButton1Click:Connect(function()
		PetSellUI.hide()
	end)

	-- Main panel
	local panel = createRoundedFrame({
		color = Color3.fromRGB(28, 24, 20),
		size = UDim2.new(0, 380, 0, 480),
		position = UDim2.new(0.5, -190, 0.5, -240),
		radius = 14,
		parent = _screenGui,
	})

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(120, 90, 50)
	panelStroke.Thickness = 2
	panelStroke.Parent = panel

	-- === Header ===
	local header = createRoundedFrame({
		color = Color3.fromRGB(160, 50, 40),
		size = UDim2.new(1, 0, 0, 40),
		radius = 14,
		parent = panel,
	})

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 150, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Text = "Sell Pets"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- Filter buttons
	local filters = { "All", "Rarity", "Type" }
	for fi, filterName in filters do
		local filterBtn = Instance.new("TextButton")
		filterBtn.Size = UDim2.new(0, 44, 0, 24)
		filterBtn.Position = UDim2.new(0, 150 + (fi - 1) * 50, 0.5, -12)
		filterBtn.BackgroundColor3 = Color3.fromRGB(50, 42, 35)
		filterBtn.TextColor3 = Color3.fromRGB(220, 200, 170)
		filterBtn.TextSize = 10
		filterBtn.Font = Enum.Font.GothamBold
		filterBtn.Text = filterName
		filterBtn.AutoButtonColor = true
		filterBtn.Parent = header

		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 6)
		fc.Parent = filterBtn
	end

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -35, 0.5, -15)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.Parent = header

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 6)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		PetSellUI.hide()
	end)

	-- === Scroll area ===
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -16, 1, -110)
	scrollFrame.Position = UDim2.new(0, 8, 0, 44)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 3
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 90, 50)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scrollFrame

	-- Calculate totals
	local totalPets = #sellablePets
	local totalCash = 0

	if totalPets == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 0, 50)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
		emptyLabel.TextSize = 13
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.Text = "No pets available to sell"
		emptyLabel.Parent = scrollFrame
	end

	-- === Pet slots ===
	for i, pet in sellablePets do
		local petInfo = Constants.PETS[pet.petName]
		local rarityColor = Constants.RARITY_COLORS[pet.rarity] or Color3.fromRGB(180, 180, 180)
		local sellPrice = calcSellPrice(pet)
		totalCash = totalCash + sellPrice

		local slot = createRoundedFrame({
			color = Color3.fromRGB(45, 38, 32),
			size = UDim2.new(1, -4, 0, 64),
			radius = 8,
			parent = scrollFrame,
		})
		slot.Name = "Slot_" .. i
		slot.LayoutOrder = i

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = rarityColor
		slotStroke.Thickness = 1
		slotStroke.Transparency = 0.5
		slotStroke.Parent = slot

		-- Pet icon placeholder
		local iconFrame = createRoundedFrame({
			color = Color3.fromRGB(35, 30, 25),
			size = UDim2.new(0, 48, 0, 48),
			position = UDim2.new(0, 8, 0.5, -24),
			radius = 6,
			parent = slot,
		})

		local iconStroke = Instance.new("UIStroke")
		iconStroke.Color = rarityColor
		iconStroke.Thickness = 1
		iconStroke.Parent = iconFrame

		-- Rarity dot
		local rarityDot = Instance.new("Frame")
		rarityDot.Size = UDim2.new(0, 10, 0, 10)
		rarityDot.Position = UDim2.new(0, 2, 0, 2)
		rarityDot.BackgroundColor3 = rarityColor
		rarityDot.Parent = iconFrame
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = rarityDot

		-- Pet name + info
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 180, 0, 16)
		nameLabel.Position = UDim2.new(0, 62, 0, 6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = (petInfo and petInfo.name or pet.petName)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- Rarity + weight
		local subInfo = Instance.new("TextLabel")
		subInfo.Size = UDim2.new(0, 180, 0, 12)
		subInfo.Position = UDim2.new(0, 62, 0, 22)
		subInfo.BackgroundTransparency = 1
		subInfo.TextColor3 = rarityColor
		subInfo.TextSize = 9
		subInfo.Font = Enum.Font.Gotham
		subInfo.Text = (pet.rarity or "Common") .. " · " .. string.format("%.1fkg", pet.weight or 0)
		subInfo.TextXAlignment = Enum.TextXAlignment.Left
		subInfo.Parent = slot

		-- Mutations
		local mutText = ""
		if pet.mutations and #pet.mutations > 0 then
			local names = {}
			for _, m in pet.mutations do
				table.insert(names, Constants.MUTATION_NAMES[m] or m)
			end
			mutText = table.concat(names, ", ")
		end

		local mutLabel = Instance.new("TextLabel")
		mutLabel.Size = UDim2.new(0, 180, 0, 12)
		mutLabel.Position = UDim2.new(0, 62, 0, 34)
		mutLabel.BackgroundTransparency = 1
		mutLabel.TextColor3 = Color3.fromRGB(180, 160, 130)
		mutLabel.TextSize = 8
		mutLabel.Font = Enum.Font.Gotham
		mutLabel.Text = if mutText ~= "" then "Mutations: " .. mutText else ""
		mutLabel.TextXAlignment = Enum.TextXAlignment.Left
		mutLabel.Parent = slot

		-- Level
		local levelLabel = Instance.new("TextLabel")
		levelLabel.Size = UDim2.new(0, 60, 0, 12)
		levelLabel.Position = UDim2.new(0, 62, 0, 47)
		levelLabel.BackgroundTransparency = 1
		levelLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
		levelLabel.TextSize = 9
		levelLabel.Font = Enum.Font.GothamBold
		levelLabel.Text = "Level " .. (pet.level or 1)
		levelLabel.TextXAlignment = Enum.TextXAlignment.Left
		levelLabel.Parent = slot

		-- Price
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(0, 60, 0, 16)
		priceLabel.Position = UDim2.new(1, -130, 0, 8)
		priceLabel.BackgroundTransparency = 1
		priceLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
		priceLabel.TextSize = 13
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.Text = formatPrice(sellPrice)
		priceLabel.TextXAlignment = Enum.TextXAlignment.Right
		priceLabel.Parent = slot

		-- Sell button
		local sellBtn = Instance.new("TextButton")
		sellBtn.Size = UDim2.new(0, 54, 0, 44)
		sellBtn.Position = UDim2.new(1, -62, 0.5, -22)
		sellBtn.BackgroundColor3 = Color3.fromRGB(190, 55, 45)
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
				-- Shrink animation
				TweenService:Create(slot, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
					Size = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1,
				}):Play()
				task.delay(0.15, function()
					local ok, price = sellFunc:InvokeServer(pet.petId)
					if ok then
						slot:Destroy()
						if _onSold then _onSold() end
					end
				end)
			end
		end)
	end

	-- === Footer ===
	local footer = createRoundedFrame({
		color = Color3.fromRGB(35, 30, 25),
		size = UDim2.new(1, -16, 0, 56),
		position = UDim2.new(0, 8, 1, -64),
		radius = 10,
		parent = panel,
	})

	local footerStroke = Instance.new("UIStroke")
	footerStroke.Color = Color3.fromRGB(100, 80, 50)
	footerStroke.Thickness = 1
	footerStroke.Parent = footer

	-- Total info
	local totalLabel = Instance.new("TextLabel")
	totalLabel.Size = UDim2.new(0.5, 0, 0, 18)
	totalLabel.Position = UDim2.new(0, 10, 0, 4)
	totalLabel.BackgroundTransparency = 1
	totalLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	totalLabel.TextSize = 11
	totalLabel.Font = Enum.Font.GothamBold
	totalLabel.Text = "Total Pets: " .. totalPets
	totalLabel.TextXAlignment = Enum.TextXAlignment.Left
	totalLabel.Parent = footer

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Size = UDim2.new(0.5, -10, 0, 18)
	cashLabel.Position = UDim2.new(0.5, 0, 0, 4)
	cashLabel.BackgroundTransparency = 1
	cashLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
	cashLabel.TextSize = 11
	cashLabel.Font = Enum.Font.GothamBold
	cashLabel.Text = "Total Cash: " .. formatPrice(totalCash)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right
	cashLabel.Parent = footer

	-- Sell All button
	local sellAllBtn = Instance.new("TextButton")
	sellAllBtn.Size = UDim2.new(1, -20, 0, 26)
	sellAllBtn.Position = UDim2.new(0, 10, 0, 25)
	sellAllBtn.BackgroundColor3 = Color3.fromRGB(170, 45, 35)
	sellAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellAllBtn.TextSize = 13
	sellAllBtn.Font = Enum.Font.GothamBold
	sellAllBtn.Text = "Sell All"
	sellAllBtn.AutoButtonColor = true
	sellAllBtn.Parent = footer

	local sellAllCorner = Instance.new("UICorner")
	sellAllCorner.CornerRadius = UDim.new(0, 6)
	sellAllCorner.Parent = sellAllBtn

	sellAllBtn.MouseButton1Click:Connect(function()
		PetSellUI._showConfirm()
	end)

	-- Slide in animation
	panel.Position = UDim2.new(0.5, -190, 0.5, -240 + 30)
	panel.BackgroundTransparency = 0.3
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -190, 0.5, -240),
		BackgroundTransparency = 0,
	}):Play()
end

function PetSellUI._showConfirm()
	if not _screenGui then return end

	local confirmOverlay = Instance.new("TextButton")
	confirmOverlay.Name = "ConfirmOverlay"
	confirmOverlay.Size = UDim2.new(1, 0, 1, 0)
	confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	confirmOverlay.BackgroundTransparency = 0.5
	confirmOverlay.Text = ""
	confirmOverlay.AutoButtonColor = false
	confirmOverlay.ZIndex = 10
	confirmOverlay.Parent = _screenGui

	local confirmFrame = createRoundedFrame({
		color = Color3.fromRGB(40, 34, 28),
		size = UDim2.new(0, 280, 0, 150),
		position = UDim2.new(0.5, -140, 0.5, -75),
		radius = 14,
		parent = _screenGui,
	})
	confirmFrame.ZIndex = 11

	local cfStroke = Instance.new("UIStroke")
	cfStroke.Color = Color3.fromRGB(200, 60, 50)
	cfStroke.Thickness = 2
	cfStroke.Parent = confirmFrame

	-- Title
	local cfTitle = Instance.new("TextLabel")
	cfTitle.Size = UDim2.new(1, 0, 0, 24)
	cfTitle.Position = UDim2.new(0, 0, 0, 15)
	cfTitle.BackgroundTransparency = 1
	cfTitle.TextColor3 = Color3.fromRGB(255, 100, 80)
	cfTitle.TextSize = 12
	cfTitle.Font = Enum.Font.Gotham
	cfTitle.Text = "Are you sure?"
	cfTitle.ZIndex = 12
	cfTitle.Parent = confirmFrame

	local cfText = Instance.new("TextLabel")
	cfText.Size = UDim2.new(1, -20, 0, 30)
	cfText.Position = UDim2.new(0, 10, 0, 38)
	cfText.BackgroundTransparency = 1
	cfText.TextColor3 = Color3.fromRGB(255, 255, 255)
	cfText.TextSize = 18
	cfText.Font = Enum.Font.GothamBold
	cfText.Text = "SELL ALL PETS!"
	cfText.ZIndex = 12
	cfText.Parent = confirmFrame

	-- Cancel
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0, 110, 0, 36)
	cancelBtn.Position = UDim2.new(0, 20, 1, -52)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(80, 70, 60)
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.TextSize = 13
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.Text = "Cancel"
	cancelBtn.ZIndex = 12
	cancelBtn.Parent = confirmFrame

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelBtn

	-- Sell All confirm
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(0, 110, 0, 36)
	confirmBtn.Position = UDim2.new(1, -130, 1, -52)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(190, 55, 45)
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.TextSize = 13
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.Text = "SELL ALL!"
	confirmBtn.ZIndex = 12
	confirmBtn.Parent = confirmFrame

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmBtn

	local function closeConfirm()
		confirmOverlay:Destroy()
		confirmFrame:Destroy()
	end

	confirmOverlay.MouseButton1Click:Connect(closeConfirm)
	cancelBtn.MouseButton1Click:Connect(closeConfirm)

	confirmBtn.MouseButton1Click:Connect(function()
		local sellAllFunc = remotes:FindFirstChild("SellAllPets")
		if sellAllFunc then
			sellAllFunc:InvokeServer()
			closeConfirm()
			PetSellUI.hide()
			if _onSold then _onSold() end
		end
	end)

	-- Pop in animation
	confirmFrame.Size = UDim2.new(0, 240, 0, 130)
	TweenService:Create(confirmFrame, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 280, 0, 150),
	}):Play()
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
