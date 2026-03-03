-- HighlightSystem.luau
-- Roblox Highlight 인스턴스로 호버/선택/충돌 하이라이트

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local HighlightSystem = {}

local _currentHighlight = nil  -- 현재 활성 Highlight 인스턴스
local _currentTarget = nil      -- 현재 하이라이트 대상

-- BasePart의 부모 Model 찾기 (Highlight용)
local function getHighlightTarget(part: BasePart): Instance
	local parent = part.Parent
	if parent and parent:IsA("Model") then
		return parent
	end
	return part
end

-- Highlight 인스턴스 생성/업데이트
local function ensureHighlight(target: BasePart, color: Color3, fillTransparency: number?)
	if _currentTarget == target and _currentHighlight then
		-- 색상만 변경
		_currentHighlight.FillColor = color
		_currentHighlight.OutlineColor = color
		_currentHighlight.FillTransparency = fillTransparency or 0.7
		return
	end

	-- 기존 제거
	HighlightSystem.clear()

	-- Model이면 Model 전체 하이라이트
	local adornee = getHighlightTarget(target)

	-- 새 Highlight 생성
	local highlight = Instance.new("Highlight")
	highlight.Name = "BuildHighlight"
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = fillTransparency or 0.7
	highlight.OutlineTransparency = 0.3
	highlight.Adornee = adornee
	highlight.Parent = adornee

	_currentHighlight = highlight
	_currentTarget = target
end

-- 호버 하이라이트 (흰색)
function HighlightSystem.setHover(target: BasePart)
	ensureHighlight(target, Constants.HIGHLIGHT_COLORS.Hover, 0.8)
end

-- 선택 하이라이트 (초록)
function HighlightSystem.setSelected(target: BasePart)
	ensureHighlight(target, Constants.HIGHLIGHT_COLORS.Selected, 0.6)
end

-- 충돌 하이라이트 (빨강)
function HighlightSystem.setCollision(target: BasePart)
	ensureHighlight(target, Constants.HIGHLIGHT_COLORS.Collision, 0.5)
end

-- 하이라이트 제거
function HighlightSystem.clear()
	if _currentHighlight then
		_currentHighlight:Destroy()
		_currentHighlight = nil
	end
	_currentTarget = nil
end

-- 현재 하이라이트 대상 반환
function HighlightSystem.getCurrentTarget(): BasePart?
	return _currentTarget
end

-- 특정 대상에 직접 Highlight 적용 (별도 인스턴스, 이동 중 프리뷰 등)
function HighlightSystem.applyTo(target: BasePart, color: Color3, fillTransparency: number?): Highlight
	local adornee = getHighlightTarget(target)
	local existing = adornee:FindFirstChild("BuildHighlight")
	if existing then
		existing.FillColor = color
		existing.OutlineColor = color
		existing.FillTransparency = fillTransparency or 0.7
		return existing
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "BuildHighlight"
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = fillTransparency or 0.7
	highlight.OutlineTransparency = 0.3
	highlight.Adornee = adornee
	highlight.Parent = adornee

	return highlight
end

-- 특정 대상의 하이라이트 제거
function HighlightSystem.removeFrom(target: BasePart)
	local adornee = getHighlightTarget(target)
	local existing = adornee:FindFirstChild("BuildHighlight")
	if existing then
		existing:Destroy()
	end
end

return HighlightSystem
