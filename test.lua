UILib v2 - Roblox UI library (client-side ModuleScript)
	Put in ReplicatedStorage as "UILib". Require from a LocalScript.

	Icons: Lucide (https://lucide.dev) through latte-soft/lucide-roblox.
	Put its module in ReplicatedStorage named "Lucide", or pass it: UILib.new(title, { Lucide = module })
	Icon args accept a Lucide name ("home"), "rbxassetid://123" or a number.

	Window options:
		Size       UDim2 offset size            (default 560x380)
		MinSize    Vector2                      (default 380x240)
		MaxSize    Vector2                      (default 900x700)
		Icon       icon shown in title bar
		ToggleKey  Enum.KeyCode to show/hide
		Profile    false to hide bottom-left profile card
		Theme      table overriding theme colors (Accent, Background, ...)
		Lucide     Lucide module
		Intro      {
			Image = "rbxassetid://..." | number,
			Sound = "rbxassetid://..." | number,
			Volume = 1, Duration = 2.5, Title = "text",
			ImageSize = Vector2.new(160, 160), Skippable = true,
		}

	API:
		window:AddTab(name, icon) -> page   (page has the same Add* methods)
		window/page:AddSection(title, icon)
		window/page:AddLabel(text, icon)
		window/page:AddButton(text, callback, icon)
		window/page:AddToggle(text, default, callback, icon)
		window/page:AddSlider(text, min, max, default, callback, icon)
		window/page:AddTextBox(placeholder, callback, icon)
		window:Notify(text, duration, icon)
		window:SetVisible(bool), window:Destroy()
	Do not mix window:Add* and window:AddTab(): once a tab exists, window:Add* is hidden.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Library = {}
Library.__index = Library

local Page = {}
Page.__index = Page

local TITLE_H = 40
local SIDEBAR_W = 132

local DefaultTheme = {
	Background = Color3.fromRGB(17, 17, 23),
	BackgroundTop = Color3.fromRGB(26, 26, 36),
	Surface = Color3.fromRGB(27, 27, 37),
	SurfaceHover = Color3.fromRGB(38, 38, 52),
	Border = Color3.fromRGB(54, 54, 72),
	Accent = Color3.fromRGB(124, 92, 255),
	Text = Color3.fromRGB(236, 236, 244),
	SubText = Color3.fromRGB(145, 145, 165),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
}

local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLOW = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

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
	local corner = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 8)
	return create("UICorner", { CornerRadius = corner }, parent)
end

local function stroke(parent, color, transparency, thickness)
	return create("UIStroke", {
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function padding(parent, amount)
	local p = UDim.new(0, amount)
	return create("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p }, parent)
end

local function tween(inst, goal, info)
	local t = TweenService:Create(inst, info or FAST, goal)
	t:Play()
	return t
end

local function toAsset(value)
	if type(value) == "number" or (type(value) == "string" and tonumber(value)) then
		return "rbxassetid://" .. value
	end
	return value
end

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function resolveLucide(provided)
	if provided then
		return provided
	end
	local module = ReplicatedStorage:FindFirstChild("Lucide")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			return result
		end
		warn("[UILib] failed to load Lucide module: " .. tostring(result))
		return nil
	end
	warn("[UILib] Lucide module not found in ReplicatedStorage. Icons by name are disabled.")
	return nil
end

-- page components -------------------------------------------------------

function Page.new(window, name)
	local self = setmetatable({}, Page)
	self.Window = window
	self.Content = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = window.Theme.Border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, window.Pages)
	padding(self.Content, 10)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, self.Content)
	return self
end

function Page:Select()
	if self._tabButton then
		self.Window:_selectTab(self)
	end
end

function Page:_row(height, clickable)
	local theme = self.Window.Theme
	local row = create(clickable and "TextButton" or "Frame", {
		Size = UDim2.new(1, 0, 0, height or 38),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
	}, self.Content)
	if clickable then
		row.AutoButtonColor = false
		row.Text = ""
	end
	round(row, 8)
	local line = stroke(row, theme.Border, 0.5)
	return row, line
end

function Page:_hoverable(row, line)
	local theme = self.Window.Theme
	row.MouseEnter:Connect(function()
		tween(row, { BackgroundColor3 = theme.SurfaceHover })
		tween(line, { Color = theme.Accent, Transparency = 0.2 })
	end)
	row.MouseLeave:Connect(function()
		tween(row, { BackgroundColor3 = theme.Surface })
		tween(line, { Color = theme.Border, Transparency = 0.5 })
	end)
end

function Page:AddSection(title, icon)
	local window = self.Window
	local theme = window.Theme
	local holder = create("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 }, self.Content)
	local x = 2
	if window:_icon(holder, icon, 14, { Position = UDim2.new(0, 2, 0.5, -7), ImageColor3 = theme.Accent }) then
		x = 22
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -x, 1, 0),
		BackgroundTransparency = 1,
		Text = string.upper(title),
		TextColor3 = theme.SubText,
		Font = theme.FontBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)
