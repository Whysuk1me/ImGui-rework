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

local FONT_SIMPLE = {
	[Enum.Font.Code] = 3,
	[Enum.Font.Gotham] = 0,
	[Enum.Font.GothamBold] = 0,
	[Enum.Font.GothamMedium] = 0,
	[Enum.Font.GothamBlack] = 0,
	[Enum.Font.Arial] = 0,
	[Enum.Font.ArialBold] = 0,
	[Enum.Font.UI] = 0,
	[Enum.Font.Plex] = 2,
	[Enum.Font.RobotoMono] = 3,
	[Enum.Font.Code] = 3,
	[Enum.Font.CodeBold] = 3,
	[Enum.Font.Highway] = 1,
	[Enum.Font.Cartoon] = 1,
	[Enum.Font.Legacy] = 1,
	[Enum.Font.SourceSans] = 2,
	[Enum.Font.SourceSansBold] = 2,
	[Enum.Font.SourceSansLight] = 2,
	[Enum.Font.SourceSansPro] = 2,
	[Enum.Font.Nunito] = 0,
	[Enum.Font.Montserrat] = 0,
	[Enum.Font.MontserratBold] = 0,
	[Enum.Font.Baloo] = 0,
	[Enum.Font.Bangers] = 1,
	[Enum.Font.Creepster] = 1,
	[Enum.Font.DenkOne] = 1,
	[Enum.Font.Fondamento] = 2,
	[Enum.Font.FredokaOne] = 0,
	[Enum.Font.Jura] = 0,
	[Enum.Font.Kalam] = 2,
	[Enum.Font.LuckiestGuy] = 1,
	[Enum.Font.Merriweather] = 2,
	[Enum.Font.Michroma] = 0,
	[Enum.Font.Oswald] = 2,
	[Enum.Font.PatrickHand] = 1,
	[Enum.Font.PermanentMarker] = 1,
	[Enum.Font.Spectral] = 2,
	[Enum.Font.TitilliumWeb] = 2,
	[Enum.Font.ZillaSlab] = 2,
	[Enum.Font.Roboto] = 0,
	[Enum.Font.RobotoBold] = 0,
	[Enum.Font.RobotoLight] = 0,
	[Enum.Font.RobotoMedium] = 0,
	[Enum.Font.RobotoSlab] = 2,
}

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
		end)
		local b = _textMeasurer.TextBounds
		return Vector2_new(math.ceil(b.X), math.ceil(b.Y))
	end
	-- Fallback — TextService (если Drawing недоступен)
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
