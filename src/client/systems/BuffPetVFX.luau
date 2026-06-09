-- BuffPetVFX.luau
-- 펫별 활성 버프에 따라 VFX/Buff 파티클을 펫 모델 메인 파트(HumanoidRootPart/mainPart)에 부착.
-- 서버 PetBuffUpdate(FireAllClients)로 동기화.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local petBuffUpdateEvent = remotes:WaitForChild("PetBuffUpdate")

local vfxFolder = ReplicatedStorage:WaitForChild("VFX")
local buffFolder = vfxFolder:WaitForChild("Buff")

-- 코드 ID(어퍼스트로피 없음) → VFX 폴더 이름(어퍼스트로피 있음)
local NAME_MAP: { [string]: string } = {
	AllysEncouragement = "Ally'sEncouragement",
	GhostsSong = "Ghost'sSong",
	DragonsPower = "Dragon'sPower",
}

local BuffPetVFX = {}

-- petId → 펫 메인 파트 (createPetModel이 mainPart.PetId 속성 + 모델명 Pet_<id> 부여)
local _petParts: { [string]: BasePart } = {}
-- petId → { [buffId] = 부착된 VFX 파트 }
local _activeVFX: { [string]: { [string]: BasePart } } = {}

local function findTemplate(buffId: string): BasePart?
	local name = NAME_MAP[buffId] or buffId
	local t = buffFolder:FindFirstChild(name)
	print(string.format("[BuffVFX-client] findTemplate buffId=%q → folderName=%q found=%s",
		tostring(buffId), tostring(name), tostring(t ~= nil)))
	if t and t:IsA("BasePart") then return t end
	return nil
end

local function detachBuff(petId: string, buffId: string)
	local petBuffs = _activeVFX[petId]
	if not petBuffs then return end
	local vfx = petBuffs[buffId]
	if vfx and vfx.Parent then vfx:Destroy() end
	petBuffs[buffId] = nil
	if next(petBuffs) == nil then _activeVFX[petId] = nil end
end

local function detachAll(petId: string)
	local petBuffs = _activeVFX[petId]
	if not petBuffs then return end
	for buffId, vfx in petBuffs do
		if vfx and vfx.Parent then vfx:Destroy() end
	end
	_activeVFX[petId] = nil
end

local function attachBuff(petPart: BasePart, petId: string, buffId: string)
	local petBuffs = _activeVFX[petId]
	if not petBuffs then
		petBuffs = {}
		_activeVFX[petId] = petBuffs
	end
	if petBuffs[buffId] and petBuffs[buffId].Parent then return end -- 이미 부착

	local template = findTemplate(buffId)
	if not template then return end

	local vfx = template:Clone()
	vfx.Name = "BuffVFX_" .. buffId
	vfx.Anchored = false
	vfx.CanCollide = false
	vfx.CanQuery = false
	vfx.CanTouch = false
	vfx.Massless = true
	vfx.Transparency = 1 -- 본체 숨김 (파티클만)
	vfx.CFrame = petPart.CFrame

	local weld = Instance.new("WeldConstraint")
	weld.Name = "BuffWeld"
	weld.Part0 = vfx
	weld.Part1 = petPart
	weld.Parent = vfx

	vfx.Parent = petPart.Parent or workspace
	petBuffs[buffId] = vfx
end

local function trackPetPart(part: BasePart)
	local petId = part:GetAttribute("PetId")
	if typeof(petId) ~= "string" or petId == "" then return end
	_petParts[petId] = part
	part.AncestryChanged:Connect(function(_, parent)
		if not parent then
			_petParts[petId] = nil
			detachAll(petId)
		end
	end)
end

local function scanWorkspace()
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("PetId") then
			trackPetPart(d)
		end
	end
end

local function applyPetBuffList(petId, buffs)
	if typeof(petId) ~= "string" or typeof(buffs) ~= "table" then return end
	local petPart = _petParts[petId]
	if not petPart or not petPart.Parent then
		-- 펫 모델이 아직 안 들어왔으면 짧게 기다린 후 재시도 (한 번)
		task.delay(0.5, function()
			local pp = _petParts[petId]
			if pp and pp.Parent then
				applyPetBuffList(petId, buffs)
			end
		end)
		return
	end
	local seen: { [string]: boolean } = {}
	for _, entry in buffs do
		if typeof(entry) == "table" and typeof(entry.buffId) == "string" then
			seen[entry.buffId] = true
			attachBuff(petPart, petId, entry.buffId)
		end
	end
	local petBuffs = _activeVFX[petId]
	if petBuffs then
		for buffId in petBuffs do
			if not seen[buffId] then
				detachBuff(petId, buffId)
			end
		end
	end
end

function BuffPetVFX.init()
	scanWorkspace()
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d:GetAttribute("PetId") then
			trackPetPart(d)
		end
	end)
	petBuffUpdateEvent.OnClientEvent:Connect(applyPetBuffList)
end

return BuffPetVFX
