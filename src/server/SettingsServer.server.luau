-- SettingsServer.server.luau
-- 클라이언트 설정 Remote 핸들러

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverScript = script.Parent
local SettingsManager = require(serverScript:WaitForChild("SettingsManager"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getSettingsFunc = remotes:WaitForChild("GetSettings")
local saveSettingEvent = remotes:WaitForChild("SaveSetting")

getSettingsFunc.OnServerInvoke = function(player)
	return SettingsManager.getSettings(player)
end

saveSettingEvent.OnServerEvent:Connect(function(player, key, value)
	if typeof(key) ~= "string" then return end
	SettingsManager.setSetting(player, key, value)
end)

print("SettingsServer 로드됨")
