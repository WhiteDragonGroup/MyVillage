-- UpgradeManager.luau
-- 건물 업그레이드 로직 (ModuleScript)
-- startUpgrade, cancelUpgrade, addProgress, completeUpgrade

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local UpgradeCfg = BalanceConfig.Upgrade
local PetCfg = BalanceConfig.Pet

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local upgradeStateChanged = remotes:WaitForChild("UpgradeStateChanged")

local UpgradeManager = {}

-- 활성 업그레이드 루프 { [buildingId] = true }
local _activeLoops = {}

-- 업그레이드 완료 콜백 (PetManager 연결용)
local _onCompleteCallback = nil

function UpgradeManager.setOnCompleteCallback(callback: (Player, string) -> ())
	_onCompleteCallback = callback
end

----------------------------------------------------------------
-- 업그레이드 시작
----------------------------------------------------------------
function UpgradeManager.startUpgrade(player: Player, building: BasePart): (boolean, string?)
	local level = building:GetAttribute("Level") or 1
	if level >= UpgradeCfg.MAX_LEVEL then
		return false, "최대 레벨"
	end

	local state = building:GetAttribute("UpgradeState") or ""
	if state == Constants.UpgradeState.Upgrading then
		return false, "이미 수리중"
	end

	-- 비용 체크 (현재 무료)
	-- local cost = UpgradeCfg.COST[level] or 0

	-- 상태 변경
	building:SetAttribute("UpgradeState", Constants.UpgradeState.Upgrading)
	building:SetAttribute("UpgradeProgress", 0)

	local buildingId = building:GetAttribute("BuildingId")

	-- 진행도 루프 시작
	UpgradeManager._startProgressLoop(player, building, buildingId)

	-- 클라이언트 알림
	upgradeStateChanged:FireClient(player, buildingId, "started", level)

	print(player.Name .. " - " .. (building:GetAttribute("ItemName") or "?") .. " 업그레이드 시작 (Lv." .. level .. ")")
	return true
end

----------------------------------------------------------------
-- 업그레이드 취소
----------------------------------------------------------------
function UpgradeManager.cancelUpgrade(player: Player, building: BasePart): (boolean, string?)
	local state = building:GetAttribute("UpgradeState") or ""
	if state ~= Constants.UpgradeState.Upgrading then
		return false, "수리중이 아님"
	end

	local buildingId = building:GetAttribute("BuildingId")

	-- 루프 중단
	_activeLoops[buildingId] = nil

	-- 상태 복원
	building:SetAttribute("UpgradeState", Constants.UpgradeState.None)
	building:SetAttribute("UpgradeProgress", 0)
	building:SetAttribute("AssignedPetId", "")

	-- 클라이언트 알림
	upgradeStateChanged:FireClient(player, buildingId, "cancelled")

	print(player.Name .. " - " .. (building:GetAttribute("ItemName") or "?") .. " 업그레이드 취소")
	return true
end

----------------------------------------------------------------
-- 진행도 루프 (펫이 배치되어 있을 때만 진행)
----------------------------------------------------------------
function UpgradeManager._startProgressLoop(player: Player, building: BasePart, buildingId: string)
	if _activeLoops[buildingId] then return end
	_activeLoops[buildingId] = true

	task.spawn(function()
		while _activeLoops[buildingId] do
			task.wait(UpgradeCfg.PROGRESS_TICK)

			-- 건물이 아직 존재하는지 확인
			if not building or not building.Parent then
				_activeLoops[buildingId] = nil
				break
			end

			-- 수리중 상태인지 확인
			local state = building:GetAttribute("UpgradeState") or ""
			if state ~= Constants.UpgradeState.Upgrading then
				_activeLoops[buildingId] = nil
				break
			end

			-- 펫이 배치되어 있는지 확인
			local assignedPetId = building:GetAttribute("AssignedPetId") or ""
			if assignedPetId == "" then
				continue
			end

			-- 진행도 증가
			local progress = building:GetAttribute("UpgradeProgress") or 0
			local increment = PetCfg.BUILD_SPEED -- 기본 속도
			progress = math.min(100, progress + increment)
			building:SetAttribute("UpgradeProgress", progress)

			-- 100% 도달 시 완료
			if progress >= 100 then
				UpgradeManager._completeUpgrade(player, building, buildingId)
				break
			end
		end
	end)
