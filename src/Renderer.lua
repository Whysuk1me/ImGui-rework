--!strict
-- Renderer.lua — материализация DrawList в Drawing-объекты.
--
-- Каждый кадр Core передаёт нам DrawList. Мы:
--   1. Идём по командам последовательно.
--   2. Берём объект из пула по индексу (или создаём новый).
--   3. Обновляем свойства объекта под команду.
--   4. Скрываем лишние объекты (если в этом кадре их меньше, чем в прошлом).
--
-- Никакого батчинга в Drawing API нет — каждый объект = отдельный
-- инстанс Drawing.new. Поэтому пул критичен для производительности.

local Util = require(script.Parent.Util)
local DrawList = require(script.Parent.DrawList)

local Renderer = {}

export type RenderPool = {
	-- Пулы по типам: Line, Rect, RectFilled, Triangle, TriangleFilled,
	-- Circle, CircleFilled, Text
	Line: { any },
	Rect: { any },
	RectFilled: { any },
	Triangle: { any },
	TriangleFilled: { any },
	Circle: { any },
	CircleFilled: { any },
	Text: { any },

	-- Счётчики использованных объектов в текущем кадре
	_used: { [string]: number },
}

-- Безопасное создание Drawing-объекта. Не все эксплойты
-- предоставляют одинаковое API.
local function newDrawing(kind: string): any
	local ok, obj = pcall(Drawing.new, kind)
	if not ok or not obj then
		error("Renderer: Drawing.new(\"" .. kind .. "\") failed — Drawing API unavailable")
	end
	obj.Visible = false
	return obj
end

function Renderer.new(): RenderPool
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

-- Получить объект из пула (или создать). Все пулы растут по необходимости.
local function getOrCreate(pool: { any }, kind: string, idx: number): any
	local obj = pool[idx]
	if not obj then
		obj = newDrawing(kind)
		pool[idx] = obj
	end
	return obj
end

-- Скрывает неиспользуемые объекты в пуле начиная с индекса fromIdx
local function hideTail(pool: { any }, fromIdx: number)
	for i = fromIdx, #pool do
		local obj = pool[i]
		if obj and obj.Visible then
			obj.Visible = false
		end
	end
end

-- ============================================================
-- Главная точка входа: отрисовать DrawList
-- ============================================================

function Renderer.Render(self: RenderPool, drawList: DrawList.DrawList)
	-- Сбросить счётчики использованных
	self._used = {}

	local cmds = drawList.commands
	for i = 1, #cmds do
		local cmd = cmds[i]
		local used = self._used[cmd.kind] or 0
		used = used + 1
		self._used[cmd.kind] = used

		-- CPU-clip: пропускаем команды, не входящие в clipRect.
		-- Для Text мы всё равно создаём/обновляем, но ставим Visible=false
		-- (иначе риски протечки в эксплойтах с прокси-объектами).
		local clip = cmd.clipRect

		if cmd.kind == "Line" then
			self:_renderLine(used, cmd, clip)
		elseif cmd.kind == "Rect" then
			self:_renderRect(used, cmd, clip)
		elseif cmd.kind == "RectFilled" then
			self:_renderRectFilled(used, cmd, clip)
		elseif cmd.kind == "Triangle" then
			self:_renderTriangle(used, cmd, clip)
		elseif cmd.kind == "TriangleFilled" then
			self:_renderTriangleFilled(used, cmd, clip)
		elseif cmd.kind == "Circle" then
			self:_renderCircle(used, cmd, clip)
		elseif cmd.kind == "CircleFilled" then
			self:_renderCircleFilled(used, cmd, clip)
		elseif cmd.kind == "Text" then
			self:_renderText(used, cmd, clip)
		end
	end

	-- Скрыть хвосты во всех пулах
	hideTail(self.Line,        (self._used.Line or 0) + 1)
	hideTail(self.Rect,        (self._used.Rect or 0) + 1)
	hideTail(self.RectFilled,  (self._used.RectFilled or 0) + 1)
	hideTail(self.Triangle,    (self._used.Triangle or 0) + 1)
	hideTail(self.TriangleFilled, (self._used.TriangleFilled or 0) + 1)
	hideTail(self.Circle,      (self._used.Circle or 0) + 1)
	hideTail(self.CircleFilled,(self._used.CircleFilled or 0) + 1)
	hideTail(self.Text,        (self._used.Text or 0) + 1)
end

-- ============================================================
-- Вспомогательные функции для каждого типа примитива
-- ============================================================

