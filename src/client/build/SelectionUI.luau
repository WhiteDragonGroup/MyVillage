-- SelectionUI.luau
-- 디자인 UI 사용 (StarterGui/BuildMode/Select)
-- Select는 Folder이므로 자식 GuiObject의 Visible로 제어

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SelectionUI = {}

local selectFolder = nil
local _callbacks = {}
local _upgradeBtn = nil
local _moveBtn = nil
local _storeBtn = nil
local _cancleBtn = nil

local function setAllVisible(visible: boolean)
	if not selectFolder then return end
	for _, child in selectFolder:GetChildren() do
		if child:IsA("GuiObject") then
			child.Visible = visible
		end
	end
end

function SelectionUI.init(callbacks: {
	onStore: () -> (),
	onCancel: () -> (),
	onMove: () -> (),
	onUpgrade: () -> (),
	onCancelUpgrade: () -> (),
})
	_callbacks = callbacks

	local buildModeGui = playerGui:WaitForChild("BuildMode", 10)
	if not buildModeGui then
		warn("[SelectionUI] BuildMode ScreenGui를 찾을 수 없음")
		return
	end

	selectFolder = buildModeGui:FindFirstChild("Select")
	if not selectFolder then
		warn("[SelectionUI] Select 폴더를 찾을 수 없음")
		return
	end

	-- 초기 숨김
	setAllVisible(false)

	_cancleBtn = selectFolder:FindFirstChild("Cancle")
	_moveBtn = selectFolder:FindFirstChild("Move")
	_storeBtn = selectFolder:FindFirstChild("Store")
	_upgradeBtn = selectFolder:FindFirstChild("Upgrade")

	if _cancleBtn and _cancleBtn:IsA("GuiButton") then
		_cancleBtn.MouseButton1Click:Connect(function()
			if _callbacks.onCancel then _callbacks.onCancel() end
		end)
	end

	if _moveBtn and _moveBtn:IsA("GuiButton") then
		_moveBtn.MouseButton1Click:Connect(function()
			if _callbacks.onMove then _callbacks.onMove() end
		end)
	end

	if _storeBtn and _storeBtn:IsA("GuiButton") then
		_storeBtn.MouseButton1Click:Connect(function()
			if _callbacks.onStore then _callbacks.onStore() end
		end)
	end

	if _upgradeBtn and _upgradeBtn:IsA("GuiButton") then
		_upgradeBtn.MouseButton1Click:Connect(function()
			local textLabel = _upgradeBtn:FindFirstChild("TextLabel")
			local btnText = textLabel and textLabel.Text or ""
			if btnText == "Assign Pet" then return end
			if _callbacks.onUpgrade then _callbacks.onUpgrade() end
		end)
	end
end

function SelectionUI.showNormal(level: number, maxLevel: number, canStore: boolean?)
	if not selectFolder then return end
	if _moveBtn then _moveBtn.Visible = true end
	if _storeBtn then
		_storeBtn.Visible = true
		if canStore == false then
			_storeBtn.Active = false
			if _storeBtn:IsA("GuiButton") then
				_storeBtn.AutoButtonColor = false
			end
			_storeBtn.BackgroundTransparency = 0.6
		else
			_storeBtn.Active = true
			if _storeBtn:IsA("GuiButton") then
				_storeBtn.AutoButtonColor = true
			end
			_storeBtn.BackgroundTransparency = 0
		end
	end
	if _cancleBtn then _cancleBtn.Visible = true end
	if _upgradeBtn then
		_upgradeBtn.Visible = (level < maxLevel)
		local textLabel = _upgradeBtn:FindFirstChild("TextLabel")
		if textLabel then textLabel.Text = "Upgrade" end
	end
end

function SelectionUI.showUpgrading()
	if not selectFolder then return end
	if _moveBtn then _moveBtn.Visible = false end
	if _storeBtn then _storeBtn.Visible = false end
	if _cancleBtn then _cancleBtn.Visible = true end
	if _upgradeBtn then
		_upgradeBtn.Visible = true
		local textLabel = _upgradeBtn:FindFirstChild("TextLabel")
		if textLabel then textLabel.Text = "Assign Pet" end
	end
end

function SelectionUI.show()
	-- show는 showNormal/showUpgrading에서 개별 처리
end

function SelectionUI.hide()
	setAllVisible(false)
end

function SelectionUI.destroy()
end

return SelectionUI
