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
local _currentPetId = nil
local _onHold = nil

function PetDetailUI.init(callbacks: { onHold: ((string) -> ())? }?)
	_onHold = callbacks and callbacks.onHold or nil

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

	-- PopUp (Hold button) - Features > PopUp
	local popUp = featuresGui:FindFirstChild("PopUp")
	if popUp then
		local holdBtn = popUp:FindFirstChildWhichIsA("TextButton", true)
			or popUp:FindFirstChildWhichIsA("ImageButton", true)
		if holdBtn then
			holdBtn.MouseButton1Click:Connect(function()
				if _currentPetId and _onHold then
					_onHold(_currentPetId)
					PetDetailUI.hide()
				end
			end)
		end
	end
end

function PetDetailUI.show(petData: { [string]: any })
	if not petInfoFrame then return end
	_visible = true
	_currentPetId = petData.petId

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

		local function setJobTransparency(jobFrame, enabled)
			if not jobFrame then return end
			jobFrame.Visible = true
			local t = if enabled then 0 else 0.8
			-- jobFrame 자체가 ImageLabel일 수 있음
			if jobFrame:IsA("ImageLabel") or jobFrame:IsA("ImageButton") then
				jobFrame.ImageTransparency = t
			end
			if jobFrame:IsA("TextLabel") then
				jobFrame.Visible = enabled
			end
			-- 자식도 처리
			for _, desc in jobFrame:GetDescendants() do
				if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
					desc.ImageTransparency = t
				elseif desc:IsA("TextLabel") then
					desc.Visible = enabled
				end
			end
		end

		-- Debug: print job frame children
		for _, child in jobsFrame:GetChildren() do
			print("[PetDetail] Job child: " .. child.Name .. " (" .. child.ClassName .. ")")
		end

		setJobTransparency(jobsFrame:FindFirstChild("Farming"), petTypes["Farming"] == true)
		setJobTransparency(jobsFrame:FindFirstChild("Mining"), petTypes["Mining"] == true)
		setJobTransparency(jobsFrame:FindFirstChild("Building"), petTypes["Construction"] == true)
	end

	-- Icon: ViewportFrame으로 3D 펫 모델 표시
	local iconFrame = frame:FindFirstChild("Icon")
	if iconFrame then
		-- 기존 이미지 숨기기
		if iconFrame:IsA("ImageLabel") then
			iconFrame.Image = ""
		end

		-- 기존 ViewportFrame 제거
		local oldVP = iconFrame:FindFirstChild("_PetViewport")
		if oldVP then oldVP:Destroy() end

		-- 월드에서 해당 펫 모델 찾기 (Pet_{petId})
		local petModel = nil
		local plotsFolder = workspace:FindFirstChild("Plots")
		if plotsFolder then
			for _, plot in plotsFolder:GetChildren() do
				if plot:GetAttribute("Owner") == game:GetService("Players").LocalPlayer.Name then
					for _, desc in plot:GetDescendants() do
						if desc:GetAttribute("PetId") == petData.petId then
							-- 최상위 Model 찾기
							local mdl = desc
							local cur = desc.Parent
							while cur and cur ~= plot do
								if cur:IsA("Model") then mdl = cur end
								cur = cur.Parent
							end
							if mdl:IsA("Model") then
								petModel = mdl
							end
							break
						end
					end
					break
				end
			end
		end

		if petModel then
			local vpf = Instance.new("ViewportFrame")
			vpf.Name = "_PetViewport"
			vpf.Size = UDim2.new(1, 0, 1, 0)
			vpf.BackgroundTransparency = 1
			vpf.ZIndex = 2
			vpf.Parent = iconFrame

			local clone = petModel:Clone()
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
	end

	-- Info (설명) — 항상 보이기
	local infoFrame = frame:FindFirstChild("Info")
	if infoFrame then
		infoFrame.Visible = true
	end

	-- Buffs (해/클로버) 임시 UI 제거
	if iconFrame then
		local buffsFrame = iconFrame:FindFirstChild("Buffs")
		if buffsFrame then
			buffsFrame.Visible = false
		end
	end

	-- 하위 Fortune Info 숨기기
	for _, desc in frame:GetDescendants() do
		if desc.Name == "Info" and desc:IsA("Frame") and desc ~= infoFrame then
			desc.Visible = false
		end
	end

	-- 3D 캐릭터에 가리지 않도록 DisplayOrder 높이기
	local featuresGui = petInfoFrame:FindFirstAncestorWhichIsA("ScreenGui")
	if featuresGui then
		featuresGui.DisplayOrder = 100
	end

	petInfoFrame.Visible = true
end

function PetDetailUI.getCurrentPetId(): string?
	return _currentPetId
end

function PetDetailUI.hide()
	if not petInfoFrame then return end
	_visible = false
	_currentPetId = nil
	petInfoFrame.Visible = false
end

function PetDetailUI.isVisible(): boolean
	return _visible
end

function PetDetailUI.destroy()
end

return PetDetailUI