end

function Page:AddLabel(text, icon)
	local window = self.Window
	local theme = window.Theme
	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, self.Content)
	local x = 2
	if window:_icon(holder, icon, 16, { Position = UDim2.new(0, 2, 0, 1), ImageColor3 = theme.SubText }) then
		x = 24
	end
	local label = create("TextLabel", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -x, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)
	return {
		Set = function(_, newText)
			label.Text = newText
		end,
	}
end

function Page:AddButton(text, callback, icon)
	local window = self.Window
	local theme = window.Theme
	local button, line = self:_row(38, true)
	self:_hoverable(button, line)

	local x = 14
	if window:_icon(button, icon, 18, { Position = UDim2.new(0, 12, 0.5, -9), ImageColor3 = theme.Accent }) then
		x = 40
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -(x + 34), 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, button)
	window:_icon(button, "chevron-right", 16, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		ImageColor3 = theme.SubText,
	})

	button.MouseButton1Down:Connect(function()
		tween(button, { BackgroundColor3 = theme.Accent }, TweenInfo.new(0.08))
	end)
	button.MouseButton1Up:Connect(function()
		tween(button, { BackgroundColor3 = theme.SurfaceHover })
	end)
	button.Activated:Connect(function()
		if callback then
			task.spawn(callback)
		end
	end)
	return button
end

