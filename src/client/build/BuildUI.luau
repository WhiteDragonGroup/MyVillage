-- BuildUI.luau
-- 빌드모드 토글 콜백 관리 (화면 버튼은 MainHUD 사이드바로 이동됨)

local BuildUI = {}

local _onToggle = nil

function BuildUI.init(onToggle: (boolean) -> ())
	_onToggle = onToggle
end

-- 외부에서 토글 호출 (키보드 B키 등)
function BuildUI.toggle()
	if _onToggle then
		_onToggle(true)
	end
end

-- 빌드모드 상태 변경 (호환용, 이제 시각 효과 없음)
function BuildUI.setBuildMode(active: boolean)
	-- MainHUD 사이드바에서 시각 표시 담당
end

function BuildUI.destroy()
end

return BuildUI
