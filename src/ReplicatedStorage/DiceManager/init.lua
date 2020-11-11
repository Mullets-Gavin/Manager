--[[
	@Author: Gavin "Mullets" Rosenthal
	@Desc: a task manager with scheduling & coroutines
--]]

--[[
[DOCUMENTATION]:
	https://github.com/Mullets-Gavin/Manager
	Listed below is a quick glance on the API, visit the link above for proper documentation.
	
	... = parameters
	
	Manager.wait(time)
	Manager.set(dictionary)
	Manager.wrap(function,...)
	Manager.spawn(function,...)
	Manager.garbage(time,instance)
	Manager.delay(time,function,...)
	Manager.retry(time,function,...)
	
	event = Manager:Connect(function)
	event:Disconnect()
	event:Fire(...)
	
	event = Manager:ConnectKey(key,function)
	event:Disconnect()
	event:Fire(...)
	
	Manager:FireKey(key,...)
	Manager:DisconnectKey(key)
	
	event = Manager:Task([fps])
	event:Queue(function)
	event:Pause()
	event:Resume()
	event:Wait()
	event:Enabled()
	event:Disconnect()
	
[LICENSE]:
	MIT License

	Copyright (c) 2020 Mullet Mafia Dev

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
--]]

--// logic
local Manager = {}
Manager.Connections = {}
Manager.LastIteration = nil
Manager.Name = 'Manager'

local Settings = {}
Settings.Debug = false
Settings.RunService = 'Stepped'

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
		['RunService'] = 'Stepped' or 'Heartbeat'
	}
--]]
function Manager.set(properties)
	assert(typeof(properties) == 'table',"[MANAGER]: 'set' expected dictionary, got '".. typeof(properties) .."'")
	
	Settings.Debug = properties['Debug'] or false
	Settings.RunService = properties['RunService'] or 'Stepped'
end

--[[
	Variations of call:
	
	.wait(time)
--]]
function Manager.wait(clock)
	if clock then
		local current = os.clock()
		
		while clock > os.clock() - current do
			Services['RunService'][Settings.RunService]:Wait()
		end
	end
	
	return Services['RunService'][Settings.RunService]:Wait()
end

--[[
	Variations of call:
	
	.wrap(function)
]]--
function Manager.wrap(code,...)
	assert(typeof(code) == 'function',"[MANAGER]: 'wrap' only accepts functions, got '".. typeof(code) .."'")
	
	local thread = coroutine.create(code)
    local ran,response = coroutine.resume(thread, ...)
   
   if not ran then
        local trace = debug.traceback(thread)
        error(response .. "\n" .. trace)
    end
end

--[[
	Variations of call:
	
	.spawn(function)
]]--
function Manager.spawn(code,...)
	assert(typeof(code) == 'function',"[MANAGER]: 'spawn' only accepts functions, got '".. typeof(code) .."'")
	
	local data = {...}
	local event; event = Services['RunService'][Settings.RunService]:Connect(function()
		event:Disconnect()
		
		local success,err = pcall(function()
			return code(table.unpack(data))
		end)
		
		if not success and Settings.Debug then
			warn(err)
		end
		
		return
	end)
end

--[[
	Variations of call:
	
	.loop(fps,code)
	.loop(code)
	
	Returns:
	
	RBXScriptSignal
--]]
function Manager.loop(...)
	local data = {...}
	local fps,code; do
		if typeof(data[1]) == 'number' then
			fps = data[1]
			code = data[2]
		else
			fps = 60
			code = data[1]
		end
	end
	
	local rate = 1/60
	local logged = 0
	local event; event = Services['RunService'][Settings.RunService]:Connect(function(delta)
		logged = logged + delta
		
		while logged >= rate do
			logged = logged - rate
			code()
		end
	end)
	
	return event
end

--[[
	Variations of call:
	
	.delay(time,function)
]]--
function Manager.delay(clock,code,...)
	assert(typeof(clock) == 'number' and typeof(code) == 'function',"[MANAGER]: 'delay' missing parameters, got '".. typeof(clock) .."' and '".. typeof(code) .."'")
	
	local data = {...}
	Manager.wrap(function()
		local current = os.clock()
		
		while clock > os.clock() - current do
			Manager.wait()
		end
		
		return Manager.wrap(code,table.unpack(data))
	end)
end

--[[
	Variations of call:
	
	.garbage(time,function)
]]--
function Manager.garbage(clock,obj)
	assert(typeof(clock) == 'number' and typeof(obj) == 'Instance',"[MANAGER]: 'garbage' missing parameters, got '".. typeof(clock) .."' and '".. typeof(Instance) .."'")
	
	Manager.wrap(function()
		local current = os.clock()
		
		while clock > os.clock() - current do
			Manager.wait()
		end
		
		obj:Destroy()
	end)
end