function Page:AddToggle(text, default, callback, icon)
	local window = self.Window
	local theme = window.Theme
	local state = default == true
	local row, line = self:_row(38, true)
	self:_hoverable(row, line)

	local x = 14
	if window:_icon(row, icon, 18, { Position = UDim2.new(0, 12, 0.5, -9), ImageColor3 = theme.Accent }) then
		x = 40
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -(x + 60), 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local pill = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = state and theme.Accent or theme.Border,
		BorderSizePixel = 0,
	}, row)
	round(pill, UDim.new(1, 0))

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = theme.Text,
		BorderSizePixel = 0,
	}, pill)
	round(knob, UDim.new(1, 0))

	local function set(value, fire)
		state = value
		tween(pill, { BackgroundColor3 = state and theme.Accent or theme.Border })
		tween(knob, { Position = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
		if fire and callback then
			task.spawn(callback, state)
		end
	end

	row.Activated:Connect(function()
		set(not state, true)
	end)

	return {
		Set = function(_, value)
			set(value == true, true)
		end,
		Get = function()
			return state
		end,
	}
end

function Page:AddSlider(text, min, max, default, callback, icon)
	local window = self.Window
	local theme = window.Theme
	local value = min
	local row, line = self:_row(56)
	self:_hoverable(row, line)

	local x = 14
	if window:_icon(row, icon, 18, { Position = UDim2.new(0, 12, 0, 9), ImageColor3 = theme.Accent }) then
		x = 40
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(x, 8),
		Size = UDim2.new(1, -(x + 70), 0, 20),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	local valueLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(60, 20),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.Accent,
		Font = theme.FontBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)

	-- hit area is taller than the bar so it is easy to grab on touch
	local hit = create("TextButton", {
		Position = UDim2.new(0, 14, 1, -26),
		Size = UDim2.new(1, -28, 0, 22),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, row)
	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = theme.Border,
		BorderSizePixel = 0,
	}, hit)
	round(bar, UDim.new(1, 0))
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
	}, bar)
	round(fill, UDim.new(1, 0))
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = theme.Text,
		BorderSizePixel = 0,
	}, bar)
	round(knob, UDim.new(1, 0))
	stroke(knob, theme.Accent, 0, 2)

	local function apply(newValue, fire)
		value = math.clamp(math.floor(newValue + 0.5), min, max)
		local alpha = (value - min) / math.max(max - min, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = tostring(value)
		if fire and callback then
			task.spawn(callback, value)
		end
	end
	apply(default or min, false)

	local function setFromX(posX)
		local alpha = math.clamp((posX - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
		apply(min + (max - min) * alpha, true)
	end

	local sliding = false
	hit.InputBegan:Connect(function(input)
		if isPointer(input) then
			sliding = true
			setFromX(input.Position.X)
		end
	end)
	table.insert(window._connections, UserInputService.InputChanged:Connect(function(input)
		if sliding and isMove(input) then
			setFromX(input.Position.X)
		end
	end))
	table.insert(window._connections, UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then
			sliding = false
		end
	end))

	return {
		Set = function(_, newValue)
			apply(newValue, true)
		end,
		Get = function()
			return value
		end,
	}
end

function Page:AddTextBox(placeholder, callback, icon)
	local window = self.Window
	local theme = window.Theme
	local row, line = self:_row(38)

	local x = 14
	if window:_icon(row, icon, 18, { Position = UDim2.new(0, 12, 0.5, -9), ImageColor3 = theme.SubText }) then
		x = 40
	end
	local box = create("TextBox", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -(x + 12), 1, 0),
		BackgroundTransparency = 1,
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = theme.SubText,
		Text = "",
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	}, row)

	box.Focused:Connect(function()
		tween(line, { Color = theme.Accent, Transparency = 0 })
	end)
	box.FocusLost:Connect(function(enterPressed)
		tween(line, { Color = theme.Border, Transparency = 0.5 })
		if callback then
			task.spawn(callback, box.Text, enterPressed)
		end
	end)
	return box
end

-- window ----------------------------------------------------------------

function Library:_icon(parent, name, size, props)
	if not name then
		return nil
	end
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromOffset(size, size)
	image.ImageColor3 = self.Theme.Text

	if type(name) == "number" or tonumber(name) or string.find(name, "^rbx") then
		image.Image = toAsset(name)
	else
		if not self._lucide then
			image:Destroy()
			return nil
		end
		local ok, asset = pcall(self._lucide.GetAsset, name, 48)
		if not ok or not asset then
			warn(('[UILib] unknown Lucide icon "%s"'):format(name))
			image:Destroy()
			return nil
		end
		image.Image = asset.Url
		image.ImageRectSize = asset.ImageRectSize
		image.ImageRectOffset = asset.ImageRectOffset
	end

	for key, value in pairs(props or {}) do
		image[key] = value
	end
	image.Parent = parent
	return image
end

