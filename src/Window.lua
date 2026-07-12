--!strict
-- Window.lua — оконная система.
-- Begin(name, opt) → End().
-- Окно хранит позицию/размер между кадрами (stateful), поддерживает:
--   - drag за title bar
--   - resize за правый нижний угол
--   - collapse/expand
--   - focus (ZIndex): последнее кликнутое окно наверх
--   - clipping дочерних виджетов по клиентской области

local Util    = require(script.Parent.Util)
local Style   = require(script.Parent.Style)
local Layout  = require(script.Parent.Layout)
local DrawList = require(script.Parent.DrawList)
local Vector2_new = Vector2.new

local Window = {}

export type WindowOptions = {
	pos: Vector2?,
	size: Vector2?,
	flags: { [string]: boolean }?,
}

export type Window = {
	-- Идентификация
	name: string,
	id: number,

	-- Позиция / размер (в абсолютных координатах экрана)
	pos: Vector2,
	size: Vector2,

	-- Состояние
	collapsed: boolean,
	focused: boolean,
	focusOrder: number, -- больше = выше

	-- Временное состояние в течение кадра
	flags: { [string]: boolean },
	appearing: boolean, -- первый кадр после открытия
	_titleBarRect: Util.Rect,
	_resizeGripRect: Util.Rect,

	-- Клиентская область (где рисуются виджеты)
	_clientRect: Util.Rect,

	-- Состояние drag/resize
	_dragging: boolean,
	_dragOffset: Vector2,
	_resizing: boolean,
	_resizeStartSize: Vector2,
	_resizeStartMouse: Vector2,

	-- Layout окна
	layout: Layout.Layout,
}

-- Хранилище окон по имени (stateful между кадрами)
-- Ключ — name (string), значение — Window
local _windows = {}
local _order = {} -- упорядоченный список (z-order)
local _focusCounter = 0

-- Найти окно по имени (создать если не существует)
function Window.GetOrCreate(name: string, defaultPos: Vector2, defaultSize: Vector2): Window
	local w = _windows[name]
	if w then return w end

	w = {
		name = name,
		id = Util.HashStr(name),
		pos = defaultPos,
		size = defaultSize,
		collapsed = false,
		focused = false,
		focusOrder = 0,
		flags = {},
		appearing = true,
		_titleBarRect = Util.Rect(0, 0, 0, 0),
		_resizeGripRect = Util.Rect(0, 0, 0, 0),
		_clientRect = Util.Rect(0, 0, 0, 0),
		_dragging = false,
		_dragOffset = Vector2_new(0, 0),
		_resizing = false,
		_resizeStartSize = Vector2_new(0, 0),
		_resizeStartMouse = Vector2_new(0, 0),
		layout = Layout.new(),
	}
	_windows[name] = w
	table.insert(_order, w)
	return w
end

function Window.GetAll(): { Window }
	return _order
end

function Window.Get(name: string): Window?
	return _windows[name]
end

-- Вызывается Core.Clear()
function Window.ClearOrder()
	table.clear(_order)
	-- _windows оставляем — stateful данные окон переживут перезагрузку
end

-- ============================================================
-- Begin / End
-- ============================================================

local Core_ref -- forward-объявление, будет установлен Core.lua после загрузки
local function setCoreRef(core)
	Core_ref = core
end
Window._setCoreRef = setCoreRef

