--!strict
-- ImGui.lua — публичный API.
-- Подключается через require(...).ImGui
-- Использование:
--
--   local ImGui = require(path.ImGui)
--   ImGui.Init()  -- однократно
--   RunService.RenderStepped:Connect(function()
--       ImGui.BeginFrame()
--       ImGui.Begin("My Window", { pos = Vector2.new(100, 100), size = Vector2.new(300, 200) })
--       ImGui.Text("hello world")
--       if ImGui.Button("press me") then print("clicked") end
--       local state = { value = false }
--       ImGui.Checkbox("enable feature", state)
--       ImGui.Separator()
--       ImGui.End()
--       ImGui.EndFrame()
--   end)
--
-- ImGui.Init() создаёт singleton-контекст (Core.new + Input.Init).

local Core    = require(script.Parent.Core)
local Window  = require(script.Parent.Window)
local Widgets = require(script.Parent.Widgets)
local Style   = require(script.Parent.Style)
local DrawList = require(script.Parent.DrawList)
local Input   = require(script.Parent.Input)
local Renderer = require(script.Parent.Renderer)

local ImGui = {}

-- ============================================================
-- Lifecycle
-- ============================================================

function ImGui.Init()
	local ctx = Core.Get()
	Widgets._setCoreRef(ctx)
end

function ImGui.Destroy()
	local ctx = Core.Get()
	Core.Destroy(ctx)
end

-- ============================================================
-- Frame
-- ============================================================

function ImGui.BeginFrame()
	local ctx = Core.Get()
	Core.BeginFrame(ctx)
end

function ImGui.EndFrame()
	local ctx = Core.Get()
	Core.EndFrame(ctx)
end

-- ============================================================
-- Window
-- ============================================================

-- Возвращает true если окно сейчас раскрыто (не collapsed).
function ImGui.Begin(name: string, opt: { pos: Vector2?, size: Vector2?, flags: { [string]: boolean }? }?): boolean
	local ctx = Core.Get()
	local w = Window.Begin(ctx.drawList, ctx.style, ctx.input, name, opt)
	ctx.currentWindow = w
	return not w.collapsed
end

function ImGui.End()
	local ctx = Core.Get()
	Window.End(ctx.drawList)
	ctx.currentWindow = nil
end

-- ============================================================
-- Widgets (проброс из Widgets)
-- ============================================================

ImGui.Button    = Widgets.Button
ImGui.Text      = Widgets.Text
ImGui.Checkbox  = Widgets.Checkbox
ImGui.Separator = Widgets.Separator
ImGui.Spacing   = Widgets.Spacing
ImGui.SameLine  = Widgets.SameLine
ImGui.Indent    = Widgets.Indent
ImGui.Unindent  = Widgets.Unindent

-- ============================================================
-- Style helpers
-- ============================================================

function ImGui.GetStyle(): Style.ImGuiStyle
	return Core.Get().style
end

function ImGui.PushStyleColor(name: string, color: Color3)
	-- MVP: прямая замена цвета
	local style = Core.Get().style
	style.Colors[name] = color
end

function ImGui.PopStyleColor()
	-- MVP: не реализовано, используется прямая замена
end

return ImGui