end

----------------------------------------------------------------
-- 업그레이드 완료
----------------------------------------------------------------
function UpgradeManager._completeUpgrade(player: Player, building: BasePart, buildingId: string)
	_activeLoops[buildingId] = nil

	local level = building:GetAttribute("Level") or 1
	local newLevel = level + 1

	-- 레벨 업
	building:SetAttribute("Level", newLevel)
	building:SetAttribute("UpgradeState", Constants.UpgradeState.None)
	building:SetAttribute("UpgradeProgress", 0)

	-- 펫 해제 (PetManager가 처리)
	local assignedPetId = building:GetAttribute("AssignedPetId") or ""
	building:SetAttribute("AssignedPetId", "")

	-- 외형 변화 적용
	UpgradeManager.applyVisualUpgrade(building, newLevel)

	-- 펫 자동 해제 콜백
	if _onCompleteCallback and assignedPetId ~= "" then
		_onCompleteCallback(player, assignedPetId)
	end

	-- 클라이언트 알림
	upgradeStateChanged:FireClient(player, buildingId, "completed", newLevel)

	print(player.Name .. " - " .. (building:GetAttribute("ItemName") or "?") .. " 레벨업! Lv." .. newLevel)

	return assignedPetId
end

----------------------------------------------------------------
-- 외형 변화 적용 (크기 증가 + 색상 밝아짐)
----------------------------------------------------------------
function UpgradeManager.applyVisualUpgrade(building: BasePart, level: number)
	-- 원본 크기 저장 (최초 1회)
	local origSizeX = building:GetAttribute("OrigSizeX")
	if not origSizeX then
		building:SetAttribute("OrigSizeX", building.Size.X)
		building:SetAttribute("OrigSizeY", building.Size.Y)
		building:SetAttribute("OrigSizeZ", building.Size.Z)
		building:SetAttribute("OrigColorR", building.Color.R)
		building:SetAttribute("OrigColorG", building.Color.G)
		building:SetAttribute("OrigColorB", building.Color.B)
	end

	local origSize = Vector3.new(
		building:GetAttribute("OrigSizeX"),
		building:GetAttribute("OrigSizeY"),
		building:GetAttribute("OrigSizeZ")
	)
	local origColor = Color3.new(
		building:GetAttribute("OrigColorR"),
		building:GetAttribute("OrigColorG"),
		building:GetAttribute("OrigColorB")
	)

	-- 크기 스케일
	local scale = UpgradeCfg.SIZE_SCALE[level] or 1.0
	building.Size = origSize * scale

	-- 색상 밝기
	local brighten = UpgradeCfg.COLOR_BRIGHTEN[level] or 0
	building.Color = Color3.new(
		math.min(1, origColor.R + brighten),
		math.min(1, origColor.G + brighten),
		math.min(1, origColor.B + brighten)
	)
end

----------------------------------------------------------------
-- 건물이 수리중인지 확인 (외부 모듈 참조용)
----------------------------------------------------------------
function UpgradeManager.isUpgrading(building: BasePart): boolean
	local state = building:GetAttribute("UpgradeState") or ""
	return state == Constants.UpgradeState.Upgrading
end

-- 플레이어 퇴장 시 해당 건물들의 루프 정리
function UpgradeManager.cleanupPlayer(plot: Instance)
	for _, child in plot:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("BuildingId") then
			local buildingId = child:GetAttribute("BuildingId")
			_activeLoops[buildingId] = nil
		end
	end
end

return UpgradeManager
