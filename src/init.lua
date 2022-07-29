local Packages = script.Parent

local Object = require(Packages.object)

--- @class Promise
--- @extends Object
--- An implementation of promise. This somewhat follows A+ spec, but
--- is not in any way an exact implementation.
local Promise = Object:Extend()

--- @prop Status !! { Resolved: any, Rejected: any, Running: any } | any
--- An enum representing promise status. When on an active promise,
--- this gets overwritten with the status of that promise.
Promise.Status = {
	Resolved = newproxy(),
	Rejected = newproxy(),
	Running = newproxy(),
}

--- @constructor
--- @param Callback !! (Resolve: (...any) -> (), Reject: (...any) -> ()) !! The function to run.
--- This will call the passed function in a coroutine. These are pretty standard promises.
--- If you are unfamiliar with promises, I suggest you read a more in depth guide. Some of my
--- favorite resources are:
--- - [Promises and Why You Should Use Them](https://devforum.roblox.com/t/promises-and-why-you-should-use-them/350825)
--- - [Using Promises](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises)
function Promise:Constructor(Callback: (Resolve: (...any) -> (), Reject: (...any) -> ()) -> ())
	--- @prop ResolveQueue !! { (...any) -> () }
	--- This a queue of functions to call when the promise is resolved.
	self._ResolveQueue = {}

	--- @prop RejectQueue !! { (...any) -> () }
	--- This a queue of functions to call when the promise is rejected.
	self._RejectQueue = {}

	self.Status = Promise.Status.Running

	local Resolve = function(...)
		self:_Resolve(...)
	end

	local Reject = function(...)
		self:_Reject(...)
	end

	--- @prop _Thread !! thread
	--- This is the coroutine that is running the callback.
	self._Thread = coroutine.create(function()
		xpcall(function()
			Callback(Resolve, Reject)
		end, function(...)
			Reject(...)
		end)
	end)

	task.spawn(self._Thread)
end

--- @method _Resolve
--- @param ... !! any !! 
--- This is the function that is called when the promise is resolved.
--- Do not call this directly.
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

--- @method _Reject
--- @param ... !! any !! 
--- This is the function that is called when the promise is rejected.
--- Do not call this directly.
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

--- @method Then
--- @param ResolveCallback !! (...any) -> (...any)? !! The function to call when the promise is resolved.
--- @param RejectCallback !! (...any) -> (...any)? !! The function to call when the promise is rejected.
--- @return Promise !! A new promise that is resolved or rejected based on the outcome of the original promise.
--- This function is the core of the promise model. When a promise is resolved or rejected,
--- these callbacks will be called. This function then returns a promise, which is resolved
--- with the value returned by the callback. Using this, you can chain promises together.
--- If you don't understand this, I once again suggest you read a more in depth guide.
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

--- @method Finally
--- @param Callback !! (...any) -> () !! The function to call when the promise is resolved or rejected.
--- @return Promise !! A new promise that is resolved or rejected based on the outcome of the original promise.
--- This function is a wrapper around `Promise:Then(Callback, Callback)`. It binds the resolve
--- and reject callbacks to the same function.
function Promise:Finally(Callback: (...any) -> (...any))
	return self:Then(function(...)
		return Callback(...)
	end, function(...)
		return Callback(...)
	end)
end

--- @method Catch
--- @param Callback !! (...any) -> () !! The function to call when the promise is rejected.
--- @return Promise !! A new promise that is resolved or rejected based on the outcome of the original promise.
--- This function is a wrapper around `Promise:Then(nil, Callback)`. It binds
--- only the reject callback.
function Promise:Catch(RejectCallback)
	return self:Then(nil, RejectCallback)
end

--- @method Wait
--- @return any !! The resolved value of the promise.
--- This function will wait until the promise is resolved. It will return the resolved value.
--- If the promise is rejected, it will throw an error.
--- 
--- **This function yields**
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

--- @static Resolve
--- @param ... !! any !! 
--- @return Promise !! A promise that is resolved with the given value.
--- This returns a promise that instantly resolves with the given value.
function Promise.Resolve(...)
	local Args = table.pack(...)
	return Promise:New(function(Resolve)
		Resolve(unpack(Args))
	end)
end

--- @static Reject
--- @param ... !! any !! 
--- @return Promise !! A promise that is rejected with the given value.
--- This returns a promise that instantly rejects with the given value.
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
