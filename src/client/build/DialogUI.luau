-- DialogUI.luau
-- NPC dialogue as BillboardGui (speech bubble next to NPC)

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DialogUI = {}

local _billboard = nil
local _visible = false
local _onChoice = nil

function DialogUI.init()
	-- Nothing to init - billboard created per show()
end

function DialogUI.show(npcName: string, greeting: string, choices: { { text: string, id: string } }, onChoice: (string) -> (), adornee: BasePart?)
	DialogUI.hide()
	_visible = true
	_onChoice = onChoice

	-- Find NPC part to attach to
	local targetPart = adornee
	if not targetPart then
		local npcFolder = workspace:FindFirstChild("NPC")
		if npcFolder then
			local npc = npcFolder:FindFirstChild("PetDealer") or npcFolder:FindFirstChild("BuildingDealer")
			if npc then
				targetPart = npc:FindFirstChild("HumanoidRootPart")
					or npc:FindFirstChild("Head")
					or npc:FindFirstChildWhichIsA("BasePart", true)
			end
		end
	end

	_billboard = Instance.new("BillboardGui")
	_billboard.Name = "DialogBubble"
	_billboard.Size = UDim2.new(0, 300, 0, 200)
	_billboard.StudsOffset = Vector3.new(0, 5, 0)
	_billboard.AlwaysOnTop = true
	_billboard.MaxDistance = 30
	_billboard.Parent = playerGui

	if targetPart then
		_billboard.Adornee = targetPart
	else
		-- Fallback: screen center
		_billboard.Parent = nil
		_billboard = nil
		-- Use screen GUI instead
		_billboard = Instance.new("ScreenGui")
		_billboard.Name = "DialogFallback"
		_billboard.DisplayOrder = 45
		_billboard.Parent = playerGui
	end

	-- Main frame
	local frame = Instance.new("Frame")
	frame.Name = "DialogFrame"
	if _billboard:IsA("BillboardGui") then
		frame.Size = UDim2.new(1, 0, 1, 0)
	else
		frame.Size = UDim2.new(0, 300, 0, 200)
		frame.Position = UDim2.new(0.5, -150, 0.5, -100)
	end
	frame.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = _billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 140, 80)
	stroke.Thickness = 2
	stroke.Parent = frame

	-- NPC name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -10, 0, 20)
	nameLabel.Position = UDim2.new(0, 5, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = npcName
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	-- Greeting text
	local greetLabel = Instance.new("TextLabel")
	greetLabel.Size = UDim2.new(1, -10, 0, 30)
	greetLabel.Position = UDim2.new(0, 5, 0, 26)
	greetLabel.BackgroundTransparency = 1
	greetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	greetLabel.TextSize = 11
	greetLabel.Font = Enum.Font.Gotham
	greetLabel.Text = greeting
	greetLabel.TextWrapped = true
	greetLabel.TextXAlignment = Enum.TextXAlignment.Left
	greetLabel.TextYAlignment = Enum.TextYAlignment.Top
	greetLabel.Parent = frame

	-- Choice buttons
	local y = 60
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
		btn.Parent = frame

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
end

function DialogUI.showResponse(text: string, duration: number?)
	if not _billboard then return end

	local frame = _billboard:FindFirstChild("DialogFrame")
	if not frame then return end

	-- Hide choices, update text
	for _, child in frame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local greetLabel = frame:FindFirstChild("TextLabel")
	-- Find the greeting label (second TextLabel)
	for _, child in frame:GetChildren() do
		if child:IsA("TextLabel") and child.Position.Y.Offset > 20 then
			child.Text = text
			break
		end
	end

	task.delay(duration or 2, function()
		DialogUI.hide()
	end)
end

function DialogUI.hide()
	_visible = false
	if _billboard then
		_billboard:Destroy()
		_billboard = nil
	end
end

function DialogUI.isVisible(): boolean
	return _visible
end

return DialogUI