function Renderer._renderLine(self: RenderPool, idx: number, cmd: any, clip: any)
	local obj = getOrCreate(self.Line, "Line", idx)
	if not cmd.p0 or not cmd.p1 then obj.Visible = false; return end

	local p0, p1 = cmd.p0, cmd.p1
	if clip then
		p0, p1 = Util.RectClipLine(clip, p0, p1)
	end

	obj.From = p0
	obj.To = p1
	obj.Color = cmd.color
	obj.Thickness = cmd.thickness
	obj.Visible = true
end

function Renderer._renderRect(self: RenderPool, idx: number, cmd: any, clip: any)
	local obj = getOrCreate(self.Rect, "Square", idx)
	if not cmd.p0 or not cmd.p1 then obj.Visible = false; return end

	local p0, p1 = cmd.p0, cmd.p1
	if clip then
		local clipped = Util.RectClip(
			{ min = p0, max = p1 },
			clip
		)
		if not clipped then obj.Visible = false; return end
		p0, p1 = clipped.min, clipped.max
	end

	obj.Position = p0
	obj.Size = Vector2.new(p1.X - p0.X, p1.Y - p0.Y)
	obj.Color = cmd.color
	obj.Thickness = cmd.thickness
	obj.Filled = false
	obj.Visible = true
end

function Renderer._renderRectFilled(self: RenderPool, idx: number, cmd: any, clip: any)
	local obj = getOrCreate(self.RectFilled, "Square", idx)
	if not cmd.p0 or not cmd.p1 then obj.Visible = false; return end

	local p0, p1 = cmd.p0, cmd.p1
	if clip then
		local clipped = Util.RectClip(
			{ min = p0, max = p1 },
			clip
		)
		if not clipped then obj.Visible = false; return end
		p0, p1 = clipped.min, clipped.max
	end

	obj.Position = p0
	obj.Size = Vector2.new(p1.X - p0.X, p1.Y - p0.Y)
	obj.Color = cmd.color
	obj.Filled = true
	obj.Thickness = 0
	obj.Visible = true
end

function Renderer._renderTriangle(self: RenderPool, idx: number, cmd: any, clip: any)
	-- Drawing API не имеет примитива "треугольник" напрямую.
	-- Раскладываем на 3 линии.
	if not cmd.p0 or not cmd.p1 or not cmd.p2 then return end
	local pts = { cmd.p0, cmd.p1, cmd.p2 }
	for i = 1, 3 do
		local lineIdx = (idx - 1) * 3 + i
		local obj = getOrCreate(self.Triangle, "Line", lineIdx)
		local a, b = pts[i], pts[(i % 3) + 1]
		if clip then
			a, b = Util.RectClipLine(clip, a, b)
		end
		obj.From = a
		obj.To = b
		obj.Color = cmd.color
		obj.Thickness = cmd.thickness
		obj.Visible = true
	end
	-- Скрыть лишние, если было больше линий, чем сейчас
	local used = (self._used.Triangle or 0) * 3
	for i = used + 1, #self.Triangle do
		local obj = self.Triangle[i]
		if obj and obj.Visible then obj.Visible = false end
	end
end

function Renderer._renderTriangleFilled(self: RenderPool, idx: number, cmd: any, clip: any)
	if not cmd.p0 or not cmd.p1 or not cmd.p2 then return end
	-- Рисуем через Quad (Square) как fallback. MVP: пропускаем clip для triangle.
	local obj = getOrCreate(self.TriangleFilled, "Square", idx)
	-- Bounding box
	local minX = math.min(cmd.p0.X, cmd.p1.X, cmd.p2.X)
	local minY = math.min(cmd.p0.Y, cmd.p1.Y, cmd.p2.Y)
	local maxX = math.max(cmd.p0.X, cmd.p1.X, cmd.p2.X)
	local maxY = math.max(cmd.p0.Y, cmd.p1.Y, cmd.p2.Y)
	obj.Position = Vector2.new(minX, minY)
	obj.Size = Vector2.new(maxX - minX, maxY - minY)
	obj.Color = cmd.color
	obj.Filled = true
	obj.Visible = true
end

function Renderer._renderCircle(self: RenderPool, idx: number, cmd: any, clip: any)
	local obj = getOrCreate(self.Circle, "Circle", idx)
	if not cmd.center then obj.Visible = false; return end

	obj.Position = cmd.center
	obj.Radius = cmd.radius
	obj.Color = cmd.color
	obj.Thickness = cmd.thickness
	obj.Filled = false
	obj.NumSides = 30
	obj.Visible = true
end

