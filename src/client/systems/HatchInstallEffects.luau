-- HatchInstallEffects.luau
-- 알 부화 / 건물 설치 시 VFX/General 의 이펙트 파트를 클론해 위치에 배치하고
-- 자식 ParticleEmitter들을 EmitCount 어트리뷰트만큼 Emit.
-- 알 부화는 등급에 따라 ParticleEmitter.Color를 등급 색으로 설정.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local eggHatchEffectEvent = remotes:WaitForChild("EggHatchEffect")
local buildingInstallEffectEvent = remotes:WaitForChild("BuildingInstallEffect")

local vfxFolder = ReplicatedStorage:WaitForChild("VFX")

local HatchInstallEffects = {}

----------------------------------------------------------------
-- 헬퍼
----------------------------------------------------------------
-- 이펙트 파트를 위치에 클론해 모든 자식 ParticleEmitter를 EmitCount만큼 Emit.
-- @param template     클론할 BasePart (VFX/General 아래의 이펙트 파트)
-- @param position     Vector3 — 이펙트가 나타날 월드 좌표
-- @param colorOverride Color3? — 모든 ParticleEmitter.Color를 이 색 단일톤으로 덮어씀 (등급별)
-- @param emitScale    number? — EmitCount 배율 (1=원본, 0.5=절반 등). nil이면 1.
local function playEffect(template: BasePart, position: Vector3, colorOverride: Color3?, emitScale: number?)
	if not template or not position then return end
	local scale = emitScale or 1

	local fx = template:Clone()
	-- 안전 설정 (충돌/조회 비활성, 위치 이동)
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.CanTouch = false
	fx.Transparency = 1 -- 본체 숨김 (파티클만)
	fx.CFrame = CFrame.new(position)
	fx.Parent = workspace

	-- 자식 ParticleEmitter들 색상 적용 + Emit
	for _, d in fx:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			if colorOverride then
				d.Color = ColorSequence.new(colorOverride)
			end
			local ec = (d:GetAttribute("EmitCount") or 1) * scale
			d:Emit(math.max(1, math.floor(ec + 0.5)))
		end
	end

	-- 가장 긴 파티클 수명 + 여유. 단순하게 3초 후 정리.
	Debris:AddItem(fx, 3)
end

----------------------------------------------------------------
-- 알 부화 이펙트
----------------------------------------------------------------
local function getEggHatchTemplate(): BasePart?
	local general = vfxFolder:FindFirstChild("General")
	local eggFolder = general and general:FindFirstChild("Egg")
	local t = eggFolder and eggFolder:FindFirstChild("EggHatch")
	if t and t:IsA("BasePart") then return t end
	return nil
end

local function onEggHatch(position, rarity)
	if typeof(position) ~= "Vector3" then return end
	local template = getEggHatchTemplate()
	if not template then
		warn("[HatchInstallEffects] EggHatch 파트 없음 (ReplicatedStorage.VFX.General.Egg.EggHatch)")
		return
	end
	local rarityColor = Constants.RARITY_COLORS and Constants.RARITY_COLORS[rarity] or nil
	playEffect(template, position, rarityColor)
end

----------------------------------------------------------------
-- 건물 설치 이펙트
----------------------------------------------------------------
local function getBuildingInstallTemplate(): BasePart?
	local general = vfxFolder:FindFirstChild("General")
	local bldFolder = general and general:FindFirstChild("Building")
	local t = bldFolder and bldFolder:FindFirstChild("BuildingInstall")
	if t and t:IsA("BasePart") then return t end
	return nil
end

-- 건물 설치 이펙트는 너무 과해서 0.4배로 축소
local BUILDING_INSTALL_EMIT_SCALE = 0.4

local function onBuildingInstall(position)
	if typeof(position) ~= "Vector3" then return end
	local template = getBuildingInstallTemplate()
	if not template then
		warn("[HatchInstallEffects] BuildingInstall 파트 없음 (ReplicatedStorage.VFX.General.Building.BuildingInstall)")
		return
	end
	-- 건물 설치는 등급 색상 적용 안 함, 파티클 양만 축소
	playEffect(template, position, nil, BUILDING_INSTALL_EMIT_SCALE)
end

----------------------------------------------------------------
-- init
----------------------------------------------------------------
function HatchInstallEffects.init()
	eggHatchEffectEvent.OnClientEvent:Connect(onEggHatch)
	buildingInstallEffectEvent.OnClientEvent:Connect(onBuildingInstall)
end

return HatchInstallEffects
