-- GiftUI.luau
-- 디자인 UI 사용 (StarterGui/Features/Gift)
-- Frame(Player들), Header(Close)

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GiftUI = {}

local giftFrame = nil
local playerListFrame = nil
local playerTemplate = nil
local _callbacks = {}
local _visible = false
local _giftItemName = nil

function GiftUI.init(callbacks: { onSelectPlayer: (string, Player) -> (), onClose: () -> () })
	_callbacks = callbacks

	local featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then
		warn("[GiftUI] Features ScreenGui를 찾을 수 없음")
		return
	end

	giftFrame = featuresGui:FindFirstChild("Gift")
	if not giftFrame then
		warn("[GiftUI] Gift를 찾을 수 없음")
		return
	end

	giftFrame.Visible = false

	-- Header Close 버튼
	local header = giftFrame:FindFirstChild("Header")
	if header then
		local closeBtn = header:FindFirstChild("Close")
		if closeBtn and closeBtn:IsA("GuiButton") then
			closeBtn.MouseButton1Click:Connect(function()
				if _callbacks.onClose then _callbacks.onClose() end
			end)
		end
	end

	-- Frame (플레이어 목록 컨테이너)
	playerListFrame = giftFrame:FindFirstChild("Frame")
	if playerListFrame then
		-- Player 템플릿 저장
		for _, child in playerListFrame:GetChildren() do
			if child.Name == "Player" and child:IsA("GuiObject") then
				if not playerTemplate then
					playerTemplate = child:Clone()
				end
				child.Visible = false
			end
		end
	end
end

function GiftUI.show(itemName: string)
	if not giftFrame or not playerListFrame then return end
	_visible = true
	_giftItemName = itemName

	-- 기존 동적 플레이어 제거
	for _, child in playerListFrame:GetChildren() do
		if child:IsA("GuiObject") and child:GetAttribute("_dynamic") then
			child:Destroy()
		end
	end

	-- 기존 템플릿 숨기기
	for _, child in playerListFrame:GetChildren() do
		if child.Name == "Player" and child:IsA("GuiObject") then
			child.Visible = false
		end
	end

	-- 다른 플레이어 목록
	local index = 0
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == player then continue end
		index = index + 1

		local slot
		if playerTemplate then
			slot = playerTemplate:Clone()
		else
			slot = Instance.new("TextButton")
			slot.Size = UDim2.new(1, -8, 0, 36)
			slot.Text = otherPlayer.DisplayName
		end

		slot.Name = "Player_" .. otherPlayer.Name
		slot.Visible = true
		slot.LayoutOrder = index
		slot:SetAttribute("_dynamic", true)
		slot.Parent = playerListFrame

		-- 이름 업데이트
		local nameText = slot:FindFirstChild("NameText") or slot:FindFirstChild("TextLabel") or slot:FindFirstChildWhichIsA("TextLabel")
		if nameText then
			nameText.Text = otherPlayer.DisplayName
		end

		-- 클릭 이벤트
		if slot:IsA("GuiButton") then
			slot.MouseButton1Click:Connect(function()
				if _callbacks.onSelectPlayer and _giftItemName then
					_callbacks.onSelectPlayer(_giftItemName, otherPlayer)
				end
			end)
		else
			local btn = slot:FindFirstChildWhichIsA("TextButton") or slot:FindFirstChildWhichIsA("ImageButton")
			if btn then
				btn.MouseButton1Click:Connect(function()
					if _callbacks.onSelectPlayer and _giftItemName then
						_callbacks.onSelectPlayer(_giftItemName, otherPlayer)
					end
				end)
			end
		end
	end

	giftFrame.Visible = true
end

function GiftUI.hide()
	if not giftFrame then return end
	_visible = false
	_giftItemName = nil
	giftFrame.Visible = false
end

function GiftUI.isVisible(): boolean
	return _visible
end

function GiftUI.destroy()
end

return GiftUI
