--!strict
-- Input.lua — состояние ввода за кадр.
-- Подписывается на UserInputService и собирает:
--   - mousePos (Vector2)
--   - mouseDown (bool)        — левая кнопка зажата
--   - mouseClicked (bool)     — leftMouse только что нажата в этом кадре
--   - mouseReleased (bool)    — только что отпущена
--   - mouseDoubleClicked (bool)
--   - scrollDelta (number)    — колесо мыши
--   - keyDown[keyCode]        — зажата ли клавиша
--   - keyPressed[keyCode]     — была ли нажата в этом кадре
--
-- Концептуально — это "буфер кадра". BeginFrame() обнуляет edge-флаги,
-- EndFrame() их не трогает. Между BeginFrame и EndFrame все события
-- инкрементально аккумулируются.

local UserInputService = game:GetService("UserInputService")

local Input = {}

export type InputState = {
	mousePos: Vector2,
	mousePosPrev: Vector2,
	mouseDown: boolean,
	mouseClicked: boolean,
	mouseReleased: boolean,
	mouseDoubleClicked: boolean,
	lastClickTime: number,

	scrollDelta: number,

	keyDown: { [Enum.KeyCode]: boolean },
	keyPressed: { [Enum.KeyCode]: boolean },

	-- Маппинг кнопок мыши, чтобы код был переиспользуем
	MouseButtonToKey: { [Enum.UserInputType]: Enum.KeyCode? },

	-- Подключения (connections для disconnect при Destroy)
	_connections: { RBXScriptConnection },
}

local DOUBLE_CLICK_TIME = 0.3 -- секунд

function Input.new(): InputState
	return {
		mousePos = Vector2.new(0, 0),
		mousePosPrev = Vector2.new(0, 0),
		mouseDown = false,
		mouseClicked = false,
		mouseReleased = false,
		mouseDoubleClicked = false,
		lastClickTime = 0,

		scrollDelta = 0,

		keyDown = {},
		keyPressed = {},

		MouseButtonToKey = {
			[Enum.UserInputType.MouseButton1] = Enum.KeyCode.Unknown,
			[Enum.UserInputType.MouseButton2] = Enum.KeyCode.Unknown,
			[Enum.UserInputType.MouseButton3] = Enum.KeyCode.Unknown,
		},

		_connections = {},
	}
end

function Input.Init(self: InputState)
	-- Инициализация позиции мыши
	local ok, mouseLoc = pcall(function()
		return UserInputService:GetMouseLocation()
	end)
	if ok and typeof(mouseLoc) == "Vector2" then
		self.mousePos = mouseLoc
		self.mousePosPrev = mouseLoc
	end

	-- Подписки
	local conn

	conn = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self.mousePos = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			self.scrollDelta = (input.Position.Z or 0)
		end
	end)
	table.insert(self._connections, conn)

	conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3 then
			self.mouseDown = true
			self.mouseClicked = true

			local now = os.clock()
			if now - self.lastClickTime < DOUBLE_CLICK_TIME then
				self.mouseDoubleClicked = true
			end
			self.lastClickTime = now
		elseif input.KeyCode then
			self.keyDown[input.KeyCode] = true
			self.keyPressed[input.KeyCode] = true
		end
	end)
	table.insert(self._connections, conn)

	conn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3 then
			self.mouseDown = false
			self.mouseReleased = true
		elseif input.KeyCode then
			self.keyDown[input.KeyCode] = false
		end
	end)
	table.insert(self._connections, conn)
end

-- Сбросить edge-флаги в начале кадра.
function Input.BeginFrame(self: InputState)
	self.mousePosPrev = self.mousePos
	self.mouseClicked = false
	self.mouseReleased = false
	self.mouseDoubleClicked = false
	self.scrollDelta = 0
	self.keyPressed = {}
end

function Input.Destroy(self: InputState)
	for _, c in ipairs(self._connections) do
		c:Disconnect()
	end
	table.clear(self._connections)
end

-- Хелперы
function Input.IsKeyDown(self: InputState, kc: Enum.KeyCode): boolean
	return self.keyDown[kc] == true
end

function Input.IsKeyPressed(self: InputState, kc: Enum.KeyCode): boolean
	return self.keyPressed[kc] == true
end

return Input
