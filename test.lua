local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local UILib = { Flags = {}, Icons = {}, _windows = {} }

local SHADOW_ASSET = "rbxassetid://6014261993" -- 9-slice soft shadow; swap if you prefer another

---------------------------------------------------------------- themes

UILib.Themes = {
	Default = {
		Window = Color3.fromRGB(18, 18, 18), Content = Color3.fromRGB(22, 22, 22),
		Element = Color3.fromRGB(30, 30, 30), ElementHover = Color3.fromRGB(38, 38, 38),
		Stroke = Color3.fromRGB(46, 46, 46), Text = Color3.fromRGB(240, 240, 240),
		SubText = Color3.fromRGB(125, 125, 125), Accent = Color3.fromRGB(235, 235, 235),
		AccentText = Color3.fromRGB(18, 18, 18), ToggleOff = Color3.fromRGB(52, 52, 52),
		KnobOff = Color3.fromRGB(150, 150, 150),
	},
	Ocean = {
		Window = Color3.fromRGB(12, 18, 28), Content = Color3.fromRGB(15, 23, 36),
		Element = Color3.fromRGB(22, 33, 50), ElementHover = Color3.fromRGB(28, 42, 63),
		Stroke = Color3.fromRGB(38, 56, 82), Text = Color3.fromRGB(230, 240, 255),
		SubText = Color3.fromRGB(110, 135, 170), Accent = Color3.fromRGB(64, 156, 255),
		AccentText = Color3.fromRGB(255, 255, 255), ToggleOff = Color3.fromRGB(40, 58, 85),
		KnobOff = Color3.fromRGB(130, 150, 180),
	},
	Amethyst = {
		Window = Color3.fromRGB(20, 15, 28), Content = Color3.fromRGB(25, 19, 35),
		Element = Color3.fromRGB(35, 27, 50), ElementHover = Color3.fromRGB(44, 34, 62),
		Stroke = Color3.fromRGB(58, 45, 82), Text = Color3.fromRGB(245, 238, 255),
		SubText = Color3.fromRGB(145, 125, 175), Accent = Color3.fromRGB(170, 110, 255),
		AccentText = Color3.fromRGB(255, 255, 255), ToggleOff = Color3.fromRGB(60, 47, 85),
		KnobOff = Color3.fromRGB(160, 140, 190),
	},
	Mint = {
		Window = Color3.fromRGB(14, 20, 19), Content = Color3.fromRGB(17, 25, 24),
		Element = Color3.fromRGB(24, 36, 34), ElementHover = Color3.fromRGB(30, 45, 42),
		Stroke = Color3.fromRGB(40, 62, 58), Text = Color3.fromRGB(232, 250, 245),
		SubText = Color3.fromRGB(111, 150, 140), Accent = Color3.fromRGB(52, 211, 153),
		AccentText = Color3.fromRGB(8, 30, 22), ToggleOff = Color3.fromRGB(42, 64, 60),
		KnobOff = Color3.fromRGB(130, 165, 155),
	},
	Rose = {
		Window = Color3.fromRGB(24, 15, 18), Content = Color3.fromRGB(30, 19, 23),
		Element = Color3.fromRGB(42, 27, 32), ElementHover = Color3.fromRGB(53, 34, 40),
		Stroke = Color3.fromRGB(72, 46, 54), Text = Color3.fromRGB(255, 240, 244),
		SubText = Color3.fromRGB(170, 125, 138), Accent = Color3.fromRGB(251, 113, 133),
		AccentText = Color3.fromRGB(255, 255, 255), ToggleOff = Color3.fromRGB(74, 48, 56),
		KnobOff = Color3.fromRGB(180, 140, 150),
	},
	Light = {
		Window = Color3.fromRGB(238, 238, 240), Content = Color3.fromRGB(246, 246, 248),
		Element = Color3.fromRGB(255, 255, 255), ElementHover = Color3.fromRGB(240, 240, 244),
		Stroke = Color3.fromRGB(215, 215, 222), Text = Color3.fromRGB(30, 30, 35),
		SubText = Color3.fromRGB(125, 125, 135), Accent = Color3.fromRGB(30, 30, 35),
		AccentText = Color3.fromRGB(255, 255, 255), ToggleOff = Color3.fromRGB(205, 205, 212),
		KnobOff = Color3.fromRGB(250, 250, 250),
	},
}

local Theme = {}
for k, v in pairs(UILib.Themes.Default) do
	Theme[k] = v
end

local bound = {} -- { inst, prop, key } : auto re-colored on theme change
local refreshers = {} -- functions re-run on theme change (state-dependent colors)

local function applyTheme()
	for i = #bound, 1, -1 do
		local b = bound[i]
		if b.inst.Parent == nil then
			table.remove(bound, i)
		else
			TweenService:Create(b.inst, TweenInfo.new(0.25), { [b.prop] = Theme[b.key] }):Play()
		end
	end
	for _, fn in ipairs(refreshers) do
		pcall(fn)
	end
end

function UILib:ModifyTheme(...)
	local t = select(select("#", ...), ...) -- works with Window.ModifyTheme(x) and Window:ModifyTheme(x)
	if type(t) == "string" then
		t = UILib.Themes[t]
	end
	if type(t) ~= "table" then
		return
	end
	for k, v in pairs(t) do
		if Theme[k] ~= nil then
			Theme[k] = v
		end
	end
	applyTheme()
end

---------------------------------------------------------------- helpers

local Quint, Back, Sine, Quad = Enum.EasingStyle.Quint, Enum.EasingStyle.Back, Enum.EasingStyle.Sine, Enum.EasingStyle.Quad
local Out, In, InOut = Enum.EasingDirection.Out, Enum.EasingDirection.In, Enum.EasingDirection.InOut

local function tween(obj, props, t, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t or 0.18, style or Quint, dir or Out), props)
	tw:Play()
	return tw
end

