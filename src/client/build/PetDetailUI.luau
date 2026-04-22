-- PetDetailUI.luau
-- 디자인 UI 사용 (StarterGui/Features/PetInfo)
-- Frame(Info, Jobs, Level, Weight), Header(Rarity), Icon

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local BalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalanceConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PetDetailUI = {}

local petInfoFrame = nil
local _visible = false

function PetDetailUI.init()
	local featuresGui = playerGui:WaitForChild("Features", 10)
	if not featuresGui then
		warn("[PetDetailUI] Features ScreenGui를 찾을 수 없음")
		return
	end

	petInfoFrame = featuresGui:FindFirstChild("PetInfo")
	if not petInfoFrame then
		warn("[PetDetailUI] PetInfo를 찾을 수 없음")
		return
	end

	petInfoFrame.Visible = false

	-- Header Close 버튼
	local header = petInfoFrame:FindFirstChild("Header")
	if header then
		local closeBtn = header:FindFirstChild("Close")
		if not closeBtn then
			-- Close가 없으면 ImageButton 찾기
			closeBtn = header:FindFirstChildWhichIsA("ImageButton") or header:FindFirstChildWhichIsA("TextButton")
		end
		if closeBtn and closeBtn:IsA("GuiButton") then
			closeBtn.MouseButton1Click:Connect(function()
				PetDetailUI.hide()
			end)
		end
	end
end

function PetDetailUI.show(petData: { [string]: any })
	if not petInfoFrame then return end
	_visible = true

	-- Header: 이름 + 희귀도
	local header = petInfoFrame:FindFirstChild("Header")
	if header then
		local textLabel = header:FindFirstChild("TextLabel")
		if textLabel then
			textLabel.Text = petData.petName or "???"
		end

		local rarityFrame = header:FindFirstChild("Rarity")
		if rarityFrame then
			local rarityText = rarityFrame:FindFirstChild("TextLabel") or rarityFrame:FindFirstChildWhichIsA("TextLabel")
			if rarityText then
				rarityText.Text = petData.rarity or "Common"
			end
		end
	end

	-- Frame: 상세 정보
	local frame = petInfoFrame:FindFirstChild("Frame")
	if frame then
		-- Info
		local infoFrame = frame:FindFirstChild("Info")
		if infoFrame then
			local textLabel = infoFrame:FindFirstChild("TextLabel") or infoFrame:FindFirstChildWhichIsA("TextLabel")
			if textLabel then
				local petType = petData.petType or "Construction"
				local petTypeKor = Constants.PetType[petType] or petType
				textLabel.Text = petData.petName .. " - " .. petTypeKor .. " specialist"
			end
		end

		-- Jobs (하는 일)
		local jobsFrame = frame:FindFirstChild("Jobs")
		if jobsFrame then
			local textLabel = jobsFrame:FindFirstChild("TextLabel") or jobsFrame:FindFirstChildWhichIsA("TextLabel")
			if textLabel then
				local petType = petData.petType or "Construction"
				textLabel.Text = Constants.PetType[petType] or petType
			end
		end

		-- Weight
		local weightFrame = frame:FindFirstChild("Weight")
		if weightFrame then
			local textLabel = weightFrame:FindFirstChild("TextLabel") or weightFrame:FindFirstChildWhichIsA("TextLabel")
			if textLabel then
				textLabel.Text = string.format("%.1fkg", petData.weight or 0)
			end
		end

		-- Level (2개 있음 - 하나는 레벨 숫자, 하나는 EXP 바)
		local levels = {}
		for _, child in frame:GetChildren() do
			if child.Name == "Level" then
				table.insert(levels, child)
			end
		end

		local level = petData.level or 1
		local xp = petData.xp or 0
		local xpRequired = BalanceConfig.Pet.XP_REQUIRED[level] or 0

		if levels[1] then
			local textLabel = levels[1]:FindFirstChild("TextLabel") or levels[1]:FindFirstChildWhichIsA("TextLabel")
			if textLabel then
				textLabel.Text = "Lv." .. level
			end
		end

		if levels[2] then
			local textLabel = levels[2]:FindFirstChild("TextLabel") or levels[2]:FindFirstChildWhichIsA("TextLabel")
			if textLabel then
				textLabel.Text = xp .. " / " .. (xpRequired > 0 and xpRequired or "MAX") .. " EXP"
			end
		end
	end

	petInfoFrame.Visible = true
end

function PetDetailUI.hide()
	if not petInfoFrame then return end
	_visible = false
	petInfoFrame.Visible = false
end

function PetDetailUI.isVisible(): boolean
	return _visible
end

function PetDetailUI.destroy()
end

return PetDetailUI
