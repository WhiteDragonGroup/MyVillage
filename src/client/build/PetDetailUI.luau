-- PetDetailUI.luau
-- Design UI: Features > PetInfo

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local BuffCfg = BalanceConfig.Buff

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getPetBuffsFunc = remotes:WaitForChild("GetPetBuffs")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PetDetailUI = {}

local petInfoFrame = nil
local _visible = false
local _currentPetId = nil
local _onHold = nil
local _pickUpFrames = {} -- 표시/숨김 동기화용
local _buffPollToken = 0 -- 버프 폴링 루프 토큰 (재진입 방지)

-- 현재 활성 버프 목록을 Buffs 슬롯에 렌더 (아이콘 + 남은시간 + 툴팁).
-- activeList: { { buffId, remaining }, ... } — 비어있으면 모든 슬롯 숨김.
local function renderBuffSlots(activeList: { { buffId: string, remaining: number } })
	if not petInfoFrame then return end
	local frame = petInfoFrame:FindFirstChild("Frame")
	if not frame then return end
	local iconFrame = frame:FindFirstChild("Icon")
	if not iconFrame then return end
	local buffsFrame = iconFrame:FindFirstChild("Buffs")
	if not buffsFrame then return end
	buffsFrame.Visible = true

	local slots = {}
	for _, child in buffsFrame:GetChildren() do
		if child:IsA("ImageLabel") or child:IsA("ImageButton") then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b) return a.Name < b.Name end)

	-- 일부 슬롯에만 Info(툴팁)가 있는 경우 대비: 있는 슬롯에서 템플릿을 떠 둔다.
	local infoTemplate = nil
	for _, slot in slots do
		local info = slot:FindFirstChild("Info")
		if info then
			infoTemplate = info
			break
		end
	end

	for i, slot in slots do
		local entry = activeList[i]
		local slotInfo = slot:FindFirstChild("Info")
		-- Info가 없는 슬롯엔 템플릿을 복제해 넣어 호버/설명이 모두 동작하게 함.
		if not slotInfo and infoTemplate and slot ~= infoTemplate.Parent then
			slotInfo = infoTemplate:Clone()
			slotInfo.Name = "Info"
			slotInfo.Parent = slot
		end
		-- 디자인 슬롯에 이미 있는 시간 라벨(직속 TextLabel) 재사용. 없을 때만 _TimeLabel 생성.
		-- (Info 안의 설명 TextLabel은 직속이 아니라 안 잡힘 → 시간 라벨 중복 방지)
		local timeLabel = slot:FindFirstChild("_TimeLabel") or slot:FindFirstChild("TextLabel")
		if entry then
			local buffId = entry.buffId
			local buffDef = BuffCfg.BUFFS[buffId]
			local iconId = (Constants.BUFF_ICONS and Constants.BUFF_ICONS[buffId])
				or (buffDef and buffDef.icon) or ""
			slot.Image = iconId
			slot.Visible = true

			-- 남은시간 라벨 (없으면 생성)
			if not timeLabel then
				timeLabel = Instance.new("TextLabel")
				timeLabel.Name = "_TimeLabel"
				timeLabel.Size = UDim2.new(1, 0, 0.35, 0)
				timeLabel.Position = UDim2.new(0, 0, 0.65, 0)
				timeLabel.BackgroundTransparency = 1
				timeLabel.TextScaled = true
				timeLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
				timeLabel.TextColor3 = Color3.new(1, 1, 1)
				timeLabel.TextStrokeTransparency = 0.4
				timeLabel.ZIndex = 10
				timeLabel.Parent = slot
			end
			timeLabel.Visible = true
			timeLabel.Text = tostring(math.ceil(entry.remaining)) .. "s"

			-- 툴팁 (호버 시 설명)
			if slotInfo and slotInfo:IsA("GuiObject") then
				local descLabel = slotInfo:FindFirstChildWhichIsA("TextLabel", true)
				if descLabel and buffDef then
					local desc = (buffDef.description or ""):gsub("{n}", tostring(buffDef.value or ""))
					descLabel.Text = (buffDef.name or buffId) .. "\n" .. desc
				end
				slotInfo.Visible = false
				if not slot:GetAttribute("_HoverWired") then
					slot:SetAttribute("_HoverWired", true)
					slot.MouseEnter:Connect(function()
						if slotInfo and slotInfo.Parent then slotInfo.Visible = true end
					end)
					slot.MouseLeave:Connect(function()
						if slotInfo and slotInfo.Parent then slotInfo.Visible = false end
					end)
				end
			end
		else
			slot.Visible = false
			if timeLabel then timeLabel.Visible = false end
			if slotInfo and slotInfo:IsA("GuiObject") then slotInfo.Visible = false end
		end
	end
