-- MutationVFX.luau
-- 돌연변이 VFX: HumanoidRootPart에 WeldConstraint로 부착
-- Gold/Celestial: 컬러 곱연산, Inverted: 색 반전

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local MutationVFX = {}

local _appliedVFX = {} -- { [BasePart]: { [mutationType]: Instance } }

local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
local mutationFolder = vfxFolder and vfxFolder:FindFirstChild("Mutation")

----------------------------------------------------------------
-- 색상 유틸리티
----------------------------------------------------------------

-- Color3 곱연산 (0~1 범위 유지)
local function multiplyColor(base: Color3, multiplier: Color3): Color3
	return Color3.new(
		math.clamp(base.R * multiplier.R, 0, 1),
		math.clamp(base.G * multiplier.G, 0, 1),
		math.clamp(base.B * multiplier.B, 0, 1)
	)
end

-- Color3 반전
local function invertColor(c: Color3): Color3
	return Color3.new(1 - c.R, 1 - c.G, 1 - c.B)
end

----------------------------------------------------------------
-- 색상 변환 적용 (Gold/Celestial → 곱연산, Inverted → 반전)
----------------------------------------------------------------
local GOLD_TINT = Color3.fromRGB(255, 215, 0) -- 정규화: (1, 0.843, 0)
local CELESTIAL_TINT = Color3.fromRGB(200, 230, 255) -- 정규화: (0.784, 0.902, 1)

local function applyColorMutation(pet: BasePart, mutationType: string)
	-- Model이면 모든 BasePart에 적용, 아니면 단일 파트
	local parts = {}
	local parent = pet.Parent
	if parent and parent:IsA("Model") then
		for _, desc in parent:GetDescendants() do
			if desc:IsA("BasePart") and not desc:GetAttribute("IsCollisionBox") then
				table.insert(parts, desc)
			end
		end
	else
		table.insert(parts, pet)
	end

	for _, part in parts do
		-- 원본 색상 저장 (최초 1회)
		if not part:GetAttribute("_OriginalColor") then
			local c = part.Color
			part:SetAttribute("_OriginalColor", string.format("%.3f,%.3f,%.3f", c.R, c.G, c.B))
		end

		local baseColor = part.Color

		if mutationType == "Gold" then
			part.Color = multiplyColor(baseColor, GOLD_TINT)
		elseif mutationType == "Celestial" then
			part.Color = multiplyColor(baseColor, CELESTIAL_TINT)
		elseif mutationType == "Inverted" then
			-- 반전은 다른 색 변환 후 최후순위로 적용
			part.Color = invertColor(part.Color)
		end
	end
end

-- 색상 복원
local function restoreColors(pet: BasePart)
	local parts = {}
	local parent = pet.Parent
	if parent and parent:IsA("Model") then
		for _, desc in parent:GetDescendants() do
			if desc:IsA("BasePart") and desc:GetAttribute("_OriginalColor") then
				table.insert(parts, desc)
			end
		end
	else
		if pet:GetAttribute("_OriginalColor") then
			table.insert(parts, pet)
		end
	end

	for _, part in parts do
		local stored = part:GetAttribute("_OriginalColor")
		if stored then
			local r, g, b = stored:match("([%d%.]+),([%d%.]+),([%d%.]+)")
			if r then
				part.Color = Color3.new(tonumber(r), tonumber(g), tonumber(b))
			end
			part:SetAttribute("_OriginalColor", nil)
		end
	end
end

