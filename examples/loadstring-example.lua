-- loadstring-example.lua — пример загрузки ImGui-rework через raw GitHub URL.
-- Работает в любом эксплойте, поддерживающем game:HttpGet и loadstring.

local IMGUI_URL = "https://raw.githubusercontent.com/Whysuk1me/ImGui-rework/main/dist/ImGui.lua"

-- 1. Скачиваем исходник.
local src, httpErr = pcall(function()
	return game:HttpGet(IMGUI_URL)
end)
if not src or type(httpErr) ~= "string" then
	warn("[ImGui-rework] HttpGet failed: " .. tostring(httpErr))
	return
end
local source = httpErr -- строка с Lua-кодом

-- 2. Проверяем, что это реально Lua (а не 404-страница GitHub).
if #source < 100 or not source:find("Virtual module loader", 1, true) then
	warn("[ImGui-rework] HttpGet вернул не код ImGui. Первые 200 байт:")
	warn(source:sub(1, 200))
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
