-- LicenseGuard.server.luau
-- GitHub Gist에 "MyVillage"가 있으면 게임 작동, 없으면 차단
-- 서버 스크립트라 클라이언트에서 코드/URL 안 보임

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

------------------------------------------------------------------------
-- 설정
------------------------------------------------------------------------
local LICENSE_URL = "https://gist.githubusercontent.com/WhiteDragonGroup/54060d3af211a6d5ba45dcb5fd01d148/raw/allowed_places.txt"
local LICENSE_KEY = "MyVillage"

-- Studio 테스트는 항상 허용
local ALWAYS_ALLOW_STUDIO = true

-- 5분마다 재검증 (Gist에서 지우면 실행 중인 서버도 꺼짐)
local CHECK_INTERVAL = 300

------------------------------------------------------------------------
-- 차단 처리
------------------------------------------------------------------------
local function blockServer()
	warn("[LicenseGuard] 라이선스 검증 실패")

	for _, child in script.Parent:GetChildren() do
		if child:IsA("Script") and child ~= script then
			child.Enabled = false
		end
	end

	for _, player in Players:GetPlayers() do
		player:Kick("이 게임은 현재 사용할 수 없습니다.")
	end

	Players.PlayerAdded:Connect(function(player)
		player:Kick("이 게임은 현재 사용할 수 없습니다.")
	end)
end

------------------------------------------------------------------------
-- 라이선스 검증
------------------------------------------------------------------------
local function checkLicense(): boolean
	if ALWAYS_ALLOW_STUDIO and game.PlaceId == 0 then
		return true
	end

	-- 캐시 우회: 매번 다른 URL로 요청
	local url = LICENSE_URL .. "?t=" .. tostring(os.time())
	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if not success then
		warn("[LicenseGuard] 외부 검증 실패: " .. tostring(response))
		return true
	end

	-- Gist 내용에 "MyVillage"가 포함되어 있으면 허용
	return string.find(response, LICENSE_KEY, 1, true) ~= nil
end

------------------------------------------------------------------------
-- 실행
------------------------------------------------------------------------
if not checkLicense() then
	blockServer()
elseif CHECK_INTERVAL > 0 then
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			if not checkLicense() then
				blockServer()
				break
			end
		end
	end)
end
