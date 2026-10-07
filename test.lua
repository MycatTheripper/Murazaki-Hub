local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UILib = {}

local Theme = {
	Window = Color3.fromRGB(18, 18, 18),
	Sidebar = Color3.fromRGB(18, 18, 18),
	Content = Color3.fromRGB(22, 22, 22),
	Element = Color3.fromRGB(30, 30, 30),
	Stroke = Color3.fromRGB(46, 46, 46),
	Text = Color3.fromRGB(240, 240, 240),
	SubText = Color3.fromRGB(125, 125, 125),
	Accent = Color3.fromRGB(235, 235, 235),
	ToggleOff = Color3.fromRGB(52, 52, 52),
}

---------------------------------------------------------------- helpers

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	inst.Parent = props and props.Parent or nil
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color, thickness)
	return new("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function tween(obj, props, t)
	TweenService:Create(obj, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function fire(cb, ...)
	if cb then
		task.spawn(cb, ...)
	end
end

local function getGuiParent()
	local ok, hui = pcall(function()
		return gethui and gethui()
	end)
	if ok and hui then
		return hui
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.Gotham
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.TextSize = props.TextSize or 14
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

local function setIcon(parent, icon, size)
	if not icon or icon == "" then
		return
	end
	if tostring(icon):find("rbxasset") or tonumber(icon) then
		local id = tonumber(icon) and ("rbxassetid://" .. icon) or icon
		return new("ImageLabel", {
			Parent = parent,
			BackgroundTransparency = 1,
			Image = id,
			Size = UDim2.fromOffset(size, size),
			ImageColor3 = Theme.Text,
		})
	end
	return label({ Parent = parent, Text = icon, TextSize = size, Size = UDim2.fromOffset(size, size), TextXAlignment = Enum.TextXAlignment.Center })
end

---------------------------------------------------------------- tab elements

local Tab = {}
Tab.__index = Tab

local function base(tab, name, h)
	tab._n += 1
	local f = new("Frame", {
		Parent = tab.Page,
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = tab._n,
	}, { corner(10), stroke() })
	if name then
		label({
			Parent = f,
			Text = name,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -140, 0, h > 42 and 38 or h),
		})
		table.insert(tab._items, { Frame = f, Name = name })
	end
	return f
end

function Tab:CreateSection(text)
	self._n += 1
	label({
		Parent = self.Page,
		Text = string.upper(text),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Theme.SubText,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = self._n,
	})
end

function Tab:CreateLabel(text)
	local f = base(self, nil, 38)
	local l = label({ Parent = f, Text = text, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), TextColor3 = Theme.SubText })
	return { Set = function(_, t) l.Text = t end }
end

