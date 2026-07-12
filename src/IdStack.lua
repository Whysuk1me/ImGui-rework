--!strict
-- IdStack.lua — стек ID для генерации уникальных ImGuiID виджетов.
-- Работает как в Dear ImGui: PushID(str) / PushID(ptr) / PopID().
-- Текущий ID = HashCombine(HashCombine(...stack), HashStr(label)).

local Util = require(script.Parent.Util)

local IdStack = {}

export type IdStack = {
	stack: { number },
}

function IdStack.new(): IdStack
	local self = { stack = {} }
	setmetatable(self, { __index = IdStack })
	return self
end

function IdStack.Push(self: IdStack, key: any)
	local id = Util.GetID(key)
	local prev = self.stack[#self.stack] or 0
	self.stack[#self.stack + 1] = Util.HashCombine(prev, id)
end

function IdStack.Pop(self: IdStack)
	assert(#self.stack > 0, "IdStack.Pop: stack is empty")
	table.remove(self.stack)
end

-- Получить текущий seed (для комбинирования с лейблом виджета).
function IdStack.Seed(self: IdStack): number
	return self.stack[#self.stack] or 0
end

-- Полный ID виджета: HashCombine(Seed, GetID(label))
function IdStack.GetID(self: IdStack, label: any): number
	return Util.HashCombine(self:Seed(), Util.GetID(label))
end

function IdStack.Size(self: IdStack): number
	return #self.stack
end

return IdStack