function Library.new(title, options)
	options = options or {}
	local self = setmetatable({}, Library)
	self.Theme = table.clone(DefaultTheme)
	for key, value in pairs(options.Theme or {}) do
		self.Theme[key] = value
	end
	self._connections = {}
	self._tabs = {}
	self._lucide = resolveLucide(options.Lucide)
	local theme = self.Theme

	local size = options.Size or UDim2.fromOffset(560, 380)
	local minSize = options.MinSize or Vector2.new(380, 240)
	local maxSize = options.MaxSize or Vector2.new(900, 700)

	self.Gui = create("ScreenGui", {
		Name = "UILib",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))

	-- main frame
	self.Main = create("Frame", {
		Name = "Main",
		Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
		Size = size,
		BackgroundColor3 = Color3.new(1, 1, 1), -- real colors come from the gradient
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
	}, self.Gui)
	round(self.Main, 12)
	stroke(self.Main, theme.Border, 0.2)
	create("UIGradient", {
		Color = ColorSequence.new(theme.BackgroundTop, theme.Background),
		Rotation = 90,
	}, self.Main)
	self._scale = create("UIScale", { Scale = 0.92 }, self.Main)

	-- title bar
	local bar = create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, TITLE_H),
		BackgroundTransparency = 1,
	}, self.Main)
	create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.Border,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, bar)

	local titleX = 14
	if self:_icon(bar, options.Icon, 18, { Position = UDim2.new(0, 14, 0.5, -9), ImageColor3 = theme.Accent }) then
		titleX = 40
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(titleX, 0),
		Size = UDim2.new(1, -(titleX + 76), 1, 0),
		BackgroundTransparency = 1,
		Text = title or "Window",
		TextColor3 = theme.Text,
		Font = theme.FontBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, bar)

	local function barButton(iconName, fallback, index)
		local button = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8 - (index - 1) * 30, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = theme.SurfaceHover,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
		}, bar)
		round(button, 6)
		local icon = self:_icon(button, iconName, 16, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = theme.SubText,
		})
		if not icon then
			button.Text = fallback
			button.TextColor3 = theme.SubText
			button.Font = theme.Font
			button.TextSize = 14
		end
		button.MouseEnter:Connect(function()
			tween(button, { BackgroundTransparency = 0 })
		end)
		button.MouseLeave:Connect(function()
			tween(button, { BackgroundTransparency = 1 })
		end)
		return button
	end
	local closeButton = barButton("x", "X", 1)
	local minimizeButton = barButton("minus", "-", 2)

	-- body: sidebar (only when tabs exist) + pages
	self.Body = create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, TITLE_H),
		Size = UDim2.new(1, 0, 1, -TITLE_H),
		BackgroundTransparency = 1,
	}, self.Main)

	self.Sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SIDEBAR_W, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
	}, self.Body)
	create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = theme.Border,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, self.Sidebar)
	self.TabList = create("ScrollingFrame", {
		Size = UDim2.new(1, -1, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, self.Sidebar)
	padding(self.TabList, 8)
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, self.TabList)

	self.Pages = create("Frame", {
		Name = "Pages",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, self.Body)
	self._defaultPage = Page.new(self, "Default")

	-- resize grip (bottom-right)
	self.Grip = create("TextButton", {
		Name = "ResizeGrip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	}, self.Main)
	local gripIcon = self:_icon(self.Grip, "grip", 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageColor3 = theme.SubText,
		ImageTransparency = 0.3,
		ZIndex = 5,
	})
	if not gripIcon then
		self.Grip.Text = "◢"
		self.Grip.TextColor3 = theme.SubText
		self.Grip.Font = theme.Font
		self.Grip.TextSize = 12
	end

	-- notifications (bottom-right)
	self.Notifications = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(280, 400),
		BackgroundTransparency = 1,
	}, self.Gui)
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.Notifications)

	-- drag + resize --------------------------------------------------------
	local dragging, dragStart, startPos = false, nil, nil
	local resizing, resizeStart, startSize = false, nil, nil

	local function track(handle, onBegin, onEnd)
		handle.InputBegan:Connect(function(input)
			if isPointer(input) then
				onBegin(input)
				local changed
				changed = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						onEnd()
						changed:Disconnect()
					end
				end)
			end
		end)
	end

	track(bar, function(input)
		dragging = true
		dragStart = input.Position
		startPos = self.Main.Position
	end, function()
		dragging = false
	end)

	track(self.Grip, function(input)
		resizing = true
		resizeStart = input.Position
		startSize = self.Main.Size
	end, function()
		resizing = false
	end)

	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		if not isMove(input) then
			return
		end
		if dragging then
			local delta = input.Position - dragStart
			self.Main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		elseif resizing then
			local delta = input.Position - resizeStart
			self.Main.Size = UDim2.fromOffset(
				math.clamp(startSize.X.Offset + delta.X, minSize.X, maxSize.X),
				math.clamp(startSize.Y.Offset + delta.Y, minSize.Y, maxSize.Y)
			)
		end
	end))

	-- minimize / close -----------------------------------------------------
	local minimized, restoreHeight = false, nil
	minimizeButton.Activated:Connect(function()
		minimized = not minimized
		local width = self.Main.Size.X.Offset
		if minimized then
			restoreHeight = self.Main.Size.Y.Offset
			self.Grip.Visible = false
			tween(self.Main, { Size = UDim2.fromOffset(width, TITLE_H) }, SLOW)
		else
			tween(self.Main, { Size = UDim2.fromOffset(width, restoreHeight) }, SLOW)
			task.delay(0.3, function()
				if not minimized and not self._destroyed then
					self.Grip.Visible = true
				end
			end)
		end
	end)
	closeButton.Activated:Connect(function()
		self:Destroy()
	end)

	if options.ToggleKey then
		table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == options.ToggleKey then
				self:SetVisible(not self.Main.Visible)
			end
		end))
	end

	-- startup: profile card + optional intro, then open --------------------
	if options.Profile ~= false then
		self:_buildProfile()
	end
	if options.Intro then
		self:_playIntro(options.Intro, function()
			if not self._destroyed then
				self:_open()
			end
		end)
	else
		self:_open()
	end

	return self
