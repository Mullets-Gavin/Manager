--[[
	@Author: Gavin "Mullets" Rosenthal
	@Desc: a task manager with scheduling & coroutines
--]]

--[[
[DOCUMENTATION]:
	https://github.com/Mullets-Gavin/DiceManager
	Listed below is a quick glance on the API, visit the link above for proper documentation.
	
	Manager.set(dictionary)
	
	Manager.wrap(function)
	Manager.spawn(function)
	Manager.delay(time,function)
	
	event = Manager:Connect(function)
	event:Disconnect()
	event:Fire()
	
	event = Manager:ConnectKey(key,function)
	event:Disconnect()
	event:Fire()
	
	Manager:DisconnectKey(key)
	
	event = Manager:Task([fps])
	event:Queue(function)
	event:Pause()
	event:Resume()
	event:Disconnect()
--]]

--// logic
local Manager = {}
Manager.Connections = {}
Manager.LastIteration = nil

local Settings = {}
Settings.Debug = false

--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
	cache[serviceName] = game:GetService(serviceName)
	return cache[serviceName]
end})

--// functions
--[[
	Variations of call:
	
	.set(properties)
	
	properties = {
		['Debug'] = bool
	}
--]]
function Manager.set(properties)
	Settings.Debug = properties['Debug'] or false
end

--[[
	Variations of call:
	
	.wrap(function)
]]--
function Manager.wrap(code,...)
	assert(typeof(code) == 'function',"[DICE MANAGER]: 'wrap' only accepts functions, got '".. typeof(code) .."'")
	local contents = table.unpack({...})
	local event
	event = Services['RunService'].Heartbeat:Connect(function()
		event:Disconnect()
		code(contents)
	end)
end

--[[
	Variations of call:
	
	.spawn(function)
]]--
function Manager.spawn(code)
	assert(typeof(code) == 'function',"[DICE MANAGER]: 'spawn' only accepts functions, got '".. typeof(code) .."'")
	local event
	event = Services['RunService'].Heartbeat:Connect(function()
		event:Disconnect()
		local success,err = pcall(function()
			code()
		end)
		if not success and Settings.Debug then
			warn(err)
		end
	end)
end

--[[
	Variations of call:
	
	.delay(time,function)
]]--
function Manager.delay(clock,code)
	assert(typeof(clock) == 'number' and typeof(code) == 'function',"[DICE MANAGER]: 'delay' missing parameters, got '".. typeof(clock) .."' and '".. typeof(code) .."'")
	local current = tick()
	while clock < tick() - current do
		Services['RunService'].Heartbeat:Wait()
	end
	Manager.wrap(code)
end

--[[
	Variations of call:
	
	:Connect(function)
	:Connect(RBXScriptConnection)
	
	Returns:
	
	control = dictionary
	control:Fire(...)
	control:Disconnect()
]]--
function Manager:Connect(code)
	assert(code ~= nil,"[DICE MANAGER]: 'Connect' missing parameters, got function '".. typeof(code) .."'")
	local control = {}
	
	function control:Disconnect()
		control = nil
		if typeof(code) == 'RBXScriptConnection' then
			code:Disconnect()
		elseif typeof(code) == 'table' then
			local success,err = pcall(function()
				code:Disconnect()
			end)
			if not success and Settings.Debug then
				warn('[DICE MANAGER]:',err)
			end
		end
		code = nil
	end
	
	function control:Fire(...)
		if typeof(code) == 'function' then
			Manager.wrap(code,...)
		else
			warn("[DICE MANAGER]: Attempted to call :Fire on '".. typeof(code) .."'")
		end
	end
	
	return control
end

