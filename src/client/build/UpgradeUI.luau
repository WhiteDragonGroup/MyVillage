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
		local cancleBtn = frame:FindFirstChild("Cancle")
		local confirmBtn = frame:FindFirstChild("Cinfirm") -- 오타 그대로 사용

		if cancleBtn and cancleBtn:IsA("GuiButton") then
			cancleBtn.MouseButton1Click:Connect(function()
				if _callbacks.onCancel then _callbacks.onCancel() end
			end)
		end

		if confirmBtn and confirmBtn:IsA("GuiButton") then
			confirmBtn.MouseButton1Click:Connect(function()
				if _callbacks.onConfirm then _callbacks.onConfirm() end
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

	if level >= UpgradeCfg.MAX_LEVEL then
		-- 최대 레벨
		if textLabels[1] then textLabels[1].Text = itemName end
		if textLabels[2] then textLabels[2].Text = "이미 최대 레벨입니다! (Lv." .. UpgradeCfg.MAX_LEVEL .. ")" end
	else
		local cost = UpgradeCfg.COST[level] or 0
		local work = UpgradeCfg.REQUIRED_WORK[level] or 0

		if textLabels[1] then textLabels[1].Text = itemName end
		if textLabels[2] then
			textLabels[2].Text = "Lv." .. level .. " → Lv." .. (level + 1) .. "\n비용: " .. cost .. " 코인 | 작업량: " .. work
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
