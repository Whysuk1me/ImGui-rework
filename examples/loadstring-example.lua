-- loadstring-example.lua — минимальный тест: одна кнопка + текст.
-- Если это работает — значит движок рабочий.

local IMGUI_URL = "https://raw.githubusercontent.com/Whysuk1me/ImGui-rework/main/dist/ImGui.lua"

local function fetch(url)
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and type(res) == "string" and #res > 0 then return res end
	local req = request or http_request
	if req then
		ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
		if ok and res and type(res) == "string" and #res > 0 then return res end
		if ok and res and type(res.Body) == "string" and #res.Body > 0 then return res.Body end
	end
	return nil, "no http"
end

-- 1. Скачать
local source, fetchErr = fetch(IMGUI_URL)
if not source then
	warn("[ImGui] fetch failed: " .. tostring(fetchErr))
	return
end
print("[ImGui] downloaded " .. #source .. " bytes")

-- 2. Компиляция
local fn, parseErr = loadstring(source)
if not fn then
	warn("[ImGui] compile failed: " .. tostring(parseErr))
	return
end
print("[ImGui] compiled OK")

-- 3. Запуск
local ok, result = pcall(fn)
if not ok or type(result) ~= "table" then
	warn("[ImGui] run failed: " .. tostring(result))
	return
end
local ImGui = result
print("[ImGui] module loaded")

-- 4. Init
local initOk, initErr = pcall(ImGui.Init)
if not initOk then
	warn("[ImGui] Init failed: " .. tostring(initErr))
	return
end
print("[ImGui] Init OK")

-- 5. Main loop — одна кнопка + текст
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local clicks = 0
local loaded = true
local conn

conn = RunService.RenderStepped:Connect(function()
	if not loaded then return end
	local ok2, err2 = pcall(function()
		ImGui.BeginFrame()

		ImGui.Begin("Test", {
			pos = Vector2.new(100, 100),
			size = Vector2.new(220, 100),
		})

		if ImGui.Button("Click me") then
			clicks += 1
		end

		ImGui.Text("Clicks: " .. tostring(clicks))

		ImGui.End()
		ImGui.EndFrame()
	end)
	if not ok2 then
		warn("[ImGui] frame error: " .. tostring(err2))
		loaded = false
		if conn then conn:Disconnect() end
		pcall(ImGui.Destroy)
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.RightShift then
		loaded = false
		if conn then conn:Disconnect() end
		pcall(ImGui.Destroy)
		print("[ImGui] unloaded")
	end
end)

print("[ImGui] running. RightShift to unload.")
