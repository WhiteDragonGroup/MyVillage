-- 관리자 패널. 서버가 비밀번호를 확인한 뒤 AdminOpen을 보내면 연다.
-- 개발용 도구라 이 패널만 한글로 표시한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminNames = require(Shared:WaitForChild("AdminNames"))
local Buildings = require(Shared:WaitForChild("Buildings"))
local Items = require(Shared:WaitForChild("Items"))
local Net = require(Shared:WaitForChild("Net"))
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local actionEvent = Net.event("AdminAction")

local PANEL_WIDTH = 600
local PANEL_HEIGHT = 640
local HEADER_HEIGHT = 52
local BUTTON_HEIGHT = 38
local TEXT_SIZE = 17
local RESET_CONFIRM_SECONDS = 3

local COLORS = {
	Backdrop = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(32, 36, 44),
	Header = Color3.fromRGB(22, 25, 31),
	Card = Color3.fromRGB(46, 51, 62),
	Title = Color3.fromRGB(255, 214, 102),
	Text = Color3.fromRGB(245, 245, 245),
	SubText = Color3.fromRGB(170, 176, 188),
	Primary = Color3.fromRGB(70, 150, 235),
	Item = Color3.fromRGB(72, 80, 96),
	Good = Color3.fromRGB(76, 175, 90),
	Danger = Color3.fromRGB(215, 70, 60),
	Input = Color3.fromRGB(250, 250, 250),
	InputText = Color3.fromRGB(30, 30, 30),
}

local AdminUi = {}

local gui, scroll
local order = 0

local function nextOrder(): number
	order += 1
	return order
end

local function send(action: string, arg1, arg2)
	actionEvent:FireServer(action, arg1, arg2)
end

local function formatNumber(value: number): string
	local text = tostring(math.abs(value))
	text = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	text = string.gsub(text, "^,", "")
	return text
end

local function button(parent: Instance, text: string, color: Color3, onClick: (TextButton) -> ()): TextButton
	local b = Ui.make("TextButton", {
		BackgroundColor3 = color,
		AutoButtonColor = true,
		FontFace = Ui.Font,
		Text = text,
		TextColor3 = COLORS.Text,
		TextSize = TEXT_SIZE,
		TextScaled = false,
		TextWrapped = true,
		LayoutOrder = nextOrder(),
		Parent = parent,
	}, { Ui.corner(8) })
	b.Activated:Connect(function()
		onClick(b)
	end)
	return b
end

