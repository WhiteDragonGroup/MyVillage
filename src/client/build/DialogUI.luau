-- DialogUI.luau
-- NPC dialogue UI with random greeting + choice buttons

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DialogUI = {}

local screenGui = nil
local mainFrame = nil
local dialogText = nil
local choicesFrame = nil
local _visible = false
local _onChoice = nil

function DialogUI.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DialogUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 45
	screenGui.Parent = playerGui

	-- Overlay
	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Text = ""
	overlay.Visible = false
	overlay.Parent = screenGui
	overlay.MouseButton1Click:Connect(function()
		DialogUI.hide()
	end)

	-- Main frame (bottom center)
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "DialogFrame"
	mainFrame.Size = UDim2.new(0, 420, 0, 220)
	mainFrame.Position = UDim2.new(0.5, -210, 1, -240)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
	mainFrame.BackgroundTransparency = 0.1
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = mainFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 140, 80)
	stroke.Thickness = 2
	stroke.Parent = mainFrame

	-- NPC name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NPCName"
	nameLabel.Size = UDim2.new(1, -20, 0, 24)
	nameLabel.Position = UDim2.new(0, 10, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = "NPC"
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = mainFrame

	-- Dialog text
	dialogText = Instance.new("TextLabel")
	dialogText.Name = "DialogText"
	dialogText.Size = UDim2.new(1, -20, 0, 40)
	dialogText.Position = UDim2.new(0, 10, 0, 34)
	dialogText.BackgroundTransparency = 1
	dialogText.TextColor3 = Color3.fromRGB(255, 255, 255)
	dialogText.TextSize = 13
	dialogText.Font = Enum.Font.Gotham
	dialogText.Text = ""
	dialogText.TextWrapped = true
	dialogText.TextXAlignment = Enum.TextXAlignment.Left
	dialogText.TextYAlignment = Enum.TextYAlignment.Top
	dialogText.Parent = mainFrame

	-- Choices frame
	choicesFrame = Instance.new("Frame")
	choicesFrame.Name = "Choices"
	choicesFrame.Size = UDim2.new(1, -20, 0, 130)
	choicesFrame.Position = UDim2.new(0, 10, 0, 80)
	choicesFrame.BackgroundTransparency = 1
	choicesFrame.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = choicesFrame
end

function DialogUI.show(npcName: string, greeting: string, choices: { { text: string, id: string } }, onChoice: (string) -> ())
	if not mainFrame then return end
	_visible = true
	_onChoice = onChoice

	-- Set NPC name
	local nameLabel = mainFrame:FindFirstChild("NPCName")
	if nameLabel then nameLabel.Text = npcName end

	-- Set greeting
	if dialogText then dialogText.Text = greeting end

	-- Clear old choices
	for _, child in choicesFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Create choice buttons
	for i, choice in choices do
		local btn = Instance.new("TextButton")
		btn.Name = choice.id
		btn.Size = UDim2.new(1, 0, 0, 28)
		btn.BackgroundColor3 = Color3.fromRGB(50, 45, 35)
		btn.TextColor3 = Color3.fromRGB(255, 240, 200)
		btn.TextSize = 13
		btn.Font = Enum.Font.GothamBold
		btn.Text = "#" .. i .. "  " .. choice.text
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.AutoButtonColor = true
		btn.LayoutOrder = i
		btn.Parent = choicesFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn

		local btnPadding = Instance.new("UIPadding")
		btnPadding.PaddingLeft = UDim.new(0, 10)
		btnPadding.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if _onChoice then
				_onChoice(choice.id)
			end
		end)
	end

	-- Show
	local overlay = screenGui:FindFirstChild("Overlay")
	if overlay then overlay.Visible = true end
	mainFrame.Visible = true
end

function DialogUI.showResponse(text: string, duration: number?)
	if dialogText then
		dialogText.Text = text
	end

	-- Hide choices
	for _, child in choicesFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child.Visible = false
		end
	end

	-- Auto close
	task.delay(duration or 2, function()
		DialogUI.hide()
	end)
end

function DialogUI.hide()
	if not mainFrame then return end
	_visible = false
	mainFrame.Visible = false
	local overlay = screenGui:FindFirstChild("Overlay")
	if overlay then overlay.Visible = false end
end

function DialogUI.isVisible(): boolean
	return _visible
end

return DialogUI