-- Color props can be "@ThemeKey" strings, e.g. BackgroundColor3 = "@Element"
local function new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		elseif type(v) == "string" and v:sub(1, 1) == "@" and k:find("Color") then
			local key = v:sub(2)
			inst[k] = Theme[key]
			table.insert(bound, { inst = inst, prop = k, key = key })
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke()
	return new("UIStroke", { Color = "@Stroke", Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function padding(t, b, l, r)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r),
	})
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

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.Gotham
	props.TextColor3 = props.TextColor3 or "@Text"
	props.TextSize = props.TextSize or 14
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

local function keyName(k)
	if typeof(k) == "EnumItem" then
		return k.Name
	end
	return tostring(k)
end

local function fadeTo(x, a, t)
	if x:IsA("TextLabel") then
		tween(x, { TextTransparency = a }, t)
	elseif x:IsA("ImageLabel") then
		tween(x, { ImageTransparency = a }, t)
	else
		tween(x, { BackgroundTransparency = a }, t)
	end
end

-- icon: number | "rbxassetid://.." | UILib.Icons[name] | short glyph/emoji
local function setIcon(parent, icon, size)
	local image, glyph
	if type(icon) == "number" and icon ~= 0 then
		image = "rbxassetid://" .. icon
	elseif type(icon) == "string" and icon ~= "" then
		if UILib.Icons[icon] then
			image = UILib.Icons[icon]
		elseif icon:find("rbxasset") then
			image = icon
		elseif (utf8.len(icon) or 99) <= 2 then
			glyph = icon
		end
	end
	if image then
		return new("ImageLabel", { Parent = parent, BackgroundTransparency = 1, Image = image, Size = UDim2.fromOffset(size, size), ImageColor3 = "@Text" })
	elseif glyph then
		return label({ Parent = parent, Text = glyph, TextSize = size, Size = UDim2.fromOffset(size, size), TextXAlignment = Enum.TextXAlignment.Center })
	end
end

---------------------------------------------------------------- notifications

local notifyHolder
local function getNotifyHolder()
	if notifyHolder and notifyHolder.Parent then
		return notifyHolder
	end
	local gui = new("ScreenGui", { Name = "UILib_Notify", Parent = getGuiParent(), ResetOnSpawn = false, DisplayOrder = 200, IgnoreGuiInset = true })
	notifyHolder = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 300, 1, -32),
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	})
	return notifyHolder
end