end

-- 서버에서 현재 펫의 활성 버프를 조회해 렌더
local function refreshActiveBuffs()
	if not _currentPetId then return end
	local petId = _currentPetId
	local ok, list = pcall(function()
		return getPetBuffsFunc:InvokeServer(petId)
	end)
	if ok and type(list) == "table" and _currentPetId == petId then
		renderBuffSlots(list)
	end
end

-- 상세 UI가 열려있는 동안 1초마다 버프 새로고침 (카운트다운/만료 반영)
local function startBuffPolling()
	_buffPollToken += 1
	local myToken = _buffPollToken
	task.spawn(function()
		while _visible and _currentPetId and myToken == _buffPollToken do
			refreshActiveBuffs()
			task.wait(1)
		end
	end)
end

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

	-- PickUp 버튼: Features 직속 PickUp만 사용 (캐릭터 아래에 표시되는 버튼)
	local pickUpCandidates = {
		featuresGui:FindFirstChild("PickUp"),
	}
	for _, pickUp in pickUpCandidates do
		if not pickUp then continue end
		-- 초기 숨김 + 추적 등록
		if pickUp:IsA("GuiObject") then
			pickUp.Visible = false
			table.insert(_pickUpFrames, pickUp)
		end
		-- 클릭 버튼 연결
		local pickBtn
		if pickUp:IsA("GuiButton") then
			pickBtn = pickUp
		else
			pickBtn = pickUp:FindFirstChildWhichIsA("TextButton", true)
				or pickUp:FindFirstChildWhichIsA("ImageButton", true)
		end
		if pickBtn then
			pickBtn.MouseButton1Click:Connect(function()
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

	-- PickUp 버튼 노출
	for _, f in _pickUpFrames do
		if f and f.Parent then f.Visible = true end
	end

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

		setJobTransparency(jobsFrame:FindFirstChild("Farming"), petTypes["Farming"] == true)
		setJobTransparency(jobsFrame:FindFirstChild("Mining"), petTypes["Mining"] == true)
		setJobTransparency(jobsFrame:FindFirstChild("Building"), petTypes["Construction"] == true)
	end

	-- Icon: 2D 이미지 (PET_ICONS)
	local iconFrame = frame:FindFirstChild("Icon")
	if iconFrame then
		-- 기존 ViewportFrame 제거 (이전 버전 잔재)
		local oldVP = iconFrame:FindFirstChild("_PetViewport")
		if oldVP then oldVP:Destroy() end

		local iconId = Constants.getPetIcon and Constants.getPetIcon(petData.petName) or ""
		if iconFrame:IsA("ImageLabel") or iconFrame:IsA("ImageButton") then
			iconFrame.Image = iconId
		else
			local img = iconFrame:FindFirstChild("_PetIcon")
			if not img then
				img = Instance.new("ImageLabel")
				img.Name = "_PetIcon"
				img.Size = UDim2.new(1, 0, 1, 0)
				img.BackgroundTransparency = 1
				img.ScaleType = Enum.ScaleType.Fit
				img.ZIndex = 2
				img.Parent = iconFrame
			end
			img.Image = iconId
		end
	end

	-- Info (설명) — 항상 보이기
	local infoFrame = frame:FindFirstChild("Info")
	if infoFrame then
		infoFrame.Visible = true
	end

	-- Buffs: 현재 활성 버프를 실시간 표시 (1초마다 폴링, 남은시간 카운트다운)
	startBuffPolling()

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
	for _, f in _pickUpFrames do
		if f and f.Parent then f.Visible = false end
	end
end

function PetDetailUI.isVisible(): boolean
	return _visible
end

function PetDetailUI.destroy()
end

return PetDetailUI