--[[
	Variations of call:
	
	:Connect(key,function)
	:Connect(key,RBXScriptConnection)
	:Connect(key,table)
	
	Returns:
	
	control = dictionary
	control:Fire(...)
	control:Disconnect()
]]--
function Manager:ConnectKey(key,code)
	assert(key ~= nil and code ~= nil,"[DICE MANAGER]: 'ConnectKey' missing parameters, got key '".. typeof(key) .."' and got function '".. typeof(code) .."'")
	if not Manager.Connections[key] then
		Manager.Connections[key] = {}
	end
	local control = {}
	
	function control:Disconnect()
		if not Manager.Connections[key] then return end
		Manager.Connections[key][code] = nil
		if typeof(code) == 'RBXScriptConnection' then
			code:Disconnect()
		elseif typeof(code) == 'table' then
			local success,err = pcall(function()
				code:Disconnect()
			end)
			if not success and Settings.Debug then
				warn('[DICE MANAGER]:',err)
			end
		end
		code = nil
	end
	
	function control:Fire(...)
		if typeof(code) == 'function' then
			Manager.wrap(code,...)
		else
			warn("[DICE MANAGER]: Attempted to call :Fire on '".. typeof(code) .."'")
		end
	end
	
	Manager.Connections[key][code] = control
	return control
end

--[[
	Variations of call:
	
	:DisconnectKey(key)
--]]
function Manager:DisconnectKey(key)
	assert(key ~= nil,"[DICE MANAGER]: 'DisconnectKey' missing parameters, got key '".. typeof(key) .."'")
	if Manager.Connections[key] then
		for code,control in pairs(Manager.Connections[key]) do
			control:Disconnect()
			Manager.Connections[key][code] = nil
		end
		Manager.Connections[key] = nil
	end
end

--[[
	Variations of call:
	
	:Task([fps])
	
	Returns:
	
	control = dictionary
	control:Queue(function)
	control:Pause()
	control:Resume()
	control:Disconnect()
--]]
function Manager:Task(targetFPS)
	targetFPS = targetFPS or 60
	assert(typeof(targetFPS) == 'number',"[DICE MANAGER]: Task scheduler only accepts numbers for frames per second, got '".. typeof(targetFPS) .."'")
	
	local control = {}
	control.CodeQueue = {}
	control.UpdateTable = {}
	control.Sleeping = true
	control.Paused = false
	control.UpdateTableEvent = nil
	
	local start = tick()
	Services['RunService'].Heartbeat:Wait()
	
	local function Update()
		Manager.LastIteration = tick()
		for index = #control.UpdateTable,1,-1 do
			control.UpdateTable[index + 1] = ((control.UpdateTable[index] >= (Manager.LastIteration - 1)) and control.UpdateTable[index] or nil)
		end
		control.UpdateTable[1] = Manager.LastIteration
	end
	
	local function Loop()
		control.UpdateTableEvent = Services['RunService'].Heartbeat:Connect(Update)
		while (true) do
			if control.Sleeping then break end
			local fps = (((tick() - start) >= 1 and #control.UpdateTable) or (#control.UpdateTable / (tick() - start)))
			if (fps >= targetFPS and (tick() - control.UpdateTable[1]) < (1 / targetFPS)) then
				if (#control.CodeQueue > 0) then
					control.CodeQueue[1]()
					table.remove(control.CodeQueue, 1)
				else
					control.Sleeping = true
					break
				end
			else
				Services['RunService'].Heartbeat:Wait()
			end
		end
		control.UpdateTableEvent:Disconnect()
		control.UpdateTableEvent = nil
	end
	
	function control:Pause()
		control.Paused = true
		control.Sleeping = true
	end
	
	function control:Resume()
		if control.Paused then
			control.Paused = false
			control.Sleeping = false
			Loop()
		end
	end
	
	function control:Disconnect()
		control:Pause()
		for index in pairs(control) do
			control[index] = nil
		end
		setmetatable(control, {
			__index = function()
				error('[DICE MANAGER]: Attempt to use destroyed task scheduler')
			end;
			__newindex = function()
				error('[DICE MANAGER]: Attempt to use destroyed task scheduler')
			end;
		})
	end
	
	function control:Queue(code)
		control.CodeQueue[#control.CodeQueue + 1] = code
		if (control.Sleeping and not control.Paused) then
			control.Sleeping = false
			Loop()
		end
	end
	
	return control
end

return Manager