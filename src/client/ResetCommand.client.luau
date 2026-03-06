-- ResetCommand.client.luau
-- TextChatService /reset 명령어 등록

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local resetDataEvent = remotes:WaitForChild("ResetData")

local resetCommand = Instance.new("TextChatCommand")
resetCommand.PrimaryAlias = "/reset"
resetCommand.Parent = TextChatService

resetCommand.Triggered:Connect(function(_originTextSource, _unfilteredText)
	resetDataEvent:FireServer()
end)
