local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EggShopUI = {}

local featuresGui = nil
local _visible = false
local popUpFrame = nil
local _callbacks = {}
local _slotName = nil
local _eggName = nil
local _cancleBtn = nil
local _confirmBtn = nil
local eggShopRestockGui = nil

local updateResolution = 60 * 5 -- EggServer 의 값과 일치하도록

function EggShopUI.init(callbacks: { onConfirm: (slotName: string, eggName: string) -> (), onCancel: () -> () })
	_callbacks = callbacks

	-- EggShopRestock BillboardGui (있을 때만 카운트다운 갱신, 없어도 init은 계속)
	eggShopRestockGui = playerGui:FindFirstChild("EggShopRestock")
	if not eggShopRestockGui then
		task.spawn(function()
			eggShopRestockGui = playerGui:WaitForChild("EggShopRestock", 30)
		end)
	end
	task.spawn(function ()
		while true do
			task.wait(1)
			if not eggShopRestockGui then continue end
			local label = eggShopRestockGui:FindFirstChildOfClass("TextLabel")
			if not label then continue end
			local remain = updateResolution - (workspace:GetServerTimeNow() % updateResolution)
			local minutes = tostring(remain // 60)
			local seconds = tostring(math.floor(remain % 60))
			if #seconds == 1 then
				seconds = "0" .. seconds
			end
			label.Text = `Eggs Restocking In : {minutes}:{seconds}`
		end
	end)

	featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then
		warn("[EggShopUI] Features ScreenGui를 찾을 수 없음")
		return
	end

	popUpFrame = featuresGui:FindFirstChild("PopUp")
	if not popUpFrame then
		warn("[EggShopUI] PopUp를 찾을 수 없음")
		return
	end
	popUpFrame.Visible = false
	
	-- 임시 보석 아이콘 숨기기
	for _, desc in popUpFrame:GetDescendants() do
		if desc:IsA("ImageLabel") and desc.Name ~= "BackPattern" then
			desc.Visible = false
		end
	end
	
	-- Frame 내 버튼 연결 (다양한 이름 변형 허용)
	local frame = popUpFrame:FindFirstChild("Frame")
	if frame then
		_cancleBtn = frame:FindFirstChild("Cancle") or frame:FindFirstChild("Cancel")
		_confirmBtn = frame:FindFirstChild("Confirm")
			or frame:FindFirstChild("Cinfirm") -- 기존 UI 오타
			or frame:FindFirstChild("Buy")

		if _cancleBtn and _cancleBtn:IsA("GuiButton") then
			_cancleBtn.MouseButton1Click:Connect(function()
				if _callbacks.onCancel and _visible then _callbacks.onCancel() end
			end)
		end

		if _confirmBtn and _confirmBtn:IsA("GuiButton") then
			_confirmBtn.MouseButton1Click:Connect(function()
				if _callbacks.onConfirm and _visible then
					_callbacks.onConfirm(_slotName, _eggName)
				end
			end)
		end
	end
end

function EggShopUI.show(slotName: string, eggName: string)
	if not popUpFrame then return end
	_visible = true

	-- TextLabel 업데이트 (2개 있음)
	local textLabels = {}
	for _, child in popUpFrame:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(textLabels, child)
		end
	end

	if _cancleBtn and _cancleBtn:FindFirstChild("TextLabel") then
		_cancleBtn.TextLabel.Text = "Cancle"
	end
	if _confirmBtn and _confirmBtn:FindFirstChild("TextLabel") then
		_confirmBtn.TextLabel.Text = "Buy"
	end

	_slotName = slotName
	_eggName = eggName

	local eggInfo = BalanceConfig.Egg.EGGS[eggName]
	local displayName = (eggInfo and eggInfo.name) or eggName
	if textLabels[1] then
		textLabels[1].Text = `Buy the egg '{displayName}'?`
	end
	if textLabels[2] then
		textLabels[2].Text = `Will cost ${eggInfo and eggInfo.price or "?"}`
	end

	popUpFrame.Visible = true
end

function EggShopUI.destroy()
end

function EggShopUI.hide()
	_visible = false
	_slotName = nil
	_eggName = nil
	popUpFrame.Visible = false
end

return EggShopUI
