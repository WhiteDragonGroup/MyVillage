-- HarvestEffect.luau
-- (1) 건물 터치 시 초록 하이라이트 (HarvestEffect)
-- (2) 드롭 흡수 시 캐릭터에 PlayerEffect_ 파티클 + 화면에 "+N" 텍스트 (CoinPickup)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local harvestEffectEvent = remotes:WaitForChild("HarvestEffect")
local coinPickupEvent = remotes:WaitForChild("CoinPickup")

local vfxFolder = ReplicatedStorage:WaitForChild("VFX")
local resourceFolder = vfxFolder:WaitForChild("Resource")

local HarvestEffect = {}

local MAIN_FONT = Font.new("rbxassetid://12187364648", Enum.FontWeight.Heavy)
local GREEN = Color3.fromRGB(80, 255, 100)

----------------------------------------------------------------
-- 건물 초록 하이라이트 (터치 피드백)
----------------------------------------------------------------
local function flashGreen(target: Instance?)
	if not target then return end
	local adornee = target:FindFirstAncestorWhichIsA("Model") or target
	local existing = adornee:FindFirstChild("_HarvestHighlight")
	if existing then existing:Destroy() end

	local hl = Instance.new("Highlight")
	hl.Name = "_HarvestHighlight"
	hl.FillColor = Color3.fromRGB(80, 255, 120)
	hl.FillTransparency = 0.45
	hl.OutlineColor = Color3.fromRGB(150, 255, 180)
	hl.OutlineTransparency = 0
	hl.Adornee = adornee
	hl.Parent = adornee

	task.spawn(function()
		task.wait(0.15)
		if not hl.Parent then return end
		local tween = TweenService:Create(hl, TweenInfo.new(0.45), {
			FillTransparency = 1,
			OutlineTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		hl:Destroy()
	end)
end

----------------------------------------------------------------
-- 픽업 파티클 — PlayerEffect_ 클론을 HRP에 Weld, 자식 ParticleEmitter들 :Emit(EmitCount)
----------------------------------------------------------------
local function playPickupParticles(kind: string)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local templateName = (kind == "gem") and "PlayerEffectDiamond" or "PlayerEffectMoney"
	local template = resourceFolder:FindFirstChild(templateName)
	if not template then return end

	local effect = template:Clone()
	if effect:IsA("BasePart") then
		effect.Anchored = false
		effect.CanCollide = false
		effect.CanQuery = false
		effect.CanTouch = false
		effect.Massless = true
		effect.Transparency = 1 -- 본체 숨김 (파티클만 보이게)
		effect.CFrame = hrp.CFrame

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = effect
		weld.Part1 = hrp
		weld.Parent = effect
	end
	effect.Parent = workspace

	-- 자식 파티클들 EmitCount 어트리뷰트만큼 Emit
	for _, d in effect:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local ec = d:GetAttribute("EmitCount") or 1
			d:Emit(ec)
		end
	end

	Debris:AddItem(effect, 1.5)
end

----------------------------------------------------------------
-- 화면 "+N" 텍스트 (메인 폰트, 초록, 위로 떠오르며 페이드)
----------------------------------------------------------------
local _pickupGui: ScreenGui? = nil
local function ensurePickupGui(): ScreenGui
	if _pickupGui and _pickupGui.Parent then return _pickupGui end
	_pickupGui = Instance.new("ScreenGui")
	_pickupGui.Name = "PickupTexts"
	_pickupGui.ResetOnSpawn = false
	_pickupGui.IgnoreGuiInset = true
	_pickupGui.DisplayOrder = 5
	_pickupGui.Parent = playerGui
	return _pickupGui
end

local function showPickupText(amount: number)
	local gui = ensurePickupGui()
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.new(0, 120, 0, 40)
	-- 화면 중하단 부근 살짝 랜덤
	local rx = 0.4 + math.random() * 0.2
	local ry = 0.55 + math.random() * 0.15
	label.Position = UDim2.new(rx, 0, ry, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = GREEN
	label.TextStrokeColor3 = Color3.fromRGB(0, 60, 0)
	label.TextStrokeTransparency = 0
	label.FontFace = MAIN_FONT
	label.TextSize = 30
	label.Text = "+" .. tostring(amount)
	label.Parent = gui

	local endPos = UDim2.new(rx, 0, ry - 0.08, 0)
	TweenService:Create(
		label,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = endPos,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	):Play()
	Debris:AddItem(label, 1.0)
end

----------------------------------------------------------------
-- init
----------------------------------------------------------------
function HarvestEffect.init()
	-- 건물 터치 피드백 (즉시 +N 텍스트는 더 이상 안 띄움 — 픽업 시 별도 표시)
	harvestEffectEvent.OnClientEvent:Connect(function(data)
		if not data then return end
		if data.building then flashGreen(data.building) end
	end)

	-- 드롭 흡수 → 캐릭터 파티클 + 화면 "+N"
	coinPickupEvent.OnClientEvent:Connect(function(data)
		if not data then return end
		playPickupParticles(data.kind or "coin")
		if data.amount and data.amount > 0 then
			showPickupText(data.amount)
		end
	end)
end

return HarvestEffect
