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

	-- Frame 직속 Info만 호버 처리 (Fortune 팝업)
	local frame = petInfoFrame:FindFirstChild("Frame")
	if frame then
		local infoFrame = frame:FindFirstChild("Info")
		if infoFrame and infoFrame:IsA("Frame") then
			-- Info 텍스트에 설명 채우기
			local infoText = infoFrame:FindFirstChild("TextLabel")
			if infoText then
				local typeNames = {}
				if petInfo and petInfo.petTypes then
					for _, pt in petInfo.petTypes do
						table.insert(typeNames, Constants.PetType[pt] or pt)
					end
				end
				infoText.Text = (petData.petName or "") .. "\nSpecializes in: " .. table.concat(typeNames, ", ")
			end
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

	-- Level (2개 모두 업데이트)
	local levelFrames = {}
	for _, child in frame:GetChildren() do
		if child.Name == "Level" then
			table.insert(levelFrames, child)
		end
	end

	for _, lvlFrame in levelFrames do
		local nameText = lvlFrame:FindFirstChild("NameText")
		if nameText then nameText.Text = "Level: " .. level end
		local nameShadow = lvlFrame:FindFirstChild("NameTextShadow")
		if nameShadow then nameShadow.Text = "Level: " .. level end

		local gaugeBar = lvlFrame:FindFirstChild("GaugeBar")
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

	-- 모든 Info 프레임 숨기기 (Frame 직속 Info 제외한 나머지)
	local iconFrame = frame:FindFirstChild("Icon")

	-- 위쪽 Info (설명) — 호버로만 표시
	local infoFrame = frame:FindFirstChild("Info")
	if infoFrame then
		infoFrame.Visible = false

		if iconFrame and not iconFrame:GetAttribute("_infoHover") then
			iconFrame:SetAttribute("_infoHover", true)
			local hoverBtn = Instance.new("TextButton")
			hoverBtn.Name = "_InfoHover"
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
	end

	-- 나머지 Info 프레임도 호버로 (Fortune 등 — 부모에 마우스 대면 보이기)
	for _, desc in frame:GetDescendants() do
		if desc.Name == "Info" and desc:IsA("Frame") and desc ~= infoFrame then
			desc.Visible = false
			local parent = desc.Parent
			if parent and not parent:GetAttribute("_infoHover") then
				parent:SetAttribute("_infoHover", true)
				local btn = Instance.new("TextButton")
				btn.Name = "_Hover"
				btn.Size = UDim2.new(1, 0, 1, 0)
				btn.BackgroundTransparency = 1
				btn.Text = ""
				btn.ZIndex = 10
				btn.Parent = parent
				btn.MouseEnter:Connect(function()
					desc.Visible = true
				end)
				btn.MouseLeave:Connect(function()
					desc.Visible = false
				end)
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
