-- autoexec.lua — standalone-точка входа для инжектора.
-- Вставляется в autoexec эксплойта или выполняется через скрипт-инжектор.
-- require'ит главный модуль ImGui и запускает demo.

-- Когда запускается через autoexec, script.Parent может быть nil.
-- Проверяем разные варианты загрузки.

local function loadImGui()
	-- Вариант 1: скрипт в autoexec, ImGui-rework лежит в workspace
	local ok, ImGui = pcall(function()
		return require(game:GetService("ReplicatedStorage").ImGui)
	end)
	if ok then return ImGui end

	-- Вариант 2: скрипт в workspace.ImGui-rework
	ok, ImGui = pcall(function()
		return require(script.Parent.src.ImGui)
	end)
	if ok then return ImGui end

	-- Вариант 3: путь задан через getgenv().IMGUI_PATH
	ok, ImGui = pcall(function()
		return require(getgenv().IMGUI_PATH)
	end)
	if ok then return ImGui end

	error("ImGui-rework: не удалось найти модуль. Укажите путь через getgenv().IMGUI_PATH = <Instance>")
end

local ImGui = loadImGui()
ImGui.Init()

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local checkboxState = { value = false }
local clickCount = 0
local conn

conn = RunService.RenderStepped:Connect(function()
	ImGui.BeginFrame()

	ImGui.Begin("ImGui-rework", {
		pos = Vector2.new(100, 100),
		size = Vector2.new(320, 240),
	})

	ImGui.Text("Standalone autoexec demo")
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

print("[ImGui-rework] loaded. Press RightShift to unload.")
