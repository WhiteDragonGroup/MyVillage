-- UI 생성 도우미와 공용 색상

local Ui = {}

-- 팀 UI와 같은 글꼴
Ui.Font = Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold)

Ui.Colors = {
	Panel = Color3.fromRGB(255, 248, 232),
	PanelDark = Color3.fromRGB(235, 222, 196),
	Text = Color3.fromRGB(70, 52, 38),
	Accent = Color3.fromRGB(96, 170, 84),
	Warning = Color3.fromRGB(214, 92, 76),
	Muted = Color3.fromRGB(170, 160, 145),
	White = Color3.fromRGB(255, 255, 255),
}

function Ui.make(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props or {} do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: number)
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Ui.label(props)
	local merged = {
		BackgroundTransparency = 1,
		FontFace = Ui.Font,
		TextColor3 = Ui.Colors.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		merged[key] = value
	end
	return Ui.make("TextLabel", merged)
end

return Ui