----------------------------------------------------------------
-- VFX 모델 부착 (WeldConstraint 방식)
----------------------------------------------------------------
local function attachVFXModel(pet: BasePart, mutationType: string)
	if not mutationFolder then return nil end

	local vfxTemplate = mutationFolder:FindFirstChild(mutationType)
	if not vfxTemplate then return nil end

	local vfx = vfxTemplate:Clone()
	vfx.Name = "MutationVFX_" .. mutationType

	-- HumanoidRootPart (베이스 파트) 찾기
	local basePart = pet
	local parent = pet.Parent
	if parent and parent:IsA("Model") then
		local hrp = parent:FindFirstChild("HumanoidRootPart")
		if hrp then
			basePart = hrp
		end
	end

	-- VFX 위치 설정 + WeldConstraint
	if vfx:IsA("Model") then
		local vfxPrimary = vfx.PrimaryPart or vfx:FindFirstChildWhichIsA("BasePart")
		if vfxPrimary then
			vfx:PivotTo(basePart.CFrame)
			vfx.Parent = basePart.Parent or basePart

			local weld = Instance.new("WeldConstraint")
			weld.Name = "MutationWeld_" .. mutationType
			weld.Part0 = basePart
			weld.Part1 = vfxPrimary
			weld.Parent = vfxPrimary
		end
	elseif vfx:IsA("BasePart") then
		vfx.CFrame = basePart.CFrame
		vfx.Anchored = false
		vfx.CanCollide = false
		vfx.CanQuery = false
		vfx.CanTouch = false
		vfx.Parent = basePart.Parent or basePart

		local weld = Instance.new("WeldConstraint")
		weld.Name = "MutationWeld_" .. mutationType
		weld.Part0 = basePart
		weld.Part1 = vfx
		weld.Parent = vfx
	end

	return vfx
end

----------------------------------------------------------------
-- 공개 API
----------------------------------------------------------------

-- 펫에 돌연변이 VFX 적용
function MutationVFX.apply(pet: BasePart, mutationType: string)
	if not _appliedVFX[pet] then
		_appliedVFX[pet] = {}
	end

	-- 이미 적용된 경우 스킵
	if _appliedVFX[pet][mutationType] then return end

	-- 1. VFX 모델 부착 (있으면)
	local vfxInstance = attachVFXModel(pet, mutationType)
	_appliedVFX[pet][mutationType] = vfxInstance or true

	-- 2. 색상 변환 (Gold/Celestial 먼저, Inverted 나중)
	if mutationType == "Gold" or mutationType == "Celestial" then
		applyColorMutation(pet, mutationType)
	end
end

-- Inverted는 다른 색 변환 후 최후순위로 호출
function MutationVFX.applyInverted(pet: BasePart)
	if not _appliedVFX[pet] then
		_appliedVFX[pet] = {}
	end
	if _appliedVFX[pet]["Inverted"] then return end

	local vfxInstance = attachVFXModel(pet, "Inverted")
	_appliedVFX[pet]["Inverted"] = vfxInstance or true

	applyColorMutation(pet, "Inverted")
end

-- 펫의 모든 돌연변이 VFX 적용 (mutations 테이블 기반)
function MutationVFX.applyAll(pet: BasePart, mutations: { string })
	if not mutations or #mutations == 0 then return end

	local hasInverted = false

	-- Gold/Celestial 등 색 변환 먼저
	for _, mut in mutations do
		if mut == "Inverted" then
			hasInverted = true
		else
			MutationVFX.apply(pet, mut)
		end
	end

	-- Inverted는 최후순위
	if hasInverted then
		MutationVFX.applyInverted(pet)
	end
end

-- 특정 돌연변이 VFX 제거
function MutationVFX.remove(pet: BasePart, mutationType: string)
	local vfxMap = _appliedVFX[pet]
	if not vfxMap then return end

	local vfx = vfxMap[mutationType]
	if vfx and typeof(vfx) ~= "boolean" then
		if vfx.Parent then
			vfx:Destroy()
		end
	end
	vfxMap[mutationType] = nil

	-- 색상 변환 타입이면 색상 복원
	if mutationType == "Gold" or mutationType == "Celestial" or mutationType == "Inverted" then
		restoreColors(pet)
	end
end

-- 모든 VFX 제거
function MutationVFX.removeAll(pet: BasePart)
	local vfxMap = _appliedVFX[pet]
	if not vfxMap then return end

	for mutationType, vfx in vfxMap do
		if vfx and typeof(vfx) ~= "boolean" then
			if vfx.Parent then
				vfx:Destroy()
			end
		end
	end

	restoreColors(pet)
	_appliedVFX[pet] = nil
end

return MutationVFX
