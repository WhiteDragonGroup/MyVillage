-- 서버 스냅샷을 보관하고 변경을 알린다

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local changed = Instance.new("BindableEvent")

local State = {
	data = { coins = 0, resources = {}, stored = {}, clockTower = 1, shop = nil },
	Changed = changed.Event,
}

Net.event("Snapshot").OnClientEvent:Connect(function(snapshot)
	State.data = snapshot
	changed:Fire()
end)

return State
