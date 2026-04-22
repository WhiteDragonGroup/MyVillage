-- VillageSignManager.luau
-- 마을 표지판 관리: 플롯 배정 시 이름/아이콘 표시, 미배정 시 비활성화

local Players = game:GetService("Players")

local VillageSignManager = {}

local signsFolder = nil

function VillageSignManager.init()
	signsFolder = workspace:FindFirstChild("VillageSigns")
	if not signsFolder then
		warn("[VillageSignManager] VillageSigns 폴더를 찾을 수 없음")
		return
	end

	-- 초기: 모든 표지판 비활성화
	for _, plotSign in signsFolder:GetChildren() do
		VillageSignManager._setSignEmpty(plotSign)
	end
end

-- 플롯 배정 시 표지판 업데이트
function VillageSignManager.assignSign(plotName: string, player: Player)
	if not signsFolder then return end

	local plotSign = signsFolder:FindFirstChild(plotName)
	if not plotSign then return end

	-- Name 표시
	local nameLabel = plotSign:FindFirstChild("Name")
	if nameLabel then
		if nameLabel:IsA("SurfaceGui") then
			local textLabel = nameLabel:FindFirstChildWhichIsA("TextLabel")
			if textLabel then
				textLabel.Text = player.Name
			end
		elseif nameLabel:IsA("BasePart") then
			local surfaceGui = nameLabel:FindFirstChildWhichIsA("SurfaceGui")
			if surfaceGui then
				local textLabel = surfaceGui:FindFirstChildWhichIsA("TextLabel")
				if textLabel then
					textLabel.Text = player.Name
				end
			end
		end
	end

	-- ProfileIcon 표시
	local profileIcon = plotSign:FindFirstChild("ProfileIcon")
	if profileIcon then
		local imageLabel = profileIcon:FindFirstChildWhichIsA("ImageLabel")
		if not imageLabel then
			imageLabel = profileIcon:FindFirstChildWhichIsA("ImageButton")
		end
		if imageLabel then
			-- 플레이어 썸네일 가져오기
			local success, result = pcall(function()
				return Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100
				)
			end)
			if success and result then
				imageLabel.Image = result
			end
		end
	end

	-- 표지판 활성화 (Transparency 복원)
	VillageSignManager._setSignActive(plotSign, true)

	print("[VillageSign] " .. plotName .. " → " .. player.Name)
end

-- 플롯 해제 시 표지판 비활성화
function VillageSignManager.releaseSign(plotName: string)
	if not signsFolder then return end

	local plotSign = signsFolder:FindFirstChild(plotName)
	if not plotSign then return end

	VillageSignManager._setSignEmpty(plotSign)

	print("[VillageSign] " .. plotName .. " 비활성화")
end

-- 표지판 비활성화 (빈 상태)
function VillageSignManager._setSignEmpty(plotSign)
	local nameLabel = plotSign:FindFirstChild("Name")
	if nameLabel then
		if nameLabel:IsA("SurfaceGui") then
			local textLabel = nameLabel:FindFirstChildWhichIsA("TextLabel")
			if textLabel then textLabel.Text = "" end
		elseif nameLabel:IsA("BasePart") then
			local surfaceGui = nameLabel:FindFirstChildWhichIsA("SurfaceGui")
			if surfaceGui then
				local textLabel = surfaceGui:FindFirstChildWhichIsA("TextLabel")
				if textLabel then textLabel.Text = "" end
			end
		end
	end

	VillageSignManager._setSignActive(plotSign, false)
end

-- 표지판 활성/비활성 시각 효과
function VillageSignManager._setSignActive(plotSign, active: boolean)
	for _, desc in plotSign:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Transparency = if active then 0 else 0.6
		end
	end
end

return VillageSignManager
