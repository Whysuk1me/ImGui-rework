-- Renderer.lua — материализация DrawList в Drawing-объекты.
--
-- Каждый кадр Core передаёт нам DrawList. Мы:
--   1. Идём по командам последовательно.
--   2. Берём объект из пула по индексу (или создаём новый).
--   3. Обновляем свойства объекта под команду.
--   4. Скрываем лишние объекты (если в этом кадре их меньше, чем в прошлом).
--
-- ZIndex: каждому объекту присваивается глобальный ZIndex = порядковый
-- номер команды. Это гарантирует правильный layering (фон < бордюр <
-- текст < виджеты), даже если пулы объектов разных типов создавались
-- в другом порядке.

local Util = require("Util")
local DrawList = require("DrawList")

local Renderer = {}

-- Безопасная установка свойства (не все эксплойты поддерживают все свойства)
local function setProp(obj, prop, val)
	pcall(function() obj[prop] = val end)
end

-- Безопасное создание Drawing-объекта.
local function newDrawing(kind)
	local ok, obj = pcall(Drawing.new, kind)
	-- Проверяем, что результат — таблица или userdata (не nil/0/false/строка).
	-- Некоторые эксплойты возвращают 0 для неподдерживаемых типов.
	if not ok or obj == nil or (type(obj) ~= "table" and type(obj) ~= "userdata") then
		return nil
	end
	pcall(function() obj.Visible = false end)
	return obj
end

function Renderer.new()
	local self = {
		Line = {},
		Rect = {},
		RectFilled = {},
		Triangle = {},
		TriangleFilled = {},
		Circle = {},
		CircleFilled = {},
		Text = {},
		_used = {},
	}
	setmetatable(self, { __index = Renderer })
	return self
end

-- Получить объект из пула (или создать).
local function getOrCreate(pool, kind, idx)
	local obj = pool[idx]
	if not obj then
		obj = newDrawing(kind)
		pool[idx] = obj
	end
	return obj
end

-- Скрыть неиспользуемые объекты начиная с индекса
local function hideTail(pool, fromIdx)
	for i = fromIdx, #pool do
		local obj = pool[i]
		if obj then
			pcall(function()
				if obj.Visible then obj.Visible = false end
			end)
		end
	end
end

-- ============================================================
-- Render — главная точка входа
-- ============================================================

function Renderer.Render(self, drawList)
	self._used = {}
	local z = 0  -- глобальный ZIndex (возрастает с каждой командой)

	local cmds = drawList.commands
	for i = 1, #cmds do
		local cmd = cmds[i]
		z = z + 1

		local kind = cmd.kind
		local used = (self._used[kind] or 0) + 1
		self._used[kind] = used

		local clip = cmd.clipRect

		if kind == "Line" then
			self:_renderLine(used, z, cmd, clip)
		elseif kind == "Rect" then
			self:_renderRect(used, z, cmd, clip)
		elseif kind == "RectFilled" then
			self:_renderRectFilled(used, z, cmd, clip)
		elseif kind == "Triangle" then
			self:_renderTriangle(used, z, cmd, clip)
		elseif kind == "TriangleFilled" then
			self:_renderTriangleFilled(used, z, cmd, clip)
		elseif kind == "Circle" then
			self:_renderCircle(used, z, cmd, clip)
		elseif kind == "CircleFilled" then
			self:_renderCircleFilled(used, z, cmd, clip)
		elseif kind == "Text" then
			self:_renderText(used, z, cmd, clip)
		end
	end

	hideTail(self.Line,             (self._used.Line or 0) + 1)
	hideTail(self.Rect,             (self._used.Rect or 0) + 1)
	hideTail(self.RectFilled,       (self._used.RectFilled or 0) + 1)
	hideTail(self.Triangle,         (self._used.Triangle or 0) + 1)
	hideTail(self.TriangleFilled,   (self._used.TriangleFilled or 0) + 1)
	hideTail(self.Circle,           (self._used.Circle or 0) + 1)
	hideTail(self.CircleFilled,     (self._used.CircleFilled or 0) + 1)
	hideTail(self.Text,             (self._used.Text or 0) + 1)
end

-- ============================================================
-- Примитивы
-- ============================================================

function Renderer._renderLine(self, idx, z, cmd, clip)
	local obj = getOrCreate(self.Line, "Line", idx)
	if not obj then return end
	if not cmd.p0 or not cmd.p1 then setProp(obj, "Visible", false); return end

	local p0, p1 = cmd.p0, cmd.p1
	if clip then
		p0, p1 = Util.RectClipLine(clip, p0, p1)
	end

	setProp(obj, "From", p0)
	setProp(obj, "To", p1)
	setProp(obj, "Color", cmd.color)
	setProp(obj, "Thickness", cmd.thickness)
	setProp(obj, "ZIndex", z)
	setProp(obj, "Visible", true)
