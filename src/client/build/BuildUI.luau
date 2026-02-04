-- BuildUI.luau
-- 빌드모드 토글 버튼 (화면 우하단)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BuildUI = {}

local screenGui = nil
local buildButton = nil
local _onToggle = nil  -- 콜백

function BuildUI.init(onToggle: (boolean) -> ())
	_onToggle = onToggle

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BuildUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	-- 빌드 버튼
	buildButton = Instance.new("TextButton")
	buildButton.Name = "BuildButton"
	buildButton.Size = UDim2.new(0, 70, 0, 70)
	buildButton.Position = UDim2.new(1, -90, 1, -90)
	buildButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	buildButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buildButton.Text = "빌드"
	buildButton.TextSize = 18
	buildButton.Font = Enum.Font.GothamBold
	buildButton.AutoButtonColor = true
	buildButton.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 35)
	corner.Parent = buildButton

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = buildButton

	-- 클릭 이벤트
	buildButton.MouseButton1Click:Connect(function()
		if _onToggle then
			_onToggle(true) -- 토글 요청
		end
	end)
end

-- 빌드모드 상태에 따라 버튼 외관 변경
function BuildUI.setBuildMode(active: boolean)
	if not buildButton then return end

	if active then
		buildButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		buildButton.Text = "닫기"
	else
		buildButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		buildButton.Text = "빌드"
	end

	-- 작은 스케일 애니메이션
	local tween = TweenService:Create(buildButton, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 75, 0, 75)
	})
	tween:Play()
	tween.Completed:Connect(function()
		TweenService:Create(buildButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
			Size = UDim2.new(0, 70, 0, 70)
		}):Play()
	end)
end

function BuildUI.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return BuildUI
