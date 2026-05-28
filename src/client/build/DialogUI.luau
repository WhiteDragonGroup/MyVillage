-- DialogUI.luau
-- NPC speech bubble on NPC head + Player choices on player head

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DialogUI = {}

local _npcBillboard = nil   -- NPC greeting bubble
local _playerBillboard = nil -- Player choices bubble
local _visible = false
local _onChoice = nil
local _choices = {}
local _choiceButtons = {}   -- index → TextButton
local _keyConnection = nil
local _selecting = false    -- prevent double selection

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
	billboard.Active = true
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

local _currentAnimateId: number = 0
function DialogUI._animateGreeting(greeting: string, greetLabel: TextLabel, callback: ()->()?, choiceDelay: number?)
	_currentAnimateId += 1
	local thisAnimateId = _currentAnimateId
	local greetingLength = utf8.len(greeting)
	
	local startTick = tick()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if _currentAnimateId ~= thisAnimateId or not _npcBillboard then
			connection:Disconnect()
			return
		end
		
		local currentTick = tick()
		local diff = currentTick - startTick
		local charLength = math.min(math.floor(diff / 0.02), greetingLength)

		greetLabel.Text = greeting:sub(1, utf8.offset(greeting, charLength + 1) - 1)

		if charLength >= greetingLength then
			connection:Disconnect()
			if not callback then
				return
			end
			if choiceDelay then
				task.wait(choiceDelay)
				if _currentAnimateId ~= thisAnimateId or not _npcBillboard then
					return
				end
			end
			callback()
		end
	end)

	-- Clear previous text
end

-- 범용 타이프라이터: 임의의 TextLabel에 글자 한 자씩 출력 (말풍선 종류 무관).
-- 라벨이 부모에서 떨어지거나 새 애니메이션이 시작되면 자동 중단.
function DialogUI._typewrite(label: TextLabel, fullText: string, callback: (() -> ())?)
	_currentAnimateId += 1
	local thisId = _currentAnimateId
	local len = utf8.len(fullText) or #fullText
	label.Text = ""
	local startTick = tick()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if _currentAnimateId ~= thisId or not label.Parent then
			connection:Disconnect()
			return
		end
		local n = math.min(math.floor((tick() - startTick) / 0.02), len)
		label.Text = fullText:sub(1, utf8.offset(fullText, n + 1) - 1)
		if n >= len then
			connection:Disconnect()
			if callback then callback() end
		end
	end)
end

function DialogUI.show(npcName: string, greeting: string, choices: { { text: string, id: string } }, onChoice: (string) -> (), npcAdornee: BasePart?, choiceDelay: number?, onGreetingAnimationDone: () -> ()?)
	DialogUI.hide()
	_visible = true
	_onChoice = onChoice
	_choices = choices

	-- === NPC speech bubble (greeting) ===
	if npcAdornee then
		_npcBillboard = createBubble(npcAdornee, Vector3.new(0, 1.5, 0), UDim2.new(0, 350, 0, 100))
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
		nameLabel.TextSize = 22 -- 13
		--nameLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
		nameLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
		nameLabel.Text = npcName
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = npcFrame

		-- Greeting text
		local greetLabel = Instance.new("TextLabel")
		greetLabel.Size = UDim2.new(1, -10, 1, -23) -- UDim2.new(1, -10, 0, 36)
		greetLabel.Position = UDim2.new(0, 5, 0, 24)
		greetLabel.BackgroundTransparency = 1
		greetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		greetLabel.TextSize = 26 -- 11
		--greetLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Regular)
		greetLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Medium)
		greetLabel.Text = ""
		greetLabel.TextWrapped = true
		greetLabel.TextXAlignment = Enum.TextXAlignment.Left
		greetLabel.TextYAlignment = Enum.TextYAlignment.Top
		greetLabel.Parent = npcFrame
		
		DialogUI._animateGreeting(greeting, greetLabel, function()
			DialogUI.showPlayerChoice(choices, onChoice)
			if onGreetingAnimationDone then
				onGreetingAnimationDone()
			end
		end, choiceDelay)
	else
		DialogUI.showPlayerChoice(choices, onChoice)
		if onGreetingAnimationDone then
			onGreetingAnimationDone()
		end
	end
