-- PetAbilityManager.server.luau
-- 펫 능동 능력 처리 (주변 펫 버프 적용 등)
-- 1초마다 모든 펫 모델 검사 → 쿨다운 끝났으면 능력 발동

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverScript = script.Parent
local BuffManager = require(serverScript:WaitForChild("BuffManager"))
local WeatherState = require(serverScript:WaitForChild("WeatherState"))

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local AbilityCfg = BalanceConfig.PetAbility

-- 마지막 발동 시간: { [petId] = tick() }
local _lastUsed: { [string]: number } = {}

local function findNearbyPets(centerPart: BasePart, range: number, samePet: string?, excludePetId: string?): { BasePart }
	local result = {}
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return result end
	for _, desc in plotsFolder:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("PetId") then
			if excludePetId and desc:GetAttribute("PetId") == excludePetId then continue end
			if samePet and desc:GetAttribute("PetName") ~= samePet then continue end
			local d = (desc.Position - centerPart.Position).Magnitude
			if d <= range then
				table.insert(result, desc)
			end
		end
	end
	return result
end

local function applyAbility(petPart: BasePart, petName: string, cfg)
	local petId = petPart:GetAttribute("PetId")
	if not petId then return end

	if cfg.kind == "buff_kin" then
		local kin = findNearbyPets(petPart, cfg.range, petName, petId)
		if #kin > 0 then
			local level = cfg.levelByKinCount and #kin or (cfg.level or 1)
			-- 자기 자신에게 적용 (같은 종 발견 시 자기가 인사받음)
			BuffManager.applyPetBuff(petId, cfg.buffId, level, cfg.duration)
		end
	elseif cfg.kind == "buff_others" then
		local others = findNearbyPets(petPart, cfg.range, nil, petId)
		for _, otherPart in others do
			local otherId = otherPart:GetAttribute("PetId")
			if otherId then
				BuffManager.applyPetBuff(otherId, cfg.buffId, cfg.level or 1, cfg.duration)
			end
		end
	elseif cfg.kind == "buff_others_multi" then
		local others = findNearbyPets(petPart, cfg.range, nil, petId)
		for _, otherPart in others do
			local otherId = otherPart:GetAttribute("PetId")
			if otherId then
				for _, b in cfg.buffs do
					BuffManager.applyPetBuff(otherId, b.buffId, b.level, b.duration)
				end
			end
		end
	elseif cfg.kind == "buff_aoe" then
		local nearby = findNearbyPets(petPart, cfg.range, nil, nil)
		for _, p in nearby do
			local pid = p:GetAttribute("PetId")
			if pid then
				BuffManager.applyPetBuff(pid, cfg.buffId, cfg.level or 1, cfg.duration)
			end
		end
	elseif cfg.kind == "buff_aoe_conditional" then
		if cfg.requireWeather and WeatherState.get and WeatherState.get() ~= cfg.requireWeather then
			return
		end
		if cfg.requireIdle then
			local state = petPart:GetAttribute("State")
			if state == "Working" then return end
		end
		local nearby = findNearbyPets(petPart, cfg.range, nil, nil)
		for _, p in nearby do
			local pid = p:GetAttribute("PetId")
			if pid then
				BuffManager.applyPetBuff(pid, cfg.buffId, cfg.level or 1, cfg.duration)
			end
		end
	elseif cfg.kind == "egg_pet" then
		-- 마을 알 모델 찾아서 부화 시간 단축
		local plot = petPart:FindFirstAncestorWhichIsA("Model")
		while plot and plot.Parent and plot.Parent.Name ~= "Plots" do
			plot = plot.Parent and plot.Parent:IsA("Model") and plot.Parent or nil
		end
		if not plot then return end
		for _, desc in plot:GetDescendants() do
			if desc:IsA("BasePart") and desc:GetAttribute("IsEgg") and not desc:GetAttribute("ReadyToHatch") then
				local placedTime = desc:GetAttribute("PlacedTime") or 0
				desc:SetAttribute("PlacedTime", placedTime - cfg.hatchReductionSec)
				break
			end
		end
	end
	-- summon kind: 별도 처리 (Witch 소환은 별도 PR로)
end

local function processPet(petPart: BasePart)
	local petName = petPart:GetAttribute("PetName")
	if not petName then return end
	local cfg = AbilityCfg.ABILITIES[petName]
	if not cfg then return end
	local petId = petPart:GetAttribute("PetId")
	if not petId then return end

	local now = tick()
	local last = _lastUsed[petId] or 0
	if now - last < cfg.cooldown then return end

	_lastUsed[petId] = now
	applyAbility(petPart, petName, cfg)
end

task.spawn(function()
	while true do
		task.wait(2)
		local plotsFolder = workspace:FindFirstChild("Plots")
		if plotsFolder then
			for _, desc in plotsFolder:GetDescendants() do
				if desc:IsA("BasePart") and desc:GetAttribute("PetId") then
					pcall(processPet, desc)
				end
			end
		end
	end
end)

print("PetAbilityManager 로드됨")
