--!strict
-- Widgets.lua — виджеты MVP.
-- Button, Text, Checkbox, Separator, Spacing.
-- Каждый виджет:
--   1. Считывает Layout.currentWindow.layout для позиции.
--   2. Пушит draw-команды в DrawList.
--   3. Делает hit-test против input.mousePos / mouseDown.
--   4. Вызывает Layout.itemSize() для авто-layout.

local Util     = require(script.Parent.Util)
local DrawList = require(script.Parent.DrawList)
local Window   = require(script.Parent.Window)
local Vector2_new = Vector2.new

local Widgets = {}

-- ============================================================
-- Внутренние хелперы
-- ============================================================

-- Получить текущий контекст (Core). Через Window._setCoreRef мы зарегистрировали его.
local function ctx()
	return Window.Current() and (Window.Current() :: any)._coreRef or nil
end

-- Более надёжный путь: получить окно и его layout/drawList/style/input.
local function currentWindow()
	local w = Window.Current()
	if not w then
		error("Widgets: called outside of Begin/End block")
	end
	return w
end

-- Доступ к глобальному контексту через Window._getCore()
-- (устанавливается в Core.new через _setCoreRef).
local _coreRef = nil
function Widgets._setCoreRef(c)
	_coreRef = c
end

local function core()
	if not _coreRef then error("Widgets: core not initialized") end
	return _coreRef
end

-- Hit-test: мышь внутри прямоугольника?
local function mouseInRect(rect: Util.Rect, mousePos: Vector2): boolean
	return Util.RectContains(rect, mousePos)
end

-- ============================================================
-- Button
-- ============================================================

function Widgets.Button(label: string, size: Vector2?): boolean
	local w = currentWindow()
	local c = core()
	local style = c.style
	local input = c.input
	local drawList = c.drawList

	-- Размер кнопки
	local btnSize = size or Vector2_new(0, 0)
	if btnSize.X == 0 then btnSize = Vector2_new(80, 0) end
	if btnSize.Y == 0 then btnSize = Vector2_new(btnSize.X, 22) end

	-- Позиция: берём из layout
	local pos = w.layout.cursor
	local rect = Util.Rect(pos.X, pos.Y, btnSize.X, btnSize.Y)

	-- Состояние
	local hovered = mouseInRect(rect, input.mousePos)
	local active = hovered and input.mouseDown
	local pressed = hovered and input.mouseClicked

	-- Цвет
	local col = style.Colors
	local color
	if active then color = col.ButtonActive
	elseif hovered then color = col.ButtonHovered
	else color = col.Button end

	-- Рисуем
	local p0 = rect.min
	local p1 = rect.max
	drawList:AddRectFilled(p0, p1, color, style.FrameRounding)

	if style.FrameBorderSize > 0 then
		drawList:AddRect(p0, p1, col.Border, style.FrameRounding, style.FrameBorderSize)
	end

	-- Текст по центру (Drawing API measurement)
	local textSize = DrawList.CalcTextSize(drawList, label, Enum.Font.Code, 14)

	local textX = p0.X + (btnSize.X - textSize.X) * style.ButtonTextAlign.X
	local textY = p0.Y + (btnSize.Y - textSize.Y) * style.ButtonTextAlign.Y
	drawList:AddText(Vector2_new(textX, textY), col.Text, label, Enum.Font.Code, 14)

	-- Layout: сдвиг курсора
	w.layout:ItemSize(btnSize, style.ItemSpacing)

	return pressed
end

-- ============================================================
-- Text
-- ============================================================

function Widgets.Text(s: string)
	local w = currentWindow()
	local c = core()
	local style = c.style
	local drawList = c.drawList

	-- Замер текста (Drawing API measurement)
	local textSize = DrawList.CalcTextSize(drawList, s, Enum.Font.Code, 14)

	local pos = w.layout.cursor
	drawList:AddText(pos, style.Colors.Text, s, Enum.Font.Code, 14)

	w.layout:ItemSize(textSize, style.ItemSpacing)
end

-- ============================================================
-- Checkbox
-- ============================================================

