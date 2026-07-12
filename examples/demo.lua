-- demo.lua — пример использования ImGui-rework.
-- Показывает окно с кнопкой, чекбоксом и сепаратором.

local ImGui = require(script.Parent.Parent.src.ImGui)

ImGui.Init()

local RunService = game:GetService("RunService")
local checkboxState = { value = false }
local clickCount = 0

local conn
conn = RunService.RenderStepped:Connect(function()
	ImGui.BeginFrame()

	ImGui.Begin("Demo Window", {
		pos = Vector2.new(100, 100),
		size = Vector2.new(300, 220),
	})

	ImGui.Text("Hello from ImGui-rework!")
	ImGui.Separator()

	if ImGui.Button("Click me") then
		clickCount += 1
		print("Button clicked! Count:", clickCount)
	end

	ImGui.SameLine()
	ImGui.Text("clicks: " .. tostring(clickCount))

	ImGui.Checkbox("Toggle feature", checkboxState)
	ImGui.Text("feature is " .. (checkboxState.value and "ON" or "OFF"))

	ImGui.Separator()
	ImGui.Text("Window is draggable by title bar.")
	ImGui.Text("Resize via bottom-right corner.")

	ImGui.End()

	ImGui.EndFrame()
end)

-- Остановка по нажатию RightShift
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		conn:Disconnect()
		ImGui.Destroy()
		print("ImGui demo destroyed")
	end
end)
