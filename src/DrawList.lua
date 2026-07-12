--!strict
-- DrawList.lua — список draw-команд за кадр.
-- Виджеты и Window добавляют команды через Add* методы, в конце кадра
-- Renderer итерирует список и материализует в Drawing-объекты.
--
-- Каждая команда несёт clipRect (наследуется от текущего окна), Renderer
-- применяет CPU-отсечение против viewport окна.

local Util = require(script.Parent.Util)
local Vector2_new = Vector2.new

local DrawList = {}

export type DrawCommand = {
	-- тип примитива
	kind: string,
	-- область отсечения в абсолютных координатах экрана. nil = не отсекать.
	clipRect: Util.Rect?,
	-- payload
	p0: Vector2?,
	p1: Vector2?,
	p2: Vector2?,
	center: Vector2?,
	radius: number?,
	size: Vector2?,
	rounding: number?,
	color: Color3,
	thickness: number,
	filled: boolean,
	text: string?,
	font: Enum.Font?,
	textSize: number?,
}

export type DrawList = {
	commands: { DrawCommand },
	_clipStack: { Util.Rect },
	_activeClip: Util.Rect?,
}

function DrawList.new(): DrawList
	local self = {
		commands = {},
		_clipStack = {},
		_activeClip = nil,
	}
	setmetatable(self, { __index = DrawList })
	return self
end

function DrawList.Clear(self: DrawList)
	table.clear(self.commands)
	self._clipStack = {}
	self._activeClip = nil
end

-- ============================================================
-- Clip stack — нужен, чтобы виджеты вложенные в BeginChild
-- не вылезали за границы. MVP: просто Push/Pop.
-- ============================================================

