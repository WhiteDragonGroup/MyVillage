-- EggInfoUI.luau
-- Design UI: Features > PetHatchRates (egg list) + Features > Odds (pet pool detail)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local EggCfg = BalanceConfig.Egg

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EggInfoUI = {}

local hatchRatesFrame = nil
local oddsFrame = nil
local _visible = false
local _oddsSlotTemplate = nil

function EggInfoUI.init()
	local featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then return end

	hatchRatesFrame = featuresGui:FindFirstChild("PetHatchRates")
	oddsFrame = featuresGui:FindFirstChild("Odds")

	if hatchRatesFrame then
		hatchRatesFrame.Visible = false

		-- Close button
		local header = hatchRatesFrame:FindFirstChild("Header")
		if header then
			local closeBtn = header:FindFirstChild("Close")
			if closeBtn and closeBtn:IsA("GuiButton") then
				closeBtn.MouseButton1Click:Connect(function()
					EggInfoUI.hide()
				end)
			end
		end

		-- Find egg slots and connect info (!) buttons
		for _, child in hatchRatesFrame:GetChildren() do
			if child:IsA("GuiObject") and child.Name ~= "Header" and child.Name ~= "Shadows" then
				local infoBtn = child:FindFirstChildWhichIsA("ImageButton", true)
					or child:FindFirstChildWhichIsA("TextButton", true)
				if infoBtn then
					local eggId = EggInfoUI._matchEggId(child)
					if eggId then
						infoBtn.MouseButton1Click:Connect(function()
							EggInfoUI._showOdds(eggId)
						end)
					end
				end
			end
		end
	end

	if oddsFrame then
		oddsFrame.Visible = false

		-- Close button on Odds
		local header = oddsFrame:FindFirstChild("Header")
		if header then
			local closeBtn = header:FindFirstChild("Close")
			if closeBtn and closeBtn:IsA("GuiButton") then
				closeBtn.MouseButton1Click:Connect(function()
					EggInfoUI._hideOdds()
				end)
			end
		end

		-- Save slot template from ScrollingFrame
		local scrollFrame = oddsFrame:FindFirstChild("ScrollingFrame")
		if scrollFrame then
			for _, child in scrollFrame:GetChildren() do
				if child:IsA("GuiObject") and child.Name == "Frame" then
					_oddsSlotTemplate = child:Clone()
					break
				end
			end
		end
	end
end

-- Match a frame to an egg ID based on name/text
function EggInfoUI._matchEggId(frame): string?
	local name = frame.Name:lower()
	local textLabel = frame:FindFirstChildWhichIsA("TextLabel", true)
	local text = textLabel and textLabel.Text:lower() or ""

	if name:find("common") or text:find("common") then return "Egg_Common" end
	if name:find("legendary") or text:find("legendary") then return "Egg_Legendary" end
	if name:find("epic") or text:find("epic") then return "Egg_Epic" end
	if name:find("rare") or text:find("rare") then return "Egg_Rare" end

	return nil
end

-- Calculate each pet's hatch probability within an egg
local function calcPetProbabilities(eggData)
	local rarityWeights = eggData.rarityWeights
	local petPool = eggData.petPool

	local rarityCount = {}
	for _, pet in petPool do
		rarityCount[pet.rarity] = (rarityCount[pet.rarity] or 0) + 1
	end

	local result = {}
	for _, pet in petPool do
		local rarityWeight = rarityWeights[pet.rarity] or 0
		local count = rarityCount[pet.rarity] or 1
		table.insert(result, {
			petName = pet.petName,
			rarity = pet.rarity,
			chance = rarityWeight / count,
		})
	end

	table.sort(result, function(a, b) return a.chance > b.chance end)
	return result
end