--[[
	Variations of call:
	
	.retry(timeout,function)
--]]
function Manager.retry(clock,code,...)
	assert(typeof(clock) == 'number' and typeof(code) == 'function',"[MANAGER]: 'retry' missing parameters, got '".. typeof(clock) .."' and '".. typeof(code) .."'")
	
	local current = os.clock()
	local success,response
	
	while not success and clock > os.clock() - current do
		success,response = pcall(code,...)
		Manager.wait()
	end
	
	if not success and Settings.Debug then
		warn(response,debug.traceback())
	end
	
	return success,response
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
	assert(code ~= nil,"[MANAGER]: 'Connect' missing parameters, got function '".. typeof(code) .."'")
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
				warn('[MANAGER]:',err)
			end
		end
		
		code = nil
		setmetatable(control, {
			__index = function()
				error('[MANAGER]: Attempt to use destroyed connection')
			end;
			__newindex = function()
				error('[MANAGER]: Attempt to use destroyed connection')
			end;
		})
	end
	
	function control:Fire(...)
		if typeof(code) == 'function' then
			return Manager.wrap(code,...)
		else
			warn("[MANAGER]: Attempted to call :Fire on '".. typeof(code) .."'")
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
	assert(key ~= nil and code ~= nil,"[ MANAGER]: 'ConnectKey' missing parameters, got key '".. typeof(key) .."' and got function '".. typeof(code) .."'")
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
				warn('[MANAGER]:',err)
			end
		end
		
		code = nil
		setmetatable(control, {
			__index = function()
				error('[MANAGER]: Attempt to use destroyed connection')
			end;
			__newindex = function()
				error('[MANAGER]: Attempt to use destroyed connection')
			end;
		})
	end
	
	function control:Fire(...)
		if typeof(code) == 'function' then
			return Manager.wrap(code,...)
		else
			warn("[MANAGER]: Attempted to call :Fire on '".. typeof(code) .."'")
		end
	end
	
	Manager.Connections[key][code] = control
	return control
end

--[[
	Variations of call:
	
	:FireKey(key)
	:FireKey(key,parameters)
--]]
function Manager:FireKey(key,...)
	assert(key ~= nil,"[MANAGER]: 'FireKey' missing parameters, got key '".. typeof(key) .."'")
	
	if Manager.Connections[key] then
		for code,control in pairs(Manager.Connections[key]) do
			control:Fire(...)
		end
	end
end

--[[
	Variations of call:
	
	:DisconnectKey(key)
--]]
function Manager:DisconnectKey(key)
	assert(key ~= nil,"[MANAGER]: 'DisconnectKey' missing parameters, got key '".. typeof(key) .."'")
	
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
	assert(typeof(targetFPS) == 'number',"[MANAGER]: Task scheduler only accepts numbers for frames per second, got '".. typeof(targetFPS) .."'")
	
	local control = {}
	control.CodeQueue = {}
	control.UpdateTable = {}
	control.Enable = true
	control.Sleeping = true
	control.Paused = false
	control.UpdateTableEvent = nil
	
	local start = os.clock()
	Manager.wait()
	
	local function Update()
		Manager.LastIteration = os.clock()
		for index = #control.UpdateTable,1,-1 do
			control.UpdateTable[index + 1] = ((control.UpdateTable[index] >= (Manager.LastIteration - 1)) and control.UpdateTable[index] or nil)
		end
		control.UpdateTable[1] = Manager.LastIteration
	end
	
	local function Loop()
		control.UpdateTableEvent = Services['RunService'][Settings.RunService]:Connect(Update)
		
		while (true) do
			if control.Sleeping then break end
			if not control:Enabled() then break end
			
			if targetFPS < 0 then
				if (#control.CodeQueue > 0) then
					control.CodeQueue[1]()
					table.remove(control.CodeQueue, 1)
					if not control:Enabled() then
						break
					end
				else
					control.Sleeping = true
					break
				end
			else
				local fps = (((os.clock() - start) >= 1 and #control.UpdateTable) or (#control.UpdateTable / (os.clock() - start)))
				if (fps >= targetFPS and (os.clock() - control.UpdateTable[1]) < (1 / targetFPS)) then
					if (#control.CodeQueue > 0) then
						control.CodeQueue[1]()
						table.remove(control.CodeQueue, 1)
						if not control:Enabled() then
							break
						end
					else
						control.Sleeping = true
						break
					end
				elseif control:Enabled() then
					Manager.wait()
				end
			end
		end
		
		control.UpdateTableEvent:Disconnect()
		control.UpdateTableEvent = nil
	end
	
	function control:Enabled()
		return control.Enable
	end
	
	function control:Pause()
		control.Paused = true
		control.Sleeping = true
		
		local fps = (((os.clock() - start) >= 1 and #control.UpdateTable) or (#control.UpdateTable / (os.clock() - start)))
		return fps
	end
	
	function control:Resume()
		if control.Paused then
			control.Paused = false
			control.Sleeping = false
			Loop()
		end
		
		local fps = (((os.clock() - start) >= 1 and #control.UpdateTable) or (#control.UpdateTable / (os.clock() - start)))
		return fps
	end
	
	function control:Wait()
		while not control.Sleeping do
			Manager.wait()
		end
		
		local fps = (((os.clock() - start) >= 1 and #control.UpdateTable) or (#control.UpdateTable / (os.clock() - start)))
		return fps
	end
	
	function control:Disconnect()
		control.Enable = false
		control:Pause()
		control.CodeQueue = nil
		control.UpdateTable = nil
		control.UpdateTableEvent:Disconnect()
		control:Wait()
		
		for index in pairs(control) do
			control[index] = nil
		end
		
		setmetatable(control, {
			__index = function()
				error('[MANAGER]: Attempt to use destroyed task scheduler')
			end;
			__newindex = function()
				error('[MANAGER]: Attempt to use destroyed task scheduler')
			end;
		})
	end
	
	function control:Queue(code)
		if not control.CodeQueue then return end
		control.CodeQueue[#control.CodeQueue + 1] = code
		
		if (control.Sleeping and not control.Paused) then
			control.Sleeping = false
			Loop()
		end
	end
	
	return control
end

return Manager