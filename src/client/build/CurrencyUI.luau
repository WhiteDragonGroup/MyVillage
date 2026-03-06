-- CurrencyUI.luau
-- 화면 상단에 코인 표시

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CurrencyUI = {}

local screenGui = nil
local coinLabel = nil
local _coins = 0

function CurrencyUI.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CurrencyUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui

	-- 코인 프레임
	local frame = Instance.new("Frame")
	frame.Name = "CoinFrame"
	frame.Size = UDim2.new(0, 140, 0, 36)
	frame.Position = UDim2.new(1, -150, 0, 10)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 80)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	-- 코인 아이콘 (텍스트)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 30, 1, 0)
	icon.Position = UDim2.new(0, 8, 0, 0)
	icon.BackgroundTransparency = 1
	icon.TextColor3 = Color3.fromRGB(255, 200, 60)
	icon.TextSize = 20
	icon.Font = Enum.Font.GothamBold
	icon.Text = "$"
	icon.Parent = frame

	-- 코인 수
	coinLabel = Instance.new("TextLabel")
	coinLabel.Name = "CoinLabel"
	coinLabel.Size = UDim2.new(1, -44, 1, 0)
	coinLabel.Position = UDim2.new(0, 38, 0, 0)
	coinLabel.BackgroundTransparency = 1
	coinLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	coinLabel.TextSize = 16
	coinLabel.Font = Enum.Font.GothamBold
	coinLabel.Text = "0"
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinLabel.Parent = frame
end

function CurrencyUI.updateCoins(coins: number)
	local oldCoins = _coins
	_coins = coins
	if coinLabel then
		coinLabel.Text = tostring(coins)

		-- 변화 애니메이션
		if coins ~= oldCoins then
			local frame = coinLabel.Parent
			if frame then
				TweenService:Create(frame, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
					Size = UDim2.new(0, 148, 0, 40)
				}):Play()
				task.delay(0.08, function()
					TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
						Size = UDim2.new(0, 140, 0, 36)
					}):Play()
				end)
			end
		end
	end
end

function CurrencyUI.getCoins(): number
	return _coins
end

function CurrencyUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return CurrencyUI
