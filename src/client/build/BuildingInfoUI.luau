-- BuildingInfoUI.luau
-- 마을(빌드모드 외)에서 건물 클릭 시 우측에 상세 페이지 표시
-- Features.BuildingInfo 디자인 사용

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local UpgradeCfg = BalanceConfig.Upgrade

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local BuildingInfoUI = {}

local _frame: GuiObject? = nil
local _onUpgrade = nil
local _currentBuildingId: string? = nil
local _visible = false

local function findChild(parent: Instance, names: { string }): Instance?
	for _, n in names do
		local c = parent:FindFirstChild(n, true)
		if c then return c end
	end
	return nil
end

local function setText(parent: Instance, names: { string }, text: string)
	local c = findChild(parent, names)
	if c and (c:IsA("TextLabel") or c:IsA("TextButton") or c:IsA("TextBox")) then
		c.Text = text
	end
end

function BuildingInfoUI.init(callbacks: { onUpgrade: ((string) -> ())? }?)
	_onUpgrade = callbacks and callbacks.onUpgrade or nil

	local featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then return end

	_frame = featuresGui:FindFirstChild("BuildingInfo")
	if not _frame then
		warn("[BuildingInfoUI] Features.BuildingInfo 없음")
		return
	end
	_frame.Visible = false

	-- 닫기 버튼이 있을 수도 있음
	local closeBtn = findChild(_frame, { "Close", "CloseButton" })
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.MouseButton1Click:Connect(function()
			BuildingInfoUI.hide()
		end)
	end

	-- Upgrade 버튼 (Frame.Upgrade or BuildingInfo.Upgrade)
	local frame = _frame:FindFirstChild("Frame") or _frame
	local upgradeBtn = frame:FindFirstChild("Upgrade")
	if upgradeBtn and upgradeBtn:IsA("GuiButton") then
		upgradeBtn.MouseButton1Click:Connect(function()
			if _currentBuildingId and _onUpgrade then
				_onUpgrade(_currentBuildingId)
			end
		end)
	elseif upgradeBtn then
		-- Frame이면 내부 버튼 또는 버튼 추가
		local innerBtn = upgradeBtn:FindFirstChildWhichIsA("GuiButton", true)
		if innerBtn then
			innerBtn.MouseButton1Click:Connect(function()
				if _currentBuildingId and _onUpgrade then
					_onUpgrade(_currentBuildingId)
				end
			end)
		end
	end
end

local function getBuildingModel(building: BasePart): (Model | BasePart)
	-- 건물의 최상위 Model 찾기 (플롯에 도달하기 전까지 가장 위 Model)
	local topModel = nil
	local current = building.Parent
	while current and current ~= workspace do
		if current:GetAttribute("Owner") ~= nil then break end
		if current.Name == "Plots" then break end
		if current:IsA("Model") then
			topModel = current
		end
		current = current.Parent
	end
	return topModel or building
end

function BuildingInfoUI.show(building: BasePart)
	if not _frame then return end

	local itemName = building:GetAttribute("ItemName") or ""
	local buildingId = building:GetAttribute("BuildingId") or ""
	local level = building:GetAttribute("Level") or 1

	local info = Constants.BUILDINGS[itemName]
	local displayName = (info and info.name) or itemName
	local rarity = (info and info.rarity) or "Common"

	_currentBuildingId = buildingId
	_visible = true

	-- Icon: ViewportFrame으로 3D 건물 모델 표시
	local frameRoot = _frame:FindFirstChild("Frame") or _frame
	local iconFrame = frameRoot:FindFirstChild("Icon")
	if iconFrame then
		if iconFrame:IsA("ImageLabel") then
			iconFrame.Image = ""
		end

		local oldVP = iconFrame:FindFirstChild("_BuildingViewport")
		if oldVP then oldVP:Destroy() end

		local source = getBuildingModel(building)
		local clone = source:Clone()
		-- 앵커 처리
		if clone:IsA("BasePart") then
			clone.Anchored = true
		else
			for _, p in clone:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
				end
			end
		end

		local vpf = Instance.new("ViewportFrame")
		vpf.Name = "_BuildingViewport"
		vpf.Size = UDim2.new(1, 0, 1, 0)
		vpf.BackgroundTransparency = 1
		vpf.LightDirection = Vector3.new(-0.4, -1, -0.3).Unit
		vpf.LightColor = Color3.fromRGB(255, 245, 220)
		vpf.Ambient = Color3.fromRGB(120, 110, 100)
		vpf.ZIndex = 2
		vpf.Parent = iconFrame

		clone.Parent = vpf

		local camera = Instance.new("Camera")
		vpf.CurrentCamera = camera
		camera.Parent = vpf

		local cf, size
		if clone:IsA("Model") then
			cf, size = clone:GetBoundingBox()
		else
			cf = clone.CFrame
			size = clone.Size
		end
		local maxDim = math.max(size.X, size.Y, size.Z)
		camera.CFrame = CFrame.lookAt(
			cf.Position + Vector3.new(maxDim * 0.55, maxDim * 0.3, maxDim * 0.85),
			cf.Position
		)
	end

	-- 헤더 텍스트 (이름 + 레벨)
	local header = _frame:FindFirstChild("Header")
	if header then
		setText(header, { "TextLabel" }, string.format("%s LV.%d", displayName, level))
		setText(header, { "TextLabelShadow" }, string.format("%s LV.%d", displayName, level))

		-- 등급 텍스트 + 색상
		local rarityFrame = header:FindFirstChild("Rarity")
		if rarityFrame then
			setText(rarityFrame, { "TextLabel", "Rarity" }, rarity)
		end
	end

	-- Info 영역 (text TEST 등)
	local frame = _frame:FindFirstChild("Frame") or _frame
	local infoFrame = frame:FindFirstChild("Info")
	if infoFrame then
		local description = info and info.description or "A useful building."
		setText(infoFrame, { "TextLabel", "InfoText", "Description" }, description)
	end

	-- 업그레이드 정보 (현재 레벨 → 다음 레벨, 비용)
	local upgradeFrame = frame:FindFirstChild("Upgrade")
	if upgradeFrame then
		local maxLevel = (UpgradeCfg and UpgradeCfg.MAX_LEVEL) or 5
		if level >= maxLevel then
			setText(upgradeFrame, { "Level", "LevelText" }, "MAX")
			setText(upgradeFrame, { "Cost", "CostText" }, "")
		else
			local cost = 0
			if UpgradeCfg and UpgradeCfg.COST then
				cost = UpgradeCfg.COST[level] or 0
			end
			setText(upgradeFrame, { "Level", "LevelText" }, string.format("Level %d→%d", level, level + 1))
			setText(upgradeFrame, { "Cost", "CostText" }, "Cost: $" .. cost)
		end
	end

	_frame.Visible = true
end

function BuildingInfoUI.hide()
	_visible = false
	_currentBuildingId = nil
	if _frame then _frame.Visible = false end
end

function BuildingInfoUI.isVisible(): boolean
	return _visible
end

function BuildingInfoUI.getCurrentBuildingId(): string?
	return _currentBuildingId
end

return BuildingInfoUI