-- 제목·설명과 버튼 격자가 들어간 카드. 반환: 버튼을 넣을 격자
local function section(title: string, description: string?, columns: number): Frame
	local card = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.Card,
		LayoutOrder = nextOrder(),
		Parent = scroll,
	}, {
		Ui.corner(10),
		Ui.make("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	Ui.label({
		Size = UDim2.new(1, 0, 0, 24),
		Text = title,
		TextColor3 = COLORS.Title,
		TextSize = 20,
		LayoutOrder = 1,
		Parent = card,
	})
	if description then
		Ui.label({
			Size = UDim2.new(1, 0, 0, 18),
			Text = description,
			TextColor3 = COLORS.SubText,
			TextSize = 14,
			LayoutOrder = 2,
			Parent = card,
		})
	end

	local gap = 8
	return Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = card,
	}, {
		Ui.make("UIGridLayout", {
			CellSize = UDim2.new(1 / columns, -gap * (columns - 1) / columns, 0, BUTTON_HEIGHT),
			CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function amountBox(parent: Instance, default: string): TextBox
	return Ui.make("TextBox", {
		BackgroundColor3 = COLORS.Input,
		FontFace = Ui.Font,
		Text = default,
		PlaceholderText = "수량 입력",
		TextColor3 = COLORS.InputText,
		TextSize = TEXT_SIZE,
		ClearTextOnFocus = false,
		LayoutOrder = nextOrder(),
		Parent = parent,
	}, { Ui.corner(8) })
end

local function readAmount(box: TextBox): number?
	local value = tonumber((string.gsub(box.Text, ",", "")))
	if value and value % 1 == 0 then
		return value
	end
	return nil
end

local function buildCoins()
	local grid = section("코인", "버튼을 누르면 바로 추가됩니다", 3)
	for _, amount in { 1000, 100000, 10000000 } do
		button(grid, "+" .. formatNumber(amount), COLORS.Good, function()
			send("Coins", amount)
		end)
	end
	local box = amountBox(grid, "5000")
	button(grid, "입력한 만큼 추가", COLORS.Primary, function()
		local amount = readAmount(box)
		if amount then
			send("Coins", amount)
		end
	end)
	button(grid, "코인 0으로", COLORS.Danger, function()
		send("Coins", -1e12)
	end)
end

local function buildResources()
	local grid = section("자원", "수량을 입력하고 자원을 누르면 그만큼 추가됩니다 (음수는 차감)", 4)
	local box = amountBox(grid, "100")

	local function withAmount(callback: (number) -> ())
		return function()
			local value = readAmount(box)
			if value then
				callback(value)
			end
		end
	end

	button(grid, "전체 추가", COLORS.Good, withAmount(function(value)
		send("Resource", "All", value)
	end))
	button(grid, "전체 비우기", COLORS.Danger, function()
		send("ClearResources")
	end)
	Ui.make("Frame", { BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = grid })

	for _, item in Items.List do
		button(grid, AdminNames.item(item.id), COLORS.Item, withAmount(function(value)
			send("Resource", item.id, value)
		end))
	end
end

local function buildBuildings()
	local grid = section("건물 지급", "누를 때마다 1개씩 보관함(인벤토리)에 들어갑니다", 3)
	local list = {}
	for _, def in Buildings.ById do
		if def.kind ~= "Landmark" then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		if a.kind ~= b.kind then
			return a.kind == "Home"
		end
		if a.unlock ~= b.unlock then
			return a.unlock < b.unlock
		end
		return a.id < b.id
	end)

	for _, def in list do
		button(grid, AdminNames.building(def.id), COLORS.Item, function()
			send("Building", def.id)
		end)
	end
end

local function buildClockTower()
	local grid = section("시계탑 레벨", "누른 레벨로 바로 바뀝니다", Buildings.MAX_LEVEL)
	for level = 1, Buildings.MAX_LEVEL do
		button(grid, level .. "레벨", COLORS.Primary, function()
			send("ClockTower", level)
		end)
	end
end

local function buildMisc()
	local grid = section("기타", nil, 3)
	button(grid, "일터 저장량 채우기", COLORS.Good, function()
		send("FillStorage")
	end)
	button(grid, "튜토리얼 건너뛰기", COLORS.Primary, function()
		send("SkipTutorial")
	end)

	local armedUntil = 0
	button(grid, "데이터 초기화", COLORS.Danger, function(b)
		if os.clock() < armedUntil then
			armedUntil = 0
			b.Text = "데이터 초기화"
			send("Reset")
			return
		end
		armedUntil = os.clock() + RESET_CONFIRM_SECONDS
		b.Text = "한 번 더 누르면 초기화"
		task.delay(RESET_CONFIRM_SECONDS, function()
			if os.clock() >= armedUntil then
				b.Text = "데이터 초기화"
			end
		end)
	end)
end

local function build()
	gui = Ui.make("ScreenGui", {
		Name = "AdminPanel",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- 뒤 화면을 어둡게 해서 패널을 읽기 쉽게 한다
	Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.Backdrop,
		BackgroundTransparency = 0.5,
		Parent = gui,
	})

	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.88, 0),
		BackgroundColor3 = COLORS.Panel,
		Active = true,
		Parent = gui,
	}, {
		Ui.corner(14),
		Ui.make("UISizeConstraint", { MaxSize = Vector2.new(PANEL_WIDTH, PANEL_HEIGHT) }),
		Ui.make("UIStroke", { Color = COLORS.Title, Thickness = 2 }),
	})

	local header = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = COLORS.Header,
		Parent = panel,
	}, { Ui.corner(14) })

	Ui.label({
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -80, 1, 0),
		Text = "관리자 패널",
		TextColor3 = COLORS.Title,
		TextSize = 24,
		Parent = header,
	})

	local close = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(64, 34),
		BackgroundColor3 = COLORS.Danger,
		FontFace = Ui.Font,
		Text = "닫기",
		TextColor3 = COLORS.Text,
		TextSize = TEXT_SIZE,
		Parent = header,
	}, { Ui.corner(8) })
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	scroll = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, HEADER_HEIGHT + 8),
		Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + 16)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = COLORS.SubText,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, {
		Ui.make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Ui.make("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 8),
		}),
	})

	buildCoins()
	buildResources()
	buildBuildings()
	buildClockTower()
	buildMisc()
end

-- 테스트용 임시 버튼. Studio에서만 보인다.
local function buildStudioButton()
	local host = Ui.make("ScreenGui", {
		Name = "AdminStudioButton",
		ResetOnSpawn = false,
		DisplayOrder = 19,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local b = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -110),
		Size = UDim2.fromOffset(80, 32),
		BackgroundColor3 = COLORS.Danger,
		FontFace = Ui.Font,
		Text = "관리자",
		TextColor3 = COLORS.Text,
		TextSize = 16,
		Parent = host,
	}, { Ui.corner(8) })
	b.Activated:Connect(function()
		if gui and gui.Enabled then
			gui.Enabled = false
		else
			Net.event("AdminStudioOpen"):FireServer()
		end
	end)
end

function AdminUi.start()
	if RunService:IsStudio() then
		buildStudioButton()
	end

	Net.event("AdminOpen").OnClientEvent:Connect(function()
		if not gui then
			build()
		end
		gui.Enabled = true
	end)
end

return AdminUi