end

function Renderer._renderRect(self, idx, z, cmd, clip)
	local obj = getOrCreate(self.Rect, "Square", idx)
	if not obj then return end
	if not cmd.p0 or not cmd.p1 then setProp(obj, "Visible", false); return end

	local p0, p1 = cmd.p0, cmd.p1
	if clip then
		local clipped = Util.RectClip({ min = p0, max = p1 }, clip)
		if not clipped then setProp(obj, "Visible", false); return end
		p0, p1 = clipped.min, clipped.max
	end

	setProp(obj, "Position", p0)
	setProp(obj, "Size", Vector2.new(p1.X - p0.X, p1.Y - p0.Y))
	setProp(obj, "Color", cmd.color)
	setProp(obj, "Thickness", cmd.thickness)
	setProp(obj, "Filled", false)
	setProp(obj, "Radius", cmd.rounding or 0)
	setProp(obj, "ZIndex", z)
	setProp(obj, "Visible", true)
end

function Renderer._renderRectFilled(self, idx, z, cmd, clip)
	local obj = getOrCreate(self.RectFilled, "Square", idx)
	if not obj then return end
	if not cmd.p0 or not cmd.p1 then setProp(obj, "Visible", false); return end

	local p0, p1 = cmd.p0, cmd.p1
	if clip then
		local clipped = Util.RectClip({ min = p0, max = p1 }, clip)
		if not clipped then setProp(obj, "Visible", false); return end
		p0, p1 = clipped.min, clipped.max
	end

	local w = p1.X - p0.X
	local h = p1.Y - p0.Y
	if w < 1 then w = 1 end
	if h < 1 then h = 1 end

	setProp(obj, "Position", p0)
	setProp(obj, "Size", Vector2.new(w, h))
	setProp(obj, "Color", cmd.color)
	setProp(obj, "Filled", true)
	setProp(obj, "Thickness", 0)
	setProp(obj, "Radius", cmd.rounding or 0)
	setProp(obj, "ZIndex", z)
	setProp(obj, "Visible", true)
end

function Renderer._renderTriangle(self, idx, z, cmd, clip)
	if not cmd.p0 or not cmd.p1 or not cmd.p2 then return end
	local obj = getOrCreate(self.Triangle, "Triangle", idx)
	if obj then
		setProp(obj, "PointA", cmd.p0)
		setProp(obj, "PointB", cmd.p1)
		setProp(obj, "PointC", cmd.p2)
		setProp(obj, "Color", cmd.color)
		setProp(obj, "Thickness", cmd.thickness)
		setProp(obj, "Filled", false)
		setProp(obj, "ZIndex", z)
		setProp(obj, "Visible", true)
	else
		-- Fallback: 3 линии
		local pts = { cmd.p0, cmd.p1, cmd.p2 }
		for i = 1, 3 do
			local li = (idx - 1) * 3 + i
			local lobj = getOrCreate(self.Triangle, "Line", li)
			if lobj then
				setProp(lobj, "From", pts[i])
				setProp(lobj, "To", pts[(i % 3) + 1])
				setProp(lobj, "Color", cmd.color)
				setProp(lobj, "Thickness", cmd.thickness)
				setProp(lobj, "ZIndex", z)
				setProp(lobj, "Visible", true)
			end
		end
	end
end

function Renderer._renderTriangleFilled(self, idx, z, cmd, clip)
	if not cmd.p0 or not cmd.p1 or not cmd.p2 then return end
	local obj = getOrCreate(self.TriangleFilled, "Triangle", idx)
	if obj then
		setProp(obj, "PointA", cmd.p0)
		setProp(obj, "PointB", cmd.p1)
		setProp(obj, "PointC", cmd.p2)
		setProp(obj, "Color", cmd.color)
		setProp(obj, "Filled", true)
		setProp(obj, "Thickness", 0)
		setProp(obj, "ZIndex", z)
		setProp(obj, "Visible", true)
	else
		-- Fallback: рисуем bounding-box Square как приближение
		local sobj = getOrCreate(self.TriangleFilled, "Square", idx)
		if sobj then
			local minX = math.min(cmd.p0.X, cmd.p1.X, cmd.p2.X)
			local minY = math.min(cmd.p0.Y, cmd.p1.Y, cmd.p2.Y)
			local maxX = math.max(cmd.p0.X, cmd.p1.X, cmd.p2.X)
			local maxY = math.max(cmd.p0.Y, cmd.p1.Y, cmd.p2.Y)
			setProp(sobj, "Position", Vector2.new(minX, minY))
			setProp(sobj, "Size", Vector2.new(maxX - minX, maxY - minY))
			setProp(sobj, "Color", cmd.color)
			setProp(sobj, "Filled", true)
			setProp(sobj, "ZIndex", z)
			setProp(sobj, "Visible", true)
		end
	end