end

function DialogUI.showPlayerChoice(choices: { { text: string, id: string } }, onChoice: (string) -> ())
	-- Player head
	local playerHead = nil
	local character = player.Character
	if character then
		playerHead = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
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

	-- Select choice with animation
	_selecting = false
	_choiceButtons = {}

	local function selectChoice(index)
		if _selecting then return end
		if not _choices[index] or not _onChoice then return end
		_selecting = true

		local btn = _choiceButtons[index]

		-- Button press animation
		if btn then
			-- Highlight selected
			TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
				BackgroundColor3 = Color3.fromRGB(180, 140, 80),
			}):Play()

			-- Shrink then restore
			local origSize = btn.Size
			TweenService:Create(btn, TweenInfo.new(0.05, Enum.EasingStyle.Quad), {
				Size = UDim2.new(origSize.X.Scale, origSize.X.Offset - 4, origSize.Y.Scale, origSize.Y.Offset - 2),
			}):Play()
			task.delay(0.05, function()
				if btn.Parent then
					TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Size = origSize,
					}):Play()
				end
			end)
		end

		-- Fade out other buttons
		for j, otherBtn in _choiceButtons do
			if j ~= index and otherBtn.Parent then
				TweenService:Create(otherBtn, TweenInfo.new(0.2), {
					BackgroundTransparency = 0.7,
					TextTransparency = 0.5,
				}):Play()
			end
		end

		-- Show player's choice as speech bubble above player head
		-- Destroy old player bubble and create new one above head
		if _playerBillboard then
			_playerBillboard:Destroy()
			_playerBillboard = nil
		end

		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if head then
			_playerBillboard = Instance.new("BillboardGui")
			_playerBillboard.Name = "PlayerSayBubble"
			_playerBillboard.Size = UDim2.new(0, 260, 0, 60)
			_playerBillboard.StudsOffset = Vector3.new(0, 1.5, 0)
			_playerBillboard.AlwaysOnTop = true
			_playerBillboard.Adornee = head
			_playerBillboard.Parent = playerGui

			local sayLabel = Instance.new("TextLabel")
			sayLabel.Size = UDim2.new(1, 0, 1, 0)
			sayLabel.BackgroundTransparency = 1
			sayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			sayLabel.TextSize = 24
			-- 게임 메인 폰트로 통일 (기존 GothamBold → 다른 말풍선과 동일 폰트)
			sayLabel.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
			sayLabel.TextStrokeTransparency = 0.5
			sayLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			sayLabel.TextWrapped = true
			sayLabel.Parent = _playerBillboard
			-- 플레이어 대사도 글자 한 자씩 (타이프라이터)
			DialogUI._typewrite(sayLabel, _choices[index].text)
		end

		-- After delay, fire callback
		task.delay(2, function()
			if _onChoice then
				_onChoice(_choices[index].id)
			end
		end)
	end

	-- Choice buttons
	local y = 5
	for i, choice in choices do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 24)
		btn.Position = UDim2.new(0, 5, 0, y)
		btn.BackgroundColor3 = Color3.fromRGB(50, 45, 35)
		btn.TextColor3 = Color3.fromRGB(255, 240, 200)
		btn.TextSize = 22
		--btn.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
		btn.FontFace = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)
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

		_choiceButtons[i] = btn

		btn.MouseButton1Click:Connect(function()
			selectChoice(i)
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
		if index then
			selectChoice(index)
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

	-- Update NPC bubble text (2번째 대사도 글자 한 자씩 타이프라이터 적용)
	if _npcBillboard then
		local frame = _npcBillboard:FindFirstChild("DialogFrame")
		if frame then
			for _, child in frame:GetChildren() do
				if child:IsA("TextLabel") and child.Position.Y.Offset > 20 then
					DialogUI._typewrite(child, text)
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