end

function Library:_buildProfile()
	local theme = self.Theme
	local player = Players.LocalPlayer

	local card = create("CanvasGroup", {
		Name = "Profile",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(230, 58),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
	}, self.Gui)
	round(card, 12)
	stroke(card, theme.Border, 0.2)

	local avatar = create("ImageLabel", {
		Position = UDim2.new(0, 10, 0.5, -20),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Image = "",
	}, card)
	round(avatar, UDim.new(1, 0))
	stroke(avatar, theme.Accent, 0.3, 2)

	create("TextLabel", {
		Position = UDim2.fromOffset(60, 10),
		Size = UDim2.new(1, -70, 0, 20),
		BackgroundTransparency = 1,
		Text = player.DisplayName,
		TextColor3 = theme.Text,
		Font = theme.FontBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	create("TextLabel", {
		Position = UDim2.fromOffset(60, 29),
		Size = UDim2.new(1, -70, 0, 18),
		BackgroundTransparency = 1,
		Text = "@" .. player.Name,
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)

	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok and avatar.Parent then
			avatar.Image = content
		end
	end)

	self.Profile = card
end

function Library:_playIntro(intro, done)
	local theme = self.Theme

	local overlay = create("TextButton", {
		Name = "Intro",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		ZIndex = 100,
	}, self.Gui)

	local imageSize = intro.ImageSize or Vector2.new(160, 160)
	local image, title
	if intro.Image then
		image = create("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, intro.Title and -24 or 0),
			Size = UDim2.fromOffset(imageSize.X, imageSize.Y),
			BackgroundTransparency = 1,
			Image = toAsset(intro.Image),
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 101,
		}, overlay)
		local pop = create("UIScale", { Scale = 0.85 }, image)
		tween(pop, { Scale = 1 }, SLOW)
	end
	if intro.Title then
		title = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, image and (imageSize.Y / 2 - 6) or 0),
			Size = UDim2.fromOffset(500, 30),
			BackgroundTransparency = 1,
			Text = intro.Title,
			TextColor3 = theme.Text,
			TextTransparency = 1,
			Font = theme.FontBold,
			TextSize = 22,
			ZIndex = 101,
		}, overlay)
	end

	if intro.Sound then
		local sound = create("Sound", {
			Name = "IntroSound",
			SoundId = toAsset(intro.Sound),
			Volume = intro.Volume or 1,
		}, self.Gui)
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		sound:Play()
	end

	tween(overlay, { BackgroundTransparency = 0.05 }, SLOW)
	if image then
		tween(image, { ImageTransparency = 0 }, SLOW)
	end
	if title then
		tween(title, { TextTransparency = 0 }, SLOW)
	end

	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		tween(overlay, { BackgroundTransparency = 1 }, SLOW)
		if image then
			tween(image, { ImageTransparency = 1 }, SLOW)
		end
		if title then
			tween(title, { TextTransparency = 1 }, SLOW)
		end
		task.delay(0.35, function()
			overlay:Destroy()
			done()
		end)
	end

	if intro.Skippable ~= false then
		overlay.Activated:Connect(finish)
	end
	task.delay(intro.Duration or 2.5, finish)