local notifyCount = 0
function UILib:Notify(o)
	o = o or {}
	notifyCount += 1
	local dur = o.Duration or math.clamp(#(o.Content or "") * 0.05 + 3, 3, 10)

	local wrap = new("Frame", { Parent = getNotifyHolder(), LayoutOrder = notifyCount, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	local n = new("CanvasGroup", {
		Parent = wrap,
		Position = UDim2.fromOffset(330, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = "@Element",
		GroupTransparency = 1,
	}, {
		corner(12), stroke(), padding(12, 12, 14, 14),
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({ Parent = n, LayoutOrder = 1, Text = o.Title or "Notification", Font = Enum.Font.GothamMedium, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
	if o.Content then
		label({ Parent = n, LayoutOrder = 2, Text = o.Content, TextSize = 13, TextColor3 = "@SubText", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
	end
	local bar = new("Frame", { Parent = n, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = "@Accent", BorderSizePixel = 0 }, { corner(1) })

	tween(n, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, 0.45, Quint)
	tween(bar, { Size = UDim2.new(0, 0, 0, 2) }, dur, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		tween(n, { Position = UDim2.fromOffset(330, 0), GroupTransparency = 1 }, 0.35, Quint, In)
		task.wait(0.4)
		wrap:Destroy()
	end)
end

---------------------------------------------------------------- tab elements

local Tab = {}
Tab.__index = Tab

local function base(tab, name, h)
	tab._n += 1
	local f = new("Frame", {
		Parent = tab.Page,
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = "@Element",
		LayoutOrder = tab._n,
	}, { corner(10), stroke() })
	f.MouseEnter:Connect(function() tween(f, { BackgroundColor3 = Theme.ElementHover }, 0.15) end)
	f.MouseLeave:Connect(function() tween(f, { BackgroundColor3 = Theme.Element }, 0.2) end)
	local title, item
	if name then
		title = label({
			Parent = f,
			Text = name,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -140, 0, h > 42 and 38 or h),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		item = { Frame = f, Name = name }
		table.insert(tab._items, item)
	end
	return f, title, item
end

local function flag(o, api)
	if o.Flag then
		UILib.Flags[o.Flag] = api
	end
end

function Tab:CreateSection(text)
	self._n += 1
	local l = label({
		Parent = self.Page,
		Text = string.upper(text),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = "@SubText",
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = self._n,
	})
	return { Set = function(_, t) l.Text = string.upper(t) end }
end

function Tab:CreateDivider()
	self._n += 1
	new("Frame", { Parent = self.Page, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = "@Stroke", BorderSizePixel = 0, LayoutOrder = self._n })
end

function Tab:CreateLabel(text, icon, color)
	local f = base(self, nil, 38)
	local ic = setIcon(f, icon, 16)
	if ic then
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = UDim2.new(0, 14, 0.5, 0)
	end
	local l = label({ Parent = f, Text = text, Position = UDim2.fromOffset(ic and 38 or 16, 0), Size = UDim2.new(1, -(ic and 54 or 32), 1, 0), TextColor3 = color or "@SubText", TextWrapped = true })
	local api = {}
	function api:Set(t, i, c)
		l.Text = t
		if c then l.TextColor3 = c end
	end
	return api
end

function Tab:CreateParagraph(o)
	self._n += 1
	local f = new("Frame", {
		Parent = self.Page,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = "@Element",
		LayoutOrder = self._n,
	}, { corner(10), stroke(), padding(12, 12, 16, 16), new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local t = label({ Parent = f, LayoutOrder = 1, Text = o.Title or "", Font = Enum.Font.GothamMedium, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
	local c = label({ Parent = f, LayoutOrder = 2, Text = o.Content or "", TextSize = 13, TextColor3 = "@SubText", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
	local item = { Frame = f, Name = o.Title or "" }
	table.insert(self._items, item)
	local api = {}
	function api:Set(v)
		t.Text = v.Title or t.Text
		c.Text = v.Content or c.Text
		item.Name = t.Text
	end
	return api
end

function Tab:CreateButton(o)
	local f, title = base(self, o.Name, 42)
	local st = f:FindFirstChildOfClass("UIStroke")
	local chev = label({ Parent = f, Text = "›", TextSize = 22, TextColor3 = "@SubText", Size = UDim2.fromOffset(30, 42), Position = UDim2.new(1, -36, 0, 0) })
	local b = new("TextButton", { Parent = f, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" })
	b.MouseEnter:Connect(function() tween(chev, { Position = UDim2.new(1, -30, 0, 0), TextColor3 = Theme.Text }, 0.2) end)
	b.MouseLeave:Connect(function() tween(chev, { Position = UDim2.new(1, -36, 0, 0), TextColor3 = Theme.SubText }, 0.2) end)
	b.MouseButton1Down:Connect(function() tween(st, { Color = Theme.Accent }, 0.08) end)
	b.MouseButton1Up:Connect(function() tween(st, { Color = Theme.Stroke }, 0.4) end)
	b.MouseButton1Click:Connect(function() fire(o.Callback) end)
	local api = {}
	function api:Set(t) title.Text = t end
	return api
end

function Tab:CreateToggle(o)
	local win = self._win
	local f, title = base(self, o.Name, 42)
	local state = (o.CurrentValue or o.Default) == true
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
		BackgroundColor3 = Theme.KnobOff,
	}, { corner(9) })

	local api = { CurrentValue = state, _type = "toggle" }
	local function render(t)
		tween(track, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff }, t)
		tween(knob, {
			Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = state and Theme.AccentText or Theme.KnobOff,
		}, t, Back)
	end
	function api:Set(v)
		state = v and true or false
		api.CurrentValue = state
		render(0.35)
		fire(o.Callback, state)
		win:_changed()
	end
	api._get = function() return state end
	api._set = function(v) api:Set(v) end

	track.MouseButton1Click:Connect(function() api:Set(not state) end)
	table.insert(refreshers, function() render(0.25) end)
	render(0)
	flag(o, api)
	return api
end

function Tab:CreateSlider(o)
	local win = self._win
	local f = base(self, o.Name, 58)
	local range = o.Range or { o.Min or 0, o.Max or 100 }
	local min, max, inc = range[1], range[2], o.Increment or 1
	local val = label({
		Parent = f,
		Position = UDim2.new(1, -116, 0, 0),
		Size = UDim2.fromOffset(100, 38),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = "@SubText",
	})
	local bar = new("Frame", {
		Parent = f,
		Position = UDim2.new(0, 16, 1, -19),
		Size = UDim2.new(1, -32, 0, 6),
		BackgroundColor3 = "@ToggleOff",
	}, { corner(3) })
	local fill = new("Frame", { Parent = bar, Size = UDim2.fromScale(0, 1), BackgroundColor3 = "@Accent" }, { corner(3) })
	local knob = new("Frame", {
		Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12), BackgroundColor3 = "@Accent",
	}, { corner(6), new("UIStroke", { Color = "@Element", Thickness = 2 }) })
	local hit = new("TextButton", { Parent = f, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" })

	local api = { CurrentValue = min, _type = "slider" }
	local function apply(v, t)
		v = math.clamp(math.round((v - min) / inc) * inc + min, min, max)
		v = tonumber(string.format("%.4f", v))
		api.CurrentValue = v
		local a = (v - min) / (max - min)
		tween(fill, { Size = UDim2.fromScale(a, 1) }, t)
		tween(knob, { Position = UDim2.fromScale(a, 0.5) }, t)
		val.Text = tostring(v) .. (o.Suffix and (" " .. o.Suffix) or "")
		return v
	end
	function api:Set(v)
		fire(o.Callback, apply(v, 0.12))
		win:_changed()
	end
	api._get = function() return api.CurrentValue end
	api._set = function(v) api:Set(v) end

	local dragging = false
	local function update(x)
		api:Set(min + (max - min) * math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1))
	end
	hit.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging = true
			tween(knob, { Size = UDim2.fromOffset(17, 17) }, 0.2, Back)
			update(i.Position.X)
		end
	end)
	table.insert(win._conns, UserInputService.InputChanged:Connect(function(i)
		if dragging and isMove(i) then update(i.Position.X) end
	end))
	table.insert(win._conns, UserInputService.InputEnded:Connect(function(i)
		if isPress(i) and dragging then
			dragging = false
			tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.25)
		end
	end))

	apply(o.CurrentValue or o.Default or min, 0)
	flag(o, api)
	return api
end

function Tab:CreateInput(o)
	local win = self._win
	local f = base(self, o.Name, 42)
	local box = new("TextBox", {
		Parent = f,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 26),
		BackgroundColor3 = "@Window",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = "@Text",
		PlaceholderText = o.PlaceholderText or o.Placeholder or "...",
		PlaceholderColor3 = "@SubText",
		Text = o.CurrentValue or "",
		ClearTextOnFocus = false,
	}, { corner(6) })
	local st = new("UIStroke", { Color = "@Stroke", Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box })
	box.Focused:Connect(function()
		tween(st, { Color = Theme.Accent }, 0.2)
		tween(box, { Size = UDim2.fromOffset(170, 26) }, 0.3)
	end)
	local api = { CurrentValue = box.Text, _type = "input" }
	function api:Set(t)
		box.Text = t
		api.CurrentValue = t
		fire(o.Callback, t)
		win:_changed()
	end
	api._get = function() return api.CurrentValue end
	api._set = function(t) api:Set(t) end
	box.FocusLost:Connect(function()
		tween(st, { Color = Theme.Stroke }, 0.3)
		tween(box, { Size = UDim2.fromOffset(150, 26) }, 0.3)
		api.CurrentValue = box.Text
		fire(o.Callback, box.Text)
		win:_changed()
		if o.RemoveTextAfterFocusLost then box.Text = "" end
	end)
	flag(o, api)
	return api
end

function Tab:CreateDropdown(o)
	local win = self._win
	local H, OPT = 42, 30
	local multi = o.MultipleOptions == true
	local options = o.Options or {}
	local f = base(self, o.Name, H)
	f.ClipsDescendants = true

	local api = { CurrentOption = {}, _type = "dropdown" }
	local shown = label({
		Parent = f,
		Position = UDim2.new(1, -220, 0, 0),
		Size = UDim2.fromOffset(180, H),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = "@SubText",
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local arrow = label({
		Parent = f, Text = "▾", TextSize = 16, TextColor3 = "@SubText",
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -24, 0, H / 2),
		Size = UDim2.fromOffset(20, 20), TextXAlignment = Enum.TextXAlignment.Center,
	})
	local list = new("Frame", { Parent = f, Position = UDim2.fromOffset(0, H), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y }, {
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local head = new("TextButton", { Parent = f, Size = UDim2.new(1, 0, 0, H), BackgroundTransparency = 1, Text = "" })

	local buttons = {}
	local open = false

	local function isSel(opt)
		return table.find(api.CurrentOption, opt) ~= nil
	end
	local function render()
		shown.Text = (#api.CurrentOption == 0 and "None" or table.concat(api.CurrentOption, ", "))
		for opt, b in pairs(buttons) do
			tween(b, { TextColor3 = isSel(opt) and Theme.Text or Theme.SubText }, 0.15)
		end
	end
	local function setOpen(s)
		open = s
		tween(f, { Size = UDim2.new(1, 0, 0, open and (H + #options * OPT + 6) or H) }, 0.35)
		tween(arrow, { Rotation = open and 180 or 0 }, 0.3)
	end
	local function commit()
		render()
		fire(o.Callback, api.CurrentOption)
		win:_changed()
	end
	local function normalize(v)
		local out = {}
		if type(v) == "string" then v = { v } end
		for _, x in ipairs(v or {}) do
			if table.find(out, x) == nil then table.insert(out, x) end
		end
		if not multi and #out > 1 then out = { out[1] } end
		return out
	end

	local function build()
		for _, b in pairs(buttons) do b:Destroy() end
		table.clear(buttons)
		for i, opt in ipairs(options) do
			local b = new("TextButton", {
				Parent = list, LayoutOrder = i, Size = UDim2.new(1, 0, 0, OPT), BackgroundTransparency = 1,
				Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = "@SubText", Text = tostring(opt),
			})
			buttons[opt] = b
			b.MouseEnter:Connect(function() if not isSel(opt) then tween(b, { TextColor3 = Theme.Text }, 0.12) end end)
			b.MouseLeave:Connect(function() if not isSel(opt) then tween(b, { TextColor3 = Theme.SubText }, 0.12) end end)
			b.MouseButton1Click:Connect(function()
				if multi then
					local idx = table.find(api.CurrentOption, opt)
					if idx then table.remove(api.CurrentOption, idx) else table.insert(api.CurrentOption, opt) end
				else
					api.CurrentOption = { opt }
					setOpen(false)
				end
				commit()
			end)
		end
		render()
	end

	function api:Set(v)
		api.CurrentOption = normalize(v)
		commit()
	end
	function api:Refresh(newOptions)
		options = newOptions or {}
		build()
		if open then setOpen(true) end
	end
	api._get = function() return api.CurrentOption end
	api._set = function(v) api:Set(v) end

	head.MouseButton1Click:Connect(function() setOpen(not open) end)
	table.insert(refreshers, render)
	api.CurrentOption = normalize(o.CurrentOption)
	build()
	flag(o, api)
	return api
end

function Tab:CreateKeybind(o)
	local win = self._win
	local f = base(self, o.Name, 42)
	local key = keyName(o.CurrentKeybind or "Q")
	local listening = false
	local btn = new("TextButton", {
		Parent = f,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(80, 26),
		BackgroundColor3 = "@Window",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = "@Text",
		Text = key,
		AutoButtonColor = false,
	}, { corner(6) })
	local st = new("UIStroke", { Color = "@Stroke", Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn })
	local api = { CurrentKeybind = key, _type = "keybind" }
	function api:Set(k)
		key = keyName(k)
		api.CurrentKeybind = key
		btn.Text = key
		tween(st, { Color = Theme.Stroke }, 0.3)
		fire(o.Callback, key) -- like Rayfield: callback receives the new key name on rebind
		win:_changed()
	end
	api._get = function() return key end
	api._set = function(k) api:Set(k) end

	btn.MouseButton1Click:Connect(function()
		listening = true
		btn.Text = "..."
		tween(st, { Color = Theme.Accent }, 0.2)
	end)
	table.insert(win._conns, UserInputService.InputBegan:Connect(function(i, gp)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if listening then
			listening = false
			api:Set(i.KeyCode.Name)
		elseif not gp and i.KeyCode.Name == key then
			tween(st, { Color = Theme.Accent }, 0.08)
			task.delay(0.12, function() tween(st, { Color = Theme.Stroke }, 0.3) end)
			if o.HoldToInteract then fire(o.Callback, true) else fire(o.Callback) end
		end
	end))
	table.insert(win._conns, UserInputService.InputEnded:Connect(function(i)
		if o.HoldToInteract and i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode.Name == key then
			fire(o.Callback, false)
		end
	end))
	flag(o, api)
	return api
end

function Tab:CreateColorPicker(o)
	local win = self._win
	local H, FULL = 42, 192
	local f = base(self, o.Name, H)
	f.ClipsDescendants = true
	local h, s, v = Color3.toHSV(o.Color or Color3.new(1, 1, 1))

	local swatch = new("TextButton", {
		Parent = f, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(46, 26), Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.fromHSV(h, s, v),
	}, { corner(6), stroke() })

	local sv = new("Frame", {
		Parent = f, Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 100),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1), Active = true,
	}, { corner(6) })
	new("Frame", { Parent = sv, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, {
		corner(6), new("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
	})
	new("Frame", { Parent = sv, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, {
		corner(6), new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }),
	})
	local svMark = new("Frame", {
		Parent = sv, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }) })

	local stops = {}
	for i = 0, 6 do
		table.insert(stops, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
	end
	local hue = new("Frame", {
		Parent = f, Position = UDim2.fromOffset(14, 164), Size = UDim2.new(1, -28, 0, 14),
		BackgroundColor3 = Color3.new(1, 1, 1), Active = true,
	}, { corner(7), new("UIGradient", { Color = ColorSequence.new(stops) }) })
	local hueMark = new("Frame", {
		Parent = hue, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { corner(3), new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }) })

	local api = { Color = Color3.fromHSV(h, s, v), _type = "color" }
	local function render()
		local c = Color3.fromHSV(h, s, v)
		api.Color = c
		swatch.BackgroundColor3 = c
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svMark.Position = UDim2.fromScale(s, 1 - v)
		hueMark.Position = UDim2.fromScale(h, 0.5)
	end
	local function changed()
		render()
		fire(o.Callback, api.Color)
		win:_changed()
	end
	function api:Set(c)
		h, s, v = Color3.toHSV(c)
		changed()
	end
	api._get = function()
		local c = api.Color
		return { math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255) }
	end
	api._set = function(t)
		if type(t) == "table" then api:Set(Color3.fromRGB(t[1] or 255, t[2] or 255, t[3] or 255)) end
	end

	local mode
	local function update(pos)
		if mode == "sv" then
			s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		elseif mode == "hue" then
			h = math.clamp((pos.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1)
		else
			return
		end
		changed()
	end
	sv.InputBegan:Connect(function(i) if isPress(i) then mode = "sv"; update(i.Position) end end)
	hue.InputBegan:Connect(function(i) if isPress(i) then mode = "hue"; update(i.Position) end end)
	table.insert(win._conns, UserInputService.InputChanged:Connect(function(i)
		if mode and isMove(i) then update(i.Position) end
	end))
	table.insert(win._conns, UserInputService.InputEnded:Connect(function(i)
		if isPress(i) then mode = nil end
	end))

	local open = false
	swatch.MouseButton1Click:Connect(function()
		open = not open
		tween(f, { Size = UDim2.new(1, 0, 0, open and FULL or H) }, 0.4)
	end)
	render()
	flag(o, api)
	return api
end

---------------------------------------------------------------- window

local Window = {}
Window.__index = Window

function Window:_restyleTabs()
	for _, t in ipairs(self._allTabs) do
		local on = t == self.Current
		local c = on and Theme.Text or Theme.SubText
		tween(t.Title, { TextColor3 = c }, 0.25)
		if t.Icon then
			tween(t.Icon, { [t.Icon:IsA("ImageLabel") and "ImageColor3" or "TextColor3"] = c }, 0.25)
		end
	end
end

function Window:_movePill(tab, instant)
	local idx = (tab == self._settings) and (#self.Tabs + 1) or table.find(self.Tabs, tab)
	if not idx then return end
	local y = (idx - 1) * 44 - self._tabList.CanvasPosition.Y
	local first = not self._tabPill.Visible
	self._tabPill.Visible = true
	tween(self._tabPill, { Position = UDim2.fromOffset(0, y) }, (instant or first) and 0 or 0.35, Quint)
end

function Window:SelectTab(tab)
	local changed = self.Current ~= tab
	self.Current = tab
	for _, t in ipairs(self._allTabs) do
		if t ~= tab then t.Holder.Visible = false end
	end
	if changed then
		tab.Holder.GroupTransparency = 1
		tab.Holder.Position = UDim2.fromOffset(0, 18)
		tab.Holder.Visible = true
		tween(tab.Holder, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.4)
	end
	self:_movePill(tab)
	self:_restyleTabs()
	self._search.Text = ""
	for _, item in ipairs(tab._items) do
		item.Frame.Visible = true
	end
end

function Window:_makeTab(name, icon, order)
	local win = self
	local tab = setmetatable({ _n = 0, _items = {}, _win = win, Name = name }, Tab)

	tab.Button = new("TextButton", {
		Parent = win._tabList,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
	})
	local ic = setIcon(tab.Button, icon, 18)
	tab.Icon = ic
	if ic then
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = UDim2.new(0, 14, 0.5, 0)
		if ic:IsA("ImageLabel") then ic.ImageColor3 = Theme.SubText else ic.TextColor3 = Theme.SubText end
	end
	tab.Title = label({
		Parent = tab.Button,
		Text = name,
		Position = UDim2.fromOffset(ic and 42 or 16, 0),
		Size = UDim2.new(1, -50, 1, 0),
		TextColor3 = Theme.SubText,
	})
	tab.Button.MouseEnter:Connect(function()
		if win.Current ~= tab then
			tween(tab.Title, { TextColor3 = Theme.Text }, 0.15)
			if ic then tween(ic, { [ic:IsA("ImageLabel") and "ImageColor3" or "TextColor3"] = Theme.Text }, 0.15) end
		end
	end)
	tab.Button.MouseLeave:Connect(function()
		if win.Current ~= tab then
			tween(tab.Title, { TextColor3 = Theme.SubText }, 0.2)
			if ic then tween(ic, { [ic:IsA("ImageLabel") and "ImageColor3" or "TextColor3"] = Theme.SubText }, 0.2) end
		end
	end)

	tab.Holder = new("CanvasGroup", { Parent = win._pages, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
	tab.Page = new("ScrollingFrame", {
		Parent = tab.Holder,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = "@Stroke",
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		padding(12, 12, 12, 14),
	})
	tab.Button.MouseButton1Click:Connect(function() win:SelectTab(tab) end)
	table.insert(win._allTabs, tab)
	return tab
end

function Window:CreateTab(name, icon)
	local tab = self:_makeTab(name, icon, #self.Tabs + 1)
	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	elseif self.Current then
		self:_movePill(self.Current, true) -- settings tab shifts down when tabs are added
	end
	return tab
end

function Window:_animate(show)
	self._token = (self._token or 0) + 1
	local tk = self._token
	if show then
		self.Main.Visible = true
		self._scale.Scale = 0.9
		self._shadow.ImageTransparency = 1
		tween(self._scale, { Scale = 1 }, 0.45, Back)
		tween(self._shadow, { ImageTransparency = 0.5 }, 0.45)
	else
		tween(self._scale, { Scale = 0.92 }, 0.2, Quad, In)
		tween(self._shadow, { ImageTransparency = 1 }, 0.2)
		task.delay(0.2, function()
			if tk == self._token then self.Main.Visible = false end
		end)
	end
end

function Window:Minimize()
	self:_animate(false)
	self._pill.Visible = true
	self._pillScale.Scale = 0.6
	tween(self._pillScale, { Scale = 1 }, 0.45, Back)
end

function Window:Show()
	self._pill.Visible = false
	self:_animate(true)
end

function Window:SetVisibility(v)
	self._pill.Visible = false
	self:_animate(v and true or false)
end

function Window:IsVisible()
	return self.Main.Visible
end

function Window:Toggle()
	self:SetVisibility(not self.Main.Visible)
end

function Window:Notify(o)
	UILib:Notify(o)
end

function Window:_changed()
	local c = self._config
	if self._loading or not (c and c.Enabled) then
		return
	end
	self._saveToken = (self._saveToken or 0) + 1
	local token = self._saveToken
	task.delay(0.6, function()
		if token == self._saveToken then
			self:SaveConfiguration()
		end
	end)
end

local function configPath(c)
	return (c.FolderName and (c.FolderName .. "/") or "") .. (c.FileName or tostring(game.PlaceId)) .. ".json"
end

function Window:SaveConfiguration()
	local c = self._config
	if not (c and c.Enabled and writefile) then
		return false
	end
	local data = {}
	for name, api in pairs(UILib.Flags) do
		if api._get then
			data[name] = api._get()
		end
	end
	return pcall(function()
		if c.FolderName and makefolder and isfolder and not isfolder(c.FolderName) then
			makefolder(c.FolderName)
		end
		writefile(configPath(c), HttpService:JSONEncode(data))
	end)
end

function Window:LoadConfiguration()
	local c = self._config
	if not (c and c.Enabled and readfile and isfile) then
		return false
	end
	local ok, data = pcall(function()
		local path = configPath(c)
		if isfile(path) then
			return HttpService:JSONDecode(readfile(path))
		end
	end)
	if not ok or type(data) ~= "table" then
		return false
	end
	self._loading = true
	for name, value in pairs(data) do
		local api = UILib.Flags[name]
		if api and api._set then
			pcall(api._set, value)
		end
	end
	self._loading = false
	return true
end

function Window:Destroy()
	for _, c in ipairs(self._conns) do
		c:Disconnect()
	end
	local idx = table.find(UILib._windows, self)
	if idx then table.remove(UILib._windows, idx) end
	self.Gui:Destroy()
end

-- animated loading overlay: logo pulse, title/subtitle slide-fade, progress bar, fade out
function Window:_intro(body, intro)
	local total = intro.Time or 2.4
	local ov = new("Frame", { Parent = body, Size = UDim2.fromScale(1, 1), BackgroundColor3 = "@Window", ZIndex = 50, Active = true }, { corner(20) })
	local items = {}

	local logo
	if intro.Image then
		logo = new("ImageLabel", {
			Parent = ov, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -52),
			Size = UDim2.fromOffset(intro.ImageSize or 84, intro.ImageSize or 84),
			BackgroundTransparency = 1, Image = intro.Image, ImageTransparency = 1, ZIndex = 51,
		})
	else
		logo = label({
			Parent = ov, Text = "◈", TextSize = 56, TextTransparency = 1, ZIndex = 51,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -52),
			Size = UDim2.fromOffset(84, 84), TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	local pulse = new("UIScale", { Parent = logo, Scale = 0.6 })
	table.insert(items, logo)

	local title, sub
	if intro.Title then
		title = label({
			Parent = ov, Text = intro.Title, Font = Enum.Font.GothamSemibold, TextSize = 24, TextTransparency = 1, ZIndex = 51,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 34),
			Size = UDim2.new(1, -40, 0, 30), TextXAlignment = Enum.TextXAlignment.Center,
		})
		table.insert(items, title)
	end
	if intro.Subtitle then
		sub = label({
			Parent = ov, Text = intro.Subtitle, TextSize = 13, TextColor3 = "@SubText", TextTransparency = 1, ZIndex = 51,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 62),
			Size = UDim2.new(1, -40, 0, 18), TextXAlignment = Enum.TextXAlignment.Center,
		})
		table.insert(items, sub)
	end
	local track = new("Frame", {
		Parent = ov, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 98),
		Size = UDim2.fromOffset(200, 4), BackgroundColor3 = "@Stroke", BackgroundTransparency = 1, ZIndex = 51,
	}, { corner(2) })
	local fill = new("Frame", { Parent = track, Size = UDim2.fromScale(0, 1), BackgroundColor3 = "@Accent", BackgroundTransparency = 1, ZIndex = 52 }, { corner(2) })
	table.insert(items, track)
	table.insert(items, fill)

	if intro.Sound then
		local snd = new("Sound", { Parent = self.Gui, SoundId = intro.Sound, Volume = intro.Volume or 0.6 })
		snd:Play()
		snd.Ended:Once(function() snd:Destroy() end)
	end

	-- timeline
	tween(pulse, { Scale = 1 }, 0.6, Back)
	fadeTo(logo, 0, 0.4)
	task.spawn(function()
		task.wait(0.6)
		while ov.Parent do
			tween(pulse, { Scale = 1.1 }, 0.7, Sine, InOut)
			task.wait(0.7)
			tween(pulse, { Scale = 1 }, 0.7, Sine, InOut)
			task.wait(0.7)
		end
	end)
	if title then
		task.delay(0.15, function()
			title.Position = UDim2.new(0.5, 0, 0.5, 46)
			tween(title, { Position = UDim2.new(0.5, 0, 0.5, 34), TextTransparency = 0 }, 0.5)
		end)
	end
	if sub then
		task.delay(0.3, function()
			sub.Position = UDim2.new(0.5, 0, 0.5, 74)
			tween(sub, { Position = UDim2.new(0.5, 0, 0.5, 62), TextTransparency = 0 }, 0.5)
		end)
	end
	task.delay(0.35, function()
		fadeTo(track, 0, 0.3)
		fadeTo(fill, 0, 0.3)
		tween(fill, { Size = UDim2.fromScale(1, 1) }, math.max(0.5, total - 0.9), Quad, InOut)
	end)
	task.delay(total, function()
		tween(ov, { BackgroundTransparency = 1 }, 0.5)
		for _, x in ipairs(items) do
			fadeTo(x, 1, 0.35)
		end
		task.wait(0.55)
		ov:Destroy()
	end)
end

function UILib:CreateWindow(cfg)
	cfg = cfg or {}
	local self = setmetatable({ Tabs = {}, _allTabs = {}, _conns = {}, _config = cfg.ConfigurationSaving }, Window)
	table.insert(UILib._windows, self)
	UILib._last = self
	local player = Players.LocalPlayer

	if cfg.Theme then
		UILib:ModifyTheme(cfg.Theme)
	end
	self.ModifyTheme = function(...) UILib:ModifyTheme(...) end -- Window.ModifyTheme(x) or Window:ModifyTheme(x)

	self.Gui = new("ScreenGui", {
		Name = cfg.Name and ("UILib_" .. cfg.Name) or "UILib",
		Parent = getGuiParent(),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
	})

	-- root: position/size/scale holder. shadow + body live inside.
	local root = new("Frame", {
		Name = "Main",
		Parent = self.Gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = cfg.Size or UDim2.fromOffset(685, 450),
		BackgroundTransparency = 1,
		Visible = false,
	})
	self.Main = root
	self._scale = new("UIScale", { Parent = root, Scale = 0.9 })
	self._shadow = new("ImageLabel", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 56, 1, 56), BackgroundTransparency = 1, Image = SHADOW_ASSET,
		ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450), ZIndex = 0,
	})
	local body = new("Frame", {
		Name = "Body", Parent = root, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = "@Window", ClipsDescendants = true, ZIndex = 1,
	}, {
		corner(20), stroke(),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(214, 214, 214)) }),
	})

	-- top bar (drag)
	local top = new("Frame", { Parent = body, Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, Active = true })
	label({ Parent = top, Text = cfg.Name or "Window", Font = Enum.Font.GothamSemibold, TextSize = 19, Position = UDim2.fromOffset(26, 12), Size = UDim2.fromOffset(300, 24) })
	label({ Parent = top, Text = cfg.Subtitle or "", TextSize = 11, TextColor3 = "@SubText", Position = UDim2.fromOffset(26, 36), Size = UDim2.fromOffset(300, 14) })

	do
		local drag, startPos, startInput
		top.InputBegan:Connect(function(i)
			if isPress(i) then
				drag, startPos, startInput = true, root.Position, i.Position
			end
		end)
		table.insert(self._conns, UserInputService.InputChanged:Connect(function(i)
			if drag and isMove(i) then
				local d = i.Position - startInput
				root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end))
		table.insert(self._conns, UserInputService.InputEnded:Connect(function(i)
			if isPress(i) then drag = false end
		end))
	end

	local function topButton(glyph, xFromRight, hoverColor, cb)
		local b = new("TextButton", {
			Parent = top,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -xFromRight, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Text = glyph,
			Font = Enum.Font.GothamMedium,
			TextSize = 18,
			TextColor3 = "@SubText",
		})
		b.MouseEnter:Connect(function() tween(b, { TextColor3 = hoverColor or Theme.Text }, 0.15) end)
		b.MouseLeave:Connect(function() tween(b, { TextColor3 = Theme.SubText }, 0.2) end)
		b.MouseButton1Click:Connect(cb)
		return b
	end
	topButton("✕", 20, Color3.fromRGB(240, 90, 90), function()
		self:_animate(false)
		task.delay(0.25, function() self:Destroy() end)
	end)
	topButton("–", 54, nil, function() self:Minimize() end)
	local gear = topButton("⚙", 88, nil, function()
		tween(self._gear, { Rotation = self._gear.Rotation + 90 }, 0.5)
		if self._settings then self:SelectTab(self._settings) end
	end)
	self._gear = gear
	local searchBtn
	local searchOpen = false
	self._search = new("TextBox", {
		Parent = top,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -158, 0.5, 0),
		Size = UDim2.fromOffset(0, 28),
		BackgroundColor3 = "@Element",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = "@Text",
		PlaceholderText = "Search...",
		PlaceholderColor3 = "@SubText",
		Text = "",
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		Visible = false,
	}, { corner(8), stroke() })
	searchBtn = topButton("⌕", 122, nil, function()
		searchOpen = not searchOpen
		if searchOpen then
			self._search.Visible = true
			tween(self._search, { Size = UDim2.fromOffset(160, 28) }, 0.35)
			task.delay(0.1, function() self._search:CaptureFocus() end)
		else
			self._search.Text = ""
			tween(self._search, { Size = UDim2.fromOffset(0, 28) }, 0.3)
			task.delay(0.3, function() if not searchOpen then self._search.Visible = false end end)
		end
	end)
	self._search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = self._search.Text:lower()
		if not self.Current then return end
		for _, item in ipairs(self.Current._items) do
			item.Frame.Visible = q == "" or item.Name:lower():find(q, 1, true) ~= nil
		end
	end)

	-- sidebar: sliding selection pill behind the tab list
	local tabHolder = new("Frame", {
		Parent = body, Position = UDim2.fromOffset(12, 66), Size = UDim2.new(0, 190, 1, -66 - 70),
		BackgroundTransparency = 1,
	})
	self._tabPill = new("Frame", {
		Parent = tabHolder, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = "@Element", Visible = false,
	}, { corner(10), stroke() })
	self._tabList = new("ScrollingFrame", {
		Parent = tabHolder,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- profile card (bottom-left)
	local card = new("Frame", {
		Parent = body,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(186, 46),
		BackgroundTransparency = 1,
	})
	local avatar = new("ImageLabel", {
		Parent = card, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(2, 6), BackgroundColor3 = "@Element", ImageTransparency = 1,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke() })
	label({ Parent = card, Text = player.DisplayName, Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -50, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	label({ Parent = card, Text = "@" .. player.Name, TextSize = 11, TextColor3 = "@SubText", Position = UDim2.fromOffset(46, 24), Size = UDim2.new(1, -50, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok then
			avatar.Image = img
			tween(avatar, { ImageTransparency = 0 }, 0.5) -- fade avatar in when loaded
		end
	end)

	-- content
	self._pages = new("Frame", {
		Parent = body,
		Position = UDim2.new(0, 214, 0, 62),
		Size = UDim2.new(1, -226, 1, -74),
		BackgroundColor3 = "@Content",
		ClipsDescendants = true,
	}, { corner(14), stroke() })

	-- resize handle
	local grip = new("Frame", {
		Parent = body, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Active = true, ZIndex = 5,
	})
	label({ Parent = grip, Text = "◢", TextSize = 10, TextColor3 = "@Stroke", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
	do
		local rs, startSize, startMouse
		local minW, minH = cfg.MinWidth or 480, cfg.MinHeight or 320
		grip.InputBegan:Connect(function(i)
			if isPress(i) then rs, startSize, startMouse = true, root.AbsoluteSize, i.Position end
		end)
		table.insert(self._conns, UserInputService.InputChanged:Connect(function(i)
			if rs and isMove(i) then
				local d = i.Position - startMouse
				root.Size = UDim2.fromOffset(math.max(minW, startSize.X + d.X), math.max(minH, startSize.Y + d.Y))
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
		BackgroundColor3 = "@Window",
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke() })
	self._pillScale = new("UIScale", { Parent = pill })
	label({ Parent = pill, Text = cfg.Name or "Window", Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -66, 0, 18) })
	label({ Parent = pill, Text = "Tap to show", TextSize = 11, TextColor3 = "@SubText", Position = UDim2.fromOffset(56, 24), Size = UDim2.new(1, -66, 0, 14) })
	label({ Parent = pill, Text = "◈", TextSize = 22, Position = UDim2.fromOffset(18, 0), Size = UDim2.fromOffset(28, 46), TextXAlignment = Enum.TextXAlignment.Center })
	pill.MouseEnter:Connect(function() tween(self._pillScale, { Scale = 1.05 }, 0.2) end)
	pill.MouseLeave:Connect(function() tween(self._pillScale, { Scale = 1 }, 0.2) end)
	pill.MouseButton1Click:Connect(function() self:Show() end)
	self._pill = pill

	-- UI toggle key (rebindable in Settings)
	self._toggleKey = keyName(cfg.ToggleUIKeybind or "K")
	table.insert(self._conns, UserInputService.InputBegan:Connect(function(i, gp)
		if not gp and i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode.Name == self._toggleKey then
			if self.Main.Visible then self:SetVisibility(false) else self:Show() end
		end
	end))

	-- built-in Settings tab (opened by the gear button)
	self._settings = self:_makeTab("Settings", "⚙", 1000)
	self._settings:CreateKeybind({
		Name = "UI Toggle Keybind",
		CurrentKeybind = self._toggleKey,
		Callback = function(k)
			if type(k) == "string" then self._toggleKey = k end
		end,
	})
	local names = {}
	for n in pairs(UILib.Themes) do table.insert(names, n) end
	table.sort(names)
	self._settings:CreateDropdown({
		Name = "Theme",
		Options = names,
		CurrentOption = { cfg.Theme and type(cfg.Theme) == "string" and cfg.Theme or "Default" },
		Callback = function(opt) UILib:ModifyTheme(opt[1]) end,
	})

	table.insert(refreshers, function()
		if self.Main.Parent and self.Current then self:_restyleTabs() end
	end)

	-- open animation + loading intro
	self:_animate(true)
	local intro = cfg.Intro or ((cfg.LoadingTitle or cfg.LoadingSubtitle) and {} or nil)
	if intro then
		intro.Title = intro.Title or cfg.LoadingTitle
		intro.Subtitle = intro.Subtitle or cfg.LoadingSubtitle
		self:_intro(body, intro)
	end

	-- auto-load saved configuration once the UI has been built
	if self._config and self._config.Enabled then
		task.delay(1.5, function()
			if self.Gui.Parent then self:LoadConfiguration() end
		end)
	end

	return self
end

---------------------------------------------------------------- library-level shortcuts (Rayfield style)

function UILib:SaveConfiguration()
	return UILib._last and UILib._last:SaveConfiguration()
end

function UILib:LoadConfiguration()
	return UILib._last and UILib._last:LoadConfiguration()
end

function UILib:SetVisibility(v)
	for _, w in ipairs(UILib._windows) do w:SetVisibility(v) end
end

function UILib:IsVisible()
	return UILib._last ~= nil and UILib._last:IsVisible()
end

function UILib:Destroy()
	for i = #UILib._windows, 1, -1 do
		UILib._windows[i]:Destroy()
	end
	if notifyHolder and notifyHolder.Parent then
		notifyHolder.Parent:Destroy()
	end
end

return UILib
