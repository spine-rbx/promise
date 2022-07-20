local Packages = script.Parent

local Object = require(Packages.object)

local Promise = Object:Extend()

Promise.Status = {
	Resolved = newproxy(),
	Rejected = newproxy(),
	Running = newproxy(),
}

function Promise:Constructor(Callback: (Reject: (...any) -> (), Resolve: (...any) -> ()) -> ())
	self._ResolveQueue = {}
	self._RejectQueue = {}

	self.Status = Promise.Status.Running

	local Resolve = function(...)
		self:_Resolve(...)
	end

	local Reject = function(...)
		self:_Reject(...)
	end

	self._Thread = coroutine.create(function()
		xpcall(function()
			Callback(Resolve, Reject)
		end, function(...)
			Reject(...)
		end)
	end)

	task.spawn(self._Thread)
end

function Promise:_Resolve(...)
	if self.Status ~= Promise.Status.Running then
		error("Cannot resolve promise that isn't running.")
	end

	self.Status = Promise.Status.Resolved
	self._Value = table.pack(...)

	for _, Callback in ipairs(self._ResolveQueue) do
		task.spawn(Callback, ...)
	end

	self._ResolveQueue = nil
	self._RejectQueue = nil
end

function Promise:_Reject(...)
	if self.Status ~= Promise.Status.Running then
		error("Cannot reject promise that isn't running.")
	end

	self.Status = Promise.Status.Rejected
	self._Value = table.pack(...)

	for _, Callback in ipairs(self._RejectQueue) do
		task.spawn(Callback, ...)
	end

	self._RejectQueue = nil
	self._ResolveQueue = nil
end

function Promise:Then(ResolveCallback: (...any) -> (...any), RejectCallback: (...any) -> (...any))
	return Promise:New(function(Resolve, Reject)
		ResolveCallback = ResolveCallback or function() end
		RejectCallback = RejectCallback or function() end

		if self.Status == Promise.Status.Resolved then
			Resolve(ResolveCallback(unpack(self._Value)))
		elseif self.Status == Promise.Status.Rejected then
			Reject(RejectCallback(unpack(self._Value)))
		elseif self.Status == Promise.Status.Running then
			self._ResolveQueue[#self._ResolveQueue + 1] = function(...)
				Resolve(ResolveCallback(...))
			end

			self._RejectQueue[#self._RejectQueue + 1] = function(...)
				Reject(RejectCallback(...))
			end
		end
	end)
end

function Promise:Finally(Callback: (...any) -> (...any))
	return self:Then(function(...)
		return Callback(...)
	end, function(...)
		return Callback(...)
	end)
end

function Promise:Catch(RejectCallback)
	return self:Then(nil, RejectCallback)
end

function Promise:Wait()
	if self.Status == Promise.Status.Resolved then
		return unpack(self._Value)
	elseif self.Status == Promise.Status.Rejected then
		return error(unpack(self._Value))
	end

	local Running = coroutine.running()

	self._ResolveQueue[#self._ResolveQueue + 1] = function(...)
		coroutine.resume(Running)
	end

	self._RejectQueue[#self._RejectQueue + 1] = function(...)
		coroutine.resume(Running)
	end

	coroutine.yield()

	if self.Status == Promise.Status.Resolved then
		return unpack(self._Value)
	elseif self.Status == Promise.Status.Rejected then
		return error(unpack(self._Value))
	end

	return
end

function Promise.Resolve(...)
	local Args = table.pack(...)
	return Promise:New(function(Resolve)
		Resolve(unpack(Args))
	end)
end

function Promise.Reject(...)
	local Args = table.pack(...)
	return Promise:New(function(_, Reject)
		Reject(unpack(Args))
	end)
end

export type Promise = Object.Object<{
	Status: any,
	_Value: { any },
	_ResolveQueue: { (...any) -> () },
	_RejectQueue: { (...any) -> () },
	_Thread: thread,

	Then: (self: Promise, ResolveCallback: (...any) -> (...any), RejectCallback: (...any) -> (...any)) -> (Promise),
	Finally: (self: Promise, Callback: (...any) -> (...any)) -> (Promise),
	Catch: (self: Promise, RejectCallback: (...any) -> (...any)) -> (Promise),
	Wait: (self: Promise) -> (...any),

	Resolve: (...any) -> (Promise),
	Reject: (...any) -> (Promise),
}, ((Resolve: (...any) -> (), Reject: (...any) -> ()) -> ())>

return Promise :: Promise