end

function Library:_open()
	self:SetVisible(true)
	if self.Profile then
		self.Profile.Visible = true
		tween(self.Profile, { GroupTransparency = 0 }, SLOW)
	end
end

function Library:SetVisible(visible)
	if visible then
		self._scale.Scale = 0.92
		self.Main.Visible = true
		tween(self._scale, { Scale = 1 }, SLOW)
	else
		self.Main.Visible = false
	end
end

function Library:_selectTab(page)
	local theme = self.Theme
	self._activeTab = page
	for _, tab in ipairs(self._tabs) do
		local active = tab == page
		tab.Content.Visible = active
		tween(tab._tabButton, { BackgroundTransparency = active and 0.82 or 1 })
		tween(tab._tabLabel, { TextColor3 = active and theme.Text or theme.SubText })
		if tab._tabIcon then
			tween(tab._tabIcon, { ImageColor3 = active and theme.Accent or theme.SubText })
		end
	end
end

function Library:AddTab(name, icon)
	local theme = self.Theme

	if #self._tabs == 0 then
		self._defaultPage.Content.Visible = false
		self.Sidebar.Visible = true
		self.Pages.Position = UDim2.fromOffset(SIDEBAR_W, 0)
		self.Pages.Size = UDim2.new(1, -SIDEBAR_W, 1, 0)
	end

	local page = Page.new(self, name)
	page.Content.Visible = false

	local button = create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		LayoutOrder = #self._tabs + 1,
	}, self.TabList)
	round(button, 8)

	local textX = 12
	local iconImage = self:_icon(button, icon, 16, {
		Position = UDim2.new(0, 10, 0.5, -8),
		ImageColor3 = theme.SubText,
	})
	if iconImage then
		textX = 34
	end
	local label = create("TextLabel", {
		Position = UDim2.fromOffset(textX, 0),
		Size = UDim2.new(1, -(textX + 6), 1, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = theme.SubText,
		Font = theme.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, button)

	page._tabButton, page._tabLabel, page._tabIcon = button, label, iconImage

	button.MouseEnter:Connect(function()
		if self._activeTab ~= page then
			tween(button, { BackgroundTransparency = 0.93 })
		end
	end)
	button.MouseLeave:Connect(function()
		if self._activeTab ~= page then
			tween(button, { BackgroundTransparency = 1 })
		end
	end)
	button.Activated:Connect(function()
		self:_selectTab(page)
	end)

	table.insert(self._tabs, page)
	if #self._tabs == 1 then
		self:_selectTab(page)
	end
	return page
end

function Library:Notify(text, duration, icon)
	local theme = self.Theme
	local toast = create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		GroupTransparency = 1,
	}, self.Notifications)
	round(toast, 10)
	stroke(toast, theme.Border, 0.3)
	create("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
	}, toast)

	local x = 16
	if self:_icon(toast, icon or "bell", 18, { Position = UDim2.new(0, 14, 0.5, -9), ImageColor3 = theme.Accent }) then
		x = 42
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -(x + 12), 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.Text,
		Font = theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, toast)

	tween(toast, { GroupTransparency = 0 })
	task.delay(duration or 3, function()
		if self._destroyed then
			return
		end
		tween(toast, { GroupTransparency = 1 })
		task.wait(0.2)
		toast:Destroy()
	end)
end

function Library:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	self.Gui:Destroy()
end

-- window-level Add* shortcuts go to the default page (no tabs)
for _, name in ipairs({ "AddSection", "AddLabel", "AddButton", "AddToggle", "AddSlider", "AddTextBox" }) do
	Library[name] = function(self, ...)
		local page = self._defaultPage
		return page[name](page, ...)
	end
end

return Library