function Renderer._renderCircleFilled(self: RenderPool, idx: number, cmd: any, clip: any)
	local obj = getOrCreate(self.CircleFilled, "Circle", idx)
	if not cmd.center then obj.Visible = false; return end

	obj.Position = cmd.center
	obj.Radius = cmd.radius
	obj.Color = cmd.color
	obj.Filled = true
	obj.Thickness = 0
	obj.NumSides = 30
	obj.Visible = true
end

function Renderer._renderText(self: RenderPool, idx: number, cmd: any, clip: any)
	local obj = getOrCreate(self.Text, "Text", idx)
	if not cmd.p0 or not cmd.text then obj.Visible = false; return end

	obj.Position = cmd.p0
	obj.Text = cmd.text
	obj.Color = cmd.color
	obj.Size = cmd.textSize or 14
	obj.Font = Renderer._fontToNumber(cmd.font)
	obj.Center = false
	obj.Outline = false
	obj.Visible = true

	-- Clip для текста — пока простой: скрываем если центр за пределами.
	-- Правильная реализация потребует TextBounds-aware проверки, оставим на следующий шаг.
end

-- Конвертация Enum.Font в число, которое ждёт Drawing API.
-- Drawing API Font: 0=UI, 1=System, 2=Plex, 3=Monospace, 4=Arial, 5=Highway,
-- 6=SourceSans, 7=SourceSansBold
--
-- Важно: не все Enum.Font значения существуют во всех версиях Roblox/эксплойтов.
-- Доступ к Enum.Font.UI при отсутствии члена бросает ошибку, поэтому
-- ищем шрифт по имени строки ВНУТРИ pcall.
local FONT_MAP: { [any]: number } = {}

-- Пары {имя, номер}. Имя ищется через Enum.Font[name] внутри pcall.
local FONT_NAMES: { [number]: { string, number } } = {
	{ "UI", 0 },
	{ "System", 1 },
	{ "Plex", 2 },
	{ "Monospace", 3 },
	{ "Arial", 4 },
	{ "ArialBold", 4 },
	{ "Highway", 5 },
	{ "SourceSans", 6 },
	{ "SourceSansBold", 7 },
	{ "Code", 3 },
	{ "Roboto", 6 },
	{ "RobotoMono", 3 },
	{ "Gotham", 6 },
	{ "GothamMedium", 6 },
	{ "GothamBold", 7 },
	{ "GothamBlack", 7 },
	{ "Montserrat", 6 },
	{ "MontserratBold", 7 },
	{ "Baloo", 6 },
	{ "BalooBold", 7 },
	{ "Bangers", 6 },
	{ "Creepster", 6 },
	{ "DenkOne", 6 },
	{ "Fondamento", 6 },
	{ "FredokaOne", 6 },
	{ "Jura", 6 },
	{ "JuraBold", 7 },
	{ "Kalam", 6 },
	{ "LuckiestGuy", 6 },
	{ "Merriweather", 6 },
	{ "Michroma", 6 },
	{ "Nunito", 6 },
	{ "Oswald", 6 },
	{ "OswaldBold", 7 },
	{ "PatrickHand", 6 },
	{ "PermanentMarker", 6 },
	{ "RobotoCondensed", 6 },
	{ "RobotoCondensedBold", 7 },
	{ "Spectral", 6 },
	{ "SpectralBold", 7 },
	{ "TitilliumWeb", 6 },
	{ "TitilliumWebBold", 7 },
	{ "ZillaSlab", 6 },
	{ "ZillaSlabBold", 7 },
}

local function buildFontMap()
	for i = 1, #FONT_NAMES do
		local entry = FONT_NAMES[i]
		local name, num = entry[1], entry[2]
		local ok, font = pcall(function()
			return Enum.Font[name]
		end)
		if ok and font then
			FONT_MAP[font] = num
		end
	end
end

buildFontMap()

function Renderer._fontToNumber(font: any): number
	if type(font) == "number" then return font end
	if not font then return 0 end
	local n = FONT_MAP[font]
	if n then return n end
	-- Fallback: EnumItem.Value
	local ok, v = pcall(function()
		return font.Value
	end)
	if ok and type(v) == "number" then return v end
	return 0
end

-- ============================================================
-- Destroy — освободить все Drawing-объекты
-- ============================================================

function Renderer.Destroy(self: RenderPool)
	for _, pool in ipairs({
		self.Line, self.Rect, self.RectFilled,
		self.Triangle, self.TriangleFilled,
		self.Circle, self.CircleFilled, self.Text,
	}) do
		for i = 1, #pool do
			local obj = pool[i]
			if obj then
				pcall(function()
					obj:Remove()
				end)
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
