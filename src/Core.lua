--!strict
-- Core.lua — глобальный контекст ImGui.
-- Хранит текущее окно, DrawList, Style, Input, Renderer.
-- BeginFrame() → (юзерский код Begin/End/Widgets) → EndFrame().

local Util     = require(script.Parent.Util)
local Style    = require(script.Parent.Style)
local Input    = require(script.Parent.Input)
local DrawList = require(script.Parent.DrawList)
local Renderer = require(script.Parent.Renderer)
local Window   = require(script.Parent.Window)

local Core = {}

export type Context = {
	style: Style.ImGuiStyle,
	input: Input.InputState,
	renderer: RenderPool, -- Renderer.RenderPool
	drawList: DrawList.DrawList,

	-- Текущее окно (top of stack)
	currentWindow: Window.Window?,

	-- Фрейм-стейт
	frame: number,
	framed: boolean, -- между BeginFrame и EndFrame
}

-- Forward-объявление типа (Renderer.RenderPool не экспортируется через type)
type RenderPool = any

local _ctx: Context? = nil

function Core.new(): Context
	local ctx = {
		style = Style.CreateDark(),
		input = Input.new(),
		renderer = Renderer.new(),
		drawList = DrawList.new(),
		currentWindow = nil,
		frame = 0,
		framed = false,
	}
	Window._setCoreRef(ctx)
	return ctx
end

-- Singleton accessor. Core.new() вызывает пользователь.
function Core.Get(): Context
	if not _ctx then
		_ctx = Core.new()
		Input.Init(_ctx.input)
	end
	return _ctx
end

function Core.BeginFrame(self: Context)
	self.frame += 1
	self.framed = true
	self.currentWindow = nil

	Input.BeginFrame(self.input)
	DrawList.Clear(self.drawList)
end

function Core.EndFrame(self: Context)
	-- Отсортировать окна по focusOrder перед рендером (для z-order).
	-- Окна с большим focusOrder рисуются последними (поверх).
	-- Однако DrawList уже накапливает команды в порядке Begin() вызовов —
	-- что соответствует z-order'у, если юзер вызывает Begin в нужном порядке.
	-- Для простоты MVP: порядок рисования = порядок Begin в кадре.
	-- Фокус меняет только визуальное состояние (title bar color).

	Renderer.Render(self.renderer, self.drawList)

	self.framed = false
	self.currentWindow = nil
end

function Core.Destroy(self: Context)
	Input.Destroy(self.input)
	Renderer.Destroy(self.renderer)
	if _ctx == self then
		_ctx = nil
	end
end

return Core