function Window.Begin(drawList: DrawList.DrawList, style: Style.ImGuiStyle, input: any, name: string, opt: WindowOptions?): Window
	local w = Window.GetOrCreate(name, opt and opt.pos or Vector2_new(100, 100), opt and opt.size or Vector2_new(300, 200))

	-- Применить флаги
	w.flags = (opt and opt.flags) or {}
	w.appearing = (w.appearing == true)

	-- Принудительный размер/позиция если есть в опциях (только первый кадр)
	if opt and opt.size and w.appearing then
		w.size = opt.size
	end
	if opt and opt.pos and w.appearing then
		w.pos = opt.pos
	end

	-- Минимальный размер
	if w.size.X < style.WindowMinSize.X then w.size = Vector2_new(style.WindowMinSize.X, w.size.Y) end
	if w.size.Y < style.WindowMinSize.Y then w.size = Vector2_new(w.size.X, style.WindowMinSize.Y) end

	-- Сначала обрабатываем ввод (drag/resize может изменить w.pos и w.size),
	-- ПОТОМ вычисляем rect'ы и layout на основе актуальной позиции.

	local titleHeight = 24
	local pad = style.WindowPadding

	-- Input handling: focus on click (нужен текущий titleBarRect для hit-test)
	local curTitleRect = Util.Rect(w.pos.X, w.pos.Y, w.size.X, titleHeight)
	local curResizeRect = Util.Rect(w.pos.X + w.size.X - 12, w.pos.Y + w.size.Y - 12, 12, 12)

	if input.mouseClicked and Util.RectContains(curTitleRect, input.mousePos) then
		w.focused = true
		w.focusOrder = _focusCounter + 1
		_focusCounter = _focusCounter + 1
	end

	-- Drag handling
	if not w.flags.NoMove then
		if not w._dragging and input.mouseClicked and Util.RectContains(curTitleRect, input.mousePos) then
			w._dragging = true
			w._dragOffset = Vector2_new(input.mousePos.X - w.pos.X, input.mousePos.Y - w.pos.Y)
		end
		if w._dragging then
			w.pos = Vector2_new(input.mousePos.X - w._dragOffset.X, input.mousePos.Y - w._dragOffset.Y)
			if not input.mouseDown then
				w._dragging = false
			end
		end
	end

	-- Resize handling
	if not w.flags.NoResize and not w.collapsed then
		if not w._resizing and input.mouseClicked and Util.RectContains(curResizeRect, input.mousePos) then
			w._resizing = true
			w._resizeStartSize = w.size
			w._resizeStartMouse = input.mousePos
		end
		if w._resizing then
			local delta = Vector2_new(input.mousePos.X - w._resizeStartMouse.X, input.mousePos.Y - w._resizeStartMouse.Y)
			w.size = Vector2_new(
				Util.Max(w._resizeStartSize.X + delta.X, style.WindowMinSize.X),
				Util.Max(w._resizeStartSize.Y + delta.Y, style.WindowMinSize.Y)
			)
			if not input.mouseDown then
				w._resizing = false
			end
		end
	end

	-- Теперь вычисляем rect'ы и layout на основе актуального w.pos / w.size
	w._titleBarRect = Util.Rect(w.pos.X, w.pos.Y, w.size.X, titleHeight)
	w._resizeGripRect = Util.Rect(w.pos.X + w.size.X - 12, w.pos.Y + w.size.Y - 12, 12, 12)

	local clientX = w.pos.X + pad.X
	local clientY = w.pos.Y + titleHeight + pad.Y
	local clientW = w.size.X - pad.X * 2
	local clientH = w.size.Y - titleHeight - pad.Y * 2
	if clientW < 0 then clientW = 0 end
	if clientH < 0 then clientH = 0 end
	w._clientRect = Util.Rect(clientX, clientY, clientW, clientH)

	-- Layout reset — layout и drawList используют ОДНУ И ТУ ЖЕ позицию
	w.layout:Reset(Vector2_new(clientX, clientY))
	drawList:PushClipRect(w._clientRect)

	-- Рисуем окно (фон + title + borders)
	Window._DrawWindow(drawList, style, w, input.mousePos)

	w.appearing = false
	return w
end

function Window._DrawWindow(drawList, style, w, mousePos)
	local col = style.Colors
	local round = style.WindowRounding
	local border = style.WindowBorderSize

	local p0 = w.pos
	local p1 = Vector2_new(w.pos.X + w.size.X, w.pos.Y + w.size.Y)

	-- Фон окна
	drawList:AddRectFilled(p0, p1, col.WindowBg, round)

	-- Title bar (отдельный фон)
	local titleH = 24
	local titleP0 = p0
	local titleP1 = Vector2_new(p1.X, p0.Y + titleH)
	drawList:AddRectFilled(titleP0, titleP1, w.focused and col.TitleBgActive or col.TitleBg, round)

	-- Border (обводка всего окна)
	if border > 0 then
		drawList:AddRect(p0, p1, col.Border, round, border)
	end

	-- Title text
	drawList:AddText(
		Vector2_new(p0.X + style.WindowPadding.X, p0.Y + 4),
		col.Text,
		w.name,
		Enum.Font.Code,
		14
	)

	-- Resize grip (треугольник в правом нижнем углу)
	if not w.flags.NoResize and not w.collapsed then
		local gripHovered = mousePos and Util.RectContains(w._resizeGripRect, mousePos)
		local gripColor = gripHovered and col.ResizeGripHovered or col.ResizeGrip
		local gx, gy = p1.X, p1.Y
		drawList:AddTriangleFilled(
			Vector2_new(gx - 14, gy),
			Vector2_new(gx, gy),
			Vector2_new(gx, gy - 14),
			gripColor
		)
	end
end

function Window.End(drawList: DrawList.DrawList)
	drawList:PopClipRect()
end

-- ============================================================
-- Хелперы для виджетов
-- ============================================================

-- Получить текущее окно (top of stack). Реализуется через Core.currentWindow.
function Window.Current(): Window?
	if Core_ref and Core_ref.currentWindow then
		return Core_ref.currentWindow
	end
	return nil
end

return Window