function Tab:CreateButton(o)
	local f = base(self, o.Name, 42)
	label({ Parent = f, Text = "›", TextSize = 22, Size = UDim2.fromOffset(30, 42), Position = UDim2.new(1, -36, 0, 0), TextColor3 = Theme.SubText })
	local b = new("TextButton", { Parent = f, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" })
	b.MouseEnter:Connect(function() tween(f, { BackgroundColor3 = Color3.fromRGB(38, 38, 38) }) end)
	b.MouseLeave:Connect(function() tween(f, { BackgroundColor3 = Theme.Element }) end)
	b.MouseButton1Click:Connect(function() fire(o.Callback) end)
end

function Tab:CreateToggle(o)
	local f = base(self, o.Name, 42)
	local state = o.Default == true
	local track = new("TextButton", {
		Parent = f,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(46, 24),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.ToggleOff,
	}, { corner(12) })
	local knob = new("Frame", {
		Parent = track,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.fromRGB(150, 150, 150),
	}, { corner(9) })

	local api = {}
	function api:Set(v, silent)
		state = v and true or false
		tween(track, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff })
		tween(knob, {
			Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = state and Theme.Window or Color3.fromRGB(150, 150, 150),
		})
		if not silent then
			fire(o.Callback, state)
		end
	end
	function api:Get() return state end

	track.MouseButton1Click:Connect(function() api:Set(not state) end)
	api:Set(state, true)
	if state then fire(o.Callback, state) end
	return api
end

function Tab:CreateSlider(o)
	local f = base(self, o.Name, 58)
	local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
	local value = min
	local val = label({
		Parent = f,
		Position = UDim2.new(1, -116, 0, 0),
		Size = UDim2.fromOffset(100, 38),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.SubText,
	})
	local bar = new("Frame", {
		Parent = f,
		Position = UDim2.new(0, 16, 1, -18),
		Size = UDim2.new(1, -32, 0, 6),
		BackgroundColor3 = Theme.ToggleOff,
	}, { corner(3) })
	local fill = new("Frame", { Parent = bar, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent }, { corner(3) })
	local hit = new("TextButton", { Parent = f, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" })

	local api = {}
	function api:Set(v, silent)
		v = math.clamp(math.round((v - min) / inc) * inc + min, min, max)
		v = tonumber(string.format("%.4f", v))
		value = v
		fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
		val.Text = tostring(v) .. (o.Suffix or "")
		if not silent then fire(o.Callback, v) end
	end
	function api:Get() return value end

	local dragging = false
	local function update(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		api:Set(min + (max - min) * a)
	end
	hit.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging = true
			update(i.Position.X)
		end
	end)
	table.insert(self._win._conns, UserInputService.InputChanged:Connect(function(i)
		if dragging and isMove(i) then update(i.Position.X) end
	end))
	table.insert(self._win._conns, UserInputService.InputEnded:Connect(function(i)
		if isPress(i) then dragging = false end
	end))

	api:Set(o.Default or min, true)
	return api
end

function Tab:CreateInput(o)
	local f = base(self, o.Name, 42)
	local box = new("TextBox", {
		Parent = f,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 26),
		BackgroundColor3 = Theme.Window,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Theme.Text,
		PlaceholderText = o.Placeholder or "...",
		PlaceholderColor3 = Theme.SubText,
		Text = o.Default or "",
		ClearTextOnFocus = false,
	}, { corner(6), stroke() })
	box.FocusLost:Connect(function(enter)
		if enter or o.CallbackOnBlur then fire(o.Callback, box.Text) end
		if o.ClearOnEnter then box.Text = "" end
	end)
	return { Set = function(_, t) box.Text = t end, Get = function() return box.Text end }
end

function Tab:CreateDropdown(o)
	local H, OPT = 42, 30
	local opts = o.Options or {}
	local f = base(self, o.Name, H)
	f.ClipsDescendants = true
	local current = o.Default
	local shown = label({
		Parent = f,
		Text = (current or "Select") .. "  ▾",
		Position = UDim2.new(1, -176, 0, 0),
		Size = UDim2.fromOffset(160, H),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.SubText,
	})
	local list = new("Frame", {
		Parent = f,
		Position = UDim2.fromOffset(0, H),
		Size = UDim2.new(1, 0, 0, #opts * OPT),
		BackgroundTransparency = 1,
	}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	local head = new("TextButton", { Parent = f, Size = UDim2.new(1, 0, 0, H), BackgroundTransparency = 1, Text = "" })

	local open = false
	local api = {}
	function api:Set(v, silent)
		current = v
		shown.Text = tostring(v) .. "  ▾"
		if not silent then fire(o.Callback, v) end
	end
	function api:Get() return current end

	local function toggle(state)
		open = state
		tween(f, { Size = UDim2.new(1, 0, 0, open and (H + #opts * OPT + 6) or H) })
	end
	for i, opt in ipairs(opts) do
		local b = new("TextButton", {
			Parent = list,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, OPT),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = Theme.SubText,
			Text = tostring(opt),
		})
		b.MouseEnter:Connect(function() b.TextColor3 = Theme.Text end)
		b.MouseLeave:Connect(function() b.TextColor3 = Theme.SubText end)
		b.MouseButton1Click:Connect(function()
			api:Set(opt)
			toggle(false)
		end)
	end
	head.MouseButton1Click:Connect(function() toggle(not open) end)
	return api
end

---------------------------------------------------------------- window

local Window = {}
Window.__index = Window

function Window:CreateTab(name, icon)
	local win = self
	local tab = setmetatable({ _n = 0, _items = {}, _win = win, Name = name }, Tab)

	tab.Button = new("TextButton", {
		Parent = win._tabList,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.Element,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = #win.Tabs + 1,
	}, { corner(10) })
	local ic = setIcon(tab.Button, icon, 18)
	if ic then
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = UDim2.new(0, 14, 0.5, 0)
	end
	tab.Title = label({
		Parent = tab.Button,
		Text = name,
		Position = UDim2.fromOffset(ic and 42 or 16, 0),
		Size = UDim2.new(1, -50, 1, 0),
		TextColor3 = Theme.SubText,
	})
	tab.Page = new("ScrollingFrame", {
		Parent = win._pages,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }),
	})

	tab.Button.MouseButton1Click:Connect(function() win:SelectTab(tab) end)
	table.insert(win.Tabs, tab)
	if #win.Tabs == 1 then win:SelectTab(tab) end
	return tab
end

function Window:SelectTab(tab)
	for _, t in ipairs(self.Tabs) do
		local on = t == tab
		t.Page.Visible = on
		tween(t.Button, { BackgroundTransparency = on and 0 or 1 })
		tween(t.Title, { TextColor3 = on and Theme.Text or Theme.SubText })
		if on then
			t.Button:FindFirstChildOfClass("UIStroke") -- keep reference simple
		end
	end
	self.Current = tab
	self._search.Text = ""
end

function Window:Minimize()
	self.Main.Visible = false
	self._pill.Visible = true
end

function Window:Show()
	self._pill.Visible = false
	self.Main.Visible = true
end

function Window:Toggle()
	if self.Main.Visible then self:Minimize() else self:Show() end
end

function Window:Destroy()
	for _, c in ipairs(self._conns) do c:Disconnect() end
	self.Gui:Destroy()
end

function UILib:CreateWindow(cfg)
	cfg = cfg or {}
	local self = setmetatable({ Tabs = {}, _conns = {} }, Window)
	local player = Players.LocalPlayer
	local size = cfg.Size or UDim2.fromOffset(685, 450)

	self.Gui = new("ScreenGui", {
		Name = cfg.Name and ("UILib_" .. cfg.Name) or "UILib",
		Parent = getGuiParent(),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
	})

	local main = new("Frame", {
		Name = "Main",
		Parent = self.Gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = Theme.Window,
		ClipsDescendants = true,
	}, { corner(20), stroke(Theme.Stroke) })
	self.Main = main

	-- top bar (drag)
	local top = new("Frame", { Parent = main, Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, Active = true })
	label({ Parent = top, Text = cfg.Name or "Window", Font = Enum.Font.GothamMedium, TextSize = 19, Position = UDim2.fromOffset(26, 12), Size = UDim2.fromOffset(300, 24) })
	label({ Parent = top, Text = cfg.Subtitle or "", TextSize = 11, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(26, 36), Size = UDim2.fromOffset(300, 14) })

	do
		local drag, startPos, startInput
		top.InputBegan:Connect(function(i)
			if isPress(i) then
				drag, startPos, startInput = true, main.Position, i.Position
			end
		end)
		table.insert(self._conns, UserInputService.InputChanged:Connect(function(i)
			if drag and isMove(i) then
				local d = i.Position - startInput
				main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end))
		table.insert(self._conns, UserInputService.InputEnded:Connect(function(i)
			if isPress(i) then drag = false end
		end))
	end

	-- top-right buttons
	local function topButton(glyph, xFromRight, cb)
		local b = new("TextButton", {
			Parent = top,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -xFromRight, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Text = glyph,
			Font = Enum.Font.GothamMedium,
			TextSize = 18,
			TextColor3 = Theme.SubText,
		})
		b.MouseEnter:Connect(function() tween(b, { TextColor3 = Theme.Text }) end)
		b.MouseLeave:Connect(function() tween(b, { TextColor3 = Theme.SubText }) end)
		b.MouseButton1Click:Connect(cb)
		return b
	end
	topButton("✕", 20, function() self:Destroy() end)
	topButton("–", 54, function() self:Minimize() end)
	topButton("⌕", 88, function()
		self._search.Visible = not self._search.Visible
		if self._search.Visible then self._search:CaptureFocus() else self._search.Text = "" end
	end)

	self._search = new("TextBox", {
		Parent = top,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -124, 0.5, 0),
		Size = UDim2.fromOffset(160, 28),
		BackgroundColor3 = Theme.Element,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Theme.Text,
		PlaceholderText = "Search...",
		PlaceholderColor3 = Theme.SubText,
		Text = "",
		ClearTextOnFocus = false,
		Visible = false,
	}, { corner(8), stroke() })
	self._search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = self._search.Text:lower()
		if not self.Current then return end
		for _, item in ipairs(self.Current._items) do
			item.Frame.Visible = q == "" or item.Name:lower():find(q, 1, true) ~= nil
		end
	end)

	-- sidebar
	self._tabList = new("ScrollingFrame", {
		Parent = main,
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.new(0, 190, 1, -66 - 70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- profile card (bottom-left)
	local card = new("Frame", {
		Parent = main,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(186, 46),
		BackgroundTransparency = 1,
	})
	local avatar = new("ImageLabel", {
		Parent = card,
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(2, 6),
		BackgroundColor3 = Theme.Element,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	label({ Parent = card, Text = player.DisplayName, Font = Enum.Font.GothamMedium, TextSize = 14, Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -50, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	label({ Parent = card, Text = "@" .. player.Name, TextSize = 11, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(46, 24), Size = UDim2.new(1, -50, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok then avatar.Image = img end
	end)

	-- content
	local content = new("Frame", {
		Parent = main,
		Position = UDim2.new(0, 214, 0, 62),
		Size = UDim2.new(1, -226, 1, -74),
		BackgroundColor3 = Theme.Content,
		ClipsDescendants = true,
	}, { corner(14), stroke() })
	self._pages = content

	-- resize handle
	local grip = new("Frame", {
		Parent = main,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 5,
	})
	label({ Parent = grip, Text = "◢", TextSize = 10, TextColor3 = Theme.Stroke, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
	do
		local rs, startSize, startMouse
		local minW, minH = cfg.MinWidth or 480, cfg.MinHeight or 320
		grip.InputBegan:Connect(function(i)
			if isPress(i) then rs, startSize, startMouse = true, main.AbsoluteSize, i.Position end
		end)
		table.insert(self._conns, UserInputService.InputChanged:Connect(function(i)
			if rs and isMove(i) then
				local d = i.Position - startMouse
				main.Size = UDim2.fromOffset(math.max(minW, startSize.X + d.X), math.max(minH, startSize.Y + d.Y))
			end
		end))
		table.insert(self._conns, UserInputService.InputEnded:Connect(function(i)
			if isPress(i) then rs = false end
		end))
	end

	-- minimized pill
	local pill = new("TextButton", {
		Parent = self.Gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(190, 46),
		BackgroundColor3 = Theme.Window,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke() })
	label({ Parent = pill, Text = cfg.Name or "Window", Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -66, 0, 18) })
	label({ Parent = pill, Text = "Tap to show", TextSize = 11, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(56, 24), Size = UDim2.new(1, -66, 0, 14) })
	label({ Parent = pill, Text = "◈", TextSize = 22, Position = UDim2.fromOffset(18, 0), Size = UDim2.fromOffset(28, 46), TextXAlignment = Enum.TextXAlignment.Center })
	pill.MouseButton1Click:Connect(function() self:Show() end)
	self._pill = pill

	-- toggle key
	local key = cfg.ToggleKey or Enum.KeyCode.RightShift
	table.insert(self._conns, UserInputService.InputBegan:Connect(function(i, gp)
		if not gp and i.KeyCode == key then self:Toggle() end
	end))

	-- intro
	if cfg.Intro then
		local intro = cfg.Intro
		local ov = new("Frame", { Parent = main, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Window, ZIndex = 50, Active = true })
		local img
		if intro.Image then
			img = new("ImageLabel", {
				Parent = ov,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(intro.ImageSize or 120, intro.ImageSize or 120),
				BackgroundTransparency = 1,
				Image = intro.Image,
				ZIndex = 51,
			})
		end
		if intro.Sound then
			local s = new("Sound", { Parent = self.Gui, SoundId = intro.Sound, Volume = intro.Volume or 0.6 })
			s:Play()
			s.Ended:Once(function() s:Destroy() end)
		end
		task.delay(intro.Time or 2.5, function()
			tween(ov, { BackgroundTransparency = 1 }, 0.4)
			if img then tween(img, { ImageTransparency = 1 }, 0.4) end
			task.wait(0.45)
			ov:Destroy()
		end)
	end

	return self
end

return UILib
