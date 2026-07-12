# ImGui-rework

Immediate-mode UI-фреймворк для Roblox поверх **Drawing API**. Реворк философии Dear ImGui под Luau.

> **Статус:** MVP. Базовое ядро + окно + Button/Text/Checkbox/Separator. Активно разрабатывается.

## Принцип

Каждый кадр ты в цикле вызываешь `Begin` / `End` и между ними описываешь виджеты. Библиотека сама управляет состоянием, инпутом и рендерингом. Никаких `Instance` / `ScreenGui` — всё рисуется через `Drawing.new(...)`.

```lua
local ImGui = require(path.ImGui)
ImGui.Init()

RunService.RenderStepped:Connect(function()
    ImGui.BeginFrame()

    ImGui.Begin("My Window", { pos = Vector2.new(100, 100), size = Vector2.new(300, 200) })
    ImGui.Text("hello world")
    if ImGui.Button("press me") then print("clicked") end
    local state = { value = false }
    ImGui.Checkbox("enable feature", state)
    ImGui.End()

    ImGui.EndFrame()
end)
```

## Архитектура

```
src/
├── ImGui.lua     — публичный API (фасад)
├── Core.lua       — глобальный контекст: BeginFrame/EndFrame
├── Util.lua       — FNV1a-хеш, Rect-операции, math-хелперы
├── IdStack.lua    — стек ID для уникальности виджетов
├── Style.lua      — цвета, отступы, размеры (dark theme)
├── Input.lua      — UserInputService (мышь, кнопки, колесо)
├── DrawList.lua   — список draw-команд с clip-стеком
├── Renderer.lua   — пул Drawing-объектов, материализация DrawList
├── Layout.lua     — auto-layout курсор, SameLine/Indent
├── Window.lua     — оконная система (drag, resize, focus)
└── Widgets.lua    — Button, Text, Checkbox, Separator, Spacing
```

### Поток кадра

```
1. ImGui.BeginFrame()           — сброс state, чтение инпута
2. ImGui.Begin("Main", opt)     — открыть окно, push clip
3.   ImGui.Text("hello")        — виджеты добавляют draw-команды
4.   if ImGui.Button("press")   — hit-test против mousePos
5. ImGui.End()                  — pop clip
6. ImGui.EndFrame()             — Renderer.Render(drawList) → Drawing
```

## Ключевые решения

| Что | Как |
|---|---|
| **Идентификация виджетов** | FNV1a-хеш строки + parent-stack → `ImGuiID` |
| **Input** | `UserInputService` (по умолчанию). Абстракция готова для хуков |
| **Рендер** | Каждый кадр: `BeginFrame()` → юзерский код → `EndFrame()` → Renderer обновляет пул Drawing-объектов |
| **Hit-testing** | CPU point-in-rect (Drawing клики не поддерживает) |
| **Clipping** | CPU-отсечение draw-команд по `clipRect` окна |
| **Focus / z-order** | `focusOrder` инкрементируется при клике на title bar |
| **Drag окон** | Tracking мыши в `InputChanged` + `dragOffset` |
| **Resize окон** | Grip в правом нижнем углу, `minSize` защита |

## Установка

### Способ 1: loadstring + raw GitHub URL (рекомендуется)

Самый простой способ — загрузить собранный бандл через `loadstring(game:HttpGet(...))`:

```lua
local URL = "https://raw.githubusercontent.com/Whysuk1me/ImGui-rework/main/dist/ImGui.lua"
local ImGui = loadstring(game:HttpGet(URL))()
ImGui.Init()
```

Бандл `dist/ImGui.lua` — один файл со всеми модулями внутри. Работает в любом эксплойте с `HttpGet` + `loadstring`. См. `examples/loadstring-example.lua`.

### Способ 2: ModuleScript (Studio / ReplicatedStorage)

1. Скопируй папку `src/` в `ReplicatedStorage.ImGui-rework` (как ModuleScript'ы).
2. В коде: `local ImGui = require(game.ReplicatedStorage.ImGui-rework.ImGui)`

### Способ 3: Autoexec (эксплойт)

1. Загрузи папку `src/` и `autoexec.lua` в workspace (или укажи путь через `getgenv().IMGUI_PATH = <Instance>`).
2. Выполни `autoexec.lua`.

### Сборка бандла (для разработчиков)

Если ты менял `src/*.lua` и хочешь пересобрать `dist/ImGui.lua`, запусти бандлер:

```powershell
# На Windows через PowerShell (без установки Lua):
pwsh scripts/bundler.ps1

# Или через Lua:
lua scripts/bundler.lua
```

Бандлер читает все `src/*.lua`, заменяет `require(script.Parent.X)` на виртуальный require и собирает один файл.

## API (MVP)

### Lifecycle
- `ImGui.Init()` — создать контекст, подписаться на input
- `ImGui.Destroy()` — освободить Drawing-объекты и отключить подключения
- `ImGui.BeginFrame()` / `ImGui.EndFrame()` — рамки кадра

### Window
- `ImGui.Begin(name, opt?) -> bool` — открыть окно. `opt: { pos, size, flags }`
- `ImGui.End()`

### Widgets
- `ImGui.Text(s)` — строка текста
- `ImGui.Button(label, size?) -> bool` — кнопка, возвращает true при клике
- `ImGui.Checkbox(label, value: { value: boolean }) -> bool` — чекбокс, мутирует `value.value`
- `ImGui.Separator()` — горизонтальная линия
- `ImGui.Spacing()` — пустой отступ
- `ImGui.SameLine(offsetX?, spacingW?)` — следующий виджет в той же строке
- `ImGui.Indent(w?)` / `ImGui.Unindent(w?)`

### Style
- `ImGui.GetStyle() -> ImGuiStyle`
- `ImGui.PushStyleColor(name, color: Color3)` — заменить цвет

## Roadmap

- [ ] SliderFloat / SliderInt
- [ ] ComboBox / DropDownList
- [ ] InputText
- [ ] TreeNode / CollapsingHeader
- [ ] TabBar / Tabs
- [ ] Scrollbar в окне (overflow content)
- [ ] Collapse button на title bar
- [ ] Color picker
- [ ] Графики (PlotLines, PlotHistogram)
- [ ] Multi-window focus order (z-order по focusOrder)
- [ ] Font management (кастомные шрифты)
- [ ] Анимации (easing hover/active)

## License

See [LICENSE](LICENSE).
