--!strict
-- Layout.lua — auto-layout курсор, ItemRect, SameLine / Indent / Spacing.
--
-- Каждый раз когда виджет хочет знать «где меня рисовать», он читает
-- Layout.cursor и Layout.contentMax. После отрисовки виджет вызывает
-- Layout.ItemSize(), который сдвигает курсор вниз на свою высоту + spacing.

local Util = require(script.Parent.Util)
local Vector2_new = Vector2.new

local Layout = {}

export type Layout = {
	-- Левый верхний угол клиентской области окна (в абсолютных координатах)
	origin: Vector2,
	-- Курсор — куда класть следующий виджет
	cursor: Vector2,
	-- Максимальная занятая область (для auto-size окна и scroll)
	contentMin: Vector2,
	contentMax: Vector2,
	-- Сколько раз в этом кадре вызывалась SameLine (для переключения строки)
	lineHeight: number,
	lineStartPos: Vector2,
	-- Текущий отступ (Indent)
	indentX: number,
	-- ItemRect последнего виджета (для IsItemHovered/Active)
	lastItemRect: Util.Rect,
	-- Для SameLine: флаг «следующий виджет должен встать в ту же строку»
	sameLine: boolean,
	-- Текущая ширина строки (для ширины виджета по умолчанию)
	lineWidth: number,
}

function Layout.new(): Layout
	local self = {
		origin = Vector2_new(0, 0),
		cursor = Vector2_new(0, 0),
		contentMin = Vector2_new(0, 0),
		contentMax = Vector2_new(0, 0),
		lineHeight = 0,
		lineStartPos = Vector2_new(0, 0),
		indentX = 0,
		lastItemRect = Util.Rect(0, 0, 0, 0),
		sameLine = false,
		lineWidth = 0,
	}
	setmetatable(self, { __index = Layout })
	return self
end

-- Сброс к началу клиентской области окна.
function Layout.Reset(self: Layout, origin: Vector2)
	self.origin = origin
	self.cursor = Vector2_new(origin.X + self.indentX, origin.Y)
	self.contentMin = origin
	self.contentMax = origin
	self.lineHeight = 0
	self.lineStartPos = self.cursor
	self.sameLine = false
	self.lineWidth = 0
end

-- Сдвинуть курсор на новую строку (если не SameLine)
function Layout.NewLine(self: Layout, spacing: Vector2)
	self.cursor = Vector2_new(self.origin.X + self.indentX, self.cursor.Y + self.lineHeight + spacing.Y)
	self.lineHeight = 0
	self.lineStartPos = self.cursor
	self.sameLine = false
	self.lineWidth = 0
end

-- SameLine: следующий виджет в той же строке
function Layout.SameLine(self: Layout, offsetX: number?, spacingW: number?)
	if not self.sameLine then
		-- Закрыть предыдущую строку: cursor уже правее последнего виджета
		self.sameLine = true
	end
	local dx = (offsetX or 0) + (spacingW or 8)
	self.cursor = Vector2_new(self.cursor.X + dx, self.lineStartPos.Y)
end

function Layout.Indent(self: Layout, w: number)
	self.indentX = self.indentX + w
	self.cursor = Vector2_new(self.cursor.X + w, self.cursor.Y)
end

function Layout.Unindent(self: Layout, w: number)
	self.indentX = self.indentX - w
	if self.indentX < 0 then self.indentX = 0 end
	self.cursor = Vector2_new(self.cursor.X - w, self.cursor.Y)
	if self.cursor.X < self.origin.X then self.cursor = Vector2_new(self.origin.X, self.cursor.Y) end
end

-- Виджет должен вызвать ItemSize после отрисовки.
-- size — размер виджета (width, height).
function Layout.ItemSize(self: Layout, size: Vector2, spacing: Vector2)
	local pos = self.cursor

	-- Обновить content bounds
	if pos.X < self.contentMin.X then self.contentMin = Vector2_new(pos.X, self.contentMin.Y) end
	if pos.Y < self.contentMin.Y then self.contentMin = Vector2_new(self.contentMin.X, pos.Y) end
	if pos.X + size.X > self.contentMax.X then self.contentMax = Vector2_new(pos.X + size.X, self.contentMax.Y) end
	if pos.Y + size.Y > self.contentMax.Y then self.contentMax = Vector2_new(self.contentMax.X, pos.Y + size.Y) end

	-- Обновить lastItemRect (для IsItemHovered/Active)
	self.lastItemRect = Util.RectFromMinMax(pos, Vector2_new(pos.X + size.X, pos.Y + size.Y))

	-- Обновить line height
	if size.Y > self.lineHeight then
		self.lineHeight = size.Y
	end

	-- Сдвинуть курсор
	if self.sameLine then
		self.cursor = Vector2_new(pos.X + size.X + spacing.X, pos.Y)
		self.lineWidth = self.lineWidth + size.X + spacing.X
	else
		self.cursor = Vector2_new(self.origin.X + self.indentX, pos.Y + size.Y + spacing.Y)
		self.lineHeight = size.Y
		self.lineStartPos = Vector2_new(self.origin.X + self.indentX, pos.Y)
	end
end

-- Принудительно выставить lastItemRect (виджет сам посчитал позицию)
function Layout.SetItemRect(self: Layout, rect: Util.Rect)
	self.lastItemRect = rect
end

return Layout
