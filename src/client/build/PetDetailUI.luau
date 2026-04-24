-- PetDetailUI.luau
-- Design UI: Features > PetInfo
-- Header: NameText, NameTextShadow, Rarity
-- Frame: Info, Jobs, Level(GaugeBar), Weight, Mutations, Buffs, Icon

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

	-- Header Close button
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

	-- 더미 텍스트 "test" 제거
	for _, desc in petInfoFrame:GetDescendants() do
		if desc:IsA("TextLabel") and desc.Text:lower():find("test") then
			desc.Text = ""
		end
	end

	-- === Header ===
	local header = petInfoFrame:FindFirstChild("Header")
	if header then
		-- Name: TextLabel 또는 NameText
		local nameText = header:FindFirstChild("NameText") or header:FindFirstChild("TextLabel")
		if nameText then nameText.Text = petData.petName or "???" end

		local nameShadow = header:FindFirstChild("NameTextShadow") or header:FindFirstChild("TextLabelShadow")
		if nameShadow then nameShadow.Text = petData.petName or "???" end

		-- Rarity
		local rarityFrame = header:FindFirstChild("Rarity")
		if rarityFrame then
			local rarityLabel = rarityFrame:FindFirstChild("TextLabel")
				or rarityFrame:FindFirstChildWhichIsA("TextLabel")
			if rarityLabel then
				local rarity = petData.rarity
			if not rarity or rarity == "" then
				rarity = petInfo and petInfo.rarity or "Common"
			end
			rarityLabel.Text = rarity
			end
		end
	end

	-- === Frame ===
	local frame = petInfoFrame:FindFirstChild("Frame")
	if not frame then
		petInfoFrame.Visible = true
		return
	end

	-- Info (Fortune) — hover only, hidden by default
	local infoFrame = frame:FindFirstChild("Info")
	if infoFrame then
		infoFrame.Visible = false
		-- Info 텍스트는 디자인 UI의 Fortune 더미 그대로 유지 (또는 업데이트)
	end

	-- Icon hover → show/hide Info (Fortune)
	local iconFrame = frame:FindFirstChild("Icon")
	if iconFrame and infoFrame and not iconFrame:GetAttribute("_hoverSet") then
		iconFrame:SetAttribute("_hoverSet", true)
		local hoverBtn = Instance.new("TextButton")
		hoverBtn.Name = "_Hover"
		hoverBtn.Size = UDim2.new(1, 0, 1, 0)
		hoverBtn.BackgroundTransparency = 1
		hoverBtn.Text = ""
		hoverBtn.ZIndex = 10
		hoverBtn.Parent = iconFrame
		hoverBtn.MouseEnter:Connect(function()
			infoFrame.Visible = true
		end)
		hoverBtn.MouseLeave:Connect(function()
			infoFrame.Visible = false
		end)
	end

	-- Jobs
	local jobsFrame = frame:FindFirstChild("Jobs")
	if jobsFrame then
		local textLabel = jobsFrame:FindFirstChild("TextLabel")
			or jobsFrame:FindFirstChildWhichIsA("TextLabel")
		if textLabel then
			local jobList = {}
			if petInfo and petInfo.petTypes then
				for _, pt in petInfo.petTypes do
					table.insert(jobList, Constants.PetType[pt] or pt)
				end
			else
				table.insert(jobList, Constants.PetType[petData.petType] or petData.petType or "?")
			end
			textLabel.Text = table.concat(jobList, ", ")
		end
	end

	-- Weight
	local weightFrame = frame:FindFirstChild("Weight")
	if weightFrame then
		local textLabel = weightFrame:FindFirstChild("TextLabel")
			or weightFrame:FindFirstChildWhichIsA("TextLabel")
		if textLabel then
			textLabel.Text = string.format("%.1fkg", petData.weight or 0)
		end
	end

	-- Level + GaugeBar (EXP)
	local levelFrame = frame:FindFirstChild("Level")
	if levelFrame then
		local textLabel = levelFrame:FindFirstChild("TextLabel")
			or levelFrame:FindFirstChildWhichIsA("TextLabel")
		if textLabel then
			textLabel.Text = "Level: " .. level
		end

		-- GaugeBar (EXP progress bar)
		local gaugeBar = levelFrame:FindFirstChild("GaugeBar")
			or levelFrame:FindFirstChildWhichIsA("Frame")
		if gaugeBar then
			local fill = gaugeBar:FindFirstChild("Fill")
				or gaugeBar:FindFirstChildWhichIsA("Frame")
			if fill then
				local ratio = if xpRequired > 0 then math.clamp(xp / xpRequired, 0, 1) else 1
				fill.Size = UDim2.new(ratio, 0, fill.Size.Y.Scale, fill.Size.Y.Offset)
			end

			local expLabel = gaugeBar:FindFirstChild("TextLabel")
				or gaugeBar:FindFirstChildWhichIsA("TextLabel")
			if expLabel then
				expLabel.Text = xp .. "/" .. (xpRequired > 0 and xpRequired or "MAX")
			end
		end
	end

	-- Mutations (Frame 또는 petInfoFrame에서 찾기)
	local mutationsFrame = frame:FindFirstChild("Mutations") or petInfoFrame:FindFirstChild("Mutations", true)
	if mutationsFrame then
		local textLabel = mutationsFrame:FindFirstChild("TextLabel")
			or mutationsFrame:FindFirstChildWhichIsA("TextLabel")
		if textLabel then
			if petData.mutations and #petData.mutations > 0 then
				local mutNames = {}
				for _, mut in petData.mutations do
					table.insert(mutNames, Constants.MUTATION_NAMES[mut] or mut)
				end
				textLabel.Text = table.concat(mutNames, ", ")
			else
				textLabel.Text = "None"
			end
		end
	end

	-- Buffs (Frame 또는 petInfoFrame에서 찾기)
	local buffsFrame = frame:FindFirstChild("Buffs") or petInfoFrame:FindFirstChild("Buffs", true)
	if buffsFrame then
		local textLabel = buffsFrame:FindFirstChild("TextLabel")
			or buffsFrame:FindFirstChildWhichIsA("TextLabel")
		if textLabel then
			if petData.traits and #petData.traits > 0 then
				textLabel.Text = table.concat(petData.traits, ", ")
			else
				textLabel.Text = "None"
			end
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
