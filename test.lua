-- UILib: small Roblox UI library (client-side ModuleScript)
-- Put in ReplicatedStorage as "UILib". Require from a LocalScript.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Library = {}
Library.__index = Library

local DefaultTheme = {
	Background = Color3.fromRGB(25, 25, 30),
	Surface = Color3.fromRGB(38, 38, 46),
	SurfaceHover = Color3.fromRGB(50, 50, 60),
	Accent = Color3.fromRGB(88, 130, 255),
	Text = Color3.fromRGB(235, 235, 240),
	SubText = Color3.fromRGB(150, 150, 160),
	Font = Enum.Font.GothamMedium,
}

local TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- helpers ---------------------------------------------------------------

local function create(class, props, parent)
	local inst = Instance.new(class)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function round(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function tween(inst, goal)
	TweenService:Create(inst, TWEEN, goal):Play()
end

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

-- window ----------------------------------------------------------------

function Library.new(title, options)
	options = options or {}
	local self = setmetatable({}, Library)
	self.Theme = table.clone(DefaultTheme)
	self._connections = {}
	local theme = self.Theme

	self.Gui = create("ScreenGui", {
		Name = "UILib",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))

	self.Main = create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = options.Size or UDim2.fromOffset(320, 380),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
	}, self.Gui)
	round(self.Main, 10)

	local bar = create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
	}, self.Main)

	create("TextLabel", {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = title or "Window",
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, bar)

	self.Content = create("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, self.Main)
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, self.Content)

	self.Notifications = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(260, 400),
		BackgroundTransparency = 1,
	}, self.Gui)
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.Notifications)

	-- dragging
	local dragging, dragStart, startPos = false, nil, nil
	table.insert(self._connections, bar.InputBegan:Connect(function(input)
		if isPointer(input) then
			dragging = true
			dragStart = input.Position
			startPos = self.Main.Position
			local changed
			changed = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					changed:Disconnect()
				end
			end)
		end
	end))
	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local delta = input.Position - dragStart
			self.Main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))

	-- optional toggle key
	if options.ToggleKey then
		table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == options.ToggleKey then
				self.Main.Visible = not self.Main.Visible
			end
		end))
	end

	return self
end

function Library:_row(height)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, height or 34),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
	}, self.Content)
	round(row)
	return row
end

-- components ------------------------------------------------------------

function Library:AddLabel(text)
	local theme = self.Theme
	local label = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, self.Content)
	return {
		Set = function(_, newText)
			label.Text = newText
		end,
	}
end

function Library:AddButton(text, callback)
	local theme = self.Theme
	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = text,
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
	}, self.Content)
	round(button)

	button.MouseEnter:Connect(function()
		tween(button, { BackgroundColor3 = theme.SurfaceHover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, { BackgroundColor3 = theme.Surface })
	end)
	button.Activated:Connect(function()
		if callback then
			task.spawn(callback)
		end
	end)
	return button
end

function Library:AddToggle(text, default, callback)
	local theme = self.Theme
	local state = default == true
	local row = self:_row(34)

	create("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local pill = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(36, 18),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = state and theme.Accent or theme.SurfaceHover,
		BorderSizePixel = 0,
	}, row)
	round(pill, 9)

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = theme.Text,
		BorderSizePixel = 0,
	}, pill)
	round(knob, 7)

	local function set(value, silent)
		state = value
		tween(pill, { BackgroundColor3 = state and theme.Accent or theme.SurfaceHover })
		tween(knob, { Position = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
		if callback and not silent then
			task.spawn(callback, state)
		end
	end

	pill.Activated:Connect(function()
		set(not state)
	end)

	return {
		Set = function(_, value)
			set(value)
		end,
		Get = function()
			return state
		end,
	}
end

function Library:AddSlider(text, min, max, default, callback)
	local theme = self.Theme
	local value = math.clamp(default or min, min, max)
	local row = self:_row(48)

	local label = create("TextLabel", {
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 4),
		BackgroundTransparency = 1,
		Text = text .. ": " .. tostring(value),
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local track = create("TextButton", {
		Position = UDim2.new(0, 12, 1, -14),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = theme.SurfaceHover,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, row)
	round(track, 3)

	local fill = create("Frame", {
		Size = UDim2.fromScale((value - min) / (max - min), 1),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
	}, track)
	round(fill, 3)

	local function setFromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		value = math.floor(min + (max - min) * alpha + 0.5)
		fill.Size = UDim2.fromScale((value - min) / (max - min), 1)
		label.Text = text .. ": " .. tostring(value)
		if callback then
			task.spawn(callback, value)
		end
	end

	local sliding = false
	track.InputBegan:Connect(function(input)
		if isPointer(input) then
			sliding = true
			setFromX(input.Position.X)
		end
	end)
	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		if sliding and isMove(input) then
			setFromX(input.Position.X)
		end
	end))
	table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then
			sliding = false
		end
	end))

	return {
		Get = function()
			return value
		end,
	}
end

function Library:AddTextBox(placeholder, callback)
	local theme = self.Theme
	local box = create("TextBox", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = theme.SubText,
		Text = "",
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
		ClearTextOnFocus = false,
	}, self.Content)
	round(box)

	box.FocusLost:Connect(function(enterPressed)
		if callback then
			task.spawn(callback, box.Text, enterPressed)
		end
	end)
	return box
end

function Library:Notify(text, duration)
	local theme = self.Theme
	local toast = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 1,
		TextTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
	}, self.Notifications)
	round(toast)

	tween(toast, { BackgroundTransparency = 0, TextTransparency = 0 })
	task.delay(duration or 3, function()
		tween(toast, { BackgroundTransparency = 1, TextTransparency = 1 })
		task.wait(0.2)
		toast:Destroy()
	end)
end

function Library:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	self.Gui:Destroy()
end

return Library
