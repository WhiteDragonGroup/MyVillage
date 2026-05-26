-- UpgradeUI.luau
-- 디자인 UI 사용 (StarterGui/Features/PopUp)
-- Frame(Cancle, Cinfirm), TextLabel x2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UpgradeUI = {}

local popUpFrame = nil
local _callbacks = {}
local _visible = false
local _cancleBtn = nil
local _confirmBtn = nil

function UpgradeUI.init(callbacks: { onConfirm: () -> (), onCancel: () -> () })
	_callbacks = callbacks

	local featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then
		warn("[UpgradeUI] Features ScreenGui를 찾을 수 없음")
		return
	end

	popUpFrame = featuresGui:FindFirstChild("PopUp")
	if not popUpFrame then
		warn("[UpgradeUI] PopUp를 찾을 수 없음")
		return
	end

	popUpFrame.Visible = false

	-- Frame 내 버튼 연결
	local frame = popUpFrame:FindFirstChild("Frame")
	if frame then
		_cancleBtn = frame:FindFirstChild("Cancle")
		_confirmBtn = frame:FindFirstChild("Confirm")

		if _cancleBtn and _cancleBtn:IsA("GuiButton") then
			_cancleBtn.MouseButton1Click:Connect(function()
				if _callbacks.onCancel and _visible then
					_callbacks.onCancel()
				end
			end)
		end

		if _confirmBtn and _confirmBtn:IsA("GuiButton") then
			_confirmBtn.MouseButton1Click:Connect(function()
				if _callbacks.onConfirm and _visible then
					_callbacks.onConfirm()
				end
			end)
		end
	end
end

function UpgradeUI.show(level: number, itemName: string)
	if not popUpFrame then return end
	_visible = true

	local UpgradeCfg = BalanceConfig.Upgrade

	-- TextLabel 업데이트 (2개 있음)
	local textLabels = {}
	for _, child in popUpFrame:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(textLabels, child)
		end
	end

	_cancleBtn.TextLabel.Text = "Cancle"
	_confirmBtn.TextLabel.Text = "Expend"

	if level >= UpgradeCfg.MAX_LEVEL then
		-- 최대 레벨
		if textLabels[1] then textLabels[1].Text = itemName end
		if textLabels[2] then textLabels[2].Text = "Already max level! (Lv." .. UpgradeCfg.MAX_LEVEL .. ")" end
	else
		local cost = UpgradeCfg.COST[level] or 0
		local work = UpgradeCfg.REQUIRED_WORK[level] or 0

		if textLabels[1] then textLabels[1].Text = itemName end
		if textLabels[2] then
			textLabels[2].Text = "정말 업그레이드 하시겠습니까?\nLv." .. level .. " → Lv." .. (level + 1) .. "\nCost: " .. cost .. " coins | Work: " .. work
		end
	end

	-- 임시 보석 아이콘 숨기기
	for _, desc in popUpFrame:GetDescendants() do
		if desc:IsA("ImageLabel") and desc.Name ~= "BackPattern" then
			desc.Visible = false
		end
	end

	popUpFrame.Visible = true
end

function UpgradeUI.hide()
	if not popUpFrame then return end
	_visible = false
	popUpFrame.Visible = false
end

function UpgradeUI.isVisible(): boolean
	return _visible
end

function UpgradeUI.destroy()
end

return UpgradeUI
