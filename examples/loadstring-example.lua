-- loadstring-example.lua — пример загрузки ImGui-rework через raw GitHub URL.

local IMGUI_URL = "https://raw.githubusercontent.com/Whysuk1me/ImGui-rework/main/dist/ImGui.lua"

-- ============================================================
-- HTTP-загрузчик с перебором бэкендов (разные эксплойты = разные API)
-- ============================================================
local function fetch(url)
	-- 1. game:HttpGet(url) — самый распространённый
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and type(res) == "string" and #res > 0 then return res end

	-- 2. game:HttpGetAsync(url)
	if game.HttpGetAsync then
		ok, res = pcall(function() return game:HttpGetAsync(url) end)
		if ok and type(res) == "string" and #res > 0 then return res end
	end

	-- 3. request({url=..., method="GET"}) — современный API
	local req = request or http_request
	if req then
		ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
		if ok and res and type(res.Body) == "string" and #res.Body > 0 then return res.Body end
		if ok and type(res) == "string" and #res > 0 then return res end
	end

	-- 4. syn.request — Synapse
	if syn and syn.request then
		ok, res = pcall(function() return syn.request({ Url = url, Method = "GET" }) end)
		if ok and res and type(res.Body) == "string" and #res.Body > 0 then return res.Body end
	end

	-- 5. http_get глобальная
	if http_get then
		ok, res = pcall(function() return http_get(url) end)
		if ok and type(res) == "string" and #res > 0 then return res end
	end

	return nil, "no http backend returned data"
end

-- Диагностика: какие функции вообще существуют в окружении
local function dumpHttpBackends()
	local found = {}
	if game.HttpGet then table.insert(found, "game:HttpGet") end
	if game.HttpGetAsync then table.insert(found, "game:HttpGetAsync") end
	if request then table.insert(found, "request") end
	if http_request then table.insert(found, "http_request") end
	if syn and syn.request then table.insert(found, "syn.request") end
	if http_get then table.insert(found, "http_get") end
	if #found == 0 then table.insert(found, "(ничего не найдено)") end
	warn("[ImGui-rework] доступные HTTP-бэкенды: " .. table.concat(found, ", "))
end

-- ============================================================
-- 1. Скачиваем исходник
-- ============================================================
local source, fetchErr = fetch(IMGUI_URL)
if not source then
	warn("[ImGui-rework] не удалось скачать бандл: " .. tostring(fetchErr))
	dumpHttpBackends()
	return
end

-- 2. Проверяем, что это реально Lua (а не 404-страница GitHub).
if #source < 100 or not source:find("Virtual module loader", 1, true) then
	warn("[ImGui-rework] HttpGet вернул не код ImGui. Первые 300 байт:")
	warn(source:sub(1, 300))
	return
end

-- 3. Компилируем.
local fn, parseErr = loadstring(source)
if not fn then
	warn("[ImGui-rework] loadstring не смог скомпилировать бандл:")
	warn(tostring(parseErr))
	return
end

-- 4. Выполняем.
local ok, result = pcall(fn)
if not ok or type(result) ~= "table" then
	warn("[ImGui-rework] запуск бандла упал:")
	warn(tostring(result))
	return
end

local ImGui = result

-- 5. Инициализация.
local initOk, initErr = pcall(ImGui.Init)
if not initOk then
	warn("[ImGui-rework] ImGui.Init упал:")
	warn(tostring(initErr))
	return
end

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local clickCount = 0
local checkboxState = { value = false }
local conn

conn = RunService.RenderStepped:Connect(function()
	local ok2, err2 = pcall(function()
		ImGui.BeginFrame()

		ImGui.Begin("ImGui-rework", {
			pos = Vector2.new(100, 100),
			size = Vector2.new(320, 240),
		})

		ImGui.Text("Loaded via loadstring + HttpGet")
		ImGui.Separator()

		if ImGui.Button("Press me") then
			clickCount += 1
		end

		ImGui.SameLine()
		ImGui.Text("count: " .. tostring(clickCount))

		ImGui.Checkbox("Enable feature", checkboxState)
		ImGui.Text("feature: " .. (checkboxState.value and "ON" or "OFF"))

		ImGui.Separator()
		ImGui.Text("RightShift to unload")

		ImGui.End()

		ImGui.EndFrame()
	end)
	if not ok2 then
		warn("[ImGui-rework] frame error: " .. tostring(err2))
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		conn:Disconnect()
		ImGui.Destroy()
		print("[ImGui-rework] unloaded")
	end
end)

print("[ImGui-rework] loaded via loadstring. Press RightShift to unload.")
