return function()
	local Promise = require(script.Parent)

	describe("Promise:New", function()
		it("should call the given function with resolve and reject", function()
			local Resolve, Reject

			local p = Promise:New(function(a, b)
				Resolve = a
				Reject = b
			end)

			expect(Resolve).to.be.a("function")
			expect(Reject).to.be.a("function")
			expect(p.Status).to.equal(Promise.Status.Running)
		end)

		it("should resolve promises", function()
			local p = Promise:New(function(resolve)
				resolve(1)
			end)

			expect(p.Status).to.equal(Promise.Status.Resolved)
			expect(p._Value[1]).to.equal(1)
		end)

		it("should reject promises", function()
			local p = Promise:New(function(resolve, reject)
				reject(1)
			end)

			expect(p.Status).to.equal(Promise.Status.Rejected)
			expect(p._Value[1]).to.equal(1)
		end)

		it("should reject promises on error", function()
			local p = Promise:New(function()
				error("this will error")
			end)

			expect(p.Status).to.equal(Promise.Status.Rejected)
			expect(p._Value[1]:find("this will error")).to.be.ok()
		end)

		it("should allow yielding", function()
			local cr
			
			local p = Promise:New(function(resolve)
				cr = coroutine.running()
				coroutine.yield()
				resolve(1)
			end)

			expect(p.Status).to.equal(Promise.Status.Running)
			coroutine.resume(cr)
			expect(p.Status).to.equal(Promise.Status.Resolved)
			expect(p._Value[1]).to.equal(1)
		end)

		it("should allow chaining", function()
			local p = Promise:New(function(resolve)
				resolve(1)
			end)

			local p2 = p:Then(function(a)
				return a + 1
			end)

			expect(p2.Status).to.equal(Promise.Status.Resolved)
			expect(p2._Value[1]).to.equal(2)
		end)
	end)

	describe("Promise.Resolve", function()
		it("should instantly resolve", function()
			local p = Promise.Resolve(1)

			expect(p.Status).to.equal(Promise.Status.Resolved)
			expect(p._Value[1]).to.equal(1)
		end)

		it("should allow chaining", function()
			local p = Promise.Resolve(1)

			local p2 = p:Then(function(a)
				return a + 1
			end)

			expect(p2.Status).to.equal(Promise.Status.Resolved)
			expect(p2._Value[1]).to.equal(2)
		end)
	end)

	describe("Promise.Reject", function()
		it("should instantly reject", function()
			local p = Promise.Reject(1)

			expect(p.Status).to.equal(Promise.Status.Rejected)
			expect(p._Value[1]).to.equal(1)
		end)

		it("should allow chaining", function()
			local p = Promise.Reject(1)

			local p2 = p:Then(nil, function(a)
				return a + 1
			end)

			expect(p2.Status).to.equal(Promise.Status.Rejected)
			expect(p2._Value[1]).to.equal(2)
		end)
	end)

	describe("Promise:Wait", function()
		it("should wait for a promise to resolve", function()
			local p = Promise:New(function(resolve)
				task.wait(1)
				resolve()
			end)

			expect(p.Status).to.equal(Promise.Status.Running)
			p:Wait()
			expect(p.Status).to.equal(Promise.Status.Resolved)
		end)

		it("should return the resolved value", function()
			local p = Promise:New(function(resolve)
				task.wait(1)
				resolve(1)
			end)

			expect(p.Status).to.equal(Promise.Status.Running)
			p:Wait()
			expect(p.Status).to.equal(Promise.Status.Resolved)
			expect(p:Wait()).to.equal(1)
		end)

		it("should error on rejection", function()
			local p = Promise:New(function(resolve, reject)
				task.wait(1)
				reject(1)
			end)

			expect(p.Status).to.equal(Promise.Status.Running)
			expect(function()
				p:Wait()
			end).to.throw()
		end)
	end)
end
