-- PetDetailUI.luau
-- Design UI: Features > PetInfo

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PetDetailUI = {}

local petInfoFrame = nil
local _visible = false

function PetDetailUI.init()
	local featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then return end

	petInfoFrame = featuresGui:FindFirstChild("PetInfo")
	if not petInfoFrame then return end

	petInfoFrame.Visible = false

	local header = petInfoFrame:FindFirstChild("Header")
	if header then
		local closeBtn = header:FindFirstChild("Close")
			or header:FindFirstChildWhichIsA("ImageButton")
			or header:FindFirstChildWhichIsA("TextButton")
		if closeBtn and closeBtn:IsA("GuiButton") then
			closeBtn.MouseButton1Click:Connect(function()
				PetDetailUI.hide()
			end)
		end
	end
end

function PetDetailUI.show(petData: { [string]: any })
	if not petInfoFrame then return end
	_visible = true

	local petInfo = Constants.PETS[petData.petName]
	local level = petData.level or 1
	local xp = petData.xp or 0
	local xpRequired = BalanceConfig.Pet.XP_REQUIRED[level] or 0

	-- === Hide all hover Info frames ===
	for _, desc in petInfoFrame:GetDescendants() do
		if desc.Name == "Info" and desc:IsA("Frame") then
			desc.Visible = false
		end
	end

	-- === Header: Name + Rarity ===
	local header = petInfoFrame:FindFirstChild("Header")
	if header then
		local nameText = header:FindFirstChild("TextLabel")
		if nameText then nameText.Text = petData.petName or "???" end

		local nameShadow = header:FindFirstChild("TextLabelShadow")
		if nameShadow then nameShadow.Text = petData.petName or "???" end

		local rarityFrame = header:FindFirstChild("Rarity")
		if rarityFrame then
			local rarityLabel = rarityFrame:FindFirstChild("TextLabel")
			if rarityLabel then
				rarityLabel.Text = (petInfo and petInfo.rarity) or petData.rarity or "Common"
			end
		end
	end

	-- === Frame ===
	local frame = petInfoFrame:FindFirstChild("Frame")
	if not frame then
		petInfoFrame.Visible = true
		return
	end

	-- Level (2개 — 첫 번째: 레벨 표시)
	local levelFrames = {}
	for _, child in frame:GetChildren() do
		if child.Name == "Level" then
			table.insert(levelFrames, child)
		end
	end

	if levelFrames[1] then
		local nameText = levelFrames[1]:FindFirstChild("NameText")
		if nameText then nameText.Text = "Level: " .. level end
		local nameShadow = levelFrames[1]:FindFirstChild("NameTextShadow")
		if nameShadow then nameShadow.Text = "Level: " .. level end

		local gaugeBar = levelFrames[1]:FindFirstChild("GaugeBar")
		if gaugeBar then
			local gauge = gaugeBar:FindFirstChild("Gauge")
			if gauge then
				local ratio = if xpRequired > 0 then math.clamp(xp / xpRequired, 0, 1) else 1
				gauge.Size = UDim2.new(ratio, 0, gauge.Size.Y.Scale, gauge.Size.Y.Offset)
			end
			local expLabel = gaugeBar:FindFirstChild("EXP")
			if expLabel then
				expLabel.Text = xp .. "/" .. (xpRequired > 0 and xpRequired or "MAX")
			end
		end
	end

	-- Weight > Weight (무게 텍스트)
	local weightFrame = frame:FindFirstChild("Weight")
	if weightFrame then
		local weightLabel = weightFrame:FindFirstChild("Weight")
		if weightLabel and weightLabel:IsA("TextLabel") then
			weightLabel.Text = string.format("Weight : %.1fkg", petData.weight or 0)
		end

		-- Weight > Mutations (돌연변이 텍스트)
		local mutLabel = weightFrame:FindFirstChild("Mutations")
		if mutLabel and mutLabel:IsA("TextLabel") then
			if petData.mutations and #petData.mutations > 0 then
				local mutNames = {}
				for _, mut in petData.mutations do
					table.insert(mutNames, Constants.MUTATION_NAMES[mut] or mut)
				end
				mutLabel.Text = "Mutations : " .. table.concat(mutNames, ", ")
			else
				mutLabel.Text = "Mutations : None"
			end
		end
	end

	-- Jobs (Farming/Mining/Building — 해당하는 것만 보이기)
	local jobsFrame = frame:FindFirstChild("Jobs")
	if jobsFrame then
		local petTypes = {}
		if petInfo and petInfo.petTypes then
			for _, pt in petInfo.petTypes do
				petTypes[pt] = true
			end
		else
			petTypes[petData.petType or "Construction"] = true
		end

		local farming = jobsFrame:FindFirstChild("Farming")
		if farming then farming.Visible = petTypes["Farming"] == true end

		local mining = jobsFrame:FindFirstChild("Mining")
		if mining then mining.Visible = petTypes["Mining"] == true end

		local building = jobsFrame:FindFirstChild("Building")
		if building then building.Visible = (petTypes["Construction"] == true) end
	end

	-- Icon > Buffs
	local iconFrame = frame:FindFirstChild("Icon")
	if iconFrame then
		local buffsFrame = iconFrame:FindFirstChild("Buffs")
		if buffsFrame then
			-- TODO: 실제 버프 데이터로 업데이트
		end
	end

	petInfoFrame.Visible = true
end

function PetDetailUI.hide()
	if not petInfoFrame then return end
	_visible = false
	petInfoFrame.Visible = false
end

function PetDetailUI.isVisible(): boolean
	return _visible
end

function PetDetailUI.destroy()
end

return PetDetailUI
