--!strict
-- Util.lua — низкоуровневые хелперы.
-- Math, Rect-операции, FNV1a-хеш (для ID виджетов), создание Vector2.

local Util = {}

-- ============================================================
-- Vector2 / конструкторы
-- ============================================================

local Vector2_new = Vector2.new

function Util.V2(x: number, y: number): Vector2
	return Vector2_new(x, y)
end

function Util.V2Zero(): Vector2
	return Vector2_new(0, 0)
end

-- ============================================================
-- Математика
-- ============================================================

function Util.Clamp(v: number, lo: number, hi: number): number
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function Util.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.Min(a: number, b: number): number
	return a < b and a or b
end

function Util.Max(a: number, b: number): number
	return a > b and a or b
end

function Util.Abs(v: number): number
	return v < 0 and -v or v
end

-- ============================================================
-- Rect — пара Vector2 (min, max). Все hit-test'ы на CPU.
-- ============================================================

export type Rect = { min: Vector2, max: Vector2 }

function Util.Rect(x: number, y: number, w: number, h: number): Rect
	return { min = Vector2_new(x, y), max = Vector2_new(x + w, y + h) }
end

function Util.RectFromMinMax(min: Vector2, max: Vector2): Rect
	return { min = min, max = max }
end

function Util.RectContains(r: Rect, p: Vector2): boolean
	return p.X >= r.min.X and p.X <= r.max.X
		and p.Y >= r.min.Y and p.Y <= r.max.Y
end

function Util.RectContainsRect(outer: Rect, inner: Rect): boolean
	return outer.min.X <= inner.min.X and outer.min.Y <= inner.min.Y
		and outer.max.X >= inner.max.X and outer.max.Y >= inner.max.Y
end

function Util.RectOverlap(a: Rect, b: Rect): boolean
	return a.min.X < b.max.X and a.max.X > b.min.X
		and a.min.Y < b.max.Y and a.max.Y > b.min.Y
end

-- Обрезать `inner` по границам `outer`. Возвращает nil, если нет пересечения.
function Util.RectClip(inner: Rect, outer: Rect): Rect?
	local x0 = Util.Max(inner.min.X, outer.min.X)
	local y0 = Util.Max(inner.min.Y, outer.min.Y)
	local x1 = Util.Min(inner.max.X, outer.max.X)
	local y1 = Util.Min(inner.max.Y, outer.max.Y)
	if x1 <= x0 or y1 <= y0 then return nil end
	return { min = Vector2_new(x0, y0), max = Vector2_new(x1, y1) }
end

function Util.RectWidth(r: Rect): number
	return r.max.X - r.min.X
end

function Util.RectHeight(r: Rect): number
	return r.max.Y - r.min.Y
end

function Util.RectSize(r: Rect): Vector2
	return Vector2_new(r.max.X - r.min.X, r.max.Y - r.min.Y)
end

-- Пересечение отрезка [p0,p1] с осью-aligned прямоугольником.
-- Возвращает обрезанные точки (или исходные, если не пересекает).
function Util.RectClipLine(r: Rect, p0: Vector2, p1: Vector2): (Vector2, Vector2)
	-- Cohen-Sutherland
	local function outcode(p: Vector2): number
		local code = 0
		if p.X < r.min.X then code = code + 1 end -- LEFT
		if p.X > r.max.X then code = code + 2 end -- RIGHT
		if p.Y < r.min.Y then code = code + 4 end -- TOP
		if p.Y > r.max.Y then code = code + 8 end -- BOTTOM
		return code
	end

	local c0, c1 = outcode(p0), outcode(p1)
	while true do
		if bit32.bor(c0, c1) == 0 then return p0, p1 end -- внутри
		if bit32.band(c0, c1) ~= 0 then
			-- снаружи: оставляем как есть — Renderer просто не нарисует
			return p0, p1
		end

		local dx = p1.X - p0.X
		local dy = p1.Y - p0.Y
		local codeOut = c0 ~= 0 and c0 or c1
		local x, y: number

		if bit32.band(codeOut, 8) ~= 0 then
			-- BOTTOM (y > max.Y)
			local t = (r.max.Y - p0.Y) / dy
			x, y = p0.X + t * dx, r.max.Y
		elseif bit32.band(codeOut, 4) ~= 0 then
			-- TOP
			local t = (r.min.Y - p0.Y) / dy
			x, y = p0.X + t * dx, r.min.Y
		elseif bit32.band(codeOut, 2) ~= 0 then
			-- RIGHT
			local t = (r.max.X - p0.X) / dx
			x, y = r.max.X, p0.Y + t * dy
		else
			-- LEFT
			local t = (r.min.X - p0.X) / dx
			x, y = r.min.X, p0.Y + t * dy
		end

		if codeOut == c0 then
			p0 = Vector2_new(x, y)
			c0 = outcode(p0)
		else
			p1 = Vector2_new(x, y)
			c1 = outcode(p1)
		end
	end
end

-- ============================================================
-- FNV1a-хеш — уникальный ImGuiID из строки.
-- ============================================================

local FNV_OFFSET = 2166136261
local FNV_PRIME  = 16777619

function Util.HashStr(s: string): number
	local h = FNV_OFFSET
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * FNV_PRIME) % 0x100000000
	end
	return h
end

-- Комбинировать два ID (для ID-стека)
function Util.HashCombine(a: number, b: number): number
	-- djb2-like combine
	local h = a
	h = bit32.bxor(h, b + 2654435761)
	h = (h * 1597334677) % 0x100000000
	return h
end

-- Преобразовать произвольный ключ виджета в стабильный ImGuiID.
-- Принимает string | number.
function Util.GetID(key: any): number
	if type(key) == "number" then return key end
	return Util.HashStr(tostring(key))
end

-- ============================================================
-- Прочее
-- ============================================================

function Util.TableCopy<T>(t: { T }): { T }
	local out = {}
	for i, v in ipairs(t) do out[i] = v end
	return out
end

return Util
