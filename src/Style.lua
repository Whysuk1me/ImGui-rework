--!strict
-- Style.lua — цвета, отступы, размеры.
-- Тёмная тема в стиле оригинального Dear ImGui (Classic Dark).

local Style = {}

-- Тип цвета: Color3 из Roblox.
export type ImGuiCol = string -- ключ в таблице Colors
export type ImGuiStyle = {
	-- Размеры (пиксели)
	WindowPadding: Vector2,
	WindowMinSize: Vector2,
	WindowRounding: number,
	WindowBorderSize: number,
	WindowTitleAlign: Vector2,

	FramePadding: Vector2,
	FrameRounding: number,
	FrameBorderSize: number,

	ItemSpacing: Vector2,
	ItemInnerSpacing: Vector2,

	IndentSpacing: number,

	ScrollbarSize: number,
	ScrollbarRounding: number,

	GrabMinSize: number,
	GrabRounding: number,

	ButtonTextAlign: Vector2,

	-- Цвета (Color3)
	Colors: { [string]: Color3 },
}

function Style.CreateDark(): ImGuiStyle
	local c = {
		Text                    = Color3.fromRGB(255, 255, 255),
		TextDisabled            = Color3.fromRGB(128, 128, 128),

		WindowBg                = Color3.fromRGB(15, 15, 15),
		WindowBgActive          = Color3.fromRGB(20, 20, 20),
		ChildBg                 = Color3.fromRGB(0, 0, 0),
		PopupBg                 = Color3.fromRGB(20, 20, 20),
		Border                  = Color3.fromRGB(40, 40, 40),
		BorderShadow            = Color3.fromRGB(0, 0, 0),

		TitleBg                 = Color3.fromRGB(10, 10, 10),
		TitleBgActive           = Color3.fromRGB(20, 65, 120),
		TitleBgCollapsed        = Color3.fromRGB(10, 10, 10),

		Button                  = Color3.fromRGB(40, 40, 40),
		ButtonHovered           = Color3.fromRGB(55, 55, 55),
		ButtonActive            = Color3.fromRGB(30, 120, 230),

		Header                  = Color3.fromRGB(30, 30, 30),
		HeaderHovered           = Color3.fromRGB(45, 45, 45),
		HeaderActive            = Color3.fromRGB(30, 120, 230),

		Separator               = Color3.fromRGB(40, 40, 40),
		SeparatorHovered        = Color3.fromRGB(60, 60, 60),
		SeparatorActive         = Color3.fromRGB(90, 120, 230),

		ResizeGrip              = Color3.fromRGB(40, 40, 40),
		ResizeGripHovered       = Color3.fromRGB(60, 60, 60),
		ResizeGripActive        = Color3.fromRGB(90, 120, 230),

		ScrollbarBg             = Color3.fromRGB(15, 15, 15),
		ScrollbarGrab           = Color3.fromRGB(60, 60, 60),
		ScrollbarGrabHovered    = Color3.fromRGB(80, 80, 80),
		ScrollbarGrabActive     = Color3.fromRGB(120, 120, 120),

		CheckMark               = Color3.fromRGB(30, 120, 230),
		SliderGrab              = Color3.fromRGB(30, 120, 230),
		SliderGrabActive        = Color3.fromRGB(60, 150, 255),

		TextSelectedBg          = Color3.fromRGB(40, 80, 140),
	}

	return {
		WindowPadding      = Vector2.new(8, 8),
		WindowMinSize      = Vector2.new(64, 32),
		WindowRounding     = 6,
		WindowBorderSize   = 1,
		WindowTitleAlign   = Vector2.new(0, 0.5),

		FramePadding       = Vector2.new(6, 4),
		FrameRounding      = 4,
		FrameBorderSize    = 0,

		ItemSpacing        = Vector2.new(8, 4),
		ItemInnerSpacing   = Vector2.new(4, 4),

		IndentSpacing      = 16,

		ScrollbarSize      = 14,
		ScrollbarRounding  = 12,

		GrabMinSize        = 12,
		GrabRounding       = 2,

		ButtonTextAlign    = Vector2.new(0.5, 0.5),

		Colors             = c,
	}
end

return Style