-- Show Odds UI with pet pool for given egg
function EggInfoUI._showOdds(eggId: string)
	if not oddsFrame then return end

	local eggData = EggCfg.EGGS[eggId]
	if not eggData then return end

	-- Update header text
	local header = oddsFrame:FindFirstChild("Header")
	if header then
		local titleText = header:FindFirstChild("TextLabel")
			or header:FindFirstChildWhichIsA("TextLabel")
		if titleText then
			titleText.Text = eggData.name .. " Odds"
		end
		local titleShadow = header:FindFirstChild("TextLabelShadow")
		if titleShadow then
			titleShadow.Text = eggData.name .. " Odds"
		end
	end

	-- Populate ScrollingFrame
	local scrollFrame = oddsFrame:FindFirstChild("ScrollingFrame")
	if scrollFrame then
		-- Clear existing slots
		for _, child in scrollFrame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local petProbs = calcPetProbabilities(eggData)

		if _oddsSlotTemplate then
			-- Use design template
			for i, petProb in petProbs do
				local petInfo = Constants.PETS[petProb.petName]
				local petRarityColor = Constants.RARITY_COLORS[petProb.rarity] or Color3.fromRGB(180, 180, 180)

				local slot = _oddsSlotTemplate:Clone()
				slot.Name = "Slot_" .. i
				slot.Visible = true
				slot.LayoutOrder = i
				slot.Parent = scrollFrame

				-- Try to fill name
				local nameText = slot:FindFirstChild("NameText")
					or slot:FindFirstChild("TextLabel")
					or slot:FindFirstChildWhichIsA("TextLabel")
				if nameText then
					nameText.Text = (petInfo and petInfo.name) or petProb.petName
				end
				local nameShadow = slot:FindFirstChild("NameTextShadow")
				if nameShadow then
					nameShadow.Text = (petInfo and petInfo.name) or petProb.petName
				end

				-- Rarity
				local rarityFrame = slot:FindFirstChild("Rarity")
				if rarityFrame then
					local rarityLabel = rarityFrame:FindFirstChild("TextLabel")
						or rarityFrame:FindFirstChildWhichIsA("TextLabel")
					if rarityLabel then
						rarityLabel.Text = petProb.rarity
					end
				end

				-- Chance / Odds text
				local oddsText = slot:FindFirstChild("OddsText")
					or slot:FindFirstChild("Chance")
					or slot:FindFirstChild("PriceText")
				if oddsText then
					oddsText.Text = string.format("%.1f%%", petProb.chance)
				end
			end
		else
			-- Fallback: code-generated slots
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 4)
			layout.Parent = scrollFrame

			for i, petProb in petProbs do
				local petInfo = Constants.PETS[petProb.petName]
				local petRarityColor = Constants.RARITY_COLORS[petProb.rarity] or Color3.fromRGB(180, 180, 180)

				local slot = Instance.new("Frame")
				slot.Size = UDim2.new(1, -4, 0, 36)
				slot.BackgroundColor3 = Color3.fromRGB(50, 45, 35)
				slot.BackgroundTransparency = 0.3
				slot.LayoutOrder = i
				slot.Parent = scrollFrame

				local slotCorner = Instance.new("UICorner")
				slotCorner.CornerRadius = UDim.new(0, 6)
				slotCorner.Parent = slot

				local slotStroke = Instance.new("UIStroke")
				slotStroke.Color = petRarityColor
				slotStroke.Thickness = 1
				slotStroke.Parent = slot

				local petNameLabel = Instance.new("TextLabel")
				petNameLabel.Size = UDim2.new(0, 160, 0, 36)
				petNameLabel.Position = UDim2.new(0, 8, 0, 0)
				petNameLabel.BackgroundTransparency = 1
				petNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				petNameLabel.TextSize = 12
				petNameLabel.Font = Enum.Font.GothamBold
				petNameLabel.Text = (petInfo and petInfo.name) or petProb.petName
				petNameLabel.TextXAlignment = Enum.TextXAlignment.Left
				petNameLabel.Parent = slot

				local rarityLabel = Instance.new("TextLabel")
				rarityLabel.Size = UDim2.new(0, 60, 0, 36)
				rarityLabel.Position = UDim2.new(0, 170, 0, 0)
				rarityLabel.BackgroundTransparency = 1
				rarityLabel.TextColor3 = petRarityColor
				rarityLabel.TextSize = 9
				rarityLabel.Font = Enum.Font.Gotham
				rarityLabel.Text = petProb.rarity
				rarityLabel.Parent = slot

				local chanceLabel = Instance.new("TextLabel")
				chanceLabel.Size = UDim2.new(0, 50, 0, 36)
				chanceLabel.Position = UDim2.new(1, -58, 0, 0)
				chanceLabel.BackgroundTransparency = 1
				chanceLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
				chanceLabel.TextSize = 13
				chanceLabel.Font = Enum.Font.GothamBold
				chanceLabel.Text = string.format("%.1f%%", petProb.chance)
				chanceLabel.TextXAlignment = Enum.TextXAlignment.Right
				chanceLabel.Parent = slot
			end
		end
	end

	oddsFrame.Visible = true
end

function EggInfoUI._hideOdds()
	if oddsFrame then
		oddsFrame.Visible = false
	end
end

function EggInfoUI.show()
	if not hatchRatesFrame then return end
	_visible = true
	hatchRatesFrame.Visible = true
end

function EggInfoUI.hide()
	_visible = false
	if hatchRatesFrame then
		hatchRatesFrame.Visible = false
	end
	EggInfoUI._hideOdds()
end

function EggInfoUI.isVisible(): boolean
	return _visible
end

return EggInfoUI
