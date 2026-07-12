-- loadstring-example.lua — пример загрузки ImGui-rework через raw GitHub URL.

local IMGUI_URL = "https://raw.githubusercontent.com/Whysuk1me/ImGui-rework/main/dist/ImGui.lua"

-- ============================================================
-- HTTP-загрузчик с перебором бэкендов
-- ============================================================
local function fetch(url)
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and type(res) == "string" and #res > 0 then return res end

	if game.HttpGetAsync then
		ok, res = pcall(function() return game:HttpGetAsync(url) end)
		if ok and type(res) == "string" and #res > 0 then return res end
	end

	local req = request or http_request
	if req then
		ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
		if ok and res and type(res.Body) == "string" and #res.Body > 0 then return res.Body end
		if ok and type(res) == "string" and #res > 0 then return res end
	end

	if syn and syn.request then
		ok, res = pcall(function() return syn.request({ Url = url, Method = "GET" }) end)
		if ok and res and type(res.Body) == "string" and #res.Body > 0 then return res.Body end
	end

	if http_get then
		ok, res = pcall(function() return http_get(url) end)
		if ok and type(res) == "string" and #res > 0 then return res end
	end

	return nil, "no http backend returned data"
end

-- ============================================================
-- 1. Скачать
-- ============================================================
local source, fetchErr = fetch(IMGUI_URL)
if not source then
	warn("[ImGui-rework] не удалось скачать бандл: " .. tostring(fetchErr))
	return
end

if #source < 100 or not source:find("Virtual module loader", 1, true) then
	warn("[ImGui-rework] HttpGet вернул не код ImGui. Первые 300 байт:")
	warn(source:sub(1, 300))
	return
end

-- 2. Компиляция
local fn, parseErr = loadstring(source)
if not fn then
	warn("[ImGui-rework] loadstring не смог скомпилировать бандл:")
	warn(tostring(parseErr))
	return
end

-- 3. Запуск
local ok, result = pcall(fn)
if not ok or type(result) ~= "table" then
	warn("[ImGui-rework] запуск бандла упал:")
	warn(tostring(result))
	return
end

local ImGui = result

-- 4. Init
local initOk, initErr = pcall(ImGui.Init)
if not initOk then
	warn("[ImGui-rework] ImGui.Init упал:")
	warn(tostring(initErr))
	return
end

-- ============================================================
-- Main loop
-- ============================================================
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local clickCount = 0
local checkboxState = { value = false }
local checkboxState2 = { value = true }
local loaded = true
local conn

conn = RunService.RenderStepped:Connect(function()
	if not loaded then return end
	local ok2, err2 = pcall(function()
		ImGui.BeginFrame()

		ImGui.Begin("ImGui-rework", {
			pos = Vector2.new(100, 100),
			size = Vector2.new(340, 260),
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

		ImGui.Checkbox("Another option", checkboxState2)

		ImGui.Separator()
		ImGui.Text("Drag title bar to move")
		ImGui.Text("Drag corner to resize")
		ImGui.Text("RightShift to unload")

		ImGui.End()

		ImGui.EndFrame()
	end)
	if not ok2 then
		warn("[ImGui-rework] frame error: " .. tostring(err2))
	end
end)

-- Выгрузка по RightShift (без проверки gameProcessed)
UserInputService.InputBegan:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.RightShift then
		loaded = false
		if conn then conn:Disconnect() end
		pcall(ImGui.Destroy)
		print("[ImGui-rework] unloaded")
	end
end)

print("[ImGui-rework] loaded. Press RightShift to unload.")
