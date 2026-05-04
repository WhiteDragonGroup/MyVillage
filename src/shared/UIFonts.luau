-- UIFonts.luau
-- 게임 공통 폰트 헬퍼

local UIFonts = {}

local FONT_ASSET = "rbxassetid://12187364648"

function UIFonts.regular(): Font
	return Font.new(FONT_ASSET, Enum.FontWeight.Regular)
end

function UIFonts.medium(): Font
	return Font.new(FONT_ASSET, Enum.FontWeight.Medium)
end

function UIFonts.bold(): Font
	return Font.new(FONT_ASSET, Enum.FontWeight.Bold)
end

function UIFonts.heavy(): Font
	return Font.new(FONT_ASSET, Enum.FontWeight.Heavy)
end

-- 기존 Enum.Font를 공통 폰트로 매핑 (대응 가중치)
function UIFonts.fromEnum(enumFont: Enum.Font): Font
	if enumFont == Enum.Font.GothamBlack or enumFont == Enum.Font.GothamBold then
		return UIFonts.bold()
	end
	if enumFont == Enum.Font.GothamMedium or enumFont == Enum.Font.SourceSansSemibold then
		return UIFonts.medium()
	end
	return UIFonts.regular()
end

-- 모든 텍스트 자식들에 공통 폰트 일괄 적용
function UIFonts.applyToDescendants(root: Instance, weight: string?)
	weight = weight or "regular"
	local font
	if weight == "bold" then font = UIFonts.bold()
	elseif weight == "medium" then font = UIFonts.medium()
	elseif weight == "heavy" then font = UIFonts.heavy()
	else font = UIFonts.regular() end

	for _, desc in root:GetDescendants() do
		if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
			desc.FontFace = font
		end
	end
end

return UIFonts
