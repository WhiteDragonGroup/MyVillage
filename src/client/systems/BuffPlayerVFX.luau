-- BuffPlayerVFX.luau
-- 플레이어가 가진 활성 버프마다 VFX/Buff 의 해당 파티클 파트를 캐릭터(HRP)에 부착.
-- buffUpdateEvent로 활성 버프 목록을 받아 추가/제거를 동기화한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buffUpdateEvent = remotes:WaitForChild("BuffUpdate")
local getBuffsFunc = remotes:WaitForChild("GetBuffs")

local vfxFolder = ReplicatedStorage:WaitForChild("VFX")
local buffFolder = vfxFolder:WaitForChild("Buff")

-- 코드 ID(어퍼스트로피 없음) → VFX 폴더 이름(어퍼스트로피 있음). 나머지는 동일 이름.
local NAME_MAP: { [string]: string } = {
	AllysEncouragement = "Ally'sEncouragement",
	GhostsSong = "Ghost'sSong",
	DragonsPower = "Dragon'sPower",
}

local BuffPlayerVFX = {}

local _active: { [string]: BasePart } = {} -- buffId → 부착된 VFX 파트

local function findTemplate(buffId: string): BasePart?
	local name = NAME_MAP[buffId] or buffId
	local t = buffFolder:FindFirstChild(name)
	if t and t:IsA("BasePart") then return t end
	return nil
end

local function getHRP(): (BasePart?, Model?)
	local character = player.Character
	if not character then return nil, nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then return nil, character end
	return hrp, character
end

local function attachBuff(buffId: string)
	if _active[buffId] then return end
	local hrp, character = getHRP()
	if not hrp then return end
	local template = findTemplate(buffId)
	if not template then return end

	local vfx = template:Clone()
	vfx.Name = "BuffVFX_" .. buffId
	vfx.Anchored = false
	vfx.CanCollide = false
	vfx.CanQuery = false
	vfx.CanTouch = false
	vfx.Massless = true
	vfx.Transparency = 1 -- 본체 숨김 (파티클만 보이게)
	vfx.CFrame = hrp.CFrame

	local weld = Instance.new("WeldConstraint")
	weld.Name = "BuffWeld"
	weld.Part0 = vfx
	weld.Part1 = hrp
	weld.Parent = vfx

	vfx.Parent = character or workspace
	_active[buffId] = vfx
end

local function detachBuff(buffId: string)
	local vfx = _active[buffId]
	if vfx and vfx.Parent then vfx:Destroy() end
	_active[buffId] = nil
end

local function clearAll()
	for buffId, vfx in _active do
		if vfx and vfx.Parent then vfx:Destroy() end
	end
	_active = {}
end

local function applyBuffList(buffs)
	if typeof(buffs) ~= "table" then return end
	local seen: { [string]: boolean } = {}
	for _, entry in buffs do
		if typeof(entry) == "table" and typeof(entry.buffId) == "string" then
			seen[entry.buffId] = true
			if not _active[entry.buffId] then
				attachBuff(entry.buffId)
			end
		end
	end
	-- 활성 목록에서 빠진 버프는 제거
	for buffId in _active do
		if not seen[buffId] then
			detachBuff(buffId)
		end
	end
end

function BuffPlayerVFX.init()
	-- 캐릭터 리스폰 시 _active 초기화 (옛 캐릭터에 붙어있던 vfx는 파괴됨)
	player.CharacterAdded:Connect(function()
		clearAll()
		-- 새 캐릭터에 재부착
		task.defer(function()
			local ok, buffs = pcall(function() return getBuffsFunc:InvokeServer() end)
			if ok then applyBuffList(buffs) end
		end)
	end)

	-- 서버 변경 사항 수신
	buffUpdateEvent.OnClientEvent:Connect(applyBuffList)

	-- 초기 로드
	task.spawn(function()
		local ok, buffs = pcall(function() return getBuffsFunc:InvokeServer() end)
		if ok then applyBuffList(buffs) end
	end)
end

return BuffPlayerVFX
