-- MoveHandleUI.luau
-- 디자인 UI 사용 (StarterGui/BuildMode/Move)
-- Move는 Folder이므로 자식 GuiObject의 Visible로 제어

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MoveHandleUI = {}

local moveFolder = nil
local _callbacks = {}
local _placeBtn = nil

local function setAllVisible(visible: boolean)
	if not moveFolder then return end
	for _, child in moveFolder:GetChildren() do
		if child:IsA("GuiObject") then
			child.Visible = visible
		end
	end
end

function MoveHandleUI.init(callbacks: { onPlace: () -> (), onRotateLeft: () -> (), onRotateRight: () -> (), onCancel: () -> () })
	_callbacks = callbacks

	local buildModeGui = playerGui:WaitForChild("BuildMode", 10)
	if not buildModeGui then
		warn("[MoveHandleUI] BuildMode ScreenGui를 찾을 수 없음")
		return
	end

	moveFolder = buildModeGui:FindFirstChild("Move")
	if not moveFolder then
		warn("[MoveHandleUI] Move 폴더를 찾을 수 없음")
		return
	end

	-- 초기 숨김
	setAllVisible(false)

	local cancleBtn = moveFolder:FindFirstChild("Cancle")
	_placeBtn = moveFolder:FindFirstChild("Place")
	local rotCCW = moveFolder:FindFirstChild("RotationCCW")
	local rotCW = moveFolder:FindFirstChild("RotationCW")

	if cancleBtn and cancleBtn:IsA("GuiButton") then
		cancleBtn.MouseButton1Click:Connect(function()
			if _callbacks.onCancel then _callbacks.onCancel() end
		end)
	end

	if _placeBtn and _placeBtn:IsA("GuiButton") then
		_placeBtn.MouseButton1Click:Connect(function()
			if _callbacks.onPlace then _callbacks.onPlace() end
		end)
	end

	if rotCCW and rotCCW:IsA("GuiButton") then
		rotCCW.MouseButton1Click:Connect(function()
			if _callbacks.onRotateLeft then _callbacks.onRotateLeft() end
		end)
	end

	if rotCW and rotCW:IsA("GuiButton") then
		rotCW.MouseButton1Click:Connect(function()
			if _callbacks.onRotateRight then _callbacks.onRotateRight() end
		end)
	end
end

function MoveHandleUI.show()
	setAllVisible(true)
end

function MoveHandleUI.hide()
	setAllVisible(false)
end

function MoveHandleUI.setPlaceEnabled(enabled: boolean)
	if not _placeBtn then return end
	_placeBtn.Active = enabled
	if enabled then
		_placeBtn.BackgroundTransparency = 0
	else
		_placeBtn.BackgroundTransparency = 0.5
	end
end

function MoveHandleUI.destroy()
end

return MoveHandleUI