end

function Renderer._renderCircle(self, idx, z, cmd, clip)
	local obj = getOrCreate(self.Circle, "Circle", idx)
	if not obj then return end
	if not cmd.center then setProp(obj, "Visible", false); return end

	setProp(obj, "Position", cmd.center)
	setProp(obj, "Radius", cmd.radius)
	setProp(obj, "Color", cmd.color)
	setProp(obj, "Thickness", cmd.thickness)
	setProp(obj, "Filled", false)
	setProp(obj, "NumSides", 30)
	setProp(obj, "ZIndex", z)
	setProp(obj, "Visible", true)
end

function Renderer._renderCircleFilled(self, idx, z, cmd, clip)
	local obj = getOrCreate(self.CircleFilled, "Circle", idx)
	if not obj then return end
	if not cmd.center then setProp(obj, "Visible", false); return end

	setProp(obj, "Position", cmd.center)
	setProp(obj, "Radius", cmd.radius)
	setProp(obj, "Color", cmd.color)
	setProp(obj, "Filled", true)
	setProp(obj, "Thickness", 0)
	setProp(obj, "NumSides", 30)
	setProp(obj, "ZIndex", z)
	setProp(obj, "Visible", true)
end

function Renderer._renderText(self, idx, z, cmd, clip)
	local obj = getOrCreate(self.Text, "Text", idx)
	if not obj then return end
	if not cmd.p0 or not cmd.text then setProp(obj, "Visible", false); return end

	setProp(obj, "Position", cmd.p0)
	setProp(obj, "Text", cmd.text)
	setProp(obj, "Color", cmd.color)
	setProp(obj, "Size", cmd.textSize or 14)
	setProp(obj, "Font", Renderer._fontToNumber(cmd.font))
	setProp(obj, "Center", false)
	setProp(obj, "Outline", false)
	setProp(obj, "ZIndex", z)
	setProp(obj, "Visible", true)
end

-- ============================================================
-- Конвертация Enum.Font → число для Drawing API
-- ============================================================

local FONT_MAP = {}

local FONT_NAMES = {
	{ "UI", 0 }, { "System", 1 }, { "Plex", 2 }, { "Monospace", 3 },
	{ "Arial", 4 }, { "ArialBold", 4 }, { "Highway", 5 },
	{ "SourceSans", 6 }, { "SourceSansBold", 7 }, { "Code", 3 },
	{ "Roboto", 6 }, { "RobotoMono", 3 }, { "Gotham", 6 },
	{ "GothamMedium", 6 }, { "GothamBold", 7 }, { "GothamBlack", 7 },
	{ "Montserrat", 6 }, { "MontserratBold", 7 }, { "Baloo", 6 },
	{ "Bangers", 6 }, { "Creepster", 6 }, { "DenkOne", 6 },
	{ "Fondamento", 6 }, { "FredokaOne", 6 }, { "Jura", 6 },
	{ "Kalam", 6 }, { "LuckiestGuy", 6 }, { "Merriweather", 6 },
	{ "Michroma", 6 }, { "Nunito", 6 }, { "Oswald", 6 },
	{ "PatrickHand", 6 }, { "PermanentMarker", 6 },
	{ "Spectral", 6 }, { "TitilliumWeb", 6 }, { "ZillaSlab", 6 },
}

local function buildFontMap()
	for i = 1, #FONT_NAMES do
		local entry = FONT_NAMES[i]
		local name, num = entry[1], entry[2]
		local ok, font = pcall(function() return Enum.Font[name] end)
		if ok and font then
			FONT_MAP[font] = num
		end
	end
end

buildFontMap()

function Renderer._fontToNumber(font)
	if type(font) == "number" then return font end
	if not font then return 0 end
	local n = FONT_MAP[font]
	if n then return n end
	local ok, v = pcall(function() return font.Value end)
	if ok and type(v) == "number" then return v end
	return 0
end

-- ============================================================
-- Destroy
-- ============================================================

function Renderer.Destroy(self)
	for _, pool in ipairs({
		self.Line, self.Rect, self.RectFilled,
		self.Triangle, self.TriangleFilled,
		self.Circle, self.CircleFilled, self.Text,
	}) do
		for i = 1, #pool do
			local obj = pool[i]
			if obj then
				pcall(function() obj:Remove() end)
			end
		end
	end

	self.Line = {}
	self.Rect = {}
	self.RectFilled = {}
	self.Triangle = {}
	self.TriangleFilled = {}
	self.Circle = {}
	self.CircleFilled = {}
	self.Text = {}
end

return Renderer
