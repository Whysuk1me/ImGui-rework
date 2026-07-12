-- loadstring-example.lua — пример загрузки ImGui-rework через raw GitHub URL.
-- Работает в любом эксплойте, поддерживающем game:HttpGet и loadstring.

-- 1. Укажи raw URL к собранному бандлу на GitHub.
--    Формат: https://raw.githubusercontent.com/<user>/<repo>/<branch>/dist/ImGui.lua
local IMGUI_URL = "https://raw.githubusercontent.com/Whysuk1me/ImGui-rework/main/dist/ImGui.lua"

-- 2. Загружаем код через HttpGet и выполняем через loadstring.
--    loadstring возвращает функцию, вызов которой возвращает модуль ImGui.
local ImGui = loadstring(game:HttpGet(IMGUI_URL))()

-- 3. Инициализация.
ImGui.Init()

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local clickCount = 0
local checkboxState = { value = false }
local conn

conn = RunService.RenderStepped:Connect(function()
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

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		conn:Disconnect()
		ImGui.Destroy()
		print("[ImGui-rework] unloaded")
	end
end)

print("[ImGui-rework] loaded via loadstring. Press RightShift to unload.")