function DrawList.PushClipRect(self: DrawList, rect: Util.Rect)
	self._clipStack[#self._clipStack + 1] = rect
	self._activeClip = rect
end

function DrawList.PopClipRect(self: DrawList)
	table.remove(self._clipStack)
	self._activeClip = self._clipStack[#self._clipStack]
end

-- ============================================================
-- Примитивы
-- ============================================================

function DrawList.AddLine(self: DrawList, p0: Vector2, p1: Vector2, color: Color3, thickness: number)
	self.commands[#self.commands + 1] = {
		kind = "Line",
		clipRect = self._activeClip,
		p0 = p0, p1 = p1,
		color = color,
		thickness = thickness or 1,
		filled = false,
	}
end

function DrawList.AddRect(self: DrawList, min: Vector2, max: Vector2, color: Color3, rounding: number?, thickness: number?)
	self.commands[#self.commands + 1] = {
		kind = "Rect",
		clipRect = self._activeClip,
		p0 = min, p1 = max,
		rounding = rounding or 0,
		color = color,
		thickness = thickness or 1,
		filled = false,
	}
end

function DrawList.AddRectFilled(self: DrawList, min: Vector2, max: Vector2, color: Color3, rounding: number?)
	self.commands[#self.commands + 1] = {
		kind = "RectFilled",
		clipRect = self._activeClip,
		p0 = min, p1 = max,
		rounding = rounding or 0,
		color = color,
		thickness = 0,
		filled = true,
	}
end

function DrawList.AddTriangle(self: DrawList, p0: Vector2, p1: Vector2, p2: Vector2, color: Color3, thickness: number?)
	self.commands[#self.commands + 1] = {
		kind = "Triangle",
		clipRect = self._activeClip,
		p0 = p0, p1 = p1, p2 = p2,
		color = color,
		thickness = thickness or 1,
		filled = false,
	}
end

function DrawList.AddTriangleFilled(self: DrawList, p0: Vector2, p1: Vector2, p2: Vector2, color: Color3)
	self.commands[#self.commands + 1] = {
		kind = "TriangleFilled",
		clipRect = self._activeClip,
		p0 = p0, p1 = p1, p2 = p2,
		color = color,
		thickness = 0,
		filled = true,
	}
end

function DrawList.AddCircle(self: DrawList, center: Vector2, radius: number, color: Color3, thickness: number?, _numSides: number?)
	-- _numSides сейчас не используется (Drawing рисует круг)
	self.commands[#self.commands + 1] = {
		kind = "Circle",
		clipRect = self._activeClip,
		center = center,
		radius = radius,
		color = color,
		thickness = thickness or 1,
		filled = false,
	}
end

function DrawList.AddCircleFilled(self: DrawList, center: Vector2, radius: number, color: Color3)
	self.commands[#self.commands + 1] = {
		kind = "CircleFilled",
		clipRect = self._activeClip,
		center = center,
		radius = radius,
		color = color,
		thickness = 0,
		filled = true,
	}
end

function DrawList.AddText(self: DrawList, pos: Vector2, color: Color3, text: string, font: Enum.Font?, textSize: number?)
	self.commands[#self.commands + 1] = {
		kind = "Text",
		clipRect = self._activeClip,
		p0 = pos,
		text = text,
		font = font or Enum.Font.Code,
		textSize = textSize or 14,
		color = color,
		thickness = 0,
		filled = false,
	}
end

-- ============================================================
-- Замер текста. Используем скрытый Drawing.Text для точности.
-- TextService:GetTextSize() НЕ совпадает с Drawing API —
-- используем TextBounds реального Drawing-объекта.
-- ============================================================

local FONT_SIMPLE = {}

do
	local MAP = {
		{ "Code", 3 }, { "CodeBold", 3 },
		{ "Gotham", 0 }, { "GothamBold", 0 }, { "GothamMedium", 0 }, { "GothamBlack", 0 },
		{ "Arial", 0 }, { "ArialBold", 0 }, { "UI", 0 },
		{ "Plex", 2 }, { "RobotoMono", 3 }, { "SourceSans", 2 },
		{ "SourceSansBold", 2 }, { "SourceSansLight", 2 }, { "SourceSansPro", 2 },
		{ "Highway", 1 }, { "Cartoon", 1 }, { "Legacy", 1 },
		{ "Bangers", 1 }, { "Creepster", 1 }, { "DenkOne", 1 },
		{ "PatrickHand", 1 }, { "PermanentMarker", 1 }, { "LuckiestGuy", 1 },
		{ "Fondamento", 2 }, { "Kalam", 2 }, { "Merriweather", 2 },
		{ "Spectral", 2 }, { "TitilliumWeb", 2 }, { "ZillaSlab", 2 },
		{ "Nunito", 0 }, { "Montserrat", 0 }, { "MontserratBold", 0 },
		{ "Baloo", 0 }, { "FredokaOne", 0 }, { "Jura", 0 }, { "Michroma", 0 },
		{ "Oswald", 2 }, { "Roboto", 0 }, { "RobotoBold", 0 },
		{ "RobotoLight", 0 }, { "RobotoMedium", 0 }, { "RobotoSlab", 2 },
	}
	for _, entry in ipairs(MAP) do
		local ok, font = pcall(function() return Enum.Font[entry[1]] end)
		if ok and font then
			FONT_SIMPLE[font] = entry[2]
		end
	end
end

-- Скрытый объект для замера текста (создаётся один раз)
local _textMeasurer = nil

local function ensureMeasurer()
	if _textMeasurer then return end
	local ok, obj = pcall(Drawing.new, "Text")
	if ok and type(obj) == "table" then
		pcall(function() obj.Visible = false end)
		_textMeasurer = obj
	end
end

local function measureText(text: string, font: Enum.Font, size: number): Vector2
	ensureMeasurer()
	if _textMeasurer then
		local num = FONT_SIMPLE[font]
		if not num then num = 0 end
		pcall(function()
			_textMeasurer.Text = text
			_textMeasurer.Size = size
			_textMeasurer.Font = num
			_textMeasurer.Position = Vector2_new(9999, 9999)
			_textMeasurer.Visible = true
		end)
		local b = _textMeasurer.TextBounds
		pcall(function() _textMeasurer.Visible = false end)
		if b and b.X > 0 then
			return Vector2_new(math.ceil(b.X), math.ceil(b.Y))
		end
	end
	-- Fallback — TextService
	local ok, bounds = pcall(function()
		return game:GetService("TextService"):GetTextSize(text, size, font, Vector2.new(math.huge, math.huge))
	end)
	if ok and bounds then return bounds end
	return Vector2_new(#text * size * 0.6, size)
end

-- Публичный хелпер
function DrawList.CalcTextSize(_: DrawList, text: string, font: Enum.Font?, size: number?): Vector2
	return measureText(text, font or Enum.Font.Code, size or 14)
end

return DrawList