function Widgets.Checkbox(label: string, value: { value: boolean }): boolean
	local w = currentWindow()
	local c = core()
	local style = c.style
	local input = c.input
	local drawList = c.drawList

	-- Размер чекбокса: квадрат style.GrabMinSize x style.GrabMinSize
	local box = style.GrabMinSize
	local boxSize = Vector2_new(box, box)

	-- Замер текста (Drawing API measurement)
	local textSize = DrawList.CalcTextSize(drawList, label, Enum.Font.Code, 14)

	local totalW = box + style.ItemInnerSpacing.X + textSize.X
	local totalH = math.max(box, textSize.Y)

	local pos = w.layout.cursor
	-- total rect для hit-test
	local rect = Util.Rect(pos.X, pos.Y, totalW, totalH)
	local hovered = mouseInRect(rect, input.mousePos)

	-- Box rect
	local boxRect = Util.Rect(pos.X, pos.Y + (totalH - box) / 2, box, box)

	-- Toggle on click
	local toggled = false
	if hovered and input.mouseClicked then
		value.value = not value.value
		toggled = true
	end

	local col = style.Colors
	-- Box bg
	local boxColor
	if value.value then
		boxColor = col.CheckMark
	else
		boxColor = hovered and col.ButtonHovered or col.Button
	end
	drawList:AddRectFilled(boxRect.min, boxRect.max, boxColor, style.GrabRounding)

	if style.FrameBorderSize > 0 then
		drawList:AddRect(boxRect.min, boxRect.max, col.Border, style.GrabRounding, style.FrameBorderSize)
	end

	-- Checkmark (если value.value)
	if value.value then
		-- Маленькая галочка: линия из левого-нижнего в центр и в правый-верхний угол
		local pad = 2
		local a = Vector2_new(boxRect.min.X + pad, boxRect.min.Y + box / 2)
		local b = Vector2_new(boxRect.min.X + box / 2, boxRect.max.Y - pad)
		local cc = Vector2_new(boxRect.max.X - pad, boxRect.min.Y + pad)
		drawList:AddLine(a, b, col.Text, 2)
		drawList:AddLine(b, cc, col.Text, 2)
	end

	-- Label
	drawList:AddText(
		Vector2_new(pos.X + box + style.ItemInnerSpacing.X, pos.Y + (totalH - textSize.Y) / 2),
		col.Text, label, Enum.Font.Code, 14
	)

	w.layout:ItemSize(Vector2_new(totalW, totalH), style.ItemSpacing)

	return toggled
end

-- ============================================================
-- Separator — горизонтальная линия на всю ширину окна
-- ============================================================

function Widgets.Separator()
	local w = currentWindow()
	local c = core()
	local style = c.style
	local drawList = c.drawList

	local pos = w.layout.cursor
	local clientRect = w._clientRect
	local width = Util.RectWidth(clientRect)
	local sepY = pos.Y + style.ItemSpacing.Y

	drawList:AddLine(
		Vector2_new(pos.X, sepY),
		Vector2_new(pos.X + width, sepY),
		style.Colors.Separator, 1
	)

	w.layout:ItemSize(Vector2_new(width, style.ItemSpacing.Y * 2 + 1), style.ItemSpacing)
end

-- ============================================================
-- Spacing — пустое пространство
-- ============================================================

function Widgets.Spacing()
	local w = currentWindow()
	local c = core()
	local style = c.style

	w.layout:ItemSize(Vector2_new(0, 4), style.ItemSpacing)
end

-- ============================================================
-- SameLine / Indent / Unindent — layout helpers (делегируют в Layout)
-- ============================================================

function Widgets.SameLine(offsetX: number?, spacingW: number?)
	local w = currentWindow()
	local c = core()
	w.layout:SameLine(offsetX, spacingW)
end

function Widgets.Indent(w_: number?)
	local w = currentWindow()
	local c = core()
	w.layout:Indent(w_ or c.style.IndentSpacing)
end

function Widgets.Unindent(w_: number?)
	local w = currentWindow()
	local c = core()
	w.layout:Unindent(w_ or c.style.IndentSpacing)
end

return Widgets
