-- Signal.luau
-- 경량 시그널 유틸리티 (Roblox BindableEvent 기반)

local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)
	self._connections = {}
	return self
end

function Signal:Connect(fn)
	local connection = {
		_fn = fn,
		_connected = true,
	}

	function connection:Disconnect()
		self._connected = false
	end

	table.insert(self._connections, connection)
	return connection
end

function Signal:Fire(...)
	for i = #self._connections, 1, -1 do
		local conn = self._connections[i]
		if conn._connected then
			task.spawn(conn._fn, ...)
		else
			table.remove(self._connections, i)
		end
	end
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Destroy()
	self._connections = {}
end

return Signal
