-- DialogUI.luau
-- NPC speech bubble on NPC head + Player choices on player head

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DialogUI = {}

local _npcBillboard = nil   -- NPC greeting bubble
local _playerBillboard = nil -- Player choices bubble
local _visible = false
local _onChoice = nil
local _choices = {}
local _keyConnection = nil

function DialogUI.init()
	-- Nothing to init - billboards created per show()
end

local function createBubble(targetPart: BasePart, studsOffset: Vector3, size: UDim2): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DialogBubble"
	billboard.Size = size
	billboard.StudsOffset = studsOffset
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 30
	billboard.Parent = playerGui

	if targetPart then
		billboard.Adornee = targetPart
	end

	return billboard
end

local function createFrame(parent: Instance, size: UDim2?): Frame
	local frame = Instance.new("Frame")
	frame.Name = "DialogFrame"
	if parent:IsA("BillboardGui") then
		frame.Size = size or UDim2.new(1, 0, 1, 0)
	else
		frame.Size = size or UDim2.new(0, 300, 0, 120)
	end
	frame.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 140, 80)
	stroke.Thickness = 2
	stroke.Parent = frame

	return frame
end

function DialogUI.show(npcName: string, greeting: string, choices: { { text: string, id: string } }, onChoice: (string) -> (), npcAdornee: BasePart?)
	DialogUI.hide()
	_visible = true
	_onChoice = onChoice
	_choices = choices

	-- Player head
	local playerHead = nil
	local character = player.Character
	if character then
		playerHead = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	end

	-- === NPC speech bubble (greeting) ===
	if npcAdornee then
		_npcBillboard = createBubble(npcAdornee, Vector3.new(0, 1.5, 0), UDim2.new(0, 250, 0, 70))
		local npcFrame = createFrame(_npcBillboard)
		npcFrame.BackgroundTransparency = 1
		-- Remove stroke on NPC bubble
		local npcStroke = npcFrame:FindFirstChildWhichIsA("UIStroke")
		if npcStroke then npcStroke:Destroy() end

		-- NPC name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -10, 0, 18)
		nameLabel.Position = UDim2.new(0, 5, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = npcName
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = npcFrame

		-- Greeting text
		local greetLabel = Instance.new("TextLabel")
		greetLabel.Size = UDim2.new(1, -10, 0, 36)
		greetLabel.Position = UDim2.new(0, 5, 0, 24)
		greetLabel.BackgroundTransparency = 1
		greetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		greetLabel.TextSize = 11
		greetLabel.Font = Enum.Font.Gotham
		greetLabel.Text = greeting
		greetLabel.TextWrapped = true
		greetLabel.TextXAlignment = Enum.TextXAlignment.Left
		greetLabel.TextYAlignment = Enum.TextYAlignment.Top
		greetLabel.Parent = npcFrame
	end

	-- === Player choices bubble (right side) ===
	local choiceHeight = 10 + #choices * 28
	if playerHead then
		_playerBillboard = createBubble(playerHead, Vector3.new(6, 1, 0), UDim2.new(0, 260, 0, choiceHeight))
	else
		-- Fallback: screen center
		_playerBillboard = Instance.new("ScreenGui")
		_playerBillboard.Name = "DialogFallback"
		_playerBillboard.DisplayOrder = 45
		_playerBillboard.Parent = playerGui
	end

	local playerFrame = createFrame(_playerBillboard)

	-- Choice buttons
	local y = 5
	for i, choice in choices do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 24)
		btn.Position = UDim2.new(0, 5, 0, y)
		btn.BackgroundColor3 = Color3.fromRGB(50, 45, 35)
		btn.TextColor3 = Color3.fromRGB(255, 240, 200)
		btn.TextSize = 11
		btn.Font = Enum.Font.GothamBold
		btn.Text = "#" .. i .. " " .. choice.text
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.AutoButtonColor = true
		btn.Parent = playerFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 5)
		btnCorner.Parent = btn

		local btnPad = Instance.new("UIPadding")
		btnPad.PaddingLeft = UDim.new(0, 8)
		btnPad.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if _onChoice then
				_onChoice(choice.id)
			end
		end)

		y = y + 28
	end

	-- Keyboard number selection (1-4) + Escape to cancel
	_keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not _visible then return end

		local keyMap = {
			[Enum.KeyCode.One] = 1,
			[Enum.KeyCode.Two] = 2,
			[Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.Four] = 4,
		}

		if input.KeyCode == Enum.KeyCode.Escape then
			DialogUI.hide()
			return
		end

		local index = keyMap[input.KeyCode]
		if index and _choices[index] and _onChoice then
			_onChoice(_choices[index].id)
		end
	end)
end

function DialogUI.showResponse(text: string, duration: number?)
	-- Hide player choices
	if _playerBillboard then
		_playerBillboard:Destroy()
		_playerBillboard = nil
	end
	if _keyConnection then
		_keyConnection:Disconnect()
		_keyConnection = nil
	end

	-- Update NPC bubble text
	if _npcBillboard then
		local frame = _npcBillboard:FindFirstChild("DialogFrame")
		if frame then
			for _, child in frame:GetChildren() do
				if child:IsA("TextLabel") and child.Position.Y.Offset > 20 then
					child.Text = text
					break
				end
			end
		end
	end

	task.delay(duration or 2, function()
		DialogUI.hide()
	end)
end

function DialogUI.hide()
	_visible = false
	_choices = {}
	_onChoice = nil
	if _keyConnection then
		_keyConnection:Disconnect()
		_keyConnection = nil
	end
	if _npcBillboard then
		_npcBillboard:Destroy()
		_npcBillboard = nil
	end
	if _playerBillboard then
		_playerBillboard:Destroy()
		_playerBillboard = nil
	end
end

function DialogUI.isVisible(): boolean
	return _visible
end

return DialogUI
