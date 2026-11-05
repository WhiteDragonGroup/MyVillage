-- 관리자 패널. 채팅에 "/admin <비밀번호>"를 입력하면 이번 접속 동안 권한을 얻는다.
-- 비밀번호는 저장소에 올리지 않도록 플레이스의 ServerStorage 속성 AdminPassword에 둔다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Village = require(script.Parent.Village)

local PASSWORD_ATTRIBUTE = "AdminPassword"
local COMMAND = "/admin"

local openEvent = Net.event("AdminOpen")
local actionEvent = Net.event("AdminAction")
local studioOpenEvent = Net.event("AdminStudioOpen") -- 테스트용 임시 버튼

local authorized = {} -- [Player] = true

local Admin = {}

local function grant(player: Player)
	authorized[player] = true
	openEvent:FireClient(player)
end

local function onCommand(player: Player, text: string)
	local command, password = string.match(text, "^%s*(%S+)%s*(%S*)")
	if not command or string.lower(command) ~= COMMAND then
		return
	end

	local expected = ServerStorage:GetAttribute(PASSWORD_ATTRIBUTE)
	if typeof(expected) ~= "string" or expected == "" then
		warn("ServerStorage." .. PASSWORD_ATTRIBUTE .. " 속성이 없어 /admin 명령을 쓸 수 없음")
		return
	end

	if password == expected then
		grant(player)
	end
end

local function setupChatCommand()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local commands = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
		local chatCommand = Instance.new("TextChatCommand")
		chatCommand.Name = "AdminCommand"
		chatCommand.PrimaryAlias = COMMAND
		chatCommand.Parent = commands

		chatCommand.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				onCommand(player, text)
			end
		end)
	else
		local function watch(player: Player)
			player.Chatted:Connect(function(text)
				onCommand(player, text)
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, player in Players:GetPlayers() do
			watch(player)
		end
	end
end

function Admin.start()
	setupChatCommand()

	actionEvent.OnServerEvent:Connect(function(player, action, arg1, arg2)
		if authorized[player] then
			Village.admin(player, action, arg1, arg2)
		end
	end)

	-- 임시 버튼은 Studio 플레이 테스트에서만 받아 준다
	studioOpenEvent.OnServerEvent:Connect(function(player)
		if RunService:IsStudio() then
			grant(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		authorized[player] = nil
	end)
end

return Admin
